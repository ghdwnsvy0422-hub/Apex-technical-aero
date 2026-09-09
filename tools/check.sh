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

step "Import resources"
# Headless import emits harmless editor progress-dialog errors, so its exit
# code is not meaningful. Real problems surface in the steps below.
timeout 600 "$GODOT" --headless --path "$GAME_DIR" --import >/dev/null 2>&1 || true

step "Environment selfcheck"
timeout 120 "$GODOT" --headless --path "$GAME_DIR" -- --selfcheck

step "Unit tests"
timeout 600 "$GODOT" --headless --path "$GAME_DIR" \
  -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests \
  -ginclude_subdirs \
  -gexit

printf '\n\033[32mAll checks passed.\033[0m\n'
