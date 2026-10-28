---
name: home-server
description: Profile of Mehrad's home server (the M3 Max MacBook Pro named `home-server` on the tailnet) - how to reach it, which Docker stacks run there, ports, tunnels, runners, backups and gotchas. Use whenever a task touches the home server or anything hosted on it - "home server", "home-server", `ssh home-server`, `~/Services`, colima, deploys to the home server, Forgejo, Pocket ID, Plane, Sentinel, hot-glue, command-centre, glean, magpie, polimon, forage, sooperarrt, strength-app, taskscape-backend, taskscape-laravel, fuckdougford, Cloudflare tunnels, self-hosted runners, or nightly backups.
---

# Home server

Hand-written facts, checked 2026-10-28. For today's live state, run:

```bash
~/.claude/skills/home-server/refresh.sh
```

It writes `live-inventory.md` next to this file. That file is local to each laptop and is not in chezmoi. If it is missing or old, run `refresh.sh` first. Read that file when you need the exact container list, ports or schedules. If it and this file disagree, the live file wins.

## Which machine am I on?

Run `scutil --get ComputerName`.

| Name | What it is |
|---|---|
| `home-server` | **The server.** 2023 MacBook Pro, M3 Max, 64 GB, macOS 26. Lid closed, always on. |
| `2024 Silver MBP` | Daily-driver laptop (M4 Max, 128 GB). Not the server. |
| `2022-silver-mbp-tpl`, `2025-silver-mbp-mindoula` | Other laptops (TPL Mac, Mindoula Mac). Not the server. |
| `old-home-server` | Retired server. Runs nothing. Rollback only; to be wiped about 2026-11-05. |
| `2023-space-black-mbp` | Offline tailnet node. Most likely the server's own old node from before it joined as `home-server`. Do not SSH to it. |
| `exit-nyc` | DigitalOcean Tailscale exit node. Repo `tailscale-exit-node`. |

## Access

- SSH: `ssh home-server`. The name comes from Tailscale MagicDNS. There is no entry in `~/.ssh/config`. If SSH fails, check Tailscale first.
- Keys only. No password login. No Tailscale SSH (plain OpenSSH over the tailnet).
- The remote login shell is **fish**. Do not pass bash syntax as an ssh argument. Do this:
  ```bash
  ssh -o ConnectTimeout=10 -o BatchMode=yes home-server bash -s <<'EOF'
  export PATH=/opt/homebrew/bin:$PATH
  docker ps
  EOF
  ```
- Give every `colima ssh` inside such a script `</dev/null`, or it eats the rest of the script.
- Tailnet name: `home-server.tail0c1e4d.ts.net`, IP `100.114.134.125`. LAN `192.168.2.139`.
- Nothing is open to the internet. Public traffic comes only through Cloudflare Tunnels (one `cloudflared` container per stack, token-based).

## Runtime

- Docker runs in **colima** (profile `default`, 10 CPU, 12 GiB, 250 GiB disk). Not OrbStack, not Docker Desktop. Docker CLI is Homebrew's.
- Published ports show up on the host as owned by `ssh`. That is colima's port forwarding. It is normal.
- On the host: `git`, `gh`, `node`, `bun` (`~/.bun/bin`), system `python3`, `restic`, `cloudflared`, `tailscale` (Homebrew, `/opt/homebrew/bin/tailscale`).
- **Not** on the host: `php`, `composer`, `pnpm`, `mise`, `psql`. Run those inside containers. Dump Postgres inside its own container (`docker exec <db> pg_dumpall -U postgres`), because the stacks use Postgres 15, 16, 17 and 18.
- Syncthing runs here as the always-on hub for the Obsidian vault (iCloud Drive on, vault kept downloaded).
- No secrets for laptops live here (`hasSecrets = false` in chezmoi). `rbw` is installed; `.env.age` files decrypt with `~/.ssh/key_age`.

## Stacks

Every stack lives in `~/Services/<dir>/` on the server. Some directory names differ from the compose project name.

| Compose project | Directory and compose file | Host port | Reach it at |
|---|---|---|---|
| command-centre | `command-centre/deploy/docker-compose.yml` | 127.0.0.1:3000 | `command.soopercooler.com` |
| forage | `forage/docker-compose.prod.yml` | 127.0.0.1:8096 | tunnel |
| forgejo | `forgejo/docker-compose.yml` | 127.0.0.1:3200 (web), 127.0.0.1:2222 (git SSH) | tailnet only: `https://home-server.tail0c1e4d.ts.net`, git SSH on port 2222 |
| fuckdougford | `fuckdougford/docker-compose.yml` | 127.0.0.1:3300 (web), 127.0.0.1:5433 (Postgres 17) | tunnel; DB on tailnet port 5433 |
| glean | `glean/docker-compose.yml` | 0.0.0.0:8788 | `glean.meh-labs.ca` (API, keys), `search.meh-labs.ca` (behind Cloudflare Access + Pocket ID) |
| hot-glue | `hot-glue-deploy/docker-compose.yml` | none | `hot-glue.meh-labs.ca` |
| magpie | `magpie/docker-compose.yml` | 0.0.0.0:8787 | `http://home-server:8787` + tunnel |
| plane | `plane/docker-compose.yml` + `docker-compose.override.yml` | none | `plane.soopercooler.com` (being replaced by taskscape-laravel) |
| pocket-id | `pocket-id/docker-compose.yml` | none | `auth.meh-labs.ca` (OIDC, passkeys only) |
| polimon | `polimon/docker-compose.yml` | 127.0.0.1:8790 (api) | tunnel |
| sentinel | `sentinel/docker-compose.prod.yml` | 127.0.0.1:8095 | `sentinel.meh-labs.ca` (error tracker, uptime, backup heartbeats) |
| sooperarrt | `art-logue/docker-compose.prod.yml` | none | tunnel |
| strength-app | `strength-app/docker-compose.prod.yml` | 127.0.0.1:8097 | tailnet only: `https://home-server.tail0c1e4d.ts.net:8443` |
| taskscape-backend | `taskscape-backend/docker-compose.yml` | none | `taskscape-app.meh-labs.ca` |
| taskscape-laravel | `taskscape-laravel/docker-compose.yml` | 0.0.0.0:8100 (app), 0.0.0.0:8180 (Reverb) | `http://home-server:8100` (has a tunnel too) |

