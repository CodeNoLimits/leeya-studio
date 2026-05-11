# Leeya Studio v1.0 · Handoff to David · 2026-05-10 21:00

## What's ready to ship NOW

📦 **`~/Desktop/leeya-studio/build/release/Leeya-Studio-v1.0.zip`** · 144 MB

Contains :
- `Leeya Studio.app` (ad-hoc signed, quarantine-stripped)
- `הפעלה ראשונה — Open First Time.command` (Gatekeeper bypass for Leeya)
- `README.md` (Hebrew + tech)

## How to send to Leeya (pick ONE)

| Channel | Steps | Risk |
|---|---|---|
| **WhatsApp** (recommended) | Drag the `.zip` from Finder onto her chat → she taps Download → moves to Desktop → extracts → right-clicks `הפעלה ראשונה.command` → **Open** | Low — quarantine bypass `.command` handles macOS warning |
| **GitHub release** | Push `~/Desktop/leeya-studio/` to a private repo `CodeNoLimits/leeya-studio-app` → create release v1.0 → upload zip → send link | Medium — she has to clone or download via web (auth) |
| **USB stick** | Copy zip to USB → physical handoff → she extracts → opens `.command` | Lowest — no quarantine bit at all |

## What you MUST do BEFORE sending (5 min)

### 1. GCP project cosmetic rename (Phase 0c)
Open `~/Desktop/leeya-studio/docs/PHASE_0C_DAVID_GCP_RENAME.md` for full steps.
TL;DR : https://console.cloud.google.com/apis/credentials/consent?project=musicaleeya
- Rename app : `Leeya Studio`
- Add Leeya's Google email as **test user** (else "unverified app" warning)

### 2. Validate the pipeline end-to-end on YOUR Mac after Gemini quota resets

Tonight's pre-flight failed because the new Gemini key hit the **20-requests-per-day** free-tier daily quota (we burned all 20 across 3 test runs). Quota resets at 00:00 UTC = ~03:00 Israel time.

**At ~03:30 Israel time** (or anytime tomorrow), run :

```bash
rm -rf /tmp/leeya_studio_preflight/pipeline /tmp/leeya_studio_preflight/shorts
python3 /tmp/leeya_studio_preflight/preflight_runner.py 2>&1 | tee preflight_final.log
```

Expected : pipeline completes step 1→11, produces `/tmp/leeya_studio_preflight/shorts/HE_no_subs/short_*.mp4` and `EN_no_subs/short_*.mp4`. Final line : `✅ PRE-FLIGHT PASSED`.

If you see `✅ PRE-FLIGHT PASSED` → ship the zip to Leeya with full confidence.
If 429 still : wait until next day OR upgrade GCP project to paid tier ($0.075/1M tokens).

### 3. Tell Leeya to create HER OWN Gemini key (1 min)

In your WhatsApp message attaching the zip, paste :

```
היי אהובה ❤️ הנה האפליקציה החדשה — Leeya Studio.

📦 חלצי את ה־zip על Desktop.
🔓 לחצי קליק ימני על "הפעלה ראשונה.command" → Open.
🌟 בויזרד, לחצי "Sign in with Google" — דפדפן יפתח לבד.

חשוב: צרי את המפתח Gemini החינמי שלך (1 דקה):
1. https://aistudio.google.com/app/apikey
2. Create API key → העתיקי
3. הדביקי בויזרד
4. לחצי "בדיקה" — אם רואה ✅, מצוין

(אם את רוצה את שלי, לחצי "Use David's key" — אבל אצלך תהיה מכסה של 20 ביום משלך.)

אחרי הויזרד, גררי וידאו ארוך, חתוך והעלה. 15-30 דקות.

נשיקות. דוד 🌹
```

## How to test on YOUR Mac without affecting Leeya's setup

```bash
# Switch to a fresh user account (System Settings → Users) named "leeya-test"
# In leeya-test, copy-and-paste the zip from a shared folder
# Extract → run הפעלה.command → wizard appears
```

Or cheat: just delete `~/Library/Application Support/LeeyaStudio/` to wipe wizard state and re-test from your own account.

```bash
rm -rf "$HOME/Library/Application Support/LeeyaStudio"
security delete-generic-password -s com.dreamnova.leeyastudio 2>/dev/null  # wipe Keychain
open "$HOME/Desktop/leeya-studio/build/Leeya Studio.app"  # wizard re-appears
```

## Architectural status

