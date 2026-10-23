import { Composition, staticFile } from "remotion";
import { FPS } from "./common";
import { Trailer, trailerDuration, type TrailerTimeline } from "./Trailer";
import { Windows, windowsDuration, type WindowsTimeline } from "./Windows";

// timeline.json is written by scripts/record-trailer.sh next to the footage.
const load = (scene: string) => fetch(staticFile(`${scene}/timeline.json`)).then((r) => r.json());

export const Root: React.FC = () => (
  <>
    <Composition
      id="Trailer"
      component={Trailer}
      fps={FPS}
      width={1920}
      height={1080}
      durationInFrames={FPS * 16}
      defaultProps={{ timeline: null as TrailerTimeline | null }}
      calculateMetadata={async ({ props }) => {
        const timeline: TrailerTimeline = props.timeline ?? (await load("trailer"));
        return { props: { timeline }, durationInFrames: Math.round(trailerDuration(timeline) * FPS) };
      }}
    />
    <Composition
      id="Windows"
      component={Windows}
      fps={FPS}
      width={1920}
      height={1080}
      durationInFrames={FPS * 16}
      defaultProps={{ timeline: null as WindowsTimeline | null }}
      calculateMetadata={async ({ props }) => {
        const timeline: WindowsTimeline = props.timeline ?? (await load("windows"));
        return { props: { timeline }, durationInFrames: Math.round(windowsDuration(timeline) * FPS) };
      }}
    />
  </>
);
