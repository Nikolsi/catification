# Contributing to Catification

Thanks for wanting to help the cats! Bug reports, ideas, pixel art, translations and code are all welcome.
Not sure where to start? Say hi in [Discussions](https://github.com/Nikolsi/catification/discussions).

## Getting started

```bash
make dev        # debug build, runs from the terminal (Ctrl-C to quit)
make run        # release .app in build/, launched like a normal app
make test       # unit tests
make sprites    # every animation of every coat in .preview/sprites.png
```

- `CATIFICATION_DEBUG=1 make dev` prints every activity change of every cat, which helps a lot when tuning behaviour.
- `Catification --settings` opens the settings window on launch.
- `scripts/build-app.sh --universal --version 1.2.3` is what the release workflow runs.

## Where things live

| Area | Files |
|---|---|
| Cat behaviour | `Sources/Catification/World/Cat.swift` |
| Character: habits, needs, routines, reactions, `.catprofile` | `Brain/` (`CatBrain.swift`, `UtilityPlanner.swift`) |
| Overlay, input, furniture, toys | `World/CatWorld.swift`, `World/WorldObjects.swift`, `World/Butterfly.swift` |
| What cats can stand on, route planning | `World/Surfaces.swift`, `World/Navigator.swift` |
| Pixel art | `Art/CatArt.swift` (cat poses), `Art/PropArt.swift`, `Art/EmoteArt.swift`, `Art/PixelFont.swift` |
| Settings | `Model/`, `UI/` |

Sprites are ASCII grids. Letters are colour *roles*, not colours: `F` fur, `S` stripes, `D` far-side fur, `B` belly and paws, `P` pink, `E` eyes, `K` ink. Outlines are added automatically. After changing art, run `make sprites` and look at the sheet.

Where the code is heading: the simulation is slowly becoming a Swift library that doesn't depend on AppKit,
with the Mac app as its first platform adapter. See [docs/architecture/engine-strategy.md](docs/architecture/engine-strategy.md).
New simulation code that doesn't need AppKit is easier to move later.

## Demo recordings

The GIFs in the README are recorded from scripted scenes, so they're easy to redo when behaviour
or art changes, and new features can come with their own clip.

```bash
brew install ffmpeg
make demos                          # every scene
scripts/record-demos.sh jump trash  # just some
```

- Scenes live in `Sources/Catification/App/DemoDirector.swift`. Each one sets up throwaway cats and
  furniture, a small stage with a backdrop (so nothing else on your screen is recorded) and a short
  script of what the cats do. `Catification --demo <scene>` runs one by hand.
- To add a scene:
  1. Add a case to `Scene` and give it a `duration`.
  2. Fill in its cats and furniture in `makeStore()`, start positions in `startPositions`, and actions in `script()`.
  3. Add the name to the list in `scripts/record-demos.sh` and show the GIF in both READMEs.
- Your terminal needs the Screen Recording permission. Don't touch the mouse while recording: the
  `pet` scene moves the cursor itself, and the others park it off-stage.

## The trailer and the windows short

`make trailer` records the trailer footage from the `trailer` demo scene and composes it with [Remotion](https://www.remotion.dev)
into `docs/media/trailer.mp4`: camera moves, slow motion on the missed jump and the end card.
`make windows-video` does the same for `docs/media/windows.mp4`, a short with real windows: the app opens a
Terminal-like and a Notes-like window, drags them around and the cats ride along and jump between them.

- The stories are scripted in `DemoDirector.swift`. The compositions live in `promo/src/Trailer.tsx` and `promo/src/Windows.tsx`
  (shared intro, footage and end card in `promo/src/common.tsx`); they are timed by the events the scene reports
  (portal, calculate, jump, hang…), so they keep working when a story changes.
- `scripts/record-trailer.sh [trailer|windows] --render` re-renders from the last recording; `cd promo && npm run studio` opens Remotion Studio for tweaking.
- Needs a MacBook with a notch, ffmpeg and Node.js. `promo/.npmrc` points at the public npm registry.

## Credit

Ideas count as contributions too. When a change lands, its `CHANGELOG.md` line credits the people behind it:
`(idea by @someone)` or `(by @someone in #12)`. The release notes then thank everyone mentioned, plus the authors of
pull requests merged since the last release, automatically. People who shaped the project also get a line in the
**Thanks** section of the README.

## Releasing (maintainer)

1. In `CHANGELOG.md`, rename `## Unreleased` to the new version, e.g. `## 0.2.0`. Show off new features with their demo GIFs as plain images (`![…](docs/media/demo-naps.gif)`).
2. Preview the notes: `scripts/release-notes.sh 0.2.0 Nikolsi/catification v0.2.0`.
3. Merge that through a PR, then tag `main`: `git tag -a v0.2.0 -m "Catification 0.2.0" && git push origin v0.2.0`.
4. The release workflow builds the app, attaches the zip and checksums, and drafts the release with those notes. GIF links are pinned to the tag. Check the draft, then publish it.

## Translations

User-facing strings use their English text as the key:

- in code: `L("Show Cats")`;
- in SwiftUI: plain literals like `Toggle("Show cats", …)`.

To add a language:

1. Copy `Resources/ru.lproj/Localizable.strings` to `Resources/<code>.lproj/Localizable.strings` and translate the right-hand sides.
2. Add the language code to `CFBundleLocalizations` in `scripts/build-app.sh`.
3. Check it with `open build/Catification.app --args -AppleLanguages '(<code>)'`.

When you add a new string in English, please add it to every existing `Localizable.strings` too, untranslated if necessary.

## Pull requests

`main` is protected: every change, the maintainer's included, goes through a pull request with green CI.

- Keep changes focused; match the style of the surrounding code.
- `make test` must pass. For behaviour changes, a short screen recording in the PR is gold.
- The app must stay offline and must not read window contents or titles.

By contributing you agree that your contributions are licensed under the [MIT License](LICENSE).
