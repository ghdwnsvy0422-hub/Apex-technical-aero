#!/usr/bin/env bash
# Driving-feel sweep (Phase 1.8): measures steering response, yaw overshoot,
# axle balance, throttle-on rotation and braking stability across the setup
# parameters that govern feel, and prints a table.
#
# Like sweep.sh this is a tuning tool, not a gate. check.sh runs the narrower
# feel probe, which only asks whether the car is still sane to drive.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

exec timeout 3600 "$REPO_ROOT/tools/godot.sh" \
  --headless --fixed-fps 30 --path "$REPO_ROOT/game" -- --sim --feelsweep "$@"
