#!/bin/sh
# Generate theme.toml immediately (alacritty needs it before the agent fires)
"$HOME/.local/bin/sync-terminal-theme"

# Load (or reload) the LaunchAgent so WatchPaths kicks in
plist="$HOME/Library/LaunchAgents/com.mehrad.sync-terminal-theme.plist"
launchctl unload "$plist" 2>/dev/null || true
launchctl load "$plist"