| Layer | Status |
|---|---|
| Swift native app (5 files, 1100 LOC) | ✅ Compiles, launches, window shows |
| First-launch wizard (Google + Gemini + ElevenLabs) | ✅ With "Test" button on Gemini key |
| Main view (drop-zone + Cut & Upload + log + results) | ✅ Streams JSONL events from Python |
| macOS Keychain storage | ✅ Service `com.dreamnova.leeyastudio` |
| Embedded Python 3.11.13 + 141 MB site-packages | ✅ |
| Embedded ffmpeg + whisper.cpp tiny + ggml-tiny.bin | ✅ |
| `leecut` Python package embedded verbatim from `~/Desktop/Leeya/leecut/` | ✅ |
| **api.py rate limiter** (7s between Gemini calls, override `LEEYA_GEMINI_MIN_INTERVAL`) | ✅ Patched in `~/Desktop/Leeya/leecut/api.py` — benefits LeeCut Max too |
| OAuth client (`client_secret.json` from MusicaLeeya) | ⚠️ Project rename pending Phase 0c |
| Pipeline E2E run | ⚠️ Blocked by Gemini free-tier daily quota — re-test post-reset |
| Pre-flight after quota reset | 🔜 Tomorrow morning |

## Tomorrow's hand-off checklist

- [ ] After 03:30 Israel time, re-run pre-flight, confirm ✅
- [ ] GCP cosmetic rename done (5 min in browser)
- [ ] Send zip via WhatsApp to Leeya with the Hebrew message above
- [ ] Be on standby for 30 min in case she hits a snag
- [ ] If wizard works on her end → ✅ done

## v0.2 backlog (this week)

1. **Cron-style daily Gemini quota tracking** — show "X/20 requests used today" in app
2. **Facebook + Instagram auto-post** via existing `~/Desktop/Mac M4 Max/10_SOCIAL_MEDIA/auto_poster.py`
3. **Format toggles** : 1:1 (FB feed) + 16:9 (YouTube long preview)
4. **Multi-language toggle** (FR/RU/ES) with explicit ETA warning
5. **Channel picker UI** (call `youtube.channels.list(mine=True)` ; show selector if she has access to multiple channels)
6. **Hebrew voice prompts** (Carmit) — port from `~/Desktop/leeya-os/swift/LeeyaOS.swift:76-94`
7. **Settings tab** to re-edit keys without "Reset onboarding" nuke
8. **Notification on long-running pipeline completion** (UNUserNotificationCenter)
9. **TikTok auto-post** via Selenium cookies
10. **Whisper large-v3 toggle** ("higher quality, 3 GB download once")

## Files in `~/Desktop/leeya-studio/`

```
docs/
  HANDOFF_DAVID.md                       ← you are here
  PHASE_0C_DAVID_GCP_RENAME.md           ← GCP rename steps
  PHASE_5_E2E_VALIDATION_REPORT.md       ← architecture vs runtime
  README_LEEYA.md                        ← Hebrew install guide for Leeya
swift/                                    ← 5 Swift files + Info.plist + build.sh
python/                                   ← orchestrator + upload + oauth_login + requirements.txt
vendor/                                   ← Python 3.11 runtime + site-packages + ffmpeg + whisper-cli + ggml-tiny + client_secret
build/
  Leeya Studio.app                       ← compiled app (test locally)
  Leeya Studio.zip                       ← quick zip
  release/
    Leeya-Studio-v1.0.zip                ← FINAL distribution package (144 MB)
    הפעלה ראשונה — Open First Time.command  ← Gatekeeper bypass helper
```

## Risks managed tonight

| # | Risk | Mitigation in v1.0 |
|---|---|---|
| 1 | Pipeline never validated end-to-end | Architecture validated up to step 2 (whisper). Steps 3-11 are stable code in leecut v2.0.0. Final E2E pending quota reset. |
| 2 | macOS Gatekeeper blocks unsigned `.zip` | `xattr -cr` strips quarantine + ad-hoc sign + `הפעלה ראשונה.command` helper auto-strips on Leeya's side |
| 3 | OAuth says "musicaleeya" / unverified | Phase 0c rename + add Leeya as test user (5 min, you do this) |
| 4 | Leeya thinks 25-min pipeline is broken | Wizard advertises "15-30 min" + per-step JSONL events update progress UI |
| 5 | Gemini key gets revoked / 429 | NOT embedded in binary (Keychain only after explicit consent) + new "בדיקה · Test" button validates BEFORE pipeline runs |

---

ב״ה. כל הקבצים שלך. רעב לעבוד מחר עם לאה. 🚀
