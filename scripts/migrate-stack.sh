#!/bin/bash
# Moves one docker compose stack from the old home server to the new one.
# Run it from the laptop, which has SSH keys for both boxes; data streams
# old -> laptop -> new over the tailnet, so neither server needs a key for the
# other.
#
#   scripts/migrate-stack.sh <project> [--no-start]
#   scripts/migrate-stack.sh <project> --dry-run
#   scripts/migrate-stack.sh <project> --rollback
#
#   project       compose project name (`docker compose ls` on the old box)
#   --no-start    copy everything but do not start it (runner-deployed stacks:
#                 their images are built by the deploy workflow)
#   --dry-run     only list what would be copied
#   --rollback    stop it on the new box and start it again on the old one
#
# The compose command is rebuilt from the labels docker put on the stack's
# containers when it was started: working dir, compose files and env files.
# Stacks differ there (sooperarrt reads .env.production, magpie and hot-glue
# read app.env too, command-centre runs from deploy/), and guessing any of it
# wrong makes compose fail on missing variables or resolve paths wrongly.
#
# What it does, in order:
#   1. reads those labels, and lists the stack's named volumes from its
#      containers' mounts (not from volume labels: sooperarrt's database volume
#      is labelled art-logue)
#   2. pg_dumpall of every Postgres container, saved on the laptop
#   3. `compose down` on the old box, so two tunnel connectors never serve the
#      same hostname and nothing writes after the copy
#   4. copies ~/Services/<dir> (compose files, .env, bind-mounted data)
#   5. streams each named volume into a volume of the same name, and creates
#      any shared external network the stack joins
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

