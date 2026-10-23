#!/bin/bash
# Records the trailer footage and renders the trailer with Remotion into docs/media/trailer.mp4.
#
#   scripts/record-trailer.sh            # record + render
#   scripts/record-trailer.sh --render   # re-render from the last recording (e.g. after editing promo/src)
#
# The story is scripted in DemoDirector (scene "trailer"). The scene waits for a go signal, so the
# recording is already running when the cat sets off; at that moment the clock in its menu bar
# ticks from 9:40 to 9:41, and ffmpeg finds that frame to line the events up with the footage.
# Needs ffmpeg, Node.js and a MacBook with a notch (the story crosses it).
set -euo pipefail

cd "$(dirname "$0")/.."
PUBLIC=promo/public
mkdir -p "$PUBLIC"

if [ "${1:-}" != "--render" ]; then
    command -v ffmpeg >/dev/null || { echo "ffmpeg not found: brew install ffmpeg" >&2; exit 1; }
    swift build -c release
    BIN="$(swift build -c release --show-bin-path)/Catification"
    TMP="$(mktemp -d)"
    GO=/tmp/catification-trailer-go
    rm -f "$GO"

    WAS_RUNNING=0
    if pgrep -x Catification >/dev/null; then WAS_RUNNING=1; pkill -x Catification; sleep 0.5; fi

    "$BIN" --demo trailer --wait-go > "$TMP/events.txt" 2>/dev/null &
    PID=$!
    for _ in $(seq 100); do [ -s "$TMP/events.txt" ] && break; sleep 0.1; done
    read -r RECT _ < "$TMP/events.txt"
    sleep 2  # let both cats land and settle

    echo "Recording..."
    screencapture -x -v -V 19 -R "$RECT" "$TMP/raw.mov" &
    REC=$!
    sleep 1.5
    touch "$GO"
    wait "$REC"
    kill "$PID" 2>/dev/null || true
    rm -f "$GO"

    # When did the clock tick over? That's "go" in footage time.
    IFS=, read -r _ _ WIDTH _ <<< "$RECT"
    OFFSET="$(ffmpeg -i "$TMP/raw.mov" -vf "crop=180:64:$((WIDTH * 2 - 190)):0,select='gt(scene\,0.003)',showinfo" -f null - 2>&1 |
        grep -o 'pts_time:[0-9.]*' | head -1 | cut -d: -f2)"
    [ -n "$OFFSET" ] || { echo "Couldn't find the sync mark in the footage" >&2; exit 1; }
    echo "Story starts ${OFFSET}s into the footage"

    # Events become footage times: { "offset": 1.62, "events": { "hang": { "t": 9.2, "x": 0.64, "y": 0.39 } } }
    # The hero is the first cat. Its last jump is the big one (the first is the hop down to a shelf).
    awk -v offset="$OFFSET" '
        $1 == "EVENT" && $4 == "Ginger" { line[$2] = sprintf("{ \"t\": %s, \"x\": %s, \"y\": %s }", $3 + offset, $5, $6) }
        END {
            printf "{\n  \"offset\": %s,\n  \"events\": {\n", offset
            n = split("portal calculate jump hang", names, " ")
            for (i = 1; i <= n; i++) printf "    \"%s\": %s%s\n", names[i], line[names[i]], (i < n ? "," : "")
            print "  }\n}"
        }
    ' "$TMP/events.txt" > "$PUBLIC/timeline.json"
    cat "$PUBLIC/timeline.json"

    ffmpeg -loglevel error -y -i "$TMP/raw.mov" -r 30 -c:v libx264 -preset slow -crf 12 -pix_fmt yuv420p "$PUBLIC/raw.mp4"
    rm -rf "$TMP"
    if [ "$WAS_RUNNING" = 1 ] && [ -d build/Catification.app ]; then open build/Catification.app; fi
fi

cp docs/media/banner.gif "$PUBLIC/banner.gif"
cd promo
[ -d node_modules ] || npm ci
npx remotion render Trailer ../docs/media/trailer.mp4
echo "Trailer written to docs/media/trailer.mp4"
