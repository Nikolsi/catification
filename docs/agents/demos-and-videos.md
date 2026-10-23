# Demo scenes, GIFs and videos

Everything visual in the README and the release notes is recorded from the app itself, from scripted scenes.

## Demo scenes

- `Catification --demo <scene>` (`App/DemoDirector.swift`) stages a small room or the menu bar around the notch,
  with fixed cats and furniture (`makeStore`), and runs a timed script (`script()`).
- The scene prints its capture rectangle (top-left global coordinates) and duration on the first line of stdout.
- Story scenes report key moments as `EVENT <name> <t> <cat> <x> <y>` lines (`DemoDirector.current?.event`),
  with the cat's position normalised to the stage (0…1, top-left). The video edits are timed by them.
- Prefer waiting for a state ("the cat has landed and sat down") over fixed delays: cats are random and
  timing differs between runs.

## Recording

- `make demos` (`scripts/record-demos.sh`) records every scene with `screencapture` and turns it into GIFs in
  `docs/media/` with ffmpeg (recorded at 2×). It quits a running Catification first and reopens it afterwards.
- `make trailer` / `make windows-video` (`scripts/record-trailer.sh [trailer|windows]`) record a story scene,
  find the sync mark (the fake menu bar clock ticks 9:40 → 9:41 when the story starts), write
  `promo/public/<scene>/timeline.json` and render with Remotion into `docs/media/<scene>.mp4`.
  `--render` re-renders the last recording.
- Needs: Screen Recording permission for the terminal, ffmpeg, Node.js, a MacBook with a notch for the
  notch scenes. Nobody should move the mouse over the recorded area while it records.

## The Remotion project (`promo/`)

- Compositions in `promo/src/`: `Trailer.tsx`, `Windows.tsx`; shared intro, footage, camera and end card in `common.tsx`.
- Clips (footage stretches with a playback rate) and camera shots (zoom + centre) are computed from the timeline.
- `promo/.npmrc` points at the public npm registry. `cd promo && npm run studio` opens Remotion Studio.

## Checking the result

Look at frames, not just the logs: extract a contact sheet with ffmpeg and check that the cat is in frame,
nothing is cut off and the story reads. Check text at phone size (scale a frame to 390 px wide).
Videos and GIFs are visual changes: open the PR and wait for the maintainer before merging.
