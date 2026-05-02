#!/bin/bash
# Multi-LLM pre-PR review.
# Run from the repo worktree after implementation is complete, before opening a PR.
# Usage: pre-pr-review.sh <issue_id> <title>
#
# Runs code-quality and security review passes through every available LLM,
# combines the feedback, has Claude address any blockers, then opens the PR.
#
# Each LLM's review commands are only invoked if both the binary and the command
# file exist. Claude's /review and /security-review are built-in; Gemini's are
# installed via setup.sh from llm-config.

set -euo pipefail

ISSUE_ID="${1:?issue_id required}"
TITLE="${2:?title required}"

CLAUDE_BIN="${CLAUDE_BIN:-$(command -v claude 2>/dev/null || echo claude)}"
GEMINI_BIN="${GEMINI_BIN:-gemini}"
CLAUDE_MODEL="${CLAUDE_MODEL:-claude-sonnet-4-6}"

REVIEWS_DIR=$(mktemp -d)
trap 'rm -rf "$REVIEWS_DIR"' EXIT

echo "==> Pre-PR review: $ISSUE_ID — $TITLE"

# Confirm there are commits to review before spending tokens.
AHEAD=$(git rev-list --count "origin/main..HEAD" 2>/dev/null || echo 0)
if [ "$AHEAD" -eq 0 ]; then
    echo "No commits ahead of origin/main — nothing to review." >&2
    exit 1
fi

# Run a single LLM review pass and capture its text output.
# Usage: run_review <output_file> <binary> <format_flag> <response_jq> <prompt>
run_claude_pass() {
    local out="$1" prompt="$2"
    command -v "$CLAUDE_BIN" &>/dev/null || return 0
    echo "    running..."
    "$CLAUDE_BIN" \
        --model "$CLAUDE_MODEL" \
        --output-format stream-json --verbose \
        -p "$prompt" 2>/dev/null \
    | jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="text") | .text' \
    > "$out" || true
}

run_gemini_pass() {
    local out="$1" command_name="$2"
    command -v "$GEMINI_BIN" &>/dev/null || return 0
    [ -f "$HOME/.gemini/commands/${command_name}.toml" ] || return 0
    echo "    running..."
    "$GEMINI_BIN" --output-format json -p "/$command_name" 2>/dev/null \
    | jq -r '.response // empty' \
    > "$out" || true
}

# --- Code quality reviews ---
echo "--- Code quality review ---"
echo "  Claude /review"
run_claude_pass "$REVIEWS_DIR/claude-quality.txt" "/review"

echo "  Gemini /review"
run_gemini_pass "$REVIEWS_DIR/gemini-quality.txt" "review"

# --- Security reviews ---
echo "--- Security review ---"
echo "  Claude /security-review"
run_claude_pass "$REVIEWS_DIR/claude-security.txt" "/security-review"

echo "  Gemini /security-review"
run_gemini_pass "$REVIEWS_DIR/gemini-security.txt" "security-review"

# --- Codex (placeholder: add once command format is confirmed) ---
# echo "  Codex /review"

# Combine non-empty review files with labelled sections.
FEEDBACK_FILE="$REVIEWS_DIR/combined.txt"
for key in claude-quality claude-security gemini-quality gemini-security; do
    f="$REVIEWS_DIR/${key}.txt"
    [ -s "$f" ] || continue
    case "$key" in
        claude-quality)  label="Claude — code quality" ;;
        claude-security) label="Claude — security" ;;
        gemini-quality)  label="Gemini — code quality" ;;
        gemini-security) label="Gemini — security" ;;
    esac
    { echo "## $label"; cat "$f"; echo; } >> "$FEEDBACK_FILE"
    echo "  captured: $label"
done

if [ ! -s "$FEEDBACK_FILE" ]; then
    echo "==> No review feedback collected — opening PR without review."
else
    echo "==> Addressing blockers..."
    run_claude_pass "$REVIEWS_DIR/fixes.txt" "/address-pre-pr-feedback $FEEDBACK_FILE"
    [ -s "$REVIEWS_DIR/fixes.txt" ] && cat "$REVIEWS_DIR/fixes.txt"
fi

echo "==> Opening PR..."
gh pr create \
    --title "$ISSUE_ID: $TITLE" \
    --base main \
    --fill
