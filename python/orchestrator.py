"""orchestrator.py — drives leecut pipeline + YouTube uploads.

Reads env vars set by the Swift PythonRunner :
    - GEMINI_API_KEY              required
    - ELEVENLABS_API_KEY          optional
    - ELEVENLABS_VOICE_ID         optional
    - LEEYA_FFMPEG                bundled ffmpeg static path
    - LEEYA_PIPELINE_DIR          where intermediate state lives
    - LEEYA_SHORTS_DIR            where final mp4 land
    - YOUTUBE_TOKEN_PATH          OAuth refresh token path
    - YOUTUBE_CLIENT_SECRET       client secret JSON path

Emits one JSON event per line on stdout (event names below are stable):
    started · pipeline_start · progress · pipeline_done · upload_start ·
    upload_progress · upload_done · done · error

Exit code:
    0 = success
    1 = config / env error
    2 = pipeline failed
    3 = at least one upload failed (others may have succeeded)
"""
from __future__ import annotations

import argparse
import json
import logging
import os
import re
import sys
import time
from pathlib import Path

# ─── Embed bundled leecut + ffmpeg before importing ─────────────────────────
RESOURCES = Path(os.environ.get("LEEYA_RESOURCES", "")) or Path(__file__).resolve().parent
LEECUT_PATH = RESOURCES / "leecut"
if LEECUT_PATH.exists():
    sys.path.insert(0, str(RESOURCES))

# Ensure ffmpeg is on PATH
ffmpeg_bin = os.environ.get("LEEYA_FFMPEG")
if ffmpeg_bin and Path(ffmpeg_bin).exists():
    bin_dir = str(Path(ffmpeg_bin).parent)
    os.environ["PATH"] = bin_dir + ":" + os.environ.get("PATH", "")
    # leecut.config.FFMPEG_BIN reads this on import — but it's a Final;
    # we'll monkey-patch it after import below if needed.

# ─── Stdout JSON emitter ────────────────────────────────────────────────────


def emit(event: str, **data) -> None:
    print(json.dumps({"event": event, **data}, ensure_ascii=False), flush=True)


# ─── Map leecut log events → progress events ───────────────────────────────
PROGRESS_MAP = {
    "pipeline.start":      ("pipeline_start", "Starting pipeline…",       0.00),
    "step1.extract":       ("progress",        "Extracting audio…",        0.05),
    "step2.transcribe":    ("progress",        "Transcribing speech…",     0.10),
    "pipeline.transcribed":("progress",        "Transcript ready",         0.20),
    "score.ok":            ("progress",        "Scoring viral segments",   0.25),
    "validate.start":      ("progress",        "Validating openings",      0.35),
    "translate.start":     ("progress",        "Translating to English",   0.45),
    "tts.start":           ("progress",        "Generating voice-over…",   0.60),
    "build.start":         ("progress",        "Encoding final shorts…",   0.75),
    "thumbnails.start":    ("progress",        "Building thumbnails…",     0.85),
    "pipeline.done":       ("pipeline_done",   "Pipeline complete",        0.90),
}


class LeecutEventBridge(logging.Handler):
    """Listens to leecut's structured JSON logger and forwards as progress events."""

    def emit(self, record: logging.LogRecord) -> None:  # noqa: A003
        msg = record.getMessage()
        for trigger, (event, label, frac) in PROGRESS_MAP.items():
            if trigger in msg:
                emit(event, step=trigger, label=label, current=frac, total=1.0)
                return


def install_progress_bridge() -> None:
    bridge = LeecutEventBridge(level=logging.INFO)
    logging.getLogger("leecut").addHandler(bridge)
    logging.getLogger("leecut.pipeline").addHandler(bridge)
    logging.getLogger("leecut.pipeline").setLevel(logging.INFO)


# ─── Title / description / tags derivation from manifest ────────────────────


def slugify(s: str) -> str:
    s = re.sub(r"\s+", " ", s).strip()
    return s[:90]


def derive_title(short, lang: str) -> str:
    en_text = short.translations.get(lang.upper()) or short.translations.get(lang.lower())
    base = en_text.split("\n")[0] if en_text else (short.hook or short.title_fr or f"Short #{short.id}")
    return slugify(base)[:100]


def derive_description(short, lang: str, channel: str = "Leeya Kats") -> str:
    body = short.translations.get(lang.upper()) or short.translations.get(lang.lower()) or ""
    sig = (
        "\n\n#shorts #youtubeauthority\n"
        "Made with Leeya Studio · cut + dubbed by AI from a long-form video.\n"
        f"More: youtube.com/@{channel}"
    )
    return (body[: 5000 - len(sig)] + sig)[:5000]


def derive_tags(short) -> list[str]:
    base = ["shorts", "viral", "creator", "youtube", "authority", "leeya"]
    if short.title_fr:
        base += [w.lower() for w in short.title_fr.split() if len(w) > 3]
    return list(dict.fromkeys(base))[:25]


# ─── Find final mp4 outputs after pipeline ──────────────────────────────────


