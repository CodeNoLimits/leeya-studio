"""oauth_login.py — desktop OAuth flow for YouTube.

Reads $YOUTUBE_CLIENT_SECRET (path to client_secret.json bundled with the app),
opens system browser, captures the user consent, and writes the resulting
refresh token to $YOUTUBE_TOKEN_PATH.

Final stdout line is a single JSON object:
    {"channel_id": "UCxxx", "channel_title": "Leeya Kats"}

Exit code:
    0 = success
    1 = config error (missing env vars / files)
    2 = auth flow failed
    3 = channels.list call failed
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

SCOPES = [
    "https://www.googleapis.com/auth/youtube.upload",
    "https://www.googleapis.com/auth/youtube",
    "https://www.googleapis.com/auth/youtube.readonly",
]


def fail(code: int, msg: str) -> None:
    print(json.dumps({"event": "error", "error": msg}), file=sys.stderr, flush=True)
    sys.exit(code)


def main() -> int:
    client_secret = os.environ.get("YOUTUBE_CLIENT_SECRET")
    token_path    = os.environ.get("YOUTUBE_TOKEN_PATH")

    if not client_secret or not Path(client_secret).exists():
        fail(1, f"Missing client_secret at {client_secret}")
    if not token_path:
        fail(1, "Missing YOUTUBE_TOKEN_PATH env")

    Path(token_path).parent.mkdir(parents=True, exist_ok=True)

    try:
        from google_auth_oauthlib.flow import InstalledAppFlow
        from google.oauth2.credentials import Credentials
        from google.auth.transport.requests import Request
        from googleapiclient.discovery import build
    except ImportError as exc:
        fail(1, f"Python deps missing: {exc}")

    creds = None
    if Path(token_path).exists():
        try:
            creds = Credentials.from_authorized_user_file(token_path, SCOPES)
        except Exception:
            creds = None
    if creds and creds.expired and creds.refresh_token:
        try:
            creds.refresh(Request())
        except Exception:
            creds = None

    if not creds or not creds.valid:
        try:
            flow = InstalledAppFlow.from_client_secrets_file(client_secret, SCOPES)
            # port=0 → OS picks a free port; opens browser; blocks until consent
            creds = flow.run_local_server(port=0, open_browser=True,
                                          authorization_prompt_message="",
                                          success_message="✓ נחתם · You can close this window.")
        except Exception as exc:
            fail(2, f"OAuth flow failed: {exc}")

    Path(token_path).write_text(creds.to_json())

    # Fetch channel info
    try:
        yt = build("youtube", "v3", credentials=creds, cache_discovery=False)
        resp = yt.channels().list(part="snippet", mine=True).execute()
        items = resp.get("items", [])
        if not items:
            fail(3, "No YouTube channel on this Google account")
        chan = items[0]
        out = {
            "channel_id": chan["id"],
            "channel_title": chan["snippet"]["title"],
        }
        # Final line as bare JSON for Swift to parse
        print(json.dumps(out), flush=True)
        return 0
    except Exception as exc:
        fail(3, f"channels.list failed: {exc}")


if __name__ == "__main__":
    sys.exit(main())
