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

## The gap

Today's brain can only *tune* behaviour: weights over a fixed list of actions, favourite places, a daily
routine, reactions picked from a fixed list. A new habit ("after eating she naps on the wardrobe",
"at 6 am he wakes you by walking over the menu bar") is a sequence with conditions, and that still
takes Swift. Closing this gap matters more for the product than portability does.

## Roadmap

Order is set by what makes new behaviour faster to build and to check. Refactoring happens only where
a step needs it.

### Now: behaviour you can check in seconds

- **Deterministic simulation** (#19): time and randomness injected (a clock and a seeded generator).
  Demo videos stop depending on retries, and runs can be replayed.
- **A fast-forward runner:** run a world for a simulated day without showing it, faster than real time,
  and count what each cat did ("the trash lover rummaged 14 times, the plain cat 3"). Behaviour tuning
  and regression tests stop needing someone to watch the screen. This first version can run inside the
  app process (layers exist but are never shown), so it doesn't wait for the big split.

### Next: behaviour recipes

A recipe is a habit as data: a trigger, conditions and steps made of primitives the cats already have.

```json
{ "name": "Morning trash patrol",
  "when": { "hours": "7-10", "every": "2h" }, "chance": 0.5,
  "do": [ { "goTo": "trash" }, { "rummage": 8 }, { "emote": "happy" }, { "say": "Treasure!" } ] }
```

- Triggers: time of day, events (petted, ate, woke up, a friend nearby), needs, where the cat is.
- Steps: go to a place or furniture, sit, nap, rummage, groom, look at or follow the cursor, emote, jump, say.
- Stored in the brain, so recipes travel in `.catprofile` files. Validated and versioned like the rest.
- Needs the actions in `Cat` to become separate steps: the first, small part of splitting simulation from
  presentation, done because recipes need it.
- Later: a recipe editor in the cat editor, and AI that turns "my cat always…" into recipes for review.

### Later, when there is a reason

- **Portable core and Linux CI** (#18): cheap hygiene, done when it is convenient.
- **Simulation and presentation fully apart:** a snapshot the renderer reads each frame; a truly headless runner.
- **Environment API:** normalised surfaces and obstacles, capability discovery, one event pipeline for user,
  OS and app events.
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
- Behaviour recipes (see the roadmap): new habits as data, not just tuned weights.
- Teaching (below): the owner shapes habits by petting and pointing, without any editor at all.
- Custom looks: palette and pattern editing, then sprite import (Aseprite / PNG sheets).
- Describe a cat in words → profile, with local AI (v0.3 ideas).

### Teaching

Cats learn from how they are treated, the way real pets do. No model, no training data: small, visible
changes to the brain the owner can always see and edit.

- **Clicker training:** stroking a cat right after it did something makes that habit a little stronger;
  squishing makes it a little weaker. Each nudge is small, habits stay within their limits (0–3) and drift
  slowly back towards the personality's default, so a cat never gets stuck at an extreme.
  (It is the classic conditioning rule from animal psychology: the change is proportional to how
  surprising the reward is.)
- **"This is her spot":** drop a cat somewhere and mark it as a favourite place.
- **The diary** (v0.3) tells what a cat has learnt: "Ginger sleeps on the wardrobe more and more."

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
- A new habit can be created, shared and checked without writing Swift.
