#!/bin/bash
# Moves the Syncthing notes hub from the old home server to the new one,
# keeping its device identity, so TPL Mac, Mindoula Mac and any other peer
# reconnect to the new box on their own: no re-pairing, nothing to change on
# them. Run it from the laptop.
#
#   scripts/migrate-syncthing.sh [--dry-run]
#
# Before running: the new box is signed in to iCloud and its Obsidian vault is
# downloaded. The script checks this itself, through Syncthing's own scan.
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
# The new box's count comes from Syncthing's own scan, through a temporary
# receive-only folder with no peers (so it cannot change a file). SSH sessions
# and plain launchd jobs are not allowed into iCloud Drive without Full Disk
# Access; the Syncthing service is, and it is the one that matters.
new_n=$(on "$NEW" '
  export PATH=/opt/homebrew/bin:$PATH
  KEY=$(syncthing cli config gui apikey get)
  syncthing cli config folders add --id vault-count --path "'"$VAULT"'" --type receiveonly >/dev/null
  for i in $(seq 1 60); do
    st=$(curl -s -H "X-API-Key: $KEY" "http://127.0.0.1:8384/rest/db/status?folder=vault-count")
    echo "$st" | grep -q "\"state\": *\"idle\"" && break
    sleep 5
  done
  syncthing cli config folders vault-count delete >/dev/null
  echo "$st" | sed -n "s/.*\"localFiles\": *\([0-9]*\).*/\1/p" | head -1')
echo "old box: $old_n files   new box (Syncthing scan): ${new_n:-?} files"
if [ -z "$new_n" ] || [ "$new_n" -lt $((old_n * 95 / 100)) ]; then
  echo "!! The new box's vault is not fully downloaded yet (or Syncthing cannot" >&2
  echo "   read it). Wait for iCloud, then run this again." >&2
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
