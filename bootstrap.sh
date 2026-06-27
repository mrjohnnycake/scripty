#!/usr/bin/env bash
# bootstrap.sh — One-liner entry point for a fresh CachyOS install.
#
# Run this on a brand new machine with nothing set up yet:
#
#   bash <(curl -s https://raw.githubusercontent.com/mrjohnnycake/scripty/master/bootstrap.sh)
#
# It clones the full script repo to ~/.local/share/post-install
# (or wherever you set DEST below) and then runs main.sh.
#
# ── EDIT THESE TWO LINES FOR YOUR REPO ───────────────────────────
REPO_URL="https://github.com/mrjohnnycake/scripty.git"
BRANCH="master"
# ──────────────────────────────────────────────────────────────────

set -euo pipefail

DEST="$HOME/.local/share/post-install"

echo
echo "── Post-Install Bootstrap ──────────────────────────────"
echo

# Reminder before the deps check in main.sh looks for the USB.
# If the USB isn't plugged in, that check will fail and exit —
# this just gives a chance to plug it in first and avoid a
# failed run.
read -rp "Is your USB drive (with the Docs folder) plugged in? [Y/n] " usb_answer
if [[ -n "$usb_answer" && ! "$usb_answer" =~ ^[Yy]$ ]]; then
  echo
  echo "Plug in the USB drive, then re-run this command:"
  echo "  bash <(curl -s https://raw.githubusercontent.com/mrjohnnycake/scripty/master/bootstrap.sh)"
  echo
  exit 1
fi
echo

# git is the one dependency we can't avoid — install it if missing.
if ! command -v git &>/dev/null; then
  echo "git not found, installing..."
  sudo pacman -S --needed --noconfirm git
fi

if [[ -d "$DEST" ]]; then
  echo "Existing install found at $DEST"
  read -rp "Pull latest changes before running? [Y/n] " answer
  if [[ -z "$answer" || "$answer" =~ ^[Yy]$ ]]; then
    git -C "$DEST" pull
  fi
else
  echo "Cloning repo to $DEST ..."
  git clone --branch "$BRANCH" "$REPO_URL" "$DEST"
fi

echo
echo "Launching main.sh ..."
echo

chmod +x "$DEST/main.sh"
exec bash "$DEST/main.sh"
