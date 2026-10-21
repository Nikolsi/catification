# Contributing to Catification

Thanks for wanting to help the cats! Bug reports, ideas, pixel art, translations and code are all welcome.

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

- Keep changes focused; match the style of the surrounding code.
- `make test` must pass. For behaviour changes, a short screen recording in the PR is gold.
- The app must stay offline and must not read window contents or titles.

By contributing you agree that your contributions are licensed under the [MIT License](LICENSE).
