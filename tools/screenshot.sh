#!/usr/bin/env bash
# Renders the client to a PNG on a machine with no display.
#
# Usage: tools/screenshot.sh [output.png] [seconds-of-simulation-to-run]
#
# Uses Xvfb and the OpenGL renderer because Forward+ needs Vulkan, which a
# headless container generally has no driver for. Resolution is kept modest:
# software rasterising is slow at higher resolutions. --fixed-fps decouples
# simulation time from wall-clock time so the physics cannot be starved by a
# slow frame: without it the capture shows a car still sitting on the grid.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT="${1:-$REPO_ROOT/capture.png}"
SIM_SECONDS="${2:-20}"
# Pass "top" as the third argument for an overhead view of the track surface.
VIEW="${3:-chase}"

EXTRA=()
if [[ "$VIEW" == "top" ]]; then
  EXTRA+=(--topdown)
fi

if ! command -v xvfb-run >/dev/null 2>&1; then
  echo "error: xvfb-run not found; cannot render without a display." >&2
  exit 127
fi

xvfb-run -a -s "-screen 0 640x360x24" \
  "$REPO_ROOT/tools/godot.sh" \
  --rendering-driver opengl3 \
  --fixed-fps 20 \
  --audio-driver Dummy \
  --resolution 640x360 \
  --path "$REPO_ROOT/game" \
  -- --autopilot "${EXTRA[@]}" "--capture=$OUTPUT" "--capture-after=$SIM_SECONDS"

echo "Wrote $OUTPUT"
