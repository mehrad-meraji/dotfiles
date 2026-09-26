# dotfiles

macOS dotfiles managed with [chezmoi](https://chezmoi.io).

Shell is [fish](https://fishshell.com); zsh is kept as a minimal fallback.
Terminal: Alacritty with Zellij, both themed Catppuccin and switched
automatically with the macOS light/dark setting.

## Install

On a blank Mac, one line:

```sh
/bin/sh -c "$(curl -fsSL https://raw.githubusercontent.com/mehrad-meraji/dotfiles/main/bootstrap.sh)"
```

`bootstrap.sh` installs the Xcode CLT, Homebrew, then only the four packages
chezmoi needs at init time (`chezmoi rbw age pinentry-mac`), logs into
Bitwarden, writes `~/.ssh/key_age`, checks it against the expected public key,
and finally runs `chezmoi init --apply`.

**Order is not optional.** `hasSecrets` and `machineRole` are evaluated once,
during `chezmoi init`, and written into `~/.config/chezmoi/chezmoi.toml`. If
`rbw` is missing at that moment, `hasSecrets` is baked to `false` and a later
`chezmoi apply` will not fix it — you have to re-run `chezmoi init`.

## Machine role

`chezmoi init` asks for a role. It decides which Homebrew set is installed and
which scripts run.

| Role | Gets | Skips |
|---|---|---|
| `laptop` | shared + laptop packages, GUI apps, Bitwarden secrets | server scripts |
| `server` | shared + `cloudflared`, `colima`, `docker`, `pinentry-mac`, `rbw`, `restic`, `tailscale`; `hasSecrets` forced off, `hasVault` on | rustup, karabiner, terminal-theme agent |

`--promptString` is keyed by the **prompt text**, not the variable name:

```sh
chezmoi init --apply --promptString "Machine role (laptop/server)=server"
```

`--promptString machineRole=server` is silently ignored and you get `laptop`.
`--promptDefaults` also gives `laptop`. Change the prompt text in
`.chezmoi.toml.tmpl` and this flag string has to change with it.

## Not installable from here

chezmoi cannot install these. Do them by hand after the first apply:

| Thing | How |
|---|---|
| Xcode | App Store |
| Adobe Creative Cloud (Photoshop, Illustrator, Premiere, Substance) | Adobe CC desktop app |
| Microsoft 365 (Word, Excel, PowerPoint, Outlook, OneNote, Teams) | Microsoft installer or App Store |
| Toggl Track, Dia | Vendor download, no cask |
| Alacritty | Homebrew disabled the cask on 2026-09-01 (fails Gatekeeper). Download from [GitHub releases](https://github.com/alacritty/alacritty/releases) |
| Licence keys — Sketch | Bitwarden |
| Apple ID, iCloud, Messages | System Settings |

## Secrets

Nothing secret is stored in this repo. Files that need a secret are rendered at
apply time from [Bitwarden](https://github.com/doy/rbw) (`rbw`), and a few SSH
keys are [age](https://age-encryption.org)-encrypted.

There are two gates, because a server needs one secret without wanting the rest:

| Gate | True when | Controls |
|---|---|---|
| `hasSecrets` | role is `laptop` **and** `rbw` is present | personal material — SSH keys, `~/.git-credentials`, Claude history, Plane API key |
| `hasVault` | `rbw` is present, any role | server-side secrets only — today just `/etc/sentinel.conf` |

So a server with `rbw` renders `/etc/sentinel.conf` and still gets none of the
laptop's keys. If `rbw` is absent both are `false`, every secret-backed file is
skipped, and the rest still applies. To force that on a machine that does have
`rbw`:

```sh
CHEZMOI_NO_SECRETS=1 chezmoi apply
```

Turning secrets on for a machine that was set up without them — note the
`init`, not `apply`, because `hasSecrets` is only computed at init time:

```sh
brew install rbw && rbw login
rbw get -f notes age-secret > ~/.ssh/key_age && chmod 600 ~/.ssh/key_age
chezmoi init --apply
```

Vault entries used:

| Entry | Renders |
|---|---|
| `Github Terminal Token` | `~/.git-credentials` |
| `age-secret` (notes field) | `~/.ssh/key_age` — the age identity |
| `Sentinel - meh-labs` (`SENTINEL_URL`, `SENTINEL_KEY` fields) | `/etc/sentinel.conf` — `server` role only |

### `/etc/sentinel.conf`

Read every minute by `sentinel agent` from the user crontab. Installed by
`home/.chezmoiscripts/run_onchange_install-sentinel-conf.sh.tmpl` — a script, not
a managed file, because the target is outside `$HOME`. `chezmoi apply` prompts for
sudo when the contents change; rotating the key in Bitwarden and re-applying is
enough to push it out.

Gated on `hasVault`, not `hasSecrets`, so a server renders this one file without
also pulling down the laptop's SSH keys and git credentials.

Without `rbw` the script deliberately leaves an existing `/etc/sentinel.conf`
untouched rather than writing a half-populated one, and warns only if the file is
missing altogether. Both gates are computed at **init** time, so a machine that
gains `rbw` later needs `chezmoi init` re-run, not just `apply`.

Set up on a server:

```sh
rbw config set email <you@example.com>
rbw config set pinentry pinentry-mac   # the TTY pinentries cannot prompt
rbw login
chezmoi init --promptString "Machine role (laptop/server)=server"
```

`pinentry-mac` matters more than it looks. With the default `pinentry`, an apply
from anything that is not an interactive terminal dies on `Inappropriate ioctl
for device` and the whole apply fails. Also note the vault re-locks after
`lock_timeout` (an hour by default), so an apply run long after the last unlock
needs `rbw unlock` first — unattended applies on a server are not possible while
a secret is fetched at apply time.

To apply only this file, without the full run (which would install the brew set
and switch the login shell to fish):

```sh
chezmoi execute-template \
  < ~/.local/share/chezmoi/home/.chezmoiscripts/run_onchange_install-sentinel-conf.sh.tmpl \
  | sh
```

To create the vault entry from a server that still has the file, once:

```sh
export BW_SESSION=$(bw unlock --raw)
scripts/add-sentinel-to-bitwarden.sh
```

## Layout

```
home/
  .chezmoi.toml.tmpl      config template (arch detection, hasSecrets gate)
  .chezmoidata/           package + plugin lists (edit these, not a Brewfile)
  .chezmoiexternal.toml   nvim, karabiner, tmux plugins pulled from upstream
  .chezmoiscripts/        install + sync hooks
  private_dot_config/     everything under ~/.config
```

Add or remove a package by editing `home/.chezmoidata/homebrew-packages.toml`
and running `chezmoi apply`.

## Not in here

`nvim` and `karabiner` live in their own repos and are pulled in as chezmoi
externals. See `home/.chezmoiexternal.toml`.
