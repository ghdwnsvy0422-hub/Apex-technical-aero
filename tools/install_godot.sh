#!/usr/bin/env bash
# Downloads the pinned Godot build into <repo>/bin/godot (gitignored).
#
# The version is pinned because engine updates silently change physics
# behaviour, which would show up as unexplained lap-time regressions.
set -euo pipefail

GODOT_VERSION="4.4-stable"
GODOT_BUILD="Godot_v${GODOT_VERSION}_linux.x86_64"
DOWNLOAD_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/${GODOT_BUILD}.zip"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="$REPO_ROOT/bin"
TARGET="$BIN_DIR/godot"

if [[ -x "$TARGET" ]] && "$TARGET" --version 2>/dev/null | grep -q "^4\.4\."; then
  echo "Godot ${GODOT_VERSION} already installed at $TARGET"
  exit 0
fi

mkdir -p "$BIN_DIR"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Downloading Godot ${GODOT_VERSION}..."
curl -sSL --fail --max-time 600 -o "$TMP_DIR/godot.zip" "$DOWNLOAD_URL"
unzip -q -o "$TMP_DIR/godot.zip" -d "$TMP_DIR"
mv "$TMP_DIR/$GODOT_BUILD" "$TARGET"
chmod +x "$TARGET"

echo "Installed: $("$TARGET" --version)"
