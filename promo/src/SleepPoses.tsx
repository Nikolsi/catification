import { AbsoluteFill, OffthreadVideo, Sequence, staticFile, useVideoConfig } from "remotion";
import { FONT } from "./common";

/**
 * A square clip for social media: the four sleeping poses side by side, from the "poses" demo
 * scene (raw footage in public/poses/raw.mp4). Yawns and lying down,
 * a jump cut past most of the nap, then the ginger cat wakes up with a big stretch.
 */
const FOOTAGE = { width: 880, height: 240 };
const SCALE = 3;
const TILE = { width: 500, height: 333 };
const WINDOW = { width: TILE.width / SCALE, height: TILE.height / SCALE, top: 92 };

const CATS = [
  { x: 122, label: "Loaf" },
  { x: 360, label: "Curled up" },
  { x: 540, label: "Sploot" },
  { x: 758, label: "Belly up" },
];

/** Footage time, in seconds: falling asleep, then waking up. */
const CLIPS = [
  { from: 0.6, to: 6.2 },
  { from: 15.2, to: 21.8 },
];

export const sleepPosesDuration = CLIPS.reduce((sum, c) => sum + c.to - c.from, 0);

const Tile: React.FC<{ x: number }> = ({ x }) => {
  const { fps } = useVideoConfig();
  const left = x - WINDOW.width / 2;
  let start = 0;
  return (
    <div style={{ width: TILE.width, height: TILE.height, overflow: "hidden", position: "relative", borderRadius: 24 }}>
      {CLIPS.map((c, i) => {
        const from = Math.round(start * fps);
        start += c.to - c.from;
        return (
          <Sequence key={i} from={from} durationInFrames={Math.round((c.to - c.from) * fps)} layout="none">
            <OffthreadVideo
              src={staticFile("poses/raw.mp4")}
              trimBefore={Math.round(c.from * fps)}
              muted
              style={{
                position: "absolute",
                width: FOOTAGE.width * SCALE,
                height: FOOTAGE.height * SCALE,
                left: -left * SCALE,
                top: -WINDOW.top * SCALE,
                imageRendering: "pixelated",
                maxWidth: "none",
              }}
            />
          </Sequence>
        );
      })}
    </div>
  );
};

export const SleepPoses: React.FC = () => (
  <AbsoluteFill
    style={{
      background: "linear-gradient(180deg, #3b3552 0%, #1f1d2a 100%)",
      fontFamily: FONT,
      color: "white",
      alignItems: "center",
    }}
  >
    <div style={{ marginTop: 52, fontSize: 64, fontWeight: 800, letterSpacing: -1 }}>How does your cat sleep?</div>
    <div
      style={{
        marginTop: 40,
        display: "grid",
        gridTemplateColumns: `${TILE.width}px ${TILE.width}px`,
        columnGap: 30,
        rowGap: 18,
      }}
    >
      {CATS.map((cat) => (
        <div key={cat.label} style={{ display: "flex", flexDirection: "column", alignItems: "center" }}>
          <Tile x={cat.x} />
          <div style={{ marginTop: 10, fontSize: 38, fontWeight: 700, color: "#e4ddf8" }}>{cat.label}</div>
        </div>
      ))}
    </div>
    <div style={{ position: "absolute", bottom: 46, display: "flex", alignItems: "baseline", gap: 18 }}>
      <span style={{ fontSize: 44, fontWeight: 900 }}>Catification</span>
      <span style={{ fontSize: 30, fontWeight: 600, color: "#c9bff0" }}>open source cats for macOS</span>
    </div>
  </AbsoluteFill>
);
