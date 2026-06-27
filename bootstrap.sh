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

# ── Mount the install USB ────────────────────────────────────────
# This is a fresh box — there's no desktop session (and therefore
# no udiskie/GNOME/KDE automounter) running yet to auto-mount the
# drive, so we drive udisks2 directly. Identifying by UUID avoids
# relying on a device name like /dev/sdb1, which can vary between
# boots or machines.
USB_UUID="2238-ADA8"

# udisks2 (for udisksctl) and exfatprogs (exFAT kernel/userspace
# support) are not part of a minimal CachyOS install.
for pkg in udisks2 exfatprogs; do
  if ! pacman -Qi "$pkg" &>/dev/null; then
    echo "$pkg not found, installing..."
    sudo pacman -S --needed --noconfirm "$pkg"
  fi
done

# udisks2's daemon needs to be running for udisksctl to work.
if ! systemctl is-active --quiet udisks2.service; then
  echo "Starting udisks2 service..."
  sudo systemctl start udisks2.service
fi

usb_mount_path=""
existing_mount="$(lsblk -no MOUNTPOINT "/dev/disk/by-uuid/$USB_UUID" 2>/dev/null | head -n1)"

if [[ -n "$existing_mount" ]]; then
  echo "USB already mounted at $existing_mount"
  usb_mount_path="$existing_mount"
elif [[ -e "/dev/disk/by-uuid/$USB_UUID" ]]; then
  echo "Mounting USB (UUID $USB_UUID)..."
  usb_dev="$(readlink -f "/dev/disk/by-uuid/$USB_UUID")"
  if udisksctl mount -b "$usb_dev"; then
    usb_mount_path="$(lsblk -no MOUNTPOINT "$usb_dev" | head -n1)"
    echo "Mounted at $usb_mount_path"
  else
    echo
    echo "Failed to mount the USB drive. You can try mounting it manually,"
    echo "then re-run this command."
    echo
    exit 1
  fi
else
  echo
  echo "Could not find a USB drive with UUID $USB_UUID."
  echo "Plug in the USB drive, then re-run this command:"
  echo "  bash <(curl -s https://raw.githubusercontent.com/mrjohnnycake/scripty/master/bootstrap.sh)"
  echo
  exit 1
fi

if [[ -z "$usb_mount_path" || ! -d "$usb_mount_path/Docs" ]]; then
  echo
  echo "USB is mounted at ${usb_mount_path:-<unknown>}, but no Docs folder was found there."
  echo "Check the drive contents, then re-run this command."
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
