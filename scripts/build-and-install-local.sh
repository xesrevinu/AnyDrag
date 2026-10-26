#!/usr/bin/env bash
# Build the local fork (main + PR #60 anchors + PR #64 focus) and install to
# /Applications/AnyDrag.app. Uses a clean env so nix's LD=ld does not break
# Xcode 27's linker driver.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-27.2.0-Beta.app/Contents/Developer}"
if [[ ! -d "$DEVELOPER_DIR" ]]; then
  DEVELOPER_DIR="$(xcode-select -p)"
fi
export DEVELOPER_DIR

xcodegen generate

rm -rf build/DerivedData
env -i \
  HOME="$HOME" USER="$USER" LOGNAME="${LOGNAME:-$USER}" TMPDIR="${TMPDIR:-/tmp}" \
  DEVELOPER_DIR="$DEVELOPER_DIR" \
  PATH="$DEVELOPER_DIR/usr/bin:$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
  xcodebuild -project AnyDrag.xcodeproj -scheme AnyDrag -configuration Release \
    -derivedDataPath build/DerivedData \
    -destination 'platform=macOS,arch=arm64' \
    ONLY_ACTIVE_ARCH=YES ARCHS=arm64 EXCLUDED_ARCHS=x86_64 \
    CODE_SIGN_IDENTITY='-' CODE_SIGNING_REQUIRED=NO \
    build

APP="$ROOT/build/DerivedData/Build/Products/Release/AnyDrag.app"
test -x "$APP/Contents/MacOS/AnyDrag"

killall AnyDrag 2>/dev/null || true
sleep 0.3
rm -rf /Applications/AnyDrag.app
cp -R "$APP" /Applications/AnyDrag.app
codesign --force --deep --sign - /Applications/AnyDrag.app

echo "Installed: $(defaults read /Applications/AnyDrag.app/Contents/Info.plist CFBundleShortVersionString)"
echo "Re-grant Accessibility if prompted, then: open -a AnyDrag"
open -a AnyDrag
