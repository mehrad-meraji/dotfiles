#!/bin/bash
# Fix Neovim Plugin Ownership Issues
# Run this script if you see "dubious ownership" errors in neovim
#
# Usage: bash ~/fix-nvim-ownership.sh

set -e

NVIM_DATA_DIR="${HOME}/.local/share/nvim"

echo "🔧 Fixing Neovim plugin directory ownership..."
echo ""

if [[ ! -d "$NVIM_DATA_DIR" ]]; then
  echo "✓ Nvim data directory doesn't exist yet (will be created correctly)"
  exit 0
fi

# Check current ownership
OWNER=$(stat -f "%Su" "$NVIM_DATA_DIR")
CURRENT_USER=$(whoami)

if [[ "$OWNER" == "$CURRENT_USER" ]]; then
  echo "✓ $NVIM_DATA_DIR is already owned by $CURRENT_USER"
  
  # Check subdirectories
  if find "$NVIM_DATA_DIR" -user root -print -quit 2>/dev/null | grep -q .; then
    echo "⚠ Found some files owned by root inside $NVIM_DATA_DIR"
    echo ""
    echo "Fixing ownership (may require sudo password)..."
    sudo chown -R "$CURRENT_USER:staff" "$NVIM_DATA_DIR"
    echo "✓ Fixed ownership of all files in $NVIM_DATA_DIR"
  else
    echo "✓ All files are owned by $CURRENT_USER"
  fi
else
  echo "⚠ $NVIM_DATA_DIR is owned by $OWNER (should be $CURRENT_USER)"
  echo ""
  echo "Fixing ownership (may require sudo password)..."
  sudo chown -R "$CURRENT_USER:staff" "$NVIM_DATA_DIR"
  echo "✓ Fixed ownership of $NVIM_DATA_DIR"
fi

echo ""
echo "✅ Done! You can now open neovim without ownership errors."
