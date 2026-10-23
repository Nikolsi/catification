import { Gif } from "@remotion/gif";
import {
  AbsoluteFill,
  Easing,
  interpolate,
  OffthreadVideo,
  Sequence,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";

/** A key moment in the footage: footage time in seconds, and where the cat is (0…1, top left). */
type Moment = { t: number; x: number; y: number };

export type Timeline = {
  /** Footage time when the story starts. */
  offset: number;
  events: { portal: Moment; calculate: Moment; jump: Moment; hang: Moment };
};

/** A stretch of footage, played at some speed. */
type Clip = { from: number; to: number; rate: number };

const END_CARD = 4;
const CROSSFADE = 0.6;

/** The cut: real time up to just before the jump, slow motion through the miss, then a beat of hanging. */
function clips(t: Timeline): Clip[] {
  const { jump, hang } = t.events;
  return [
    { from: t.offset + 0.6, to: jump.t - 0.3, rate: 1 },
    { from: jump.t - 0.3, to: hang.t + 0.4, rate: 0.3 },
    { from: hang.t + 0.4, to: hang.t + 2.6, rate: 1 },
  ];
}

const clipLength = (c: Clip) => (c.to - c.from) / c.rate;

export function trailerDuration(t: Timeline): number {
  return clips(t).reduce((sum, c) => sum + clipLength(c), 0) + END_CARD - CROSSFADE;
}

/** Output time of a footage moment (assumes it falls inside one of the clips). */
function outputTime(t: Timeline, footage: number): number {
  let elapsed = 0;
  for (const c of clips(t)) {
    if (footage <= c.to) return elapsed + Math.max(0, footage - c.from) / c.rate;
    elapsed += clipLength(c);
  }
  return elapsed;
}

type Shot = { at: number; zoom: number; x: number; y: number };

/** Camera keyframes in output seconds: zoom and the point of the footage to centre on. */
function shots(t: Timeline): Shot[] {
  const e = t.events;
  const at = (footage: number) => outputTime(t, footage);
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
    { at: at(e.hang.t) + 3, zoom: 3.1, x: e.hang.x, y: e.hang.y - 0.04 },
  ];
}

function camera(list: Shot[], time: number) {
  const times = list.map((s) => s.at);
  const ease = { easing: Easing.inOut(Easing.cubic), extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;
  const zoom = interpolate(time, times, list.map((s) => s.zoom), ease);
  // Keep the frame inside the footage: no empty edges when zoomed in.
  const clamp = (v: number) => Math.min(1 - 0.5 / zoom, Math.max(0.5 / zoom, v));
  const x = clamp(interpolate(time, times, list.map((s) => s.x), ease));
  const y = clamp(interpolate(time, times, list.map((s) => s.y), ease));
  return { zoom, x, y };
}

const Footage: React.FC<{ timeline: Timeline }> = ({ timeline }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const time = frame / fps;
  const { zoom, x, y } = camera(shots(timeline), time);

  // A tiny wobble while the cat hangs on for dear life.
  const hangAt = outputTime(timeline, timeline.events.hang.t);
  const wobble = time > hangAt ? Math.sin((time - hangAt) * 38) * Math.max(0, 1 - (time - hangAt) / 0.6) * 4 : 0;

  let start = 0;
  return (
    <AbsoluteFill style={{ backgroundColor: "#1f1d2a", overflow: "hidden" }}>
      <AbsoluteFill
        style={{
          transformOrigin: "50% 50%",
          transform: `translate(${wobble}px, 0) scale(${zoom}) translate(${(0.5 - x) * 100}%, ${(0.5 - y) * 100}%)`,
        }}
      >
        {clips(timeline).map((c, i) => {
          const from = Math.round(start * fps);
          const length = Math.round(clipLength(c) * fps);
          start += clipLength(c);
          return (
            <Sequence key={i} from={from} durationInFrames={length}>
              <OffthreadVideo
                src={staticFile("raw.mp4")}
                trimBefore={Math.round(c.from * fps)}
                playbackRate={c.rate}
                muted
                style={{ width: "100%", height: "100%", imageRendering: "pixelated" }}
              />
            </Sequence>
          );
        })}
      </AbsoluteFill>
    </AbsoluteFill>
  );
};

const EndCard: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const t = frame / fps;
  const rise = (delay: number) => ({
    opacity: interpolate(t, [delay, delay + 0.5], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }),
    transform: `translateY(${interpolate(t, [delay, delay + 0.6], [24, 0], {
      easing: Easing.out(Easing.cubic),
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
    })}px)`,
  });
  return (
    <AbsoluteFill
      style={{
        background: "linear-gradient(180deg, #3b3552 0%, #1f1d2a 100%)",
        alignItems: "center",
        justifyContent: "center",
        fontFamily: '"SF Pro Rounded", "SF Pro Display", system-ui, -apple-system, sans-serif',
        color: "white",
      }}
    >
      <div style={{ ...rise(0.2), fontSize: 168, fontWeight: 900, letterSpacing: -2 }}>Catification</div>
      <div style={{ ...rise(0.5), fontSize: 54, fontWeight: 600, color: "#d9d1f2", marginTop: 8 }}>
        open source cats for macOS
      </div>
      <div style={{ ...rise(0.9), marginTop: 70 }}>
        <Gif src={staticFile("banner.gif")} width={1440} height={144} fit="contain" style={{ imageRendering: "pixelated" }} />
      </div>
      <div style={{ ...rise(1.3), fontSize: 34, fontWeight: 500, color: "#9e96bf", marginTop: 40 }}>
        github.com/Nikolsi/catification
      </div>
    </AbsoluteFill>
  );
};

export const Trailer: React.FC<{ timeline: Timeline | null }> = ({ timeline }) => {
  const frame = useCurrentFrame();
  const { fps, durationInFrames } = useVideoConfig();
  if (!timeline) return null;
  const cardFrom = durationInFrames - Math.round(END_CARD * fps);
  const fade = interpolate(frame, [cardFrom, cardFrom + CROSSFADE * fps], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  return (
    <AbsoluteFill>
      <Footage timeline={timeline} />
      <Sequence from={cardFrom}>
        <AbsoluteFill style={{ opacity: fade }}>
          <EndCard />
        </AbsoluteFill>
      </Sequence>
    </AbsoluteFill>
  );
};
