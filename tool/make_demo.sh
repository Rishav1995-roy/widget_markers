#!/usr/bin/env bash
# Regenerates doc/demo.gif and doc/screenshot_*.png deterministically, without a
# device. The map in the images is a stand-in drawn in Flutter.
#   usage: tool/make_demo.sh            (needs flutter on PATH, or set FLUTTER="fvm spawn 3.47.7")
set -euo pipefail
cd "$(dirname "$0")/.."
FLUTTER="${FLUTTER:-flutter}"
GENERATE_DEMO=1 $FLUTTER test test/demo/demo_test.dart --tags demo --run-skipped --timeout 10m
FRAMES=build/demo_frames
FF="${FFMPEG:-ffmpeg}"
$FF -y -loglevel error -framerate 12 -i "$FRAMES/f_%03d.png" \
  -vf "scale=380:-1:flags=lanczos,palettegen=max_colors=80:stats_mode=diff" "$FRAMES/palette.png"
$FF -y -loglevel error -framerate 12 -i "$FRAMES/f_%03d.png" -i "$FRAMES/palette.png" \
  -lavfi "scale=380:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle" \
  doc/demo.gif
cp "$FRAMES/shot_light.png" doc/screenshot_light.png
cp "$FRAMES/shot_dark.png" doc/screenshot_dark.png
cp "$FRAMES/shot_clusters.png" doc/screenshot_clusters.png
ls -l doc
