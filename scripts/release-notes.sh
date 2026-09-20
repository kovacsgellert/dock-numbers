#!/bin/bash
# Compose GH release notes from CHANGELOG.md.
# Usage: scripts/release-notes.sh <tag>
#   prerelease tag (contains "-"): that version's section only
#   final tag: that section plus all prerelease sections of the same
#   version (everything since the previous non-prerelease).
# Prints Markdown with a "# <tag>" title to stdout.
set -euo pipefail
TAG="${1:?usage: release-notes.sh <tag>}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
echo "# $TAG"
echo
awk -v tag="$TAG" '
  /^## / {
    if (collect) exit
    if ($2 == tag) { collect = 1 }
    next
  }
  collect && !started && NF == 0 { next }
  collect { started = 1; print }
' "$ROOT/CHANGELOG.md"
