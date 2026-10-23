import { Composition, staticFile } from "remotion";
import { Trailer, trailerDuration, type Timeline } from "./Trailer";

const FPS = 30;

export const Root: React.FC = () => (
  <Composition
    id="Trailer"
    component={Trailer}
    fps={FPS}
    width={1920}
    height={1080}
    durationInFrames={FPS * 16}
    defaultProps={{ timeline: null as Timeline | null }}
    calculateMetadata={async ({ props }) => {
      // timeline.json is written by scripts/record-trailer.sh next to the footage.
      const timeline: Timeline = props.timeline ?? (await fetch(staticFile("timeline.json")).then((r) => r.json()));
      return {
        props: { timeline },
        durationInFrames: Math.round(trailerDuration(timeline) * FPS),
      };
    }}
  />
);
