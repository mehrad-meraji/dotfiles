#!/bin/bash
# Moves one docker compose stack from the old home server to the new one.
# Run it from the laptop, which has SSH keys for both boxes; data streams
# old -> laptop -> new over the tailnet, so neither server needs a key for the
# other.
#
#   scripts/migrate-stack.sh <project> <dir> <compose-file> [--no-start]
#   scripts/migrate-stack.sh <project> <dir> <compose-file> --dry-run
#   scripts/migrate-stack.sh <project> <dir> <compose-file> --rollback
#
#   project       compose project name (`docker compose ls` on the old box)
#   dir           directory under ~/Services that holds the stack
#   compose-file  path relative to <dir>
#   --no-start    copy everything but do not start it (runner-deployed stacks:
#                 their images are built by the deploy workflow)
#   --dry-run     only list what would be copied
#   --rollback    stop it on the new box and start it again on the old one
#
# What it does, in order:
#   1. lists the stack's named volumes from its containers' mounts (not from
#      volume labels: sooperarrt's database volume is labelled art-logue)
#   2. pg_dumpall of every Postgres container, saved on the laptop
#   3. `compose down` on the old box, so two tunnel connectors never serve the
#      same hostname and nothing writes after the copy
#   4. copies ~/Services/<dir> (compose files, .env, bind-mounted data)
#   5. streams each named volume into a volume of the same name
#   6. `compose up -d` on the new box, which builds any image with a `build:`
#      section natively for arm64 (the old box is Intel)
#
# The old box keeps its containers' volumes untouched, so --rollback always
# works.
set -euo pipefail

OLD=${OLD_HOST:-old-home-server}
NEW=${NEW_HOST:-home-server}
OLD_DOCKER=/usr/local/bin/docker   # Docker Desktop on the Intel box
NEW_DOCKER=/opt/homebrew/bin/docker
BASE=/Users/mehrad/Services
SAVE="$HOME/home-server-migration"

[ $# -ge 3 ] || { sed -n '6,17p' "$0"; exit 1; }
proj=$1 dir=$2 file=$3 mode=${4:-}
compose_old="$OLD_DOCKER compose -p $proj --project-directory $BASE/$dir -f $BASE/$dir/$file"
compose_new="$NEW_DOCKER compose -p $proj --project-directory $BASE/$dir -f $BASE/$dir/$file"
step() { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }

if [ "$mode" = --rollback ]; then
  step "Rolling back $proj: down on $NEW, up on $OLD"
  ssh "$NEW" "$compose_new down"
  ssh "$OLD" "$compose_old up -d"
  ssh "$OLD" "$compose_old ps"
  exit 0
fi

step "Reading $proj on $OLD"
containers=$(ssh "$OLD" "$OLD_DOCKER ps -aq --filter label=com.docker.compose.project=$proj")
[ -n "$containers" ] || { echo "!! no containers for project '$proj' on $OLD" >&2; exit 1; }
volumes=$(ssh "$OLD" "$OLD_DOCKER inspect --format '{{range .Mounts}}{{if eq .Type \"volume\"}}{{.Name}} {{end}}{{end}}' $(echo $containers)" |
  tr ' ' '\n' | grep -vE '^$|^[0-9a-f]{64}$' | sort -u || true)
pg=$(ssh "$OLD" "$OLD_DOCKER ps --filter label=com.docker.compose.project=$proj --format '{{.Names}} {{.Image}}'" |
  awk 'tolower($2) ~ /postgres|postgis/ {print $1}' || true)
echo "volumes:  ${volumes:-(none)}" | tr '\n' ' '; echo
echo "postgres: ${pg:-(none)}" | tr '\n' ' '; echo
ssh "$OLD" "du -sh $BASE/$dir"

[ "$mode" = --dry-run ] && exit 0

mkdir -p "$SAVE/$proj"
for c in $pg; do
  step "pg_dumpall $c -> $SAVE/$proj/$c.sql.gz (fallback if the copied data dir misbehaves)"
  ssh "$OLD" "$OLD_DOCKER exec $c sh -c 'pg_dumpall -U \"\${POSTGRES_USER:-postgres}\"'" | gzip >"$SAVE/$proj/$c.sql.gz"
  [ -s "$SAVE/$proj/$c.sql.gz" ] || { echo "!! empty dump for $c; stopping before anything changes" >&2; exit 1; }
done

step "Stopping $proj on $OLD"
ssh "$OLD" "$compose_old down"

step "Copying $BASE/$dir"
ssh "$NEW" "mkdir -p $BASE"
ssh "$OLD" "tar -C $BASE -cf - $dir" | ssh "$NEW" "tar -C $BASE -xf -"

for v in $volumes; do
  step "Volume $v"
  ssh "$NEW" "$NEW_DOCKER volume create $v" >/dev/null
  ssh "$OLD" "$OLD_DOCKER run --rm -v $v:/from:ro alpine tar -C /from -cf - ." |
    ssh "$NEW" "$NEW_DOCKER run --rm -i -v $v:/to alpine tar -C /to -xf -"
done

if [ "$mode" = --no-start ]; then
  step "Copied, not started. Enable its runner, then re-run its deploy workflow."
  exit 0
fi

step "Starting $proj on $NEW"
if ! ssh "$NEW" "$compose_new up -d"; then
  echo "!! up failed. If an image is missing, it is built by a deploy workflow:" >&2
  echo "   enable the runner and re-run the deploy, or roll back with --rollback." >&2
  exit 1
fi
ssh "$NEW" "$compose_new ps"
echo
echo "Check the site, then move on. Roll back with: $0 $proj $dir $file --rollback"
