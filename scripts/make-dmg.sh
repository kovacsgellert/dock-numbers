#!/bin/bash
# Build a drag-to-Applications DMG from dist/dock-numbers.app.
# Usage: ./scripts/make-dmg.sh   (run package-app.sh first)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${OUT:-$ROOT/dist}"
APP="$OUT/dock-numbers.app"
STAGE="$OUT/dmg-stage"
DMG="$OUT/dock-numbers-macos-arm64.dmg"

test -d "$APP" || { echo "ERROR: $APP not found, run scripts/package-app.sh first" >&2; exit 1; }
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "dock-numbers" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
echo "Wrote $DMG"
