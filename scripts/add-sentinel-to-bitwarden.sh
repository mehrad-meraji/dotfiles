#!/bin/sh
# One-time: create the Bitwarden item that holds the Sentinel agent credentials,
# reading them from the /etc/sentinel.conf that already exists on this machine.
#
# The key is read from disk and passed to `bw` over stdin - it is never echoed,
# never placed in a command line (so it stays out of `ps` and shell history),
# and never written to this repo.
#
# Uses the `bw` CLI rather than `rbw`: rbw cannot create items with custom
# fields. Both talk to the same vault, and this runs once.
#
# Usage:  export BW_SESSION=$(bw unlock --raw)
#         scripts/add-sentinel-to-bitwarden.sh

set -eu

ITEM_NAME="Sentinel - meh-labs"
CONF="${SENTINEL_CONF:-/etc/sentinel.conf}"

command -v bw >/dev/null 2>&1 || { echo "bw CLI not found" >&2; exit 1; }
[ -r "$CONF" ] || { echo "cannot read $CONF" >&2; exit 1; }

status=$(bw status 2>/dev/null | python3 -c 'import json,sys;print(json.load(sys.stdin)["status"])' 2>/dev/null || echo unknown)
case "$status" in
  unlocked) ;;
  locked)          echo "Vault is locked. Run: export BW_SESSION=\$(bw unlock --raw)" >&2; exit 1 ;;
  unauthenticated) echo "Not logged in. Run: bw login   then: export BW_SESSION=\$(bw unlock --raw)" >&2; exit 1 ;;
  *)               echo "Could not determine bw status (got: $status)" >&2; exit 1 ;;
esac

# Refuse to create a duplicate.
if bw list items --search "$ITEM_NAME" 2>/dev/null \
   | python3 -c 'import json,sys;sys.exit(0 if json.load(sys.stdin) else 1)' 2>/dev/null; then
    echo "An item matching \"$ITEM_NAME\" already exists." >&2
    echo "Edit it in Bitwarden rather than creating a second copy." >&2
    exit 1
fi

# Build the item JSON. Values come from the file; nothing is interpolated by the
# shell, so a key containing '=' or shell metacharacters is handled correctly.
payload=$(CONF="$CONF" ITEM_NAME="$ITEM_NAME" python3 - <<'PY'
import json, os

conf, fields = os.environ["CONF"], {}
with open(conf) as fh:
    for line in fh:
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        fields[k.strip()] = v.strip()

missing = [k for k in ("SENTINEL_URL", "SENTINEL_KEY") if not fields.get(k)]
if missing:
    raise SystemExit(f"{conf} is missing: {', '.join(missing)}")

print(json.dumps({
    "type": 2,                       # secure note
    "name": os.environ["ITEM_NAME"],
    "notes": ("Credentials for `sentinel agent` (per-minute crontab).\n"
              "Consumed as /etc/sentinel.conf, installed by chezmoi:\n"
              "home/.chezmoiscripts/run_onchange_install-sentinel-conf.sh.tmpl\n"
              "Rotate here, then run `chezmoi apply`."),
    "secureNote": {"type": 0},
    "fields": [
        {"name": "SENTINEL_URL", "value": fields["SENTINEL_URL"], "type": 0},   # text
        {"name": "SENTINEL_KEY", "value": fields["SENTINEL_KEY"], "type": 1},   # hidden
    ],
}))
PY
)

printf '%s' "$payload" | bw encode | bw create item >/dev/null
echo "Created Bitwarden secure note: $ITEM_NAME"
echo "  SENTINEL_URL  (text)"
echo "  SENTINEL_KEY  (hidden)"
echo
echo "Verify with:  bw get item \"$ITEM_NAME\" | python3 -m json.tool | grep -A2 SENTINEL_URL"
echo "Then:         chezmoi apply"
