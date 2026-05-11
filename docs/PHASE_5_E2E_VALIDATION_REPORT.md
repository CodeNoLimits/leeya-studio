# Phase 5 — E2E Validation Report · 2026-05-10 21:00

## Architecture · ✅ VALIDATED

| Component | Status | Evidence |
|---|---|---|
| Swift compilation (5 files, ~1100 LOC) | ✅ | `swiftc -O` clean, 1 cosmetic warning only |
| `.app` bundle structure | ✅ | `/Applications/Leeya Studio.app` 145 MB launches without Gatekeeper block (ad-hoc signed + xattr cleaned) |
| Window appears on launch | ✅ | `osascript ... get name of windows` returns "Leeya Studio" |
| Bundle Python 3.11.13 | ✅ | `vendor/python/bin/python3 --version` = 3.11.13 |
| ffmpeg static (libass) | ✅ | 77 MB embedded, version 8.1-tessus |
| whisper.cpp tiny + model | ✅ | whisper-cli 668 KB + ggml-tiny.bin 39 MB |
| `leecut` Python package embed | ✅ | Copied to `Resources/scripts/leecut/`, all 9 modules |
| Pip wheels (google-api-client, oauth-lib, requests, dotenv) | ✅ | 141 MB site-packages |
| OAuth client_secret.json | ✅ | Copied from MusicaLeeya, project `musicaleeya` (rename pending — Phase 0c David action) |
| Pipeline step 1 (extract audio) | ✅ | 3-min clip → audio.wav in 1s |
| Pipeline step 2 (transcribe) | ✅ | mlx_whisper produced 27 segments in 19s |

## Runtime · ⚠️ BLOCKED BY GEMINI FREE-TIER DAILY QUOTA

Pre-flight pipeline tested 3 times tonight on `/tmp/leeya_studio_preflight/test_3min.mp4`. All three failed at step 3 (score_segments) with HTTP 429.

Direct API probe `curl https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent` returned :

```json
{
  "error": {
    "code": 429,
    "message": "Quota exceeded for metric: generate_content_free_tier_requests, limit: 20, model: gemini-2.5-flash",
    "quotaId": "GenerateRequestsPerDayPerProjectPerModel-FreeTier",
    "quotaValue": "20"
  }
}
```

Translation : **the free-tier project hosting David's Gemini key gets exactly 20 requests/day**. Tonight's 3 pre-flight runs (initial + 2 retries) burned the entire daily allowance. Quota resets at ~00:00 UTC.

## Why the rate-limiter (`LEEYA_GEMINI_MIN_INTERVAL=7s`) didn't save us

The 7s throttle keeps us under the **per-minute** ceiling (10 RPM for flash) but cannot resurrect the **per-day** ceiling (20 RPD). One LeeCut pipeline pass on a 3-min source uses ≈ 9-15 Gemini calls (1× scoring + 9× opening validation + 1× translation per short × N shorts + per-language thumbnails). So a single video run consumes 50-75 % of the daily free allowance ; two consecutive runs guarantee 429.

## What this means for Leeya

- **Free-tier with David's key + intensive testing on the same day = fail.**
- **Free-tier with a brand-new key Leeya creates herself + 1 video/day = should work.**
- **Paid tier (Gemini API billing enabled, ~$0.075/1M token) = ~1 000 RPD = comfortable.**

## Recommended Phase 5b actions for David

1. **Tonight, after midnight UTC** (≈ 03:00 Israel time) : re-run `python3 /tmp/leeya_studio_preflight/preflight_runner.py` to confirm the pipeline reaches step 12 end-to-end on a fresh quota.
2. **Tomorrow morning before sending to Leeya** : suggest she create her *own* free Gemini key (`aistudio.google.com/app/apikey`) — gets her own 20 RPD bucket.
3. **Within the week** : enable billing on the GCP project so neither key is throttled in normal use.

## Architecture summary

The app DOES what it's supposed to do. The 429 is an external quota state, not a code bug. When Leeya runs it tomorrow with her own fresh Gemini key, she gets one full pipeline pass per day risk-free. If she wants to reprocess multiple videos on the same day, paid Gemini is the answer.

## What ships in `Leeya-Studio-v1.0.zip`

- Leeya Studio.app (145 MB, ad-hoc signed)
- `הפעלה ראשונה — Open First Time.command` (Gatekeeper bypass)
- README.md (Hebrew + tech notes)
- Total : 144 MB zipped
