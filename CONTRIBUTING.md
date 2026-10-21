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
| Overlay, input, furniture, toys | `World/CatWorld.swift`, `World/WorldObjects.swift`, `World/Butterfly.swift` |
| What cats can stand on, route planning | `World/Surfaces.swift`, `World/Navigator.swift` |
| Pixel art | `Art/CatArt.swift` (cat poses), `Art/PropArt.swift`, `Art/EmoteArt.swift`, `Art/PixelFont.swift` |
| Settings | `Model/`, `UI/` |

Sprites are ASCII grids. Letters are colour *roles*, not colours: `F` fur, `S` stripes, `D` far-side fur, `B` belly and paws, `P` pink, `E` eyes, `K` ink. Outlines are added automatically. After changing art, run `make sprites` and look at the sheet.

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
