#!/usr/bin/env bash
# Pre-commit / CI gate: asserts the engine is configured as assumed and that
# every test passes. Fails loudly with a non-zero exit code.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="$REPO_ROOT/tools/godot.sh"
GAME_DIR="$REPO_ROOT/game"

step() {
  printf '\n\033[1m=== %s ===\033[0m\n' "$1"
}

step "Import and compile scripts"
# Headless import emits harmless editor progress-dialog errors, so its exit
# code says nothing. A GDScript parse error, however, only shows up as text on
# stderr while the process still exits 0 - so the output is scanned instead.
import_output="$(timeout 600 "$GODOT" --headless --path "$GAME_DIR" --import 2>&1 || true)"
if grep -qE 'SCRIPT ERROR|Parse Error|Failed to compile' <<<"$import_output"; then
  grep -E 'SCRIPT ERROR|Parse Error|Failed to compile|^ +at: ' <<<"$import_output" >&2
  echo "error: scripts failed to compile" >&2
  exit 1
fi

step "Environment selfcheck"
timeout 120 "$GODOT" --headless --path "$GAME_DIR" -- --selfcheck

step "Unit tests"
timeout 600 "$GODOT" --headless --path "$GAME_DIR" \
  -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests \
  -ginclude_subdirs \
  -gexit

step "Physics probe"
# --fixed-fps decouples simulation time from wall-clock time so minutes of
# driving run in seconds.
timeout 900 "$GODOT" --headless --fixed-fps 30 --path "$GAME_DIR" -- --sim

printf '\n\033[32mAll checks passed.\033[0m\n'
