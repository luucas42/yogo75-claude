#!/bin/bash
# Builds Yogo.app from the Swift package, ad-hoc signs it and installs it to ~/Applications.
# Usage: scripts/build-app.sh [--open]
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
BIN="$(swift build -c release --show-bin-path)"

APP="build/Yogo.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
# The main binary is YogoApp, not Yogo: APFS is case-insensitive and would collide with the yogo CLI.
cp "$BIN/YogoApp" "$APP/Contents/MacOS/YogoApp"
cp "$BIN/yogo" "$APP/Contents/MacOS/yogo"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>YogoApp</string>
  <key>CFBundleIdentifier</key><string>com.barisgcynr.yogo</string>
  <key>CFBundleName</key><string>Yogo</string>
  <key>CFBundleDisplayName</key><string>Yogo</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>15.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST
codesign --force --sign - "$APP/Contents/MacOS/yogo"
codesign --force --sign - "$APP"

# Quit a running copy first so the keyboard and the socket are released cleanly.
if pgrep -x YogoApp >/dev/null; then
  osascript -e 'tell application id "com.barisgcynr.yogo" to quit' || pkill -x YogoApp || true
  for _ in 1 2 3 4 5; do pgrep -x YogoApp >/dev/null || break; sleep 1; done
fi
mkdir -p "$HOME/Applications"
rm -rf "$HOME/Applications/Yogo.app"
cp -R "$APP" "$HOME/Applications/Yogo.app"
echo "Kuruldu: $HOME/Applications/Yogo.app"
if [[ "${1:-}" == "--open" ]]; then open "$HOME/Applications/Yogo.app"; fi
