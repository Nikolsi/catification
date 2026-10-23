#!/bin/bash
# Prints the CHANGELOG.md section for a version as GitHub release notes.
#
#   scripts/release-notes.sh <version> <owner/repo> <tag>
#   scripts/release-notes.sh Unreleased Nikolsi/catification main     # preview the next release
#
# Images in the changelog use paths relative to the repo (docs/media/demo-naps.gif) so they show
# up on GitHub; here they're pinned to the release tag, so a release keeps the GIFs it shipped
# with even if they're re-recorded later.
set -euo pipefail

cd "$(dirname "$0")/.."
VERSION="$1" REPO="$2" REF="$3"
BASE="https://github.com/$REPO/raw/$REF"

awk -v v="$VERSION" '
    $0 ~ "^## " { if (found) exit; if ($2 == v || index(v, $2) == 1) found = 1; next }
    found { print }
' CHANGELOG.md |
    sed -E "s#\]\((docs/media/[^)]+)\)#]($BASE/\1)#g; s#src=\"(docs/media/[^\"]+)\"#src=\"$BASE/\1\"#g"
