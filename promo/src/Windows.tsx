import { type Clip, Cut, duration, Footage, outputTime, type Shot, type Timeline } from "./common";

export type WindowsTimeline = Timeline<"drag" | "calculate" | "jump" | "landed" | "drag2">;

/** Real time, with the leap from one window to the other in slow motion. */
function clips(t: WindowsTimeline): Clip[] {
  const { jump, landed, drag2 } = t.events;
  return [
    { from: t.offset + 0.4, to: jump.t - 0.2, rate: 1 },
    { from: jump.t - 0.2, to: landed.t + 0.3, rate: 0.35 },
    { from: landed.t + 0.3, to: drag2.t + 3.1, rate: 1 },
  ];
}

export const windowsDuration = (t: WindowsTimeline) => duration(clips(t));

function shots(t: WindowsTimeline): Shot[] {
  const e = t.events;
  const at = (footage: number) => outputTime(clips(t), footage);
  return [
    // The whole desktop first: real windows, and cats on top of them.
    { at: 0, zoom: 1, x: 0.5, y: 0.5 },
    // Closer while the terminal is dragged with the cat riding on it.
    { at: at(e.drag.t), zoom: 1.35, x: 0.5, y: 0.52 },
    { at: at(e.calculate.t) - 0.3, zoom: 1.6, x: e.calculate.x, y: e.calculate.y + 0.06 },
    { at: at(e.calculate.t) + 0.6, zoom: 2, x: e.calculate.x + 0.03, y: e.calculate.y - 0.02 },
    { at: at(e.jump.t), zoom: 2, x: (e.calculate.x + e.landed.x) / 2, y: (e.calculate.y + e.landed.y) / 2 },
    { at: at(e.landed.t) + 0.3, zoom: 2.1, x: e.landed.x + 0.04, y: e.landed.y + 0.04 },
    // Pull back as the Notes window is dragged too, cats and all.
    { at: at(e.drag2.t) + 0.7, zoom: 1.8, x: e.landed.x + 0.04, y: e.landed.y + 0.1 },
    { at: at(e.drag2.t) + 3.1, zoom: 1.15, x: 0.5, y: 0.5 },
  ];
}

export const Windows: React.FC<{ timeline: WindowsTimeline | null }> = ({ timeline }) => {
  if (!timeline) return null;
  return (
    <Cut intro="They live on your windows.">
      <Footage src="windows/raw.mp4" clips={clips(timeline)} shots={shots(timeline)} />
    </Cut>
  );
};