def find_outputs(shorts_dir: Path, lang: str, manifest) -> list[tuple[int, Path, Path | None]]:
    """Return list of (short_id, video_path, optional_thumbnail_path)."""
    out: list[tuple[int, Path, Path | None]] = []
    target_dirs = [
        shorts_dir / f"{lang.upper()}_no_subs",
        shorts_dir / f"{lang.upper()}_with_subs",
    ]
    thumbs_dir = shorts_dir / "thumbnails"

    for short in manifest.shorts:
        sid = short.id
        # Look for any mp4 starting with short_<sid>_ or short_<sid:02d>_
        candidate = None
        for d in target_dirs:
            if not d.exists():
                continue
            for p in sorted(d.glob(f"short_{sid:02d}_*.mp4")) + sorted(d.glob(f"short_{sid}_*.mp4")):
                candidate = p
                break
            if candidate:
                break
        if not candidate:
            continue
        thumb = None
        for ext in ("png", "jpg"):
            for pat in (f"short_{sid:02d}_{lang.upper()}_*.{ext}",
                        f"short_{sid:02d}_*_{lang.upper()}.{ext}",
                        f"short_{sid}_{lang.upper()}_*.{ext}"):
                hits = list(thumbs_dir.glob(pat)) if thumbs_dir.exists() else []
                if hits:
                    thumb = hits[0]
                    break
            if thumb:
                break
        out.append((sid, candidate, thumb))
    return out


# ─── Main entry point ───────────────────────────────────────────────────────


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--video",    required=True, help="Path to long-form source video")
    p.add_argument("--shorts",   type=int, default=5,        help="Number of shorts (advisory only — pipeline picks)")
    p.add_argument("--lang",     default="EN",                help="Target language ISO code (EN only for v1.0)")
    p.add_argument("--upload",   action="store_true",         help="Auto-upload to YouTube as $privacy")
    p.add_argument("--privacy",  default="unlisted",
                   choices=["unlisted", "public", "private"])
    args = p.parse_args()

    src = Path(args.video).expanduser().resolve()
    if not src.exists():
        emit("error", error=f"Video not found at {src}")
        return 1

    # Required env
    if not os.environ.get("GEMINI_API_KEY"):
        emit("error", error="GEMINI_API_KEY not set — re-run wizard")
        return 1

    # Persistent dirs from env (set by Swift PythonRunner)
    pipeline_dir = Path(os.environ.get("LEEYA_PIPELINE_DIR") or "/tmp/leeya_studio/pipeline")
    shorts_dir   = Path(os.environ.get("LEEYA_SHORTS_DIR")   or "/tmp/leeya_studio/shorts")
    pipeline_dir.mkdir(parents=True, exist_ok=True)
    shorts_dir.mkdir(parents=True, exist_ok=True)

    install_progress_bridge()

    emit("started", video=str(src), shorts=args.shorts, lang=args.lang,
         upload=args.upload, privacy=args.privacy,
         pipeline_dir=str(pipeline_dir), shorts_dir=str(shorts_dir))

    # ─── Patch leecut.config paths via env BEFORE importing pipeline ────────
    # The Final-typed paths in cfg are read at import time. We monkey-patch
    # by re-binding the module attributes after import, BUT since they're
    # used inside functions via cfg.PIPELINE_DIR etc., attribute reassignment
    # works as long as nothing captured them as locals.
    try:
        from leecut import config as cfg
        cfg.PIPELINE_DIR = pipeline_dir              # type: ignore[misc]
        cfg.SHORTS_DIR   = shorts_dir                # type: ignore[misc]
        if ffmpeg_bin:
            cfg.FFMPEG_BIN = ffmpeg_bin              # type: ignore[misc]
        from leecut.pipeline import run_pipeline
        from leecut.manifest import Manifest
    except Exception as exc:
        emit("error", error=f"leecut import failed: {exc}")
        return 2

    # ─── Run the pipeline ───────────────────────────────────────────────────
    try:
        run_pipeline(
            source_video=src,
            pipeline_dir=pipeline_dir,
            shorts_dir=shorts_dir,
            language="he",
            target_languages=(args.lang.upper(),),
        )
    except Exception as exc:
        emit("error", error=f"pipeline failed: {exc}")
        return 2

    # ─── Read manifest + find outputs ──────────────────────────────────────
    manifest_path = pipeline_dir / "translated_manifest.json"
    if not manifest_path.exists():
        emit("error", error=f"manifest not found at {manifest_path}")
        return 2

    manifest = Manifest.load(manifest_path)
    outputs = find_outputs(shorts_dir, args.lang, manifest)
    if not outputs:
        emit("error", error=f"no {args.lang.upper()} mp4 outputs in {shorts_dir}")
        return 2

    emit("progress", step="ready_for_upload", label=f"{len(outputs)} shorts ready",
         current=0.92, total=1.0)

    # ─── Upload loop (sequential — YouTube quota friendly) ─────────────────
    if args.upload:
        try:
            from upload_single_video import upload, get_youtube_client
            youtube = get_youtube_client()
        except Exception as exc:
            emit("error", error=f"YouTube auth failed: {exc}")
            return 3

        any_failed = False
        for idx, (sid, video_path, thumb) in enumerate(outputs, start=1):
            short = manifest.short_by_id(sid)
            title = derive_title(short, args.lang) if short else f"Short #{sid}"
            desc  = derive_description(short, args.lang) if short else ""
            tags  = derive_tags(short) if short else ["shorts"]
            emit("upload_start", file=str(video_path), title=title,
                 current=idx, total=len(outputs))
            try:
                url = upload(
                    video=video_path,
                    title=title,
                    description=desc,
                    tags=tags,
                    thumbnail=thumb,
                    privacy=args.privacy,
                    language=args.lang.lower(),
                    youtube=youtube,
                )
                emit("upload_done", file=str(video_path), url=url,
                     current=idx, total=len(outputs))
            except Exception as exc:
                any_failed = True
                emit("error", file=str(video_path), error=str(exc)[:300])
                # continue with the next short rather than abort all
                time.sleep(1)

        emit("done", uploaded=len(outputs), any_failed=any_failed,
             current=1.0, total=1.0)
        return 3 if any_failed else 0

    emit("done", uploaded=0, any_failed=False, current=1.0, total=1.0)
    return 0


if __name__ == "__main__":
    sys.exit(main())
