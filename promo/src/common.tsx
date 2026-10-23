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
export type Moment = { t: number; x: number; y: number };

/** What scripts/record-trailer.sh writes next to the footage. */
export type Timeline<Events extends string> = {
  /** Footage time when the story starts. */
  offset: number;
  events: Record<Events, Moment>;
};

/** A stretch of footage, played at some speed. */
export type Clip = { from: number; to: number; rate: number };

/** Camera keyframe in output seconds: zoom, and the point of the footage to centre on. */
export type Shot = { at: number; zoom: number; x: number; y: number };

export const FPS = 30;
export const END_CARD = 4;
export const INTRO = 1.7;
export const CROSSFADE = 0.6;
export const FONT = '"SF Pro Rounded", "SF Pro Display", system-ui, -apple-system, sans-serif';

const clipLength = (c: Clip) => (c.to - c.from) / c.rate;

export function duration(clips: Clip[]): number {
  return clips.reduce((sum, c) => sum + clipLength(c), 0) + END_CARD - CROSSFADE;
}

/** Output time of a footage moment (a moment cut out by a jump cut maps to the start of the next clip). */
export function outputTime(clips: Clip[], footage: number): number {
  let elapsed = 0;
  for (const c of clips) {
    if (footage <= c.to) return elapsed + Math.max(0, footage - c.from) / c.rate;
    elapsed += clipLength(c);
  }
  return elapsed;
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

/** The recording, cut into clips and filmed by a moving camera. `shake` adds a short wobble at that output time. */
export const Footage: React.FC<{ src: string; clips: Clip[]; shots: Shot[]; shake?: number }> = ({ src, clips, shots, shake }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const time = frame / fps;
  const { zoom, x, y } = camera(shots, time);
  const wobble =
    shake !== undefined && time > shake ? Math.sin((time - shake) * 38) * Math.max(0, 1 - (time - shake) / 0.6) * 4 : 0;

  let start = 0;
  return (
    <AbsoluteFill style={{ backgroundColor: "#1f1d2a", overflow: "hidden" }}>
      <AbsoluteFill
        style={{
          transformOrigin: "50% 50%",
          transform: `translate(${wobble}px, 0) scale(${zoom}) translate(${(0.5 - x) * 100}%, ${(0.5 - y) * 100}%)`,
        }}
      >
        {clips.map((c, i) => {
          const from = Math.round(start * fps);
          const length = Math.round(clipLength(c) * fps);
          start += clipLength(c);
          return (
            <Sequence key={i} from={from} durationInFrames={length}>
              <OffthreadVideo
                src={staticFile(src)}
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

const Intro: React.FC<{ text: string }> = ({ text }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const t = frame / fps;
  const opacity = interpolate(t, [0, 0.25, 1.35, 1.7], [0, 1, 1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const scale = interpolate(t, [0, 1.7], [0.96, 1.04]);
  return (
    <AbsoluteFill style={{ backgroundColor: `rgba(16, 14, 24, ${0.55 * opacity})`, alignItems: "center", justifyContent: "center" }}>
      <div
        style={{
          opacity,
          transform: `scale(${scale})`,
          fontFamily: FONT,
          fontSize: 116,
          fontWeight: 800,
          color: "white",
          letterSpacing: -1.5,
          textShadow: "0 6px 30px rgba(0,0,0,0.6)",
        }}
      >
        {text}
      </div>
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
        fontFamily: FONT,
        color: "white",
      }}
    >
      <div style={{ ...rise(0.2), fontSize: 200, fontWeight: 900, letterSpacing: -3 }}>Catification</div>
      <div style={{ ...rise(0.5), fontSize: 88, fontWeight: 700, color: "#e4ddf8", marginTop: 4 }}>
        open source cats for macOS
      </div>
      <div style={{ ...rise(0.9), marginTop: 56 }}>
        <Gif src={staticFile("banner.gif")} width={1600} height={160} fit="contain" style={{ imageRendering: "pixelated" }} />
      </div>
      <div style={{ ...rise(1.3), fontSize: 76, fontWeight: 700, color: "#c9bff0", marginTop: 44 }}>
        github.com/Nikolsi/catification
      </div>
    </AbsoluteFill>
  );
};

/** Intro line over the footage, then the end card. */
export const Cut: React.FC<{ intro: string; children: React.ReactNode }> = ({ intro, children }) => {
  const frame = useCurrentFrame();
  const { fps, durationInFrames } = useVideoConfig();
  const cardFrom = durationInFrames - Math.round(END_CARD * fps);
  const fade = interpolate(frame, [cardFrom, cardFrom + CROSSFADE * fps], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  return (
    <AbsoluteFill>
      {children}
      <Sequence durationInFrames={Math.round(INTRO * fps)}>
        <Intro text={intro} />
      </Sequence>
      <Sequence from={cardFrom}>
        <AbsoluteFill style={{ opacity: fade }}>
          <EndCard />
        </AbsoluteFill>
      </Sequence>
    </AbsoluteFill>
  );
};
