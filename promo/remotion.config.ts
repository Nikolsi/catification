import { Config } from "@remotion/cli/config";

// PNG frames keep the pixel art free of compression smudges before the final encode.
Config.setVideoImageFormat("png");
Config.setCodec("h264");
Config.setCrf(16);
Config.setPixelFormat("yuv420p");
