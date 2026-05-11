# Leeya ↔ David Bridge · Architecture

> **One link for Leeya. One repo for David. Claude on both sides.**
> Locked 2026-05-11. Reference for all future DreamNova family apps.

## The principle

Leeya is non-technical. She must never see a terminal, a GitHub login, a `.env` file, or an API key. She gets ONE link from David. That link does everything.

David codes in Claude Code on his Mac. Every iteration auto-publishes. Leeya's link always serves the latest. When Leeya needs help, David gets pinged. When David ships, Leeya gets notified.

## Components

```
┌─────────────────────┐        ┌─────────────────────┐
│  David's Mac        │        │  Leeya's Mac        │
│  Claude Code Opus   │        │  Claude.ai web      │
│  ~/.claude/CLAUDE.md│        │  Projects custom    │
│  (full agentic)     │        │  instructions       │
└──────────┬──────────┘        └──────────┬──────────┘
           │                              │
           │ push                         │ click link
           ▼                              ▼
┌──────────────────────────────────────────────────────┐
│              GitHub: CodeNoLimits/leeya-studio       │
│              (PUBLIC repo · source + releases)       │
└──────────┬───────────────────────────────────────────┘
           │ webhook
           ▼
┌──────────────────────────────────────────────────────┐
│              Vercel: leeya-studio-bridge.vercel.app  │
│              Env: GITHUB_PAT, DAVID_GEMINI_KEY,      │
│                   DAVID_ELEVENLABS_KEY, LEEYA_VOICE  │
│                                                       │
│  /api/download       → 302 to latest .zip            │
│  /api/david-key      → JSON {key} from env           │
│  /api/notify-david   → ntfy/email when Leeya needs   │
│  /api/videos         → list of Leeya's generated     │
│                        shorts (stored via R2/Drive)  │
└──────────────────────────────────────────────────────┘
```

## The link Leeya gets

**https://leeya-studio-bridge.vercel.app**

On that page she sees ONE big button per action:
- **⬇  Download App** → triggers `/api/download` → .zip starts downloading
- **🎬 My Videos** → gallery of all the shorts she's produced (v1.1)
- **✂️  Edit Subtitles** → opens a video → quick subtitle re-edit, no re-pipeline (v1.1)
- **🆘  Ask David** → triggers `/api/notify-david` → David's iPhone pings (v1.1)

## What lives where

