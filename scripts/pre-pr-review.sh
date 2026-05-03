#!/bin/bash
# Multi-LLM pre-PR review.
# Run from the repo worktree after implementation is complete, before opening a PR.
# Usage: pre-pr-review.sh <issue_id> <title> [--open-pr] [--severity blockers|all]
#        pre-pr-review.sh --fix-from <reviews_dir> [--severity blockers|all]
#
# Runs code-quality and security review passes through every available LLM,
# combines the feedback, has Claude address findings, then prints the
# gh pr create command (or opens the PR automatically with --open-pr).
#
# --fix-from <dir> skips the review passes and runs only the fix step
# against <dir>/combined.txt. Use this to iterate on fixes from a prior run.
# --severity controls what gets fixed: "blockers" (default) fixes BLOCKERS
# only; "all" also addresses SUGGESTIONS and OBSERVATIONS.

set -euo pipefail

OPEN_PR=false
FIX_FROM=""
SEVERITY="blockers"
POSITIONAL=()
while [ $# -gt 0 ]; do
    case "$1" in
        --open-pr)  OPEN_PR=true; shift ;;
        --fix-from) FIX_FROM="${2:?--fix-from requires a directory}"; shift 2 ;;
        --severity) SEVERITY="${2:?--severity requires a value}"; shift 2 ;;
        *)          POSITIONAL+=("$1"); shift ;;
    esac
done

case "$SEVERITY" in
    blockers|all) ;;
    *) echo "--severity must be 'blockers' or 'all', got: $SEVERITY" >&2; exit 1 ;;
esac

if [ -n "$FIX_FROM" ]; then
    ISSUE_ID=""
    TITLE=""
else
    ISSUE_ID="${POSITIONAL[0]:?issue_id required}"
    TITLE="${POSITIONAL[1]:?title required}"
fi

CLAUDE_BIN="${CLAUDE_BIN:-$(command -v claude 2>/dev/null || echo claude)}"
GEMINI_BIN="${GEMINI_BIN:-gemini}"
CLAUDE_MODEL="${CLAUDE_MODEL:-claude-sonnet-4-6}"

# Resolve the real script location even when invoked via a symlink.
SCRIPT_REAL="${BASH_SOURCE[0]}"
if [ -L "$SCRIPT_REAL" ]; then
    SCRIPT_REAL="$(readlink "$SCRIPT_REAL")"
fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_REAL")" && pwd)"
PROMPTS_DIR="$SCRIPT_DIR/../shared/prompts"

if [ -n "$FIX_FROM" ]; then
    REVIEWS_DIR="$FIX_FROM"
    [ -d "$REVIEWS_DIR" ] || { echo "Reviews dir not found: $REVIEWS_DIR" >&2; exit 1; }
    echo "==> Addressing blockers from $REVIEWS_DIR"
else
    # Reviews go inside the project directory so Claude can read them.
    # Each run gets a unique directory; old runs accumulate for inspection.
    REVIEWS_DIR=".pre-pr-review/${ISSUE_ID}-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$REVIEWS_DIR"
    echo "==> Pre-PR review: $ISSUE_ID — $TITLE"
fi

AHEAD=$(git rev-list --count "origin/main..HEAD" 2>/dev/null || echo 0)
if [ "$AHEAD" -eq 0 ]; then
    echo "No commits ahead of origin/main — nothing to review." >&2
    exit 1
fi

# Compute diff once and pass it inline to both LLMs.
# This avoids !{...} confirmation prompts (Gemini) and slash-command
# discovery issues (Claude headless), keeping both symmetric.
DIFF=$(git diff origin/main..HEAD)

build_prompt() {
    local prompt_file="$1"
    printf '%s\n\n```diff\n%s\n```' "$(cat "$prompt_file")" "$DIFF"
}

