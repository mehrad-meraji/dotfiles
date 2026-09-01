# dotfiles

macOS dotfiles managed with [chezmoi](https://chezmoi.io).

Shell is [fish](https://fishshell.com); zsh is kept as a minimal fallback.
Terminals: WezTerm / Alacritty / Kitty, all themed Catppuccin and switched
automatically with the macOS light/dark setting.

## Install

```sh
brew install chezmoi
chezmoi init --apply mehrad-meraji
```

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

Set up secrets on a personal machine:

```sh
brew install rbw && rbw login
chezmoi apply
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
