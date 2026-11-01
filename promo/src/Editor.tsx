import { AbsoluteFill, Easing, interpolate, Sequence, useCurrentFrame, useVideoConfig } from "remotion";
import { type Clip, Cut, duration, FONT, FPS, Footage, outputTime, type Shot, type Timeline } from "./common";

export type EditorTimeline = Timeline<
  | "name"
  | "story"
  | "habit"
  | "trash"
  | "rummage"
  | "rummaged"
  | "spot"
  | "nap"
  | "asleep"
  | "ritual"
  | "pet"
  | "follow"
  | "home"
  | "end"
>;

/**
 * "Bring your own cat": brisk while the cursor works the editor, a jump cut through the long
 * rummage and the sit after the cuddle, a quick walk across the room, then real time for the ending.
 */
function clips(t: EditorTimeline): Clip[] {
  const e = t.events;
  return [
    { from: t.offset + 0.2, to: e.story.t - 0.2, rate: 1.4 },
    { from: e.story.t - 0.2, to: e.habit.t, rate: 1.8 },
    { from: e.habit.t, to: e.rummage.t + 3.2, rate: 1.7 },
    { from: e.rummaged.t - 0.9, to: e.nap.t + 0.2, rate: 1.6 },
    { from: e.nap.t + 0.2, to: e.asleep.t + 1, rate: 2.4 },
    { from: e.asleep.t + 1, to: e.pet.t, rate: 2 },
    { from: e.pet.t, to: e.pet.t + 4.6, rate: 1.3 },
    { from: e.follow.t - 0.5, to: e.home.t + 0.3, rate: 3 },
    { from: e.home.t + 0.3, to: e.end.t + 0.6, rate: 1 },
  ];
}

export const editorDuration = (t: EditorTimeline) => duration(clips(t));

function shots(t: EditorTimeline): Shot[] {
  const e = t.events;
  const at = (footage: number) => outputTime(clips(t), footage);
  const list: Shot[] = [
    // The whole desktop: the editor on the left, the cat in its room on the right.
    { at: 0, zoom: 1, x: 0.5, y: 0.5 },
    // The editor and the cat together, so each click shows on the cat.
    { at: at(e.name.t), zoom: 1.3, x: 0.47, y: 0.58 },
    { at: at(e.story.t) - 0.4, zoom: 1.3, x: 0.47, y: 0.58 },
    // Close on the story as it's typed, then on the habit it turns into.
    { at: at(e.story.t) + 0.3, zoom: 2, x: e.story.x, y: e.story.y + 0.05 },
    { at: at(e.habit.t), zoom: 1.9, x: e.habit.x, y: e.habit.y + 0.05 },
    { at: at(e.trash.t), zoom: 1.9, x: e.habit.x, y: e.habit.y + 0.05 },
    // Over to the room for each thing she does, back to the editor for the next setting.
    { at: at(e.trash.t) + 0.6, zoom: 2.2, x: e.rummage.x, y: e.rummage.y - 0.1 },
    { at: at(e.rummaged.t), zoom: 2.2, x: e.rummage.x, y: e.rummage.y - 0.1 },
    { at: at(e.spot.t) - 0.2, zoom: 1.9, x: e.spot.x, y: e.spot.y + 0.08 },
    { at: at(e.nap.t), zoom: 1.9, x: e.spot.x, y: e.spot.y + 0.08 },
    { at: at(e.nap.t) + 0.5, zoom: 2.1, x: (e.nap.x + e.asleep.x) / 2, y: e.asleep.y - 0.1 },
    { at: at(e.asleep.t) + 0.4, zoom: 2.3, x: e.asleep.x, y: e.asleep.y - 0.1 },
    { at: at(e.ritual.t) - 0.2, zoom: 1.9, x: e.ritual.x, y: e.ritual.y },
    { at: at(e.pet.t) - 0.7, zoom: 1.9, x: e.ritual.x, y: e.ritual.y },
    { at: at(e.pet.t), zoom: 2.4, x: e.pet.x, y: e.pet.y - 0.1 },
    // She follows the cursor over to the editor, and settles down beside it.
    { at: at(e.follow.t), zoom: 2, x: (e.pet.x + e.home.x) / 2, y: e.home.y - 0.12 },
    { at: at(e.home.t) + 0.4, zoom: 2.1, x: e.home.x - 0.06, y: e.home.y - 0.14 },
    { at: at(e.end.t) + 0.6, zoom: 1.7, x: e.home.x - 0.12, y: e.home.y - 0.2 },
  ];
  // Moments squeezed together by a fast clip can come out of order: keep each shot after the last.
  return list.reduce<Shot[]>((done, s) => [...done, { ...s, at: Math.max(s.at, (done.at(-1)?.at ?? -1) + 0.1) }], []);
}

/** A line from her story, shown while she lives it. */
const Caption: React.FC<{ text: string; length: number }> = ({ text, length }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const t = frame / fps;
  const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;
  const opacity = interpolate(t, [0, 0.25, length - 0.3, length], [0, 1, 1, 0], clamp);
  const rise = interpolate(t, [0, 0.4], [18, 0], { ...clamp, easing: Easing.out(Easing.cubic) });
  return (
    // At the top: she's down on the floor, below it.
    <AbsoluteFill style={{ justifyContent: "flex-start", alignItems: "center", paddingTop: 70 }}>
      <div
        style={{
          opacity,
          transform: `translateY(${rise}px)`,
          fontFamily: FONT,
          fontSize: 62,
          fontWeight: 700,
          color: "white",
          padding: "16px 40px",
          borderRadius: 999,
          background: "rgba(16, 14, 24, 0.72)",
        }}
      >
        “{text}”
      </div>
    </AbsoluteFill>
  );
};

export const Editor: React.FC<{ timeline: EditorTimeline | null }> = ({ timeline }) => {
  if (!timeline) return null;
  const e = timeline.events;
  const at = (footage: number) => outputTime(clips(timeline), footage);
  const caption = (text: string, from: number, to: number) => (
    <Sequence from={Math.round(from * FPS)} durationInFrames={Math.round((to - from) * FPS)}>
      <Caption text={text} length={to - from} />
    </Sequence>
  );
  return (
    <Cut intro="Bring your own cat.">
      <Footage src="editor/raw.mp4" clips={clips(timeline)} shots={shots(timeline)} />
      {caption("Raids the trash.", at(e.trash.t) + 0.3, at(e.rummaged.t))}
      {caption("Naps belly up in her bed.", at(e.nap.t) + 0.3, at(e.asleep.t) + 1.2)}
      {caption("Follows me around after cuddles.", at(e.pet.t) + 0.6, at(e.home.t) + 1.2)}
    </Cut>
  );
};
