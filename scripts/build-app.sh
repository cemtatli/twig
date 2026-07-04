#!/bin/bash
# Builds WorktreeGUI.app -- a double-clickable, menubar-only macOS app bundle.
# Usage:
#   ./scripts/build-app.sh            # build the .app in the project root
#   ./scripts/build-app.sh --install  # also copy it to /Applications
set -euo pipefail
cd "$(dirname "$0")/.."

BIN_NAME="WorktreeGUI"
APP_DISPLAY="Twig"
BUNDLE_ID="com.cem.worktreegui"
APP="${BIN_NAME}.app"

echo "==> Building release binary"
swift build -c release
BIN_PATH="$(swift build -c release --show-bin-path)/${BIN_NAME}"

echo "==> Assembling ${APP}"
rm -rf "${APP}"
mkdir -p "${APP}/Contents/MacOS" "${APP}/Contents/Resources"
cp "${BIN_PATH}" "${APP}/Contents/MacOS/${BIN_NAME}"

# Optional icon: drop an AppIcon.icns into Resources/ before running to use it.
ICON_KEY=""
if [ -f "Resources/AppIcon.icns" ]; then
  cp "Resources/AppIcon.icns" "${APP}/Contents/Resources/AppIcon.icns"
  ICON_KEY="<key>CFBundleIconFile</key><string>AppIcon</string>"
fi

cat > "${APP}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>${APP_DISPLAY}</string>
  <key>CFBundleDisplayName</key><string>${APP_DISPLAY}</string>
  <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
  <key>CFBundleExecutable</key><string>${BIN_NAME}</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>1.0</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  ${ICON_KEY}
</dict>
</plist>
PLIST

echo "==> Ad-hoc code signing"
codesign --force --deep --sign - "${APP}"

echo "OK: built $(pwd)/${APP}"

if [ "${1:-}" = "--install" ]; then
  echo "==> Installing to /Applications"
  rm -rf "/Applications/${APP}"
  cp -R "${APP}" "/Applications/${APP}"
  echo "OK: installed /Applications/${APP} -- launch from Spotlight/Launchpad."
fi
