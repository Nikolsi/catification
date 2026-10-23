# Catification: guide for coding agents

The single entry point for any coding agent (Claude Code, Codex, Cursor, Copilot, Gemini…); there is
deliberately no `CLAUDE.md`, so Claude Code reads this file too. Humans: see
[CONTRIBUTING.md](CONTRIBUTING.md); everything there applies to agents too.

Catification is a native macOS app (Swift, AppKit, no dependencies): pixel-art cats that live in the
menu bar, on windows and on the desktop. They walk, jump (doing the maths first), nap in favourite spots,
go through portals at the notch and react to the mouse. Open source, MIT, macOS 13+.

## Commands

```bash
make dev        # debug build, run from the terminal; CATIFICATION_DEBUG=1 logs every cat's decisions
make test       # unit tests (swift test): must pass before every PR
make sprites    # every animation of every coat in .preview/sprites.png: look at it after art changes
make app        # release .app in build/ (ad-hoc signed)
make demos      # re-record the README GIFs (needs Screen Recording permission)
.build/debug/Catification --simulate 8   # eight simulated hours in seconds: what every cat did
```

## Rules that matter

- **Privacy:** the app stays offline and never reads window titles or contents, only window bounds.
  Anything that needs a permission (Accessibility for desktop icons) is optional and off until the user turns it on.
- **Every user-facing string is localised:** `L("English text")` in AppKit code, plain literals in SwiftUI,
  and the same key added to every `Resources/*.lproj/Localizable.strings`.
- **Saved data keeps loading:** settings and `.catprofile` files decode leniently (unknown keys skipped,
  missing ones defaulted, values clamped). Never break an old file; add a test when you touch a format.
- **Built-in personalities behave exactly as before:** `BrainTests.testPresetsReproduceTheOldWeights` pins them.
- **Performance:** one 60 Hz timer; idle CPU should stay around 2–3%. No per-frame allocations or
  implicit animations (wrap layer changes in `CATransaction` with actions disabled).
- **Workflow:** `main` is protected. Work on a branch, open a PR, CI (`build`) must be green, squash merge.
  Visual or promotional changes (art, GIFs, videos, README media) wait for the maintainer's review before merging.
- **Never commit** `build/`, `.build/`, `promo/node_modules/`, recordings in `promo/public/*/`, local settings
  such as `.claude/settings.local.json`, or anything secret. Add files by name rather than `git add -A`.

## Style

- Match the surrounding code: small types, few comments that explain *why*, no banner comments.
- British spelling in code, comments and docs (behaviour, colour, favourite), plain short sentences.
- New simulation code that doesn't need AppKit should not import it: it is moving into a portable
  engine (see the [engine strategy](docs/architecture/engine-strategy.md)).

## Docs for agents

| Doc | Read it when you… |
|---|---|
| [docs/agents/architecture.md](docs/agents/architecture.md) | need the code map, coordinates, the world loop, surfaces and navigation |
| [docs/agents/behaviour.md](docs/agents/behaviour.md) | change what cats decide or do, or the brain / `.catprofile` format |
| [docs/agents/art.md](docs/agents/art.md) | draw or change sprites, furniture, emotes |
| [docs/agents/demos-and-videos.md](docs/agents/demos-and-videos.md) | add a demo scene, re-record GIFs, the trailer or the windows short |
| [docs/agents/workflow.md](docs/agents/workflow.md) | branch, commit, open a PR, update the changelog, release |
| [docs/architecture/engine-strategy.md](docs/architecture/engine-strategy.md) | plan anything structural: where the code is heading |
