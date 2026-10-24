# Behaviour and the brain

A cat's character is data (`CatBrain`), not code. The app runs it locally and deterministically, without any AI.

## How a cat decides

1. When a cat is free, `Cat.decide()` builds a `PlannerContext`: energy, the social and curiosity needs,
   mood, the hour and which actions make sense right now (a post exists, a playmate is free…).
2. `UtilityPlanner.scores` multiplies, per `CatAction`: base weight × habit × current state × needs × active routines.
3. `UtilityPlanner.pick` chooses at random in proportion to the scores, so cats are likely, not robotic.
4. `Cat.perform(_:world:)` runs the action through the existing methods (`goToSleep`, `goRummage`, `startPlay`…).

`CATIFICATION_DEBUG=1 make dev` logs every activity change with the scores.

## Checking behaviour over a simulated day

Don't tune behaviour by watching the screen. Run it:

- `Catification --simulate 8 [--seed N] [cats.catprofile …]` prints, per cat, the actions it started,
  the share of time per activity, where it napped and how often it jumped, calculated, hung and fell.
- In tests, use `World` (`World/World.swift`): `World(seed:)`, `spawn(character:)`, `emit(.petted, to:)`,
  `run(for:)` / `update(deltaTime:)`, then read `world.report`. See `WorldTests` for examples.
- The same seed, cats and steps give the same report. Everything cats do takes time from `Sim.time` and
  randomness from `Sim.rng`; never call `Date()`, `CACurrentMediaTime()` or `.random()` without
  `using: &Sim.rng` in simulation code, and don't let the order of a `Set` or `Dictionary` decide anything
  (sort first: `SurfaceID` and `Navigator.Node` are `Comparable` for that).

## The brain (`Brain/CatBrain.swift`)

- `habits`: multiplier per `CatAction` (0…3); only the special ones are listed in the editor.
- `places`: favourite nap spots per `CatPlace` (box, laundry, wardrobe, flower pot, high shelf, friends…).
- `needs`: how much loneliness and boredom sway choices.
- `routines`: hour windows that boost an action ("afternoon: nap").
- `reactions`: event → response with a chance and a cooldown. Built-in ones have stable IDs from `UUID(stable:)`.
- `recipes`: habits made of several steps, "rituals" in the editor (`Brain/Recipe.swift`). A trigger
  (`{"event": "petted"}` or `{"hours": [19, 23]}`), then steps (`{"goTo": "laundry"}`, `{"sleep": 120}`,
  `{"zoomies": true}`…). Event recipes start at the cat's next decision after the event; time-of-day recipes
  compete with the actions in the planner by `weight`. A step that can't happen drops the recipe; petting,
  squishing or picking a cat up interrupts it. Unknown triggers and steps from newer versions are kept on
  save but never run. Built-in templates: `RecipeTemplate`.
- `phrases`: lines per situation, for the thought bubbles to come.

Personalities (`playful`, `lazy`, …) are presets: `CatBrain.preset(_:)`. They reproduce the weights the
app used before brains existed, and `BrainTests.testPresetsReproduceTheOldWeights` keeps it that way.

## Formats

- `CatConfig` (in settings and in `.catprofile`) has an optional `brain`; without it the personality's preset is used.
- Decoding is lenient: unknown actions, places and keys are skipped, values are clamped, missing fields get defaults.
  A profile from a newer version must still load. Add a decoding test for every format change.
- `CatProfile` writes the full brain out, so a shared cat keeps working if presets change later.
- `UUID(stable:)` output is saved in profiles: never change how it is computed.

## Adding something

- **A new action:** a `CatAction` case with a title (localised), a base weight in `UtilityPlanner.baseWeights`,
  availability in `Cat.decide()`, execution in `Cat.perform`, and a test. Presets must keep their old scores:
  check `testPresetsReproduceTheOldWeights`.
- **A new nap spot:** a `CatPlace` case and title, how `CatWorld` finds such a spot (`napSpot`/`napFurniture`),
  and furniture art if it is a piece of furniture.
- **A new reaction event:** hook it where the event happens in `Cat`/`CatWorld`, then let the brain decide the response.
