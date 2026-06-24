#!/usr/bin/env bash
# steps/step3_root_changes.sh — Step 3: Root & System Tweaks
# ─────────────────────────────────────────────────────────────────
# Mirrors your 3_root-changes.sh.
# System-level changes: services, sysctl, grub, etc.
# Marked needs_reboot=no in MAIN — add a ui::warn here if yours does.
# ─────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/deps.sh"
source "$SCRIPT_DIR/../lib/ui.sh"
source "$SCRIPT_DIR/../lib/installers.sh"


# ── 1. Enable system services ────────────────────────────────────
ui::section "System services"
# TODO: add your services
# sudo systemctl enable --now bluetooth
# sudo systemctl enable --now cups
ui::success "Services configured"

# ── 2. sysctl / kernel tweaks ────────────────────────────────────
ui::section "Kernel / sysctl tweaks"
# TODO: add sysctl settings or /etc/sysctl.d/ files
# echo "vm.swappiness=10" | sudo tee /etc/sysctl.d/99-custom.conf
# sudo sysctl --system
ui::info "No sysctl changes configured (add yours in this section)"

# ── 3. GRUB / bootloader ─────────────────────────────────────────
ui::section "Bootloader"
# TODO: any grub config tweaks
# sudo nano /etc/default/grub   # <-- not interactive-friendly; use sed instead
# sudo grub-mkconfig -o /boot/grub/grub.cfg
ui::info "No bootloader changes configured (add yours in this section)"

# ── 4. Filesystem / fstab tweaks ─────────────────────────────────
ui::section "Filesystem"
# TODO: tmpfs, noatime, etc.

# ── 5. User groups ───────────────────────────────────────────────
ui::section "User groups"
# TODO: add user to needed groups
# sudo usermod -aG video,audio,input "$USER"
# ui::success "User groups updated"

# ── 6. Sudo / root environment ───────────────────────────────────
ui::section "Sudo and root shell environment"

install::run_cmd \
  "Back up /etc/sudoers and remove sudo password requirement?" \
  "Passwordless sudo" \
  'sudo cp /etc/sudoers /root/sudoers.bak
   echo "$USER ALL=(ALL) NOPASSWD: ALL" | sudo EDITOR="tee -a" visudo'

install::run_cmd \
  "Reset root .bashrc to your custom version?" \
  "Root .bashrc" \
  'sudo rm -f /root/.bashrc
   sudo cp "$HOME/.bashrc" /root/.bashrc'

install::run_cmd \
  "Symlink root Neovim config to your user config?" \
  "Root Neovim config" \
  'sudo mkdir -p /root/.config
   sudo ln -sf "$HOME/.config/nvim" /root/.config/nvim'

# ── 7. ── ADD YOUR COMMANDS HERE ─────────────────────────────────

ui::success "Step 3 complete — all steps finished!"
ui::info   "You may want to reboot for all changes to take full effect."










