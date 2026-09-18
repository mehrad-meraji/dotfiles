#!/usr/bin/env bash
# Claude Code status line script
# Reads JSON from stdin and outputs a formatted status line

input=$(cat)

# Extract fields
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
model=$(echo "$input" | jq -r '.model.display_name // ""')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
remaining_pct=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
vim_mode=$(echo "$input" | jq -r '.vim.mode // empty')
five_h=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
week=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

# Shorten cwd: replace $HOME with ~
home_dir="$HOME"
short_cwd="${cwd/#$home_dir/\~}"

# Build status parts
parts=()

# Directory
[ -n "$short_cwd" ] && parts+=("$short_cwd")

# Model
[ -n "$model" ] && parts+=("$model")

# Context usage
if [ -n "$used_pct" ]; then
  used_int=$(printf '%.0f' "$used_pct")
  parts+=("ctx:${used_int}%")
fi

# Rate limits
rate_str=""
if [ -n "$five_h" ]; then
  rate_str="5h:$(printf '%.0f' "$five_h")%"
fi
if [ -n "$week" ]; then
  [ -n "$rate_str" ] && rate_str="$rate_str "
  rate_str="${rate_str}7d:$(printf '%.0f' "$week")%"
fi
[ -n "$rate_str" ] && parts+=("$rate_str")

# Vim mode
[ -n "$vim_mode" ] && parts+=("[$vim_mode]")

# Join parts with separator
IFS=' | '
printf '%s' "${parts[*]}"
