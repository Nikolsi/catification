#!/bin/bash
# Prints the CHANGELOG.md section for a version as GitHub release notes.
#
#   scripts/release-notes.sh <version> <owner/repo> <tag>
#   scripts/release-notes.sh Unreleased Nikolsi/catification main     # preview the next release
#
# - Images in the changelog use paths relative to the repo (docs/media/demo-naps.gif) so they show
#   up on GitHub; here they're pinned to the release tag, so a release keeps the GIFs it shipped
#   with even if they're re-recorded later.
# - A "Thanks" section lists everyone @mentioned in the section ("idea by @someone") and the
#   authors of pull requests merged since the previous tag (needs `gh`; skipped without it),
#   leaving out the repository owner and bots.
set -euo pipefail

cd "$(dirname "$0")/.."
VERSION="$1" REPO="$2" REF="$3"
OWNER="${REPO%%/*}"
BASE="https://github.com/$REPO/raw/$REF"

SECTION="$(awk -v v="$VERSION" '
    $0 ~ "^## " { if (found) exit; if ($2 == v || index(v, $2) == 1) found = 1; next }
    found { print }
' CHANGELOG.md)"

printf '%s\n' "$SECTION" |
    sed -E "s#\]\((docs/media/[^)]+)\)#]($BASE/\1)#g; s#src=\"(docs/media/[^\"]+)\"#src=\"$BASE/\1\"#g"

PEOPLE="$(printf '%s\n' "$SECTION" | grep -oE '(^|[^[:alnum:]])@[A-Za-z0-9][A-Za-z0-9-]*' | grep -oE '@.*' | cut -c2- || true)"
if command -v gh >/dev/null && PREVIOUS="$(git describe --tags --abbrev=0 "$REF^" 2>/dev/null)"; then
    AUTHORS="$(gh api "repos/$REPO/compare/$PREVIOUS...$REF" --jq '.commits[].author.login // empty' 2>/dev/null || true)"
    PEOPLE="$(printf '%s\n%s\n' "$PEOPLE" "$AUTHORS")"
fi
THANKS="$(printf '%s\n' "$PEOPLE" | grep -v -e '^$' -e '\[bot\]$' | grep -vix "$OWNER" | sort -fu | sed 's/^/@/' | paste -sd ',' - | sed 's/,/, /g' || true)"
if [ -n "$THANKS" ]; then
    printf '\n### Thanks\n\nThank you %s for helping with this release.\n' "$THANKS"
fi
