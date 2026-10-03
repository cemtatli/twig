#!/bin/bash
# Usage: ./scripts/package-release.sh 1.0.0
# Builds a universal app, ZIP, DMG and SHA-256 checksums without installing it.
set -euo pipefail
cd "$(dirname "$0")/.."
TASK_ROOT="$(pwd -P)"
TASK_VERSION="${1:-1.0.0}"
if [[ ! "$TASK_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Expected a version such as 1.0.0" >&2
  exit 1
fi
TASK_OUTPUT="$TASK_ROOT/dist/v$TASK_VERSION"
if [[ -e "$TASK_OUTPUT" ]]; then
  echo "Output already exists: $TASK_OUTPUT. Choose a new version or move it aside." >&2
  exit 1
fi

TASK_BUILD_ARGS=(--build-system native)
if [[ -n "${TWIG_MACOS_SDK:-}" ]]; then
  TASK_BUILD_ARGS+=(--sdk "$TWIG_MACOS_SDK")
fi
for TASK_ARCH in arm64 x86_64; do
  swift build "${TASK_BUILD_ARGS[@]}" -c release --triple "$TASK_ARCH-apple-macosx14.0" \
    --scratch-path ".build/release-verified-$TASK_ARCH"
done
TASK_ARM_BIN="$(swift build "${TASK_BUILD_ARGS[@]}" -c release --triple arm64-apple-macosx14.0 --scratch-path .build/release-verified-arm64 --show-bin-path)/Twig"
TASK_INTEL_BIN="$(swift build "${TASK_BUILD_ARGS[@]}" -c release --triple x86_64-apple-macosx14.0 --scratch-path .build/release-verified-x86_64 --show-bin-path)/Twig"

TASK_APP="$TASK_OUTPUT/Twig.app"
mkdir -p "$TASK_APP/Contents/MacOS" "$TASK_APP/Contents/Resources"
lipo -create "$TASK_ARM_BIN" "$TASK_INTEL_BIN" -output "$TASK_APP/Contents/MacOS/Twig"
cp Resources/ReleaseInfo.plist "$TASK_APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $TASK_VERSION" "$TASK_APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $TASK_VERSION" "$TASK_APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$TASK_APP/Contents/Resources/AppIcon.icns"
plutil -lint "$TASK_APP/Contents/Info.plist"
codesign --force --sign - "$TASK_APP"
codesign --verify --strict --all-architectures --verbose "$TASK_APP"
lipo "$TASK_APP/Contents/MacOS/Twig" -verify_arch arm64
lipo "$TASK_APP/Contents/MacOS/Twig" -verify_arch x86_64

TASK_ZIP="Twig-$TASK_VERSION-universal.zip"
TASK_DMG="Twig-$TASK_VERSION-universal.dmg"
ditto -c -k --sequesterRsrc --keepParent "$TASK_APP" "$TASK_OUTPUT/$TASK_ZIP"
TASK_STAGE="$(mktemp -d "$TASK_ROOT/.build/package-stage.XXXXXX")"
ditto "$TASK_APP" "$TASK_STAGE/Twig.app"
ln -s /Applications "$TASK_STAGE/Applications"
hdiutil create -volname "Twig $TASK_VERSION" -srcfolder "$TASK_STAGE" \
  -format UDZO -ov "$TASK_OUTPUT/$TASK_DMG"
hdiutil verify "$TASK_OUTPUT/$TASK_DMG"
(cd "$TASK_OUTPUT" && shasum -a 256 "$TASK_ZIP" "$TASK_DMG" > SHA256SUMS.txt)
echo "Release artifacts: $TASK_OUTPUT"
echo "Ad-hoc signed; not notarized. See README for first-launch information."