The public hostname column is **not complete**. Tunnels are token-based, so their hostname rules live in the Cloudflare dashboard (Zero Trust, Networks, Tunnels), not in files on the server.

Archived stacks: `~/Services/_archive/`.

## Code hosting and CI

- **Forgejo** is the main git host for most active repos (`origin`). GitHub repos are mirrors. Container registry: `home-server.tail0c1e4d.ts.net/mehrad/<image>`.
- Forgejo sign-in is Pocket ID only. Break-glass steps: `home-server-services/docs/decisions.md`.
- Forgejo runner `home-server` (LaunchAgent `com.mehrad.forgejo-runner`), one job at a time. Labels: `home-server`, `self-hosted`, `macOS`, `ARM64`, plus Docker labels `ubuntu-latest`, `ubuntu-24.04`, `ubuntu-24.04-arm`, `ubuntu-22.04`. CI job containers are named `FORGEJO-ACTIONS-TASK-*`.
- On Forgejo, use `https://data.forgejo.org/forgejo/upload-artifact@v4` (and `download-artifact`), not the GitHub `actions/*-artifact@v4`.
- GitHub Actions runners (LaunchAgents `actions.runner.*`) for: `mehrad-meraji/forage`, `hot-glue`, `provincial-receipts` (fuckdougford), `sentinel`, `taskscape-laravel`, and the `SOOPERCOOLER` org.
- Renovate runs from LaunchAgent `local.renovate`.

## Scheduled jobs (LaunchAgents, server time)

| Time | Job |
|---|---|
| 03:00 daily | `com.mehrad.strength-app-backup` |
| 03:10 daily | `com.mehrad.fuckdougford-backup` |
| 03:30 daily | `com.mehrad.home-server-backup` |
| 04:00 daily | `com.mehrad.forgejo-backup` (restic to Cloudflare R2 bucket `tier0-backup`) |
| 04:15 daily | `com.mehrad.pocket-id-backup` (R2) |
| 04:45 daily | `com.mehrad.taskscape-backup` |
| 04:30 Sunday | `com.mehrad.docker-prune` |
| 05:00 Sunday | `com.mehrad.forgejo-runner-cleanup` |
| always on | `com.mehrad.sentinel-agent`, `com.mehrad.forgejo-runner` |

Forgejo and Pocket ID backups send Sentinel heartbeats, so a failure alerts. The other backups were not checked for alerts. Their scripts: `~/Services/strength-app/backup-db.sh`, `~/Services/fuckdougford/backup-db.sh`, `~/.local/bin/home-server-backup`, `~/.local/bin/taskscape-backup`.

## Disks

| Mount | Size | Use |
|---|---|---|
| `/` | 3.6 TB | System, `~/Services`, colima VM |
| `/Volumes/Glacier` | 3.6 TB | Data drive (was named `Mehrad`) |
| `/Volumes/Projects` | 931 GB | Projects drive |
| `/Volumes/TimeMachine` | 1.8 TB | Time Machine. **95% full on 2026-10-28.** |

No stack bind-mounts the external drives. The colima VM shares only `$HOME`.

## Power

`sleep 0`, wake on LAN on, FileVault off with auto-login so it comes back by itself after a power cut.

## Where the deeper docs are

- Repo `~/Projects/home-server-services` (GitHub `mehrad-meraji/home-server-services`): Forgejo and Pocket ID stacks, runner config, backup scripts, restore drills. Start with `docs/decisions.md` and `docs/runbooks/`.
- Vault folder `Projects/home-server/` in the Obsidian vault: design, migration history and checklist. `home-server.md` there is long and partly out of date (it says OrbStack; the real runtime is colima).
- Dotfiles (chezmoi, `mehrad-meraji/dotfiles`): the `server` role provisions this box.
- Each app's own repo has its deploy notes (for example `strength-app/docs/runbooks/deploy-home-server.md`, `fuckdougford/docs/self-hosting.md`).
- `~/Projects/home-lab-infra` is the **old DigitalOcean** Terraform setup. It is not this server.
- `~/code/papercuts.md`: search it for `home-server` before you debug server tooling.

## Rules

- Ask before you restart, stop or redeploy a stack. They serve live public sites.
- Never print or copy `.env` values into chat, files or commits.
- Port 3000 belongs to command-centre. Pick a free port for anything new, and check `live-inventory.md` first.
