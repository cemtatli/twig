#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p Resources
TMP="$(mktemp -d)"
MASTER="$TMP/icon_1024.png"

# Try running as a script first; fall back to compiling if that fails.
if ! swift scripts/make-icon.swift "$MASTER" 2>/dev/null; then
    echo "Direct swift run failed, compiling instead..."
    swiftc scripts/make-icon.swift -o "$TMP/makeicon"
    "$TMP/makeicon" "$MASTER"
fi

SET="$TMP/AppIcon.iconset"
mkdir -p "$SET"
# Standard macOS iconset sizes.
for spec in "16:16x16" "32:16x16@2x" "32:32x32" "64:32x32@2x" \
            "128:128x128" "256:128x128@2x" "256:256x256" "512:256x256@2x" \
            "512:512x512" "1024:512x512@2x"; do
  px="${spec%%:*}"; name="${spec##*:}"
  sips -z "$px" "$px" "$MASTER" --out "$SET/icon_${name}.png" >/dev/null
done
iconutil -c icns "$SET" -o Resources/AppIcon.icns
echo "OK: wrote Resources/AppIcon.icns"
rm -rf "$TMP"