run_claude_pass() {
    local out="$1" prompt_file="$2"
    command -v "$CLAUDE_BIN" &>/dev/null || { echo "    skipped (claude not found)"; return 0; }
    [ -f "$prompt_file" ] || { echo "    skipped (prompt file not found: $prompt_file)"; return 0; }
    echo "    running..."
    "$CLAUDE_BIN" \
        --model "$CLAUDE_MODEL" \
        --output-format stream-json --verbose \
        --dangerously-skip-permissions \
        -p "$(build_prompt "$prompt_file")" 2>/dev/null \
    | jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="text") | .text' \
    > "$out" || true
}

address_findings() {
    local feedback_file="$REVIEWS_DIR/combined.txt"
    if [ ! -s "$feedback_file" ]; then
        echo "==> No review feedback in $feedback_file."
        return 0
    fi
    echo ""
    local instructions
    if [ "$SEVERITY" = "all" ]; then
        echo "==> Addressing all findings..."
        instructions='Address findings from the following multi-LLM pre-PR review.\nFix BLOCKERS first, then also address SUGGESTIONS and OBSERVATIONS where the change is clearly an improvement. Skip any item you disagree with and briefly note why.'
    else
        echo "==> Addressing blockers..."
        instructions='Address blocker-level issues from the following multi-LLM pre-PR review.\nIgnore SUGGESTIONS and OBSERVATIONS — fix BLOCKERS only.'
    fi
    local fix_prompt="$REVIEWS_DIR/fix-prompt.txt"
    {
        printf "$instructions\n\n"
        cat "$feedback_file"
    } > "$fix_prompt"
    run_claude_pass "$REVIEWS_DIR/fixes.txt" "$fix_prompt"
    [ -s "$REVIEWS_DIR/fixes.txt" ] && cat "$REVIEWS_DIR/fixes.txt"
}

run_gemini_pass() {
    local out="$1" prompt_file="$2"
    command -v "$GEMINI_BIN" &>/dev/null || { echo "    skipped (gemini not found)"; return 0; }
    [ -f "$prompt_file" ] || { echo "    skipped (prompt file not found: $prompt_file)"; return 0; }
    echo "    running..."
    # Force OAuth auth by stripping API-key env vars; an expired
    # GEMINI_API_KEY/GOOGLE_API_KEY otherwise takes precedence over
    # ~/.gemini/oauth_creds.json and fails the request.
    env -u GEMINI_API_KEY -u GOOGLE_API_KEY -u GOOGLE_GENAI_API_KEY \
        "$GEMINI_BIN" --output-format json \
        -p "$(build_prompt "$prompt_file")" 2>"$out.stderr" \
    | jq -r '.response // empty' \
    > "$out" || true
    if [ ! -s "$out" ] && [ -s "$out.stderr" ]; then
        echo "    gemini produced no response — see $out.stderr"
    fi
}

if [ -n "$FIX_FROM" ]; then
    address_findings
    exit 0
fi

# --- Code quality reviews ---
echo "--- Code quality review ---"
echo "  Claude"
run_claude_pass "$REVIEWS_DIR/claude-quality.txt" "$PROMPTS_DIR/pre-pr-quality-check.txt"

echo "  Gemini"
run_gemini_pass "$REVIEWS_DIR/gemini-quality.txt" "$PROMPTS_DIR/pre-pr-quality-check.txt"

# --- Security reviews ---
echo "--- Security review ---"
echo "  Claude"
run_claude_pass "$REVIEWS_DIR/claude-security.txt" "$PROMPTS_DIR/pre-pr-security-check.txt"

echo "  Gemini"
run_gemini_pass "$REVIEWS_DIR/gemini-security.txt" "$PROMPTS_DIR/pre-pr-security-check.txt"

# --- Codex (placeholder) ---

# Combine and display non-empty review files.
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

address_findings

PR_CMD="gh pr create --title \"$ISSUE_ID: $TITLE\" --base main --fill"

if [ "$OPEN_PR" = true ]; then
    echo "==> Opening PR..."
    eval "$PR_CMD"
else
    echo ""
    echo "==> Review complete. When satisfied, open the PR with:"
    echo "    $PR_CMD"
fi
