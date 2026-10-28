#!/usr/bin/env bash
# Snapshot the home server's live state into live-inventory.md (next to this script).
# Names, ports and schedules only. It never reads .env files or secrets.
set -euo pipefail

out="$(cd "$(dirname "$0")" && pwd)/live-inventory.md"
tmp="$(mktemp)"

{
  echo "# home-server live inventory"
  echo
  echo "Generated $(date '+%Y-%m-%d %H:%M %Z') from $(scutil --get ComputerName 2>/dev/null || hostname) by refresh.sh. Do not edit by hand."
  echo
  echo '```'
  ssh -o ConnectTimeout=10 -o BatchMode=yes home-server bash -s <<'EOF'
export PATH=/opt/homebrew/bin:$PATH
echo "== machine"; scutil --get ComputerName; sysctl -n machdep.cpu.brand_string; echo "$(( $(sysctl -n hw.memsize) / 1073741824 )) GB RAM"; echo "macOS $(sw_vers -productVersion)"; uptime
echo; echo "== disks"; df -h / /Volumes/Glacier /Volumes/Projects /Volumes/TimeMachine 2>/dev/null
echo; echo "== colima"; colima list </dev/null 2>/dev/null
echo; echo "== compose stacks"; docker compose ls
echo; echo "== containers (name | image | ports)"; docker ps --format '{{.Names}} | {{.Image}} | {{.Ports}}' | grep -v '^FORGEJO-ACTIONS-TASK' | sort
echo; echo "== running CI job containers"; docker ps --format '{{.Names}}' | grep -c '^FORGEJO-ACTIONS-TASK' || true
echo; echo "== tailscale serve"; tailscale serve status 2>&1
echo; echo "== tailnet peers"; tailscale status 2>&1 | awk '{print $1, $2, $4, $5, $6, $7}'
echo; echo "== brew services"; brew services list
echo; echo "== LaunchAgents (schedule)"
for p in ~/Library/LaunchAgents/*.plist; do
  s=$(/usr/libexec/PlistBuddy -c "Print :StartCalendarInterval" "$p" 2>/dev/null | tr -s ' \n' ' ' || true)
  printf '%s  %s\n' "$(basename "$p" .plist)" "${s:-(no calendar: keep-alive or interval)}"
done
EOF
  echo '```'
} >"$tmp"

mv "$tmp" "$out"
echo "Wrote $out"
