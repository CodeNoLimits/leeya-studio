#!/bin/bash
# pack.sh — build Leeya Studio.app from source.
# Compiles Swift, copies bundled python runtime + leecut + ffmpeg + whisper,
# ad-hoc codesigns, strips quarantine xattrs, and zips for distribution.
#
# Output: build/Leeya Studio.app   and   build/Leeya Studio.zip

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Leeya Studio"
BUNDLE_ID="com.dreamnova.leeyastudio"
APP_DIR="$ROOT/build/$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"
RES="$CONTENTS/Resources"
MACOS="$CONTENTS/MacOS"

echo "▶ Cleaning old build…"
rm -rf "$APP_DIR" "$ROOT/build/$APP_NAME.zip"

mkdir -p "$MACOS" "$RES/python" "$RES/site-packages" "$RES/scripts" "$RES/bin" "$RES/models"

# ─── Compile Swift ──────────────────────────────────────────────────────────
echo "▶ Compiling Swift…"
swiftc -O -target arm64-apple-macos13.0 \
       -framework SwiftUI -framework AppKit -framework AVFoundation \
       -framework Security -framework UniformTypeIdentifiers \
       "$ROOT/swift"/*.swift \
       -o "$MACOS/leeya-studio"

cp "$ROOT/swift/Info.plist" "$CONTENTS/Info.plist"

# ─── Embed Python runtime ───────────────────────────────────────────────────
echo "▶ Embedding Python 3.11 runtime…"
cp -R "$ROOT/vendor/python/"* "$RES/python/"

# ─── Pip wheels (already pre-installed in vendor/site-packages) ────────────
echo "▶ Copying site-packages…"
cp -R "$ROOT/vendor/site-packages/"* "$RES/site-packages/" 2>/dev/null || true

# ─── leecut package + tonight's scripts ─────────────────────────────────────
echo "▶ Copying leecut + scripts…"
cp -R "$HOME/Desktop/Leeya/leecut" "$RES/scripts/leecut"
# Sanitize: strip __pycache__ to keep bundle clean
find "$RES/scripts/leecut" -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
find "$RES/site-packages"  -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
find "$RES/python"         -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true

cp "$ROOT/python/orchestrator.py"        "$RES/scripts/"
cp "$ROOT/python/upload_single_video.py" "$RES/scripts/"
cp "$ROOT/python/oauth_login.py"         "$RES/scripts/"

# ─── ffmpeg (whisper handled by Python mlx-whisper in site-packages) ────────
echo "▶ Embedding ffmpeg…"
cp "$ROOT/vendor/ffmpeg" "$RES/bin/ffmpeg"
chmod +x "$RES/bin/ffmpeg"

# ─── OAuth client secret ────────────────────────────────────────────────────
cp "$ROOT/vendor/client_secret.json" "$RES/client_secret.json"

# ─── Make python interpreter executable + relink shebangs ──────────────────
chmod +x "$RES/python/bin/"*
# python3.11 inside the bundle uses absolute path to itself — let's adjust
# the standard launcher script to point to its own location at runtime.
cat > "$RES/scripts/run_py.sh" <<'EOSH'
#!/bin/bash
# Launcher used by Swift PythonRunner. Wires PYTHONPATH + PATH to bundle.
HERE="$(cd "$(dirname "$0")/.." && pwd)"
export PYTHONPATH="$HERE/site-packages:$HERE/scripts:$HERE/scripts/leecut"
export PATH="$HERE/bin:$PATH"
export PYTHONUNBUFFERED=1
export PYTHONDONTWRITEBYTECODE=1
exec "$HERE/python/bin/python3" "$@"
EOSH
chmod +x "$RES/scripts/run_py.sh"

# ─── Codesign ad-hoc (no Apple Developer needed) ────────────────────────────
echo "▶ Ad-hoc codesigning…"
codesign --deep --force --sign - --options runtime "$APP_DIR" || \
  codesign --deep --force --sign - "$APP_DIR"

# ─── Strip quarantine ──────────────────────────────────────────────────────
xattr -cr "$APP_DIR" || true

# ─── Helper .command for Leeya to bypass Gatekeeper after download ─────────
mkdir -p "$ROOT/build/release"
HELPER="$ROOT/build/release/הפעלה ראשונה — Open First Time.command"
cat > "$HELPER" <<'EOSH'
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
EOSH
chmod +x "$HELPER"

# ─── Final zip (ditto preserves resource forks + symlinks correctly) ───────
echo "▶ Packaging .zip…"
cd "$ROOT/build"
ditto -c -k --keepParent "$APP_NAME.app" "$APP_NAME.zip"

# ─── Distribution bundle (zip + helper .command + readme) ───────────────────
DIST="$ROOT/build/release/Leeya-Studio-v1.0"
rm -rf "$DIST"
mkdir -p "$DIST"
cp -R "$APP_DIR" "$DIST/"
cp "$HELPER" "$DIST/"
cp "$ROOT/docs/README_LEEYA.md" "$DIST/README.md" 2>/dev/null || \
  echo "Read README_LEEYA.md inside the docs folder for setup steps." > "$DIST/README.txt"
cd "$ROOT/build/release"
ditto -c -k --keepParent "Leeya-Studio-v1.0" "Leeya-Studio-v1.0.zip"

# ─── Summary ─────────────────────────────────────────────────────────────────
echo ""
echo "✓ Build complete."
echo "   App:        $APP_DIR"
echo "   Quick zip:  $ROOT/build/$APP_NAME.zip ($(du -sh "$ROOT/build/$APP_NAME.zip" | cut -f1))"
echo "   Dist zip:   $ROOT/build/release/Leeya-Studio-v1.0.zip ($(du -sh "$ROOT/build/release/Leeya-Studio-v1.0.zip" | cut -f1))"
echo ""
echo "▶ To test locally:    open '$APP_DIR'"
echo "▶ To send to Leeya:   share build/release/Leeya-Studio-v1.0.zip via WhatsApp / GitHub"
