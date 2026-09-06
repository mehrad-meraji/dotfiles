# dotfiles

macOS dotfiles managed with [chezmoi](https://chezmoi.io).

Shell is [fish](https://fishshell.com); zsh is kept as a minimal fallback.
Terminals: WezTerm / Alacritty / Kitty, all themed Catppuccin and switched
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
| `server` | shared + `cloudflared`, `restic`, `tailscale`; `hasSecrets` forced off | rustup, karabiner, terminal-theme agent |

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
| Licence keys — Sketch, Raycast Pro, Herd Pro | Bitwarden |
| Apple ID, iCloud, Messages | System Settings |

## Secrets

Nothing secret is stored in this repo. Files that need a secret are rendered at
apply time from [Bitwarden](https://github.com/doy/rbw) (`rbw`), and a few SSH
keys are [age](https://age-encryption.org)-encrypted.

If `rbw` is not installed, `hasSecrets` is `false` and every secret-backed file
is skipped — the rest still applies. To force that on a machine that does have
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
