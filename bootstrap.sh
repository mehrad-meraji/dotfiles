#!/bin/sh
# Bootstrap a fresh Mac. One line, from a blank macOS:
#
#   /bin/sh -c "$(curl -fsSL https://raw.githubusercontent.com/mehrad-meraji/dotfiles/main/bootstrap.sh)"
#
# Order matters. `hasSecrets` and `machineRole` are decided ONCE, during
# `chezmoi init`, and are baked into ~/.config/chezmoi/chezmoi.toml. If rbw is
# missing or the age key is absent at that moment, every secret-backed file is
# skipped and a later `chezmoi apply` will NOT fix it. So: tools first, then
# secrets, then init.
set -eu

GITHUB_USER=mehrad-meraji
EMAIL=mehrad.meraji@gmail.com

step() { printf '\n\033[1;34m==>\033[0m %s\n' "$1"; }

# 1. Xcode command line tools — git and the compilers Homebrew needs.
if ! xcode-select -p >/dev/null 2>&1; then
  step "Installing Xcode command line tools (a dialog will open)"
  xcode-select --install
  printf 'Press return once the install has finished. '
  read -r _
fi

# 2. Homebrew.
if ! command -v brew >/dev/null 2>&1; then
  step "Installing Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
BREW_PREFIX=/opt/homebrew
[ -d "$BREW_PREFIX" ] || BREW_PREFIX=/usr/local
eval "$("$BREW_PREFIX/bin/brew" shellenv)"

# 3. Only the tools chezmoi itself needs at init time. Everything else comes
#    from .chezmoidata/homebrew-packages.toml once chezmoi runs.
step "Installing chezmoi, rbw, age, pinentry-mac"
brew install chezmoi rbw age pinentry-mac

# 4. Bitwarden. rbw's config is NOT in the dotfiles repo, so set it here.
step "Configuring rbw (Bitwarden)"
rbw config set email "$EMAIL"
rbw config set pinentry "$BREW_PREFIX/bin/pinentry-mac"
rbw login
rbw sync

# 5. Seed the age identity BEFORE init, so chezmoi can decrypt the
#    encrypted_*.age files on the very first apply.
if [ ! -f "$HOME/.ssh/key_age" ]; then
  step "Writing ~/.ssh/key_age from Bitwarden"
  mkdir -p "$HOME/.ssh"
  rbw get -f notes age-secret > "$HOME/.ssh/key_age"
  chmod 600 "$HOME/.ssh/key_age"
fi
EXPECTED=age1yds3tez2pyfda2nputpnd9vqqf6rm6al7a92rd82ah5mcflk4gds2jgdnd
ACTUAL=$(age-keygen -y "$HOME/.ssh/key_age")
if [ "$ACTUAL" != "$EXPECTED" ]; then
  echo "age key mismatch: got $ACTUAL, expected $EXPECTED" >&2
  echo "Fix ~/.ssh/key_age before continuing, or nothing encrypted will decrypt." >&2
  exit 1
fi
echo "age identity OK"

# 6. chezmoi. This prompts for the machine role; answer laptop or server.
#    Non-interactive: --promptString is keyed by the PROMPT TEXT, not the
#    variable name, so it is
#      chezmoi init --apply --promptString "Machine role (laptop/server)=server"
#    and NOT --promptString machineRole=server, which is silently ignored.
step "Running chezmoi init --apply"
chezmoi init --apply "$GITHUB_USER"

step "Done. Open a new terminal."
