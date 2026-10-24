#!/bin/bash
# Records the README demo GIFs into docs/media/demo-<scene>.gif.
#
#   scripts/record-demos.sh                 # every scene
#   scripts/record-demos.sh jump trash      # just these
#
# Each scene is scripted in Sources/Catification/App/DemoDirector.swift. The app runs with
# throwaway settings and paints a backdrop over the stage, so only the cats get recorded.
# Needs ffmpeg (brew install ffmpeg) and the Screen Recording permission for your terminal.
# Don't touch the mouse while a scene records: the "pet" scene moves the cursor itself.
set -euo pipefail

cd "$(dirname "$0")/.."
command -v ffmpeg >/dev/null || { echo "ffmpeg not found: brew install ffmpeg" >&2; exit 1; }

swift build -c release
BIN="$(swift build -c release --show-bin-path)/Catification"

if [ $# -gt 0 ]; then SCENES=("$@"); else SCENES=(notch jump miss trash butterflies pet play naps poses); fi
OUT=docs/media
TMP="$(mktemp -d)"
mkdir -p "$OUT"

WAS_RUNNING=0
if pgrep -x Catification >/dev/null; then WAS_RUNNING=1; pkill -x Catification; sleep 0.5; fi

for scene in "${SCENES[@]}"; do
    echo "Recording ${scene}..."
    "$BIN" --demo "$scene" > "$TMP/$scene.txt" 2>/dev/null &
    PID=$!
    for _ in $(seq 100); do [ -s "$TMP/$scene.txt" ] && break; sleep 0.1; done
    read -r RECT DURATION < "$TMP/$scene.txt"
    IFS=, read -r _ _ WIDTH _ <<< "$RECT"

    CURSOR=()
    if [ "$scene" = pet ]; then CURSOR=(-C); fi
    screencapture -x -v ${CURSOR[@]+"${CURSOR[@]}"} -V "${DURATION%.*}" -R "$RECT" "$TMP/$scene.mov"
    kill "$PID" 2>/dev/null || true
    wait "$PID" 2>/dev/null || true

    # Keep the full Retina resolution: stages are small so cats look big.
    GIF_WIDTH=$((WIDTH * 2))
    ffmpeg -loglevel error -y -i "$TMP/$scene.mov" -vf \
        "fps=20,scale=${GIF_WIDTH}:-1:flags=neighbor,split[a][b];[a]palettegen=max_colors=128:stats_mode=diff[p];[b][p]paletteuse=dither=none:diff_mode=rectangle" \
        -loop 0 "$OUT/demo-$scene.gif"
    echo "  $OUT/demo-$scene.gif ($(du -h "$OUT/demo-$scene.gif" | cut -f1))"
done

rm -rf "$TMP"
if [ "$WAS_RUNNING" = 1 ] && [ -d build/Catification.app ]; then open build/Catification.app; fi
