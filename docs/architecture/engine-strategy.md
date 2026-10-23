# Engine strategy

> **The engine simulates characters in a world. The platform adapter makes the operating system part of that world.**

**Status:** accepted direction, adopted step by step. Not a rewrite.

Catification stays the product: delightful cats on a Mac desktop. Underneath it, the simulation
(characters, their brains, movement, the world they live in) gradually becomes a Swift library
that doesn't know about AppKit. The macOS app becomes its first *platform adapter*: it tells the
engine where the windows, the menu bar and the notch are, and draws what the engine says.

Abstractions come from real product needs, not ahead of them. Each step below has to pay off on
its own, in the Mac app, before the next one starts.

## Layers

| Layer | What it is | Today |
|---|---|---|
| **A. Engine** | World and entity state, needs, behaviour selection, navigation, physics, events, scheduling. Pure Swift, no AppKit, SwiftUI or Core Animation. | Mixed into `World/Cat.swift` and `World/CatWorld.swift` |
| **B. Content** | Cat personalities, actions, sprites, furniture, toys, profiles. Data where possible. | `Brain/`, `Model/`, `Art/` |
| **C. Platform adapter** | Screens, windows, the notch, input, permissions, the overlay, rendering. | `World/Surfaces.swift`, `DesktopIcons.swift`, `OverlayPanel.swift`, the layer code in `Cat`/`CatWorld` |
| **D. Apps and tools** | Catification, the character editor, a headless runner, scene recording. | The app, `UI/`, `DemoDirector`, `promo/` |

## Principles

1. **The engine owns simulation state.** Native UI objects are never the source of truth for the world or a character.
2. **Adapters observe the OS.** The engine gets normalised observations (surfaces, obstacles, events), not windows or accessibility objects.
3. **Rendering is a projection of the simulation.** Layers and images live outside the engine.
4. **Capabilities are explicit.** An environment may or may not have window surfaces, a notch, desktop icons.
5. **Content is data.** Characters and behaviours move towards versioned, validated data formats that load without Swift.
6. **AI is optional.** Everything works without a model, a network connection or a key.
7. **Migration is incremental.** Existing features and saved cats (`.catprofile`, settings) keep working at every step.

## Where we are (dependency audit)

A first pass over the imports of every source file:

| Group | Files | Notes |
|---|---|---|
| **Portable now** | `Brain/UtilityPlanner`, `Model/CatConfig`, `Model/Furniture`, `App/Localization` | Foundation only. |
| **Portable with a small change** | `World/Navigator` | CoreGraphics types only; on Linux `CGFloat`/`CGPoint`/`CGRect` come from Foundation. |
| | `Brain/CatBrain` | `CryptoKit` for `UUID(stable:)`. Preset IDs are saved in profiles, so the replacement must produce the same bytes (swift-crypto, or our own SHA-256). |
| | `Brain/CatProfile` | The file format and the save/open panels share a file: split. |
| | `Model/RGB` | `Color`/`NSColor` conversions move to an extension in the app. |
| **Art** | `PixelCanvas`, `PropArt`, `EmoteArt`, `PixelFont`, `SpriteSheet` | The ASCII art is portable; rasterising uses CoreGraphics. Later: render into a plain pixel buffer and let the adapter make images. |
| **The knot** | `World/Cat` (~1600 lines), `World/CatWorld` (~1300 lines) | Simulation and presentation in the same classes: a cat owns its `CALayer`s, the world owns the panel, timers and window tracking. Splitting these is most of the work. |
| **Platform** | `Surfaces`, `DesktopIcons`, `OverlayPanel`, `WorldGeometry`, `Portal`, `Particle`, `Butterfly`, `WorldObjects`, `App/`, `UI/` | Stay in the app; some of their logic (portal state, butterfly flight) moves to the engine later. |

## Roadmap

### Now: a portable core (alongside v0.2–v0.3)

- A `CatificationCore` library target with what is portable today: brain, planner, models, navigator.
  The app depends on it. Nothing changes for users.
- A Linux job in CI that builds and tests the core, so it stays portable.
- **Deterministic simulation:** time and randomness injected (a clock and a seeded generator).
  This pays off immediately: demo videos stop depending on retries and "wait until the cat sits",
  and behaviour gets scenario tests ("a trash-loving cat rummages more over a simulated day").

### Next: simulation and presentation apart

- Extract the state and `update()` of a cat (`CatSim`) from `Cat`, and the world's state from `CatWorld`,
  bit by bit, in the places we touch for features anyway.
- A snapshot that the macOS renderer reads each frame. Thought bubbles (v0.3) are the first new
  presentation element built on it.
- A **headless runner**: run a world for a simulated day without a screen. Used by tests, and by the
  AI features to check that "description → character" really produces the cat that was described.

### Later, when there is a reason

- **Environment API:** normalised surfaces and obstacles, capability discovery, one event pipeline
  for user, OS and app events (app awareness from the v0.3 ideas lands here).
- **Declarative behaviours:** reactions and routines in a versioned format, loaded and validated at runtime.
- **A second platform.** Windows only when people ask for it. The portable core is the cheap part;
  the adapter (window enumeration, a transparent click-through overlay, rendering, and a new home for
  the portals without a notch) is close to a new app.
- **Other kinds of characters.** The engine shouldn't assume cats where it doesn't need to, but it gets
  generalised when a second real kind of character exists, not before.

## Product tracks this enables

### Characters without Swift

What exists: the character editor (coat, personality, habits, nap spots, routines, reactions,
"About this cat"), `.catprofile` export/import, and the brain as JSON.

Next steps, in rough order:
- Double-click a `.catprofile` to import it (document type in the app bundle), and a gallery of shared cats in Discussions.
- A published, versioned JSON schema for profiles, so people can write and validate them by hand.
- Reactions and routines fully editable in the editor; phrases per cat once bubbles exist.
- Custom looks: palette and pattern editing, then sprite import (Aseprite / PNG sheets).
- Describe a cat in words → profile, with local AI (v0.3 ideas).

### Installing

Today: a zip from GitHub Releases, ad-hoc signed, so the first launch needs "Open Anyway" or `xattr`.

- **Homebrew tap now:** `brew install --cask nikolsi/tap/catification` from our own tap, bumped by the
  release workflow. Homebrew no longer helps users skip Gatekeeper (`--no-quarantine` is deprecated), so
  it still needs "Open Anyway" until builds are notarized.
- **Notarized builds:** a Developer ID certificate (Apple Developer Program) and notarization in the
  release workflow. That removes the warning, and is required for the official `homebrew/cask` tap, which
  is dropping unsigned casks.
- **Official `homebrew/cask`** once builds are notarized and the project meets its notability bar.

### Cartoons (an idea for the future)

The trailer is already a scripted scene recorded from the app and edited with Remotion. With a
deterministic, headless engine, scenes could be scripted as data and rendered frame by frame without
screen recording. Cartoons with these characters stop being a hack. Not planned; a reason to keep
the simulation deterministic and the renderer separate.

## Non-goals

- Rewriting Catification from scratch, or leaving Swift.
- Supporting every OS at once, or identical integrations everywhere.
- A general game engine, physics framework or plugin marketplace.
- AI as a requirement for behaviour.
- A separate engine repository, until the engine has a second real user.

## Success criteria

- The core builds and passes tests on macOS and Linux.
- Core modules don't import AppKit, SwiftUI or Core Animation.
- Catification keeps its behaviour and its ~2–3% idle CPU.
- Saved cats keep loading across format changes.
- The same simulation runs with and without a screen.
- A cat's behaviour can be created or changed without writing Swift.
