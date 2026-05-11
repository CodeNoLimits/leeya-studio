# Leeya Studio

> **One Mac app. Drop a long video. Get viral shorts uploaded to YouTube.**
> Hebrew → English with Leeya's own voice cloned. 15–30 min, fully unattended.

A SwiftUI native macOS app that wraps a Python pipeline (Whisper + Gemini + ElevenLabs + ffmpeg + YouTube Data API) behind a 1-screen wizard and a single "Cut & Upload" button.

## Download

**👉 [Latest release](https://github.com/CodeNoLimits/leeya-studio/releases/latest)** — get the `Leeya-Studio-v*.zip` asset.

Direct URL (always points to newest):
```
https://github.com/CodeNoLimits/leeya-studio/releases/latest/download/Leeya-Studio.zip
```

## Install (Mac, first time)

1. Download the `.zip` from the latest release.
2. Extract to your Desktop. You get a folder `Leeya-Studio-v1.0/`.
3. **Right-click** `הפעלה ראשונה — Open First Time.command` → **Open** → click **Open** again on the macOS warning.
4. The app launches. Strip-quarantine ritual is automatic.

## Use

1. **Wizard** (first launch only):
   - Sign in with Google → opens browser OAuth → token cached in macOS Keychain.
   - Gemini API key → click **"Use David's key"** OR paste yours from [aistudio.google.com/app/apikey](https://aistudio.google.com/app/apikey).
   - ElevenLabs key → optional (Leeya's voice clone needs David's key OR skip for Gemini TTS fallback).
   - Click **"Test"** to verify Gemini key works → ✅ green = ready.
2. **Main screen**: drag a long-form `.mp4`/`.mov`/`.mkv` (up to 5 GB) onto the drop-zone.
3. Click **✂️ Cut & Upload (15–30 min)**.
4. Watch live log. Get list of clickable YouTube URLs at the end.

## What's under the hood

A Claude Code–authored pipeline wrapped in a friendly Mac UI. Enter your API keys once and the app applies the full agentic workflow on every drop:

- **Whisper-tiny MLX** transcribes Hebrew audio with word-level timestamps.
- **Gemini 2.5 Flash** scores 5–9 viral segments, validates openings/closings, translates HE→EN.
- **ElevenLabs Multilingual v2** speaks the EN translation in Leeya's own cloned voice.
- **ffmpeg + libass** cuts, reframes 9:16, burns subtitles, encodes h264 + AAC.
- **YouTube Data API v3** uploads each short as `unlisted` (you publish manually after review).

No terminal. No Python knowledge. No model downloads (everything bundled — 432 MB once).

## Source layout

```
swift/                Native Mac app (5 files, ~1100 LOC)
  LeeyaStudio.swift   App entry + AppDelegate
  WizardView.swift    First-launch onboarding
  MainView.swift      Drop-zone + progress + results
  Keychain.swift      macOS Keychain wrapper
  PythonRunner.swift  Embedded-python subprocess streamer
  Info.plist          Bundle metadata
  build.sh            Shortcut → ../build/pack.sh

python/               Orchestrator + uploader (3 files, ~400 LOC)
  orchestrator.py     Drives leecut.run_pipeline + emits JSONL events to Swift
  upload_single_video.py  YouTube resumable upload (adapted from MusicaLeeya 05_upload)
  oauth_login.py      Desktop OAuth flow → token cached
  requirements.txt    Python deps installed into bundle

vendor/               (NOT committed — pulled at build time)
  python/             python-build-standalone Python 3.11.13 arm64
  site-packages/      pre-pip-installed: google-api-client + oauthlib + mlx-whisper + ...
  ffmpeg              evermeet static (libass)
  client_secret.json  OAuth client (project musicaleeya)

build/                pack.sh → Leeya Studio.app → Leeya-Studio.zip
docs/                 Handoff notes + Hebrew README for Leeya
```

## Build from source

```bash
git clone https://github.com/CodeNoLimits/leeya-studio.git
cd leeya-studio
# Pull vendor assets (heavy — Python runtime + ffmpeg + ElevenLabs deps)
bash build/setup_vendor.sh
# Compile + package
bash build/pack.sh
# → build/release/Leeya-Studio-v1.0.zip ready to ship
```

## Publishing a new version

```bash
bash build/publish.sh v1.0.1 "Fix audio sync drift"
# → builds, tags, pushes, uploads .zip to GitHub release.
# Leeya re-downloads from the same URL — she always gets the latest.
```

## Stack

| Layer | Tech |
|---|---|
| UI | SwiftUI native, macOS 13+, arm64 |
| Subprocess driver | NSTask + Pipe + JSONL streaming |
| Secrets | macOS Keychain (service `com.dreamnova.leeyastudio`) |
| Pipeline | Python 3.11 + leecut v2.0.0 |
| Transcribe | mlx-whisper tiny (Apple Silicon) |
| LLM | Gemini 2.5 Flash + Pro fallback |
| TTS | ElevenLabs multilingual_v2 + Gemini TTS fallback |
| Encode | ffmpeg 8.1 + libass + libx264 |
| Upload | google-api-python-client (YouTube Data API v3) |
| Packaging | swiftc + codesign --sign - + ditto |

## License

Private use by Leeya + David Amor. Not for redistribution.

---

Made with ❤️ by [David](https://leeya.vercel.app) using [Claude Code](https://claude.com/claude-code).
