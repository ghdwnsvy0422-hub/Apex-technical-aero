#!/usr/bin/env bash
# Parameter sweep (PRODUCTION_PLAN PART C-4): measures each setup's performance
# envelope, rebuilds the racing line's speed profile from what that car can
# actually do, then drives a flying lap with the AI driver.
#
# This is a balance tool, not a gate - it takes minutes and its output is a
# table to read, so check.sh does not run it.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

exec timeout 1800 "$REPO_ROOT/tools/godot.sh" \
  --headless --fixed-fps 30 --path "$REPO_ROOT/game" -- --sim --sweep "$@"
