#!/usr/bin/env bash
# Builds a proper Authenticator.app bundle around the SPM executable.
# A bundle is required because:
#   - MenuBarExtra only works in a bundled app
#   - The Keychain identifies clients by code-signature; ad-hoc signing the
#     bundle gives the app a stable identity so "Always Allow" sticks
#   - LSUIElement=true keeps the app out of the Dock
set -euo pipefail

cd "$(dirname "$0")"

CONFIG="release"
BUNDLE="Authenticator.app"
EXE_NAME="Authenticator"

echo "==> swift build -c $CONFIG"
swift build -c "$CONFIG"

BIN_PATH=".build/$CONFIG/$EXE_NAME"
if [[ ! -x "$BIN_PATH" ]]; then
  echo "Build did not produce $BIN_PATH" >&2
  exit 1
fi

echo "==> Assembling $BUNDLE"
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS"
mkdir -p "$BUNDLE/Contents/Resources"

cp "$BIN_PATH" "$BUNDLE/Contents/MacOS/$EXE_NAME"

cat > "$BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>          <string>Authenticator</string>
  <key>CFBundleDisplayName</key>   <string>Authenticator</string>
  <key>CFBundleExecutable</key>    <string>$EXE_NAME</string>
  <key>CFBundleIdentifier</key>    <string>dev.local.authenticator</string>
  <key>CFBundleVersion</key>       <string>1</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundlePackageType</key>   <string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key>           <true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSCameraUsageDescription</key><string>Not used; reserved for future scanning.</string>
</dict>
</plist>
PLIST

echo "==> Ad-hoc codesign (stable Keychain identity)"
codesign --force --sign - --timestamp=none --options runtime "$BUNDLE" >/dev/null

echo
echo "Built $BUNDLE"
echo "Run with:  open ./$BUNDLE"
