#!/bin/bash
# Moves the Syncthing notes hub from the old home server to the new one,
# keeping its device identity, so TPL Mac, Mindoula Mac and any other peer
# reconnect to the new box on their own: no re-pairing, nothing to change on
# them. Run it from the laptop.
#
#   scripts/migrate-syncthing.sh [--dry-run]
#
# Before running: the new box is signed in to iCloud and its Obsidian vault is
# fully downloaded (the headless check on `chezmoi apply` says so).
#
# One identity must never be online twice, or peers see two machines claiming
# the same ID and sync becomes unreliable. So the old box's Syncthing.app is
# stopped AND moved out of /Applications, so it cannot start again at login if
# the old box reboots during the 30-day rollback window. To undo:
#   ssh old-home-server 'mv ~/Syncthing.app.disabled /Applications/Syncthing.app'
set -euo pipefail

OLD=${OLD_HOST:-old-home-server}
NEW=${NEW_HOST:-home-server}
CONF='$HOME/Library/Application Support/Syncthing'     # expanded remotely
VAULT='$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/Notes'
FILES="config.xml cert.pem key.pem https-cert.pem https-key.pem"
step() { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
on() { local host=$1; shift; ssh "$host" 'bash -s' <<<"$*"; }

step "Checking both vault copies"
old_n=$(on "$OLD" "find \"$VAULT\" -type f | wc -l" | tr -d ' ')
new_n=$(on "$NEW" "[ -d \"$VAULT\" ] && find \"$VAULT\" -type f | wc -l || echo 0" | tr -d ' ')
evicted=$(on "$NEW" "find \"$VAULT\" -type f -flags dataless 2>/dev/null | wc -l" | tr -d ' ')
echo "old box: $old_n files   new box: $new_n files, $evicted not downloaded"
if [ "$new_n" -lt $((old_n * 95 / 100)) ] || [ "$evicted" -ne 0 ]; then
  echo "!! The new box's vault is not fully downloaded yet. Wait for iCloud" >&2
  echo "   (Finder: right-click Notes > Keep Downloaded), then run this again." >&2
  exit 1
fi
on "$OLD" "cd \"$CONF\" && ls $FILES" >/dev/null || { echo "!! old box is missing some of: $FILES" >&2; exit 1; }
[ "${1:-}" = --dry-run ] && { echo "dry run: would move $FILES"; exit 0; }

step "Stopping Syncthing on the new box (its fresh identity is discarded)"
on "$NEW" "/opt/homebrew/bin/brew services stop syncthing >/dev/null; sleep 2"

step "Stopping Syncthing.app on the old box and parking it"
on "$OLD" "pkill -x Syncthing || true; pkill -f 'Syncthing.app/Contents/Resources/syncthing/syncthing' || true; sleep 3
  if [ -d /Applications/Syncthing.app ]; then mv /Applications/Syncthing.app ~/Syncthing.app.disabled; fi
  pgrep -f 'Syncthing.app/Contents/Resources/syncthing' && { echo '!! still running'; exit 1; } || true"

step "Copying the identity and config: $FILES"
on "$NEW" "mkdir -p \"$CONF\" && cd \"$CONF\" && rm -rf index-v2 && mkdir -p ~/home-server-migration && tar -czf ~/home-server-migration/syncthing-fresh-identity.tgz $FILES 2>/dev/null || true"
on "$OLD" "cd \"$CONF\" && tar -cf - $FILES" | ssh "$NEW" "bash -c 'cd \"$CONF\" && tar -xf - && chmod 600 key.pem https-key.pem'"

step "Starting Syncthing on the new box"
on "$NEW" "/opt/homebrew/bin/brew services start syncthing >/dev/null; sleep 15
  /opt/homebrew/bin/syncthing cli show system | grep -E '\"myID\"' | cut -c1-40
  /opt/homebrew/bin/syncthing cli show connections | grep -E '\"connected\"|\"address\"' | head -8"

echo
echo "Device ID above must start with 2HL2SXN (the old box's). Peers may take a"
echo "few minutes to find the new address. To watch it:"
echo "  ssh -L 8384:127.0.0.1:8384 home-server   then open http://localhost:8384"
