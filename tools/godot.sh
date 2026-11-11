#!/usr/bin/env bash
# Locates the Godot binary and execs it with the given arguments.
#
# Search order: $GODOT -> <repo>/bin/godot -> godot/godot4 on PATH.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

find_godot() {
  if [[ -n "${GODOT:-}" ]]; then
    echo "$GODOT"
    return 0
  fi
  if [[ -x "$REPO_ROOT/bin/godot" ]]; then
    echo "$REPO_ROOT/bin/godot"
    return 0
  fi
  local candidate
  for candidate in godot godot4; do
    if command -v "$candidate" >/dev/null 2>&1; then
      command -v "$candidate"
      return 0
    fi
  done
  return 1
}

if ! GODOT_BIN="$(find_godot)"; then
  echo "error: Godot not found. Run tools/install_godot.sh or set \$GODOT." >&2
  exit 127
fi

exec "$GODOT_BIN" "$@"
