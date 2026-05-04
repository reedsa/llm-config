#!/usr/bin/env bash
# Claude Code status line script
# Line 1: cwd + git branch info
# Line 2: model name + context window progress bar

input=$(cat)

# --- Extract fields from JSON ---
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
model=$(echo "$input" | jq -r '.model.display_name // ""')
model_id=$(echo "$input" | jq -r '.model.id // ""')
ctx_used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
ctx_remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
ctx_window=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
ctx_input=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // 0')

# --- Detect 1M context variant ---
# Model IDs with a [1m] suffix (e.g. claude-opus-4-7[1m]) signal the 1M window.
# Fall back to checking display_name for "1M" as a secondary signal.
is_1m=0
if [[ "$model_id" == *"[1m]"* ]]; then
    is_1m=1
elif [[ "$model" == *"1M"* ]]; then
    is_1m=1
fi

if [ "$is_1m" -eq 1 ]; then
    effective_total=1000000
    total_label="1M"
else
    effective_total=200000
    total_label=""  # will be set below from ctx_window
fi

# --- ANSI color helpers ---
# Use $'...' ANSI-C quoting so the variables contain real ESC characters.
# This way they pass through printf's %s arguments correctly (printf only
# interprets backslash escapes in the format string, not in %s args).
RESET=$'\033[0m'
BOLD=$'\033[1m'
DIM=$'\033[2m'

# Foreground colors
FG_WHITE=$'\033[97m'
FG_CYAN=$'\033[96m'
FG_YELLOW=$'\033[93m'
FG_GREEN=$'\033[92m'
FG_RED=$'\033[91m'
FG_BLUE=$'\033[94m'
FG_MAGENTA=$'\033[95m'
FG_GRAY=$'\033[37m'

# --- Line 1: cwd + git branch ---

# Shorten home directory to ~
if [ -n "$cwd" ]; then
    home="$HOME"
    display_cwd="${cwd/#$home/~}"
else
    display_cwd="$(pwd)"
    display_cwd="${display_cwd/#$HOME/~}"
fi

# Git info (run in the cwd, skip optional locks)
git_info=""
if git_branch=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null); then
    # Dirty check
    if GIT_OPTIONAL_LOCKS=0 git -C "$cwd" diff --quiet HEAD 2>/dev/null; then
        git_state="clean"
        state_color="$FG_GREEN"
        state_icon=""
    else
        git_state="dirty"
        state_color="$FG_YELLOW"
        state_icon="*"
    fi
    git_info=" ${DIM}on${RESET} ${FG_MAGENTA}${BOLD}${git_branch}${state_icon}${RESET}${state_color} (${git_state})${RESET}"
fi

printf "${FG_CYAN}${BOLD}%s${RESET}%s\n" "$display_cwd" "$git_info"

# --- Shared helper: build a progress bar string ---
# Usage: build_bar filled_count empty_count bar_color
# Sets global BAR_STR to the rendered bar (caller prints it).
BAR_WIDTH=16

build_bar() {
    local f=$1 e=$2 bcolor=$3
    local s=""
    for ((i=0; i<f; i++)); do s+="█"; done
    local t=""
    for ((i=0; i<e; i++)); do t+="░"; done
    printf "${FG_GRAY}[${bcolor}%s${FG_GRAY}%s]${RESET}" "$s" "$t"
}

# --- Shared helper: format remaining seconds as Xd Yh Zm or Yh Zm or Zm ---
fmt_remaining() {
    local secs=$1
    if [ "$secs" -le 0 ]; then
        echo "now"
        return
    fi
    local days=$(( secs / 86400 ))
    local hrs=$(( (secs % 86400) / 3600 ))
    local mins=$(( (secs % 3600) / 60 ))
    if [ "$days" -gt 0 ]; then
        printf "%dd %dh left" "$days" "$hrs"
    elif [ "$hrs" -gt 0 ]; then
        printf "%dh %dm left" "$hrs" "$mins"
    else
        printf "%dm left" "$mins"
    fi
}

# --- Line 2: context window ---
# Layout: emoji  label  [progressbar]  percentage%  (token_display)

if [ -n "$ctx_used" ] && [ "$ctx_used" != "null" ]; then
    used_pct=$(printf "%.0f" "$ctx_used")
else
    # Fall back to computing from token counts if percentages not available.
    # Use effective_total for accuracy when on a 1M model.
    if [ "$effective_total" -gt 0 ] && [ "$ctx_input" -gt 0 ]; then
        used_pct=$(( ctx_input * 100 / effective_total ))
    elif [ "$ctx_window" -gt 0 ] && [ "$ctx_input" -gt 0 ]; then
        used_pct=$(( ctx_input * 100 / ctx_window ))
    else
        used_pct=0
    fi
fi

# Clamp to 0–100
[ "$used_pct" -lt 0 ] && used_pct=0
[ "$used_pct" -gt 100 ] && used_pct=100

# Tokens for display — use effective_total for 1M models, ctx_window otherwise
if [ "$is_1m" -eq 1 ]; then
    used_k=$(( effective_total * used_pct / 100 / 1000 ))
    total_label="1M"
    token_display="${used_k}k/${total_label}"
