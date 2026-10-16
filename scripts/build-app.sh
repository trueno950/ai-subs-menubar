#!/usr/bin/env bash
# Builds the Swift package and assembles a runnable AISubs.app bundle.
# Works with Command Line Tools only (no full Xcode required).
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
swift build -c "$CONFIG"

APP="build/AISubs.app"
BIN=".build/$CONFIG/AISubs"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/AISubs"
cp Packaging/Info.plist "$APP/Contents/Info.plist"

# Ad-hoc sign so Keychain and notifications attribute correctly.
codesign --force --sign - "$APP" >/dev/null 2>&1 || true

echo "Built $APP"