[ $# -ge 1 ] || { sed -n '6,15p' "$0"; exit 1; }
proj=$1 mode=${2:-}
step() { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }

# The old containers are gone after the move, so the compose arguments are saved
# here for --rollback.
ARGS_FILE="$SAVE/$proj/compose-args"

if [ "$mode" = --rollback ]; then
  [ -s "$ARGS_FILE" ] || { echo "!! no $ARGS_FILE; was $proj migrated from this laptop?" >&2; exit 1; }
  args=$(cat "$ARGS_FILE")
  services=$(cat "$SAVE/$proj/services" 2>/dev/null || true)
  step "Rolling back $proj: down on $NEW, up on $OLD"
  ssh "$NEW" "$NEW_DOCKER compose $args --profile '*' down"
  ssh "$OLD" "$OLD_DOCKER compose $args up -d $services"
  ssh "$OLD" "$OLD_DOCKER compose $args ps"
  exit 0
fi

step "Reading $proj on $OLD"
containers=$(ssh "$OLD" "$OLD_DOCKER ps -aq --filter label=com.docker.compose.project=$proj")
[ -n "$containers" ] || { echo "!! no containers for project '$proj' on $OLD" >&2; exit 1; }
first=$(echo "$containers" | head -1)
label() { ssh "$OLD" "$OLD_DOCKER inspect $first --format '{{index .Config.Labels \"com.docker.compose.project.$1\"}}'"; }
wd=$(label working_dir) files=$(label config_files) envfiles=$(label environment_file)
case $wd in "$BASE"/*) ;; *) echo "!! working dir $wd is not under $BASE" >&2; exit 1 ;; esac
dir=${wd#"$BASE"/}; dir=${dir%%/*}      # top-level dir to copy, e.g. command-centre
args="-p $proj --project-directory $wd"
for f in ${files//,/ }; do args="$args -f $f"; done
for e in ${envfiles//,/ }; do args="$args --env-file $e"; done
# The services that existed on the old box, named explicitly on `up`: compose
# then starts them even when they sit behind a profile (magpie's tunnel does),
# which a bare `up` would skip.
services=$(ssh "$OLD" "$OLD_DOCKER inspect --format '{{index .Config.Labels \"com.docker.compose.service\"}}' $(echo $containers)" | sort -u | tr '\n' ' ')
compose_old="$OLD_DOCKER compose $args"
compose_new="$NEW_DOCKER compose $args"
echo "compose:  docker compose $args"
echo "services: $services"
# Fail here, before anything is stopped, if compose cannot read the config.
ssh "$OLD" "$compose_old config -q" || { echo "!! compose cannot read $proj's config with those arguments" >&2; exit 1; }
volumes=$(ssh "$OLD" "$OLD_DOCKER inspect --format '{{range .Mounts}}{{if eq .Type \"volume\"}}{{.Name}} {{end}}{{end}}' $(echo $containers)" |
  tr ' ' '\n' | grep -vE '^$|^[0-9a-f]{64}$' | sort -u || true)
pg=$(ssh "$OLD" "$OLD_DOCKER ps --filter label=com.docker.compose.project=$proj --format '{{.Names}} {{.Image}}'" |
  awk 'tolower($2) ~ /postgres|postgis/ {print $1}' || true)
# Networks shared between stacks (e.g. tunnel-edge, which carries Plane through
# command-centre's tunnel) are declared external, so compose will not create
# them. Anything not prefixed with the project name is one of those.
networks=$(ssh "$OLD" "$OLD_DOCKER inspect --format '{{range \$k, \$v := .NetworkSettings.Networks}}{{\$k}} {{end}}' $(echo $containers)" |
  tr ' ' '\n' | grep -vE "^$|^${proj}_|^(bridge|host|none)$" | sort -u || true)
echo "volumes:  ${volumes:-(none)}" | tr '\n' ' '; echo
echo "shared networks: ${networks:-(none)}" | tr '\n' ' '; echo
echo "postgres: ${pg:-(none)}" | tr '\n' ' '; echo
ssh "$OLD" "du -sh $BASE/$dir"

[ "$mode" = --dry-run ] && exit 0

mkdir -p "$SAVE/$proj"
echo "$args" >"$ARGS_FILE"
echo "$services" >"$SAVE/$proj/services"
for c in $pg; do
  step "pg_dumpall $c -> $SAVE/$proj/$c.sql.gz (fallback if the copied data dir misbehaves)"
  # unset PGHOST etc.: Plane's db container sets PGHOST=plane-db, which forces
  # a TCP connection that wants a password instead of the local socket.
  ssh "$OLD" "$OLD_DOCKER exec $c sh -c 'unset PGHOST PGPORT PGDATABASE; pg_dumpall -U \"\${POSTGRES_USER:-postgres}\"'" | gzip >"$SAVE/$proj/$c.sql.gz"
  [ -s "$SAVE/$proj/$c.sql.gz" ] || { echo "!! empty dump for $c; stopping before anything changes" >&2; exit 1; }
done

step "Stopping $proj on $OLD"
# --profile "*": a plain down skips services behind a profile, which left
# magpie's and polimon's tunnels running on the old box after their moves.
ssh "$OLD" "$compose_old --profile '*' down"

step "Copying $BASE/$dir"
ssh "$NEW" "mkdir -p $BASE"
ssh "$OLD" "tar -C $BASE -cf - $dir" | ssh "$NEW" "tar -C $BASE -xf -"

for v in $volumes; do
  step "Volume $v"
  # Carry the volume's labels over, or compose warns that it "was not created
  # by Docker Compose" on every up.
  labels=$(ssh "$OLD" "$OLD_DOCKER volume inspect $v --format '{{range \$k, \$val := .Labels}}--label {{\$k}}={{\$val}} {{end}}'")
  ssh "$NEW" "$NEW_DOCKER volume inspect $v" >/dev/null 2>&1 || ssh "$NEW" "$NEW_DOCKER volume create $labels $v" >/dev/null
  ssh "$OLD" "$OLD_DOCKER run --rm -v $v:/from:ro alpine tar -C /from -cf - ." |
    ssh "$NEW" "$NEW_DOCKER run --rm -i -v $v:/to alpine tar -C /to -xf -"
done

for n in $networks; do
  step "Shared network $n"
  ssh "$NEW" "$NEW_DOCKER network inspect $n" >/dev/null 2>&1 || ssh "$NEW" "$NEW_DOCKER network create $n"
done

if [ "$mode" = --no-start ]; then
  step "Copied, not started. Enable its runner, then re-run its deploy workflow."
  exit 0
fi

step "Starting $proj on $NEW"
if ! ssh "$NEW" "$compose_new up -d $services"; then
  echo "!! up failed. If an image is missing, it is built by a deploy workflow:" >&2
  echo "   enable the runner and re-run the deploy, or roll back with --rollback." >&2
  exit 1
fi
ssh "$NEW" "$compose_new ps"
echo
echo "Check the site, then move on. Roll back with: $0 $proj --rollback"
