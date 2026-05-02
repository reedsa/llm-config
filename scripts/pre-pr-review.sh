#!/bin/bash
# Multi-LLM pre-PR review.
# Run from the repo worktree after implementation is complete, before opening a PR.
# Usage: pre-pr-review.sh <issue_id> <title>
#
# Runs code-quality and security review passes through every available LLM,
# combines the feedback, has Claude address any blockers, then opens the PR.

set -euo pipefail

ISSUE_ID="${1:?issue_id required}"
TITLE="${2:?title required}"
# Pass --open-pr to skip the confirmation and open the PR automatically (for CI/runners).
OPEN_PR=false
for arg in "$@"; do [ "$arg" = "--open-pr" ] && OPEN_PR=true; done

CLAUDE_BIN="${CLAUDE_BIN:-$(command -v claude 2>/dev/null || echo claude)}"
GEMINI_BIN="${GEMINI_BIN:-gemini}"
CLAUDE_MODEL="${CLAUDE_MODEL:-claude-sonnet-4-6}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROMPTS_DIR="$SCRIPT_DIR/../shared/prompts"

# Reviews go inside the project directory so Claude can read them.
# Each run gets a unique directory; old runs accumulate for inspection.
REVIEWS_DIR=".pre-pr-review/${ISSUE_ID}-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$REVIEWS_DIR"

echo "==> Pre-PR review: $ISSUE_ID — $TITLE"

# Confirm there are commits to review before spending tokens.
AHEAD=$(git rev-list --count "origin/main..HEAD" 2>/dev/null || echo 0)
if [ "$AHEAD" -eq 0 ]; then
    echo "No commits ahead of origin/main — nothing to review." >&2
    exit 1
fi

# Compute diff once — passed inline to Gemini to avoid !{...} confirmation prompts.
DIFF=$(git diff origin/main..HEAD)

run_claude_pass() {
    local out="$1" prompt="$2"
    command -v "$CLAUDE_BIN" &>/dev/null || return 0
    echo "    running..."
    "$CLAUDE_BIN" \
        --model "$CLAUDE_MODEL" \
        --output-format stream-json --verbose \
        --dangerously-skip-permissions \
        -p "$prompt" 2>/dev/null \
    | jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="text") | .text' \
    > "$out" || true
}

run_gemini_pass() {
    local out="$1" prompt_file="$2"
    command -v "$GEMINI_BIN" &>/dev/null || return 0
    [ -f "$prompt_file" ] || return 0
    echo "    running..."
    local full_prompt
    full_prompt="$(cat "$prompt_file")

$(printf '```diff\n%s\n```' "$DIFF")"
    "$GEMINI_BIN" --output-format json -p "$full_prompt" 2>/dev/null \
    | jq -r '.response // empty' \
    > "$out" || true
}

# --- Code quality reviews ---
echo "--- Code quality review ---"
echo "  Claude /pre-pr-quality-check"
run_claude_pass "$REVIEWS_DIR/claude-quality.txt" "/pre-pr-quality-check"

echo "  Gemini"
run_gemini_pass "$REVIEWS_DIR/gemini-quality.txt" "$PROMPTS_DIR/pre-pr-quality-check.txt"

# --- Security reviews ---
echo "--- Security review ---"
echo "  Claude /pre-pr-security-check"
run_claude_pass "$REVIEWS_DIR/claude-security.txt" "/pre-pr-security-check"

echo "  Gemini"
run_gemini_pass "$REVIEWS_DIR/gemini-security.txt" "$PROMPTS_DIR/pre-pr-security-check.txt"

# --- Codex (placeholder: add once command format is confirmed) ---
# echo "  Codex /review"

# Combine non-empty review files with labelled sections.
# Print each review's content as it's captured so the user can see findings.
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
    echo ""
    echo "  --- $label ---"
    cat "$f"
done

if [ ! -s "$FEEDBACK_FILE" ]; then
    echo "==> No review feedback collected."
else
    echo ""
    echo "==> Addressing blockers..."
    run_claude_pass "$REVIEWS_DIR/fixes.txt" "/address-pre-pr-feedback $FEEDBACK_FILE"
    [ -s "$REVIEWS_DIR/fixes.txt" ] && cat "$REVIEWS_DIR/fixes.txt"
fi

PR_CMD="gh pr create --title \"$ISSUE_ID: $TITLE\" --base main --fill"

if [ "$OPEN_PR" = true ]; then
    echo "==> Opening PR..."
    eval "$PR_CMD"
else
    echo ""
    echo "==> Review complete. When satisfied, open the PR with:"
    echo "    $PR_CMD"
fi
