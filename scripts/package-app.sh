#!/bin/bash
# Assemble DockShortcuts.app from the SwiftPM release binary.
# Usage: VERSION=0.1.0 OUT=dist ./scripts/package-app.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${VERSION:-$(git -C "$ROOT" describe --tags --always 2>/dev/null || echo 0.0.0-dev)}"
OUT="${OUT:-$ROOT/dist}"
APP="$OUT/DockShortcuts.app"

swift build -c release --product dock-shortcuts --package-path "$ROOT"
BIN="$(swift build -c release --show-bin-path --package-path "$ROOT")/dock-shortcuts"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/"
cp "$ROOT/assets/dock-shortcuts.icns" "$ROOT/assets/menubar.png" "$APP/Contents/Resources/"
sed -e "s/__VERSION__/$VERSION/g" "$ROOT/packaging/Info.plist" > "$APP/Contents/Info.plist"
# Ad-hoc seal so the bundle is self-consistent (still unsigned: no notarization).
codesign --force --deep --sign - "$APP"
echo "Built $APP ($VERSION)"
