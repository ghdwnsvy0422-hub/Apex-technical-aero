#!/usr/bin/env bash
# Renders the client to a PNG on a machine with no display.
#
# Usage: tools/screenshot.sh [output.png] [frames-to-wait]
#
# Uses Xvfb and the OpenGL renderer because Forward+ needs Vulkan, which a
# headless container generally has no driver for.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT="${1:-$REPO_ROOT/capture.png}"
FRAMES="${2:-300}"

if ! command -v xvfb-run >/dev/null 2>&1; then
  echo "error: xvfb-run not found; cannot render without a display." >&2
  exit 127
fi

xvfb-run -a -s "-screen 0 1600x900x24" \
  "$REPO_ROOT/tools/godot.sh" \
  --rendering-driver opengl3 \
  --audio-driver Dummy \
  --resolution 1600x900 \
  --path "$REPO_ROOT/game" \
  -- --autopilot "--capture=$OUTPUT" "--capture-frames=$FRAMES"

echo "Wrote $OUTPUT"