else
    display_total="${ctx_window}"
    used_k=$(( display_total * used_pct / 100 / 1000 ))
    total_k=$(( display_total / 1000 ))
    token_display="${used_k}k/${total_k}k"
fi

# Number of filled blocks
ctx_filled=$(( BAR_WIDTH * used_pct / 100 ))
ctx_empty=$(( BAR_WIDTH - ctx_filled ))

# Color based on usage
if [ "$used_pct" -lt 60 ]; then
    bar_color="$FG_GREEN"
elif [ "$used_pct" -lt 85 ]; then
    bar_color="$FG_YELLOW"
else
    bar_color="$FG_RED"
fi

# Emoji reflecting context fill state
if [ "$used_pct" -lt 15 ]; then
    ctx_emoji="😌"
elif [ "$used_pct" -lt 35 ]; then
    ctx_emoji="🙂"
elif [ "$used_pct" -lt 55 ]; then
    ctx_emoji="😐"
elif [ "$used_pct" -lt 75 ]; then
    ctx_emoji="😅"
elif [ "$used_pct" -lt 90 ]; then
    ctx_emoji="😰"
else
    ctx_emoji="🔥"
fi

ctx_bar=$(build_bar "$ctx_filled" "$ctx_empty" "$bar_color")

# Build context segment (no trailing newline — will be joined with burn blocks)
ctx_segment=$(printf "%s  ${DIM}%s${RESET}  %s  ${bar_color}%d%%${RESET}  ${DIM}(%s)${RESET}" \
    "$ctx_emoji" \
    "$model" \
    "$ctx_bar" \
    "$used_pct" \
    "$token_display")

# --- Rate-limit burn windows (5h and 7d) — joined onto the same line ---
# Only rendered when the rate_limits data is present.

now=$(date +%s)

# Shared helper: smiley emoji from a used-percentage (same scale as context block)
burn_emoji() {
    local pct=$1
    if [ "$pct" -lt 15 ]; then
        echo "😌"
    elif [ "$pct" -lt 35 ]; then
        echo "🙂"
    elif [ "$pct" -lt 55 ]; then
        echo "😐"
    elif [ "$pct" -lt 75 ]; then
        echo "😅"
    elif [ "$pct" -lt 90 ]; then
        echo "😰"
    else
        echo "🔥"
    fi
}

# --- 5-hour window ---
five_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')

five_segment=""
if [ -n "$five_pct" ] && [ -n "$five_reset" ]; then
    five_pct_int=$(printf "%.0f" "$five_pct")
    [ "$five_pct_int" -lt 0 ] && five_pct_int=0
    [ "$five_pct_int" -gt 100 ] && five_pct_int=100

    five_secs=$(( five_reset - now ))
    five_remaining=$(fmt_remaining "$five_secs")

    five_filled=$(( BAR_WIDTH * five_pct_int / 100 ))
    five_empty=$(( BAR_WIDTH - five_filled ))

    if [ "$five_pct_int" -lt 60 ]; then
        five_color="$FG_GREEN"
    elif [ "$five_pct_int" -lt 85 ]; then
        five_color="$FG_YELLOW"
    else
        five_color="$FG_RED"
    fi

    five_emoji=$(burn_emoji "$five_pct_int")
    five_bar=$(build_bar "$five_filled" "$five_empty" "$five_color")
    five_label="5h (↻ ${five_remaining})"

    five_segment=$(printf "%s  ${DIM}%s${RESET}  %s  ${five_color}%d%%${RESET}" \
        "$five_emoji" \
        "$five_label" \
        "$five_bar" \
        "$five_pct_int")
fi

# --- 7-day window ---
seven_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
seven_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

seven_segment=""
if [ -n "$seven_pct" ] && [ -n "$seven_reset" ]; then
    seven_pct_int=$(printf "%.0f" "$seven_pct")
    [ "$seven_pct_int" -lt 0 ] && seven_pct_int=0
    [ "$seven_pct_int" -gt 100 ] && seven_pct_int=100

    seven_secs=$(( seven_reset - now ))
    seven_remaining=$(fmt_remaining "$seven_secs")

    seven_filled=$(( BAR_WIDTH * seven_pct_int / 100 ))
    seven_empty=$(( BAR_WIDTH - seven_filled ))

    if [ "$seven_pct_int" -lt 60 ]; then
        seven_color="$FG_GREEN"
    elif [ "$seven_pct_int" -lt 85 ]; then
        seven_color="$FG_YELLOW"
    else
        seven_color="$FG_RED"
    fi

    seven_emoji=$(burn_emoji "$seven_pct_int")
    seven_bar=$(build_bar "$seven_filled" "$seven_empty" "$seven_color")
    seven_label="7d (↻ ${seven_remaining})"

    seven_segment=$(printf "%s  ${DIM}%s${RESET}  %s  ${seven_color}%d%%${RESET}" \
        "$seven_emoji" \
        "$seven_label" \
        "$seven_bar" \
        "$seven_pct_int")
fi

# --- Combine all segments onto one line ---
DIVIDER="${DIM} │ ${RESET}"
line2="$ctx_segment"
[ -n "$five_segment" ]  && line2="${line2}${DIVIDER}${five_segment}"
[ -n "$seven_segment" ] && line2="${line2}${DIVIDER}${seven_segment}"
printf "%s\n" "$line2"
