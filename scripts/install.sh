#!/usr/bin/env bash
# Builds and installs AI Subs into /Applications.
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/build-app.sh release

rm -rf /Applications/AISubs.app
cp -R build/AISubs.app /Applications/AISubs.app

echo "Installed /Applications/AISubs.app"
echo "Launch it from Spotlight (\"AI Subs\") — the icon appears in the menu bar."
echo "Tip: enable Launch at login in Settings → General."
