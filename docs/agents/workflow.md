# Workflow

## Branches and pull requests

- `main` is protected: every change goes through a pull request with the `build` check green
  (`swift build -c release` and `swift test` on macOS). Squash merge only.
- One focused change per PR. Fill in the template: what and why, how it looks (a screenshot or recording
  for behaviour and art), and the checklist (tests, localisation, privacy).
- Visual or promotional work (art, GIFs, videos, README media) waits for the maintainer's review.
  Small routine fixes can be merged once CI is green, if the maintainer asked for it.
- Don't change git identity or global git config. Don't push tags; releases are the maintainer's.

## Commits

- Imperative subject under ~70 characters ("Add a windows demo scene"), a body that explains why.
- Stage files by name. Never commit build output, `node_modules`, recordings or local settings.

## Changelog and credit

- User-visible changes get a line under `## Unreleased` in `CHANGELOG.md`. Show new features with their demo GIF.
- Credit ideas and contributions inline: `(idea by @someone)` or `(by @someone in #12)`.
  `scripts/release-notes.sh` turns these, plus the authors of merged PRs, into the release notes' Thanks section.

## Releases (maintainer)

Rename `## Unreleased` to the version, merge through a PR, then tag `vX.Y.Z` on `main`. The release workflow
builds the universal app, attaches the zip and checksums and drafts the release. See CONTRIBUTING → Releasing.

## Planning

Releases are tracked as GitHub milestones with a release issue each (`release` label); ideas without a release
live in the ideas backlog issue (`idea` label); the engine work has the `engine` label. Link the issue in the PR.
