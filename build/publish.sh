#!/bin/bash
# publish.sh — build + tag + GitHub release for Leeya Studio.
#
# Usage:
#   bash build/publish.sh v1.0.1 "Fix audio sync drift"
#   bash build/publish.sh v1.1.0 "Add Instagram auto-post"
#
# Always uploads under both the versioned name (Leeya-Studio-v1.x.x.zip)
# AND the stable name (Leeya-Studio.zip) so Leeya's download bookmark
# never breaks.

set -euo pipefail

VERSION="${1:-}"
NOTES="${2:-Iteration release}"

if [[ -z "$VERSION" ]] || ! [[ "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Usage: $0 vX.Y.Z \"release notes\""
    echo "Example: $0 v1.0.1 \"Fix audio sync drift\""
    exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REPO="CodeNoLimits/leeya-studio"
APP_NAME="Leeya Studio"
VERSIONED_ZIP="build/release/Leeya-Studio-${VERSION#v}.zip"
STABLE_ZIP="/tmp/Leeya-Studio.zip"

echo "▶ [1/5] Building $VERSION…"
bash build/pack.sh

# Rename the built zip to include the version
ORIG_ZIP="build/release/Leeya-Studio-v1.0.zip"
if [[ -f "$ORIG_ZIP" && "$ORIG_ZIP" != "$VERSIONED_ZIP" ]]; then
    mv "$ORIG_ZIP" "$VERSIONED_ZIP"
fi
cp "$VERSIONED_ZIP" "$STABLE_ZIP"
SIZE_MB=$(du -m "$VERSIONED_ZIP" | cut -f1)
echo "   ✓ Zip $SIZE_MB MB at $VERSIONED_ZIP"

echo "▶ [2/5] Committing version bump…"
git add -A
if ! git diff --cached --quiet; then
    git -c user.name="CodeNoLimits" -c user.email="dreamnovaultimate@gmail.com" \
        commit -m "release: $VERSION — $NOTES"
fi

echo "▶ [3/5] Tagging $VERSION + pushing…"
git tag -a "$VERSION" -m "$VERSION — $NOTES" 2>/dev/null || echo "   (tag exists, reusing)"
git push origin main --tags 2>&1 | tail -3

echo "▶ [4/5] Creating GitHub release…"
gh release create "$VERSION" \
    "$VERSIONED_ZIP" "$STABLE_ZIP" \
    --repo "$REPO" \
    --title "$APP_NAME $VERSION" \
    --notes "$NOTES

## Install
Download \`Leeya-Studio.zip\` below → extract to Desktop → right-click \`הפעלה ראשונה.command\` → Open.

## Stable download URL
\`\`\`
https://github.com/$REPO/releases/latest/download/Leeya-Studio.zip
\`\`\`
This URL always serves the newest release. Leeya can bookmark it." \
    2>&1 | tail -3

echo "▶ [5/5] Verifying download URL…"
URL="https://github.com/$REPO/releases/latest/download/Leeya-Studio.zip"
HTTP=$(curl -sI -L "$URL" -o /dev/null -w "%{http_code}")
if [[ "$HTTP" == "200" ]]; then
    echo "   ✅ Download URL live: $URL"
else
    echo "   ⚠️  HTTP $HTTP — check release at https://github.com/$REPO/releases"
fi

echo ""
echo "═══════════════ DONE ═══════════════"
echo "  Version    : $VERSION ($SIZE_MB MB)"
echo "  Release    : https://github.com/$REPO/releases/tag/$VERSION"
echo "  For Leeya  : $URL"
echo ""
echo "  WhatsApp Leeya:"
echo "    היי אהובה ❤️ עדכון חדש ל־Leeya Studio."
echo "    https://github.com/$REPO/releases/latest/download/Leeya-Studio.zip"
echo "    מחקי את הגרסה הישנה, חלצי את החדשה, הפעלי ראשונה.command."
