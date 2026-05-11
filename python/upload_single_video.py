"""upload_single_video.py — adapt of MusicaLeeya 05_upload_youtube.py for one mp4.

Used by orchestrator.py after the leecut pipeline emits per-language shorts.

Reads OAuth from $YOUTUBE_TOKEN_PATH (refresh token cached by oauth_login.py)
and uploads ONE video. Idempotent: writes a sidecar `<video>.uploaded.json`
with the final youtube_id; reruns return the cached URL without re-upload.

CLI usage:
    python upload_single_video.py \
        --video /path/short.mp4 \
        --title "..." --description "..." --tags tag1,tag2 \
        --thumbnail /path/thumb.jpg \
        --privacy unlisted \
        --language en
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import time
from pathlib import Path

SCOPES = [
    "https://www.googleapis.com/auth/youtube.upload",
    "https://www.googleapis.com/auth/youtube",
]
CHUNK_SIZE = 8 * 1024 * 1024  # 8 MB resumable chunks
RETRYABLE_ERRORS = (500, 502, 503, 504)


def emit(event: str, **data) -> None:
    """Print a JSONL event to stdout for the Swift caller."""
    print(json.dumps({"event": event, **data}), flush=True)


def get_youtube_client():
    from google.oauth2.credentials import Credentials
    from google.auth.transport.requests import Request
    from googleapiclient.discovery import build

    token_path = os.environ.get("YOUTUBE_TOKEN_PATH") or ""
    if not Path(token_path).exists():
        raise RuntimeError(f"OAuth token not found at {token_path} — run oauth_login.py first")

    creds = Credentials.from_authorized_user_file(token_path, SCOPES)
    if creds.expired and creds.refresh_token:
        creds.refresh(Request())
        Path(token_path).write_text(creds.to_json())
    if not creds.valid:
        raise RuntimeError("OAuth token invalid — re-run wizard")
    return build("youtube", "v3", credentials=creds, cache_discovery=False)


def upload(
    video: Path,
    title: str,
    description: str,
    tags: list[str],
    thumbnail: Path | None,
    privacy: str = "unlisted",
    language: str = "en",
    category_id: str = "22",  # People & Blogs
    youtube=None,
) -> str:
    """Upload one video. Returns YouTube URL."""
    from googleapiclient.http import MediaFileUpload
    from googleapiclient.errors import HttpError

    sidecar = video.with_suffix(video.suffix + ".uploaded.json")
    if sidecar.exists():
        cached = json.loads(sidecar.read_text())
        url = cached.get("url")
        if url:
            emit("upload_skip_cached", file=str(video), url=url)
            return url

    if youtube is None:
        youtube = get_youtube_client()

    body = {
        "snippet": {
            "title": title[:100],
            "description": description[:5000],
            "tags": tags[:30],
            "categoryId": category_id,
            "defaultLanguage": language,
            "defaultAudioLanguage": language,
        },
        "status": {
            "privacyStatus": privacy,  # unlisted / public / private
            "selfDeclaredMadeForKids": False,
            "embeddable": True,
        },
    }
    media = MediaFileUpload(str(video), chunksize=CHUNK_SIZE,
                            resumable=True, mimetype="video/mp4")

    request = youtube.videos().insert(part="snippet,status", body=body, media_body=media)
    response = None
    last_progress_pct = -10
    backoff = 2
    while response is None:
        try:
            status, response = request.next_chunk()
            if status:
                pct = int(status.progress() * 100)
                if pct - last_progress_pct >= 5:
                    emit("upload_progress", file=str(video), pct=pct)
                    last_progress_pct = pct
        except HttpError as e:
            if e.resp.status in RETRYABLE_ERRORS:
                time.sleep(min(backoff, 30))
                backoff *= 2
                continue
            raise

    video_id = response["id"]
    url = f"https://youtu.be/{video_id}"
    emit("upload_video_done", file=str(video), url=url, video_id=video_id)

    # Set thumbnail if provided
    if thumbnail and thumbnail.exists():
        try:
            youtube.thumbnails().set(videoId=video_id, media_body=str(thumbnail)).execute()
            emit("upload_thumb_set", file=str(video), thumbnail=str(thumbnail))
        except Exception as exc:
            emit("upload_thumb_failed", file=str(video), error=str(exc)[:200])

    sidecar.write_text(json.dumps({"video_id": video_id, "url": url, "ts": time.time()}))
    return url


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--video",       required=True)
    p.add_argument("--title",       required=True)
    p.add_argument("--description", default="")
    p.add_argument("--tags",        default="")
    p.add_argument("--thumbnail",   default="")
    p.add_argument("--privacy",     default="unlisted",
                   choices=["unlisted", "public", "private"])
    p.add_argument("--language",    default="en")
    args = p.parse_args()

    tags_list = [t.strip() for t in args.tags.split(",") if t.strip()]
    thumb = Path(args.thumbnail) if args.thumbnail else None

    try:
        url = upload(
            video=Path(args.video),
            title=args.title,
            description=args.description,
            tags=tags_list,
            thumbnail=thumb,
            privacy=args.privacy,
            language=args.language,
        )
        emit("done", url=url)
        return 0
    except Exception as exc:
        emit("error", error=str(exc)[:500])
        return 2


if __name__ == "__main__":
    sys.exit(main())
