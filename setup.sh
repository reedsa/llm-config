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

echo "==> Global Claude context (~/.claude/CLAUDE.md)"
link_files "$REPO_DIR/home/claude" "$HOME/.claude" "md"

echo "==> Claude home scripts (~/.claude/*.sh)"
link_files "$REPO_DIR/home/claude" "$HOME/.claude" "sh"

echo "==> Global Gemini context (~/.gemini/GEMINI.md)"
link_files "$REPO_DIR/home/gemini" "$HOME/.gemini" "md"

echo "==> Claude commands (~/.claude/commands/)"
link_files "$REPO_DIR/claude/commands" "$HOME/.claude/commands" "md"

echo "==> Gemini commands (~/.gemini/commands/)"
link_files "$REPO_DIR/gemini/commands" "$HOME/.gemini/commands" "toml"

echo "==> Scripts (~/.local/bin/)"
mkdir -p "$HOME/.local/bin"
for src in "$REPO_DIR/scripts/"*.sh; do
  [ -e "$src" ] || continue
  name="$(basename "$src" .sh)"
  dst="$HOME/.local/bin/$name"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    echo "  ok   $dst"
  elif [ -e "$dst" ] && [ ! -L "$dst" ]; then
    echo "  skip $dst (exists, not a symlink — remove manually to replace)"
  else
    chmod +x "$src"
    ln -sf "$src" "$dst"
    echo "  link $dst -> $src"
  fi
done

echo "Done."
