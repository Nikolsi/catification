# Architecture

## Code map

| Area | Files |
|---|---|
| App start, menu, command-line switches (`--demo`, `--settings`, `--render-banner`…) | `App/App.swift`, `App/AppDelegate.swift` |
| Scripted demo scenes for recordings | `App/DemoDirector.swift` |
| A cat: state, activities, movement, jumping, reactions, its layers | `World/Cat.swift` |
| The world: overlay panel, the 60 Hz tick, input, furniture, toys, emotes, maths overlays | `World/CatWorld.swift`, `World/WorldObjects.swift` |
| Screen geometry: menu bar, notch, floor | `World/WorldGeometry.swift` |
| What cats can stand on; windows and desktop icons as surfaces | `World/Surfaces.swift`, `World/DesktopIcons.swift` |
| Route planning and jump ballistics | `World/Navigator.swift` |
| Notch portals, butterflies, particles | `World/Portal.swift`, `World/Butterfly.swift`, `World/Particle.swift` |
| A cat's character as data and the action planner | `Brain/CatBrain.swift`, `Brain/UtilityPlanner.swift`, `Brain/CatProfile.swift` |
| Saved settings, cats, furniture | `Model/` |
| Pixel art and renderers | `Art/` |
| Settings window and cat editor (SwiftUI) | `UI/` |

All paths are under `Sources/Catification/`. Tests are in `Tests/CatificationTests/`.

## The world loop

- `CatWorld` owns a borderless, click-through `NSPanel` covering the screen (`OverlayPanel.swift`) and a
  60 Hz `Timer`. Each tick updates every cat and object, then moves their `CALayer`s.
- **Modes** (`WorldMode`): `menuBar` (cats only on the menu bar), `screen` (whole screen, above windows),
  `desktop` (behind windows, on the desktop).
- The panel ignores the mouse except right over a cat or prop, so the rest of the screen keeps working.

## Coordinates

- World / panel coordinates: points, **origin bottom-left, y up**, relative to the panel (the screen).
- `CGWindowListCopyWindowInfo` and `screencapture` use **top-left** global coordinates anchored at the
  primary display; convert with the primary screen's height (see `WindowTracker.update`).
- Sprites are drawn at an integer pixel scale (`cat.pixel`, from the screen and the cat's size) with
  nearest-neighbour filtering, so pixel art stays crisp.

## Surfaces and navigation

- A `Surface` is a horizontal walkable line: `id` (`SurfaceID`: `.menuBar`, `.ground`, `.shelf(UUID)`,
  `.perch`, `.window(Int)`, `.icon`, `.top(UUID)` for furniture tops…), `y` and visible `segments`.
- Window tops come from window bounds only, cut wherever a window in front covers them. Surfaces above the
  menu bar line are ignored.
- `Navigator` runs Dijkstra over surface segments. A hop is a jump (`Navigator.hop`) or a climb along a
  post (`ClimbLink`). Limits (`NavLimits`) scale with the cat's pixel size.
- Big jumps start with a "calculation" (formulas drawn around the cat). Some jumps miss on purpose and the
  cat hangs on the edge.
- Cats standing on a window ride along when the window moves; the tracker polls faster while someone rides.

## Where new code goes

Keep simulation logic (state, decisions, geometry) free of AppKit where you can, and keep layers and
images in the presentation code. The plan is in the [engine strategy](../architecture/engine-strategy.md):
a portable core first (`Brain/`, `Model/`, `Navigator`), then splitting `Cat`/`CatWorld` into simulation
and presentation.
