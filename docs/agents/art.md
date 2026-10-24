# Pixel art

All art is drawn in code as ASCII grids, rendered at an integer scale with nearest-neighbour filtering.

- Cat poses: `Art/CatArt.swift`. Furniture and toys: `Art/PropArt.swift`. Emotes (hearts, zzz, "?"): `Art/EmoteArt.swift`.
  Pixel text for the jump maths: `Art/PixelFont.swift`. Rasterising: `Art/PixelCanvas.swift`.
- In cat sprites, letters are colour **roles**, not colours: `F` fur, `S` stripes, `D` far-side fur,
  `B` belly and paws, `P` pink, `E` eyes, `K` ink. Coats map roles to colours, so one pose works for every coat.
- Animations live in `Anim` (frames per second and where the head is, for emotes) and `CatArt.frames`. Sleeping has several poses (`sleep`, `sleepCurled`, `sleepSploot`, `sleepBelly`); `yawn` and `stretch` play over sitting and standing for a moment. Purely visual random choices use `Sim.looks`, never `Sim.rng`, so looks never change behaviour.
- `Catification --dump-sprites out.png sleep,yawn` renders just the named animations for a few coats: much quicker to check than the whole sheet.
- Outlines are added automatically: soft for cats, hard for props. Don't draw them by hand.
- Facing: poses are drawn facing right and mirrored for left. When adding a walk or run cycle, check that the
  feet move the way the cat walks (an easy way to get a moonwalk).
- After any art change run `make sprites` and look at `.preview/sprites.png` (every animation, every coat).
- Generated images: `make banner` renders the README banner and the social preview into `docs/media/` (commit them);
  the app icon is rendered by `IconRenderer` (`--render-icon`) during `make app`.

Keep the style: small sprites (a cat canvas is 26×18 sprite pixels), a limited palette per coat, readable silhouettes.
Show art changes in the PR with a screenshot or the sprite sheet; they wait for the maintainer's review.
