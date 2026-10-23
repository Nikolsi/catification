import { type Clip, Cut, duration, Footage, outputTime, type Shot, type Timeline } from "./common";

export type TrailerTimeline = Timeline<"portal" | "calculate" | "jump" | "hang" | "fell">;

/**
 * The cut: real time up to just before the jump, slow motion through the miss, a good long hang
 * (the cat hangs on for four seconds; a jump cut keeps the best of it), then the punchline: it
 * falls, looks puzzled and grooms as if it meant to.
 */
function clips(t: TrailerTimeline): Clip[] {
  const { jump, hang, fell } = t.events;
  return [
    { from: t.offset + 0.6, to: jump.t - 0.3, rate: 1 },
    { from: jump.t - 0.3, to: hang.t + 0.4, rate: 0.3 },
    { from: hang.t + 0.4, to: hang.t + 2.6, rate: 1 },
    { from: fell.t - 0.9, to: fell.t + 2.4, rate: 1 },
  ];
}

export const trailerDuration = (t: TrailerTimeline) => duration(clips(t));

function shots(t: TrailerTimeline): Shot[] {
  const e = t.events;
  const at = (footage: number) => outputTime(clips(t), footage);
  const mid = { x: (e.calculate.x + e.hang.x) / 2, y: (e.calculate.y + e.hang.y) / 2 };
  return [
    { at: 0, zoom: 1.25, x: 0.3, y: 0.25 },
    { at: at(e.portal.t) - 0.4, zoom: 1.9, x: 0.5, y: 0.12 },
    // Out of the portal, follow the cat to the right: the menu bar and the shelf below it.
    { at: at(e.portal.t) + 1.2, zoom: 1.6, x: 0.72, y: 0.3 },
    { at: at(e.calculate.t) - 0.8, zoom: 1.6, x: 0.72, y: 0.35 },
    { at: at(e.calculate.t) + 0.4, zoom: 2.4, x: e.calculate.x, y: e.calculate.y - 0.08 },
    { at: at(e.jump.t), zoom: 2.2, x: mid.x, y: mid.y - 0.05 },
    { at: at(e.hang.t), zoom: 2.8, x: e.hang.x, y: e.hang.y - 0.04 },
    { at: at(e.hang.t + 2.6) - 0.01, zoom: 3.1, x: e.hang.x, y: e.hang.y - 0.04 },
    // Follow the fall down to where it lands, then sit on the "I meant to do that".
    { at: at(e.fell.t), zoom: 2.0, x: (e.hang.x + e.fell.x) / 2, y: (e.hang.y + e.fell.y) / 2 },
    { at: at(e.fell.t) + 0.8, zoom: 3.2, x: e.fell.x, y: e.fell.y - 0.06 },
    { at: at(e.fell.t) + 3, zoom: 3.5, x: e.fell.x, y: e.fell.y - 0.06 },
  ];
}

export const Trailer: React.FC<{ timeline: TrailerTimeline | null }> = ({ timeline }) => {
  if (!timeline) return null;
  // A tiny wobble while the cat hangs on for dear life.
  const shake = outputTime(clips(timeline), timeline.events.hang.t);
  return (
    <Cut intro="Your Mac has a cat problem.">
      <Footage src="trailer/raw.mp4" clips={clips(timeline)} shots={shots(timeline)} shake={shake} />
    </Cut>
  );
};
