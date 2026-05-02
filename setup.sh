#!/bin/bash
# Idempotent symlink installer for llm-config.
# Run after cloning or pulling to wire commands into each CLI's discovery path.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

link_files() {
  local src_dir="$1"
  local dst_dir="$2"
  local ext="$3"

  if [ ! -d "$src_dir" ]; then
    return
  fi

  mkdir -p "$dst_dir"

  for src in "$src_dir"/*."$ext"; do
    [ -e "$src" ] || continue
    local name
    name="$(basename "$src")"
    local dst="$dst_dir/$name"

    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
      echo "  ok   $dst"
    elif [ -e "$dst" ] && [ ! -L "$dst" ]; then
      echo "  skip $dst (exists, not a symlink — remove manually to replace)"
    else
      ln -sf "$src" "$dst"
      echo "  link $dst -> $src"
    fi
  done
}

echo "==> Claude commands (~/.claude/commands/)"
link_files "$REPO_DIR/claude/commands" "$HOME/.claude/commands" "md"

echo "==> Gemini commands (~/.gemini/commands/)"
link_files "$REPO_DIR/gemini/commands" "$HOME/.gemini/commands" "toml"

echo "Done."
