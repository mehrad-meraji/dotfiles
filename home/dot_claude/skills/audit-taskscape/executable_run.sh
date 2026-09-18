#!/bin/bash
# Nightly taskscape audit runner. Invoked by launchd.
set -u

LOG_DIR="$HOME/.claude/skills/audit-taskscape/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/$(date +%Y-%m-%d).log"

# Ensure claude CLI is on PATH (launchd has a minimal env)
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

{
  echo "=== Taskscape audit started at $(date) ==="
  claude --print --dangerously-skip-permissions "/audit-taskscape" 2>&1
  echo "=== Exit code: $? ==="
  echo "=== Finished at $(date) ==="
} >> "$LOG_FILE" 2>&1