| Asset | Where | Why |
|---|---|---|
| Mac app binary (`.zip`, 188 MB) | GitHub Release | Free public download, no auth |
| Source code | GitHub PUBLIC repo | Anyone can audit/fork; no secrets in source |
| Secret keys | Vercel env vars (encrypted) | Rotatable without rebuild |
| Generated shorts (mp4 archive) | Cloudflare R2 (free tier 10GB) | Persistent, fast CDN, free up to 10GB |
| Subtitle JSON state | Vercel KV (Redis free 10K/day) | Quick read for editor UI |
| Pipeline manifests (auditable) | Same GitHub repo, `manifests/` folder | Versioned, queryable |
| User activity log (Leeya's actions) | Vercel KV with TTL | Triggers David notifications |

## Iteration flow (David)

```bash
# David codes a fix
cd ~/Desktop/leeya-studio
# edit swift/MainView.swift
bash build/publish.sh v1.0.1 "Fix audio sync drift"
# → builds .app
# → commits + tags + pushes
# → uploads .zip to GitHub Release v1.0.1
# → /api/download now serves v1.0.1 to Leeya
# → optionally posts to ntfy.sh/david so his iPhone pings ("v1.0.1 live")
```

## Notification flow (Leeya → David)

When Leeya hits **🆘 Ask David** in the app:
1. App POSTs to `https://leeya-studio-bridge.vercel.app/api/notify-david` with her current context (video file, error, question text).
2. Bridge writes the request to a `leeya_help_<ts>.md` file in the leeya-studio repo via Octokit (`repos.createOrUpdateFileContents`).
3. The commit triggers a GitHub webhook → ntfy.sh/david → David's iPhone gets a push.
4. Or simpler: webhook → email to `dreamnovaultimate@gmail.com`.

David sees the request in his Claude Code session via SessionStart auto-pull. Replies by committing a `david_reply_<ts>.md` file. Same webhook fires back to Leeya.

## Notification flow (David → Leeya)

When David ships v1.x.y:
1. `publish.sh` POSTs to `/api/notify-leeya` after the GitHub Release is created.
2. Bridge sends WhatsApp via `wa.me/972[Leeya number]?text=...` OR email to `katsleeya@gmail.com`.
3. Message: "🎬 גרסה חדשה זמינה — לחצי כדי לעדכן: https://leeya-studio-bridge.vercel.app"

## Permanent Claude instructions

### David's side · `~/.claude/CLAUDE.md` (already exists)

Add this section:
```markdown
## Leeya Bridge — PERMANENT

When user mentions "Leeya app", "Leeya Studio", "ma femme", "her shorts",
or asks for a Leeya iteration:
1. Repo: github.com/CodeNoLimits/leeya-studio (PUBLIC, source + Mac app)
2. Bridge: leeya-studio-bridge.vercel.app (env-injected secrets)
3. Iteration: `bash ~/Desktop/leeya-studio/build/publish.sh vX.Y.Z "notes"`
4. Leeya gets the new version by clicking the same URL — no action needed from her
5. Notifications: /api/notify-david for incoming help requests
6. Architecture spec: ~/Desktop/leeya-studio/BRIDGE.md
```

### Leeya's side · Claude.ai Projects custom instructions

Leeya uses Claude on the web (claude.ai). She creates a Project called "Leeya OS" and pastes this in custom instructions:

```
אני ליה. אני עובדת עם דוד על Leeya Studio.

הקישור שלי הוא https://leeya-studio-bridge.vercel.app — כל מה שצריך נמצא שם.

אם אני שואלת אותך לעזור לי עם הסרטונים, אל תנסה להריץ קוד.
במקום, נווט אותי לכפתורים בתוך האפליקציה Leeya Studio:
- "Cut & Upload" — חיתוך וידאו ארוך לחמישה shorts
- "My Videos" — לראות את הסרטונים שעשיתי
- "Edit Subtitles" — לערוך כתוביות מהר
- "Ask David" — לקרוא לדוד אם משהו לא עובד

הקוד נמצא ב־github.com/CodeNoLimits/leeya-studio
אם אתה רוצה לראות מה האפליקציה עושה — ספר לי בעברית פשוטה.

I am Leeya. I work with David on Leeya Studio.
My single link is https://leeya-studio-bridge.vercel.app — everything I need is there.
If I ask for help with the videos, don't try to run code. Instead, guide me through
the big buttons in the Leeya Studio app on my Mac. The source is at
github.com/CodeNoLimits/leeya-studio — explain it to me in simple Hebrew if needed.
```

## v1.1 backlog (this week, in priority order)

1. **`/api/videos` endpoint** — lists all generated shorts. Storage: Cloudflare R2 (free 10 GB). David's `publish.sh` uploads after every pipeline run.
2. **Bridge landing page redesign** — single-link UX with 4 big buttons (Download / Videos / Subtitles / Ask David). Open Sans only per Leeya brand bible.
3. **Subtitle editor in Mac app** — load existing .ass / .srt from manifest, edit in a SwiftUI form, save → re-encode ONLY the subs layer (no Whisper re-run, no Gemini re-translate). Fast: ~30s per short instead of 30 min.
4. **`/api/notify-david` endpoint** — POST writes to repo, webhook → ntfy.sh/david_personal → iPhone push.
5. **Subtitle font picker** — Leeya passes her preferred font (uploaded via app or fetched from Google Fonts). Bake into the encode.
6. **Landing page editor** — Leeya updates her own landing copy via the app (commits to leeya-katz-v2 repo via bridge PAT).
7. **GitHub webhook for David notifications** — every Leeya commit pings David.

## What this enables

- **Leeya never installs anything else** — one link, one Mac app, done.
- **David ships at speed** — `publish.sh` is the only command, everything else automatic.
- **Audit trail** — every Leeya action is a git commit, every David fix is a release, all timestamped.
- **No secret leakage** — keys live in Vercel env, never in source or binary.
- **Reusable pattern** — same architecture works for any future DreamNova family app (LIA OS, ViraLeeya, NovaReels).

## Reference files

- `~/.claude/CLAUDE.md` (David's global instructions — needs Leeya section added)
- `~/Desktop/leeya-studio/BRIDGE.md` (this file)
- `~/Desktop/leeya-studio-bridge/app/api/` (live endpoints)
- `~/Desktop/leeya-studio/build/publish.sh` (iteration script)
- Memory: `reference_leeya_david_bridge.md` (canonical pattern, propagate to all family projects)
