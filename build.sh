#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release --arch arm64 --arch x86_64
BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"
APP="dist/AirText.app"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN_DIR/AirText" "$APP/Contents/MacOS/AirText"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
printf '\nBuilt: %s/%s\n' "$PWD" "$APP"
