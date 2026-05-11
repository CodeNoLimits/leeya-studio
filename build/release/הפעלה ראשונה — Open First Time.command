#!/bin/bash
# הפעלה ראשונה — Open Leeya Studio for the first time
# Strips Gatekeeper quarantine + opens the app. Run ONCE after extracting the zip.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
APP="$HERE/Leeya Studio.app"
if [ ! -d "$APP" ]; then
    echo "❌ Leeya Studio.app not found in $HERE"
    echo "   Make sure you extracted the .zip into the same folder as this file."
    read -n 1 -s -r -p "Press any key to close…"; echo
    exit 1
fi
echo "▶ Removing quarantine flags…"
xattr -cr "$APP"
echo "▶ Opening Leeya Studio…"
open "$APP"
sleep 1
