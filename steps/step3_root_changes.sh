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




ORIGINAL SCRIPT COMMANDS ARE AT THE BOTTOM OF THE FILE





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

# ── 6. ── ADD YOUR COMMANDS HERE ─────────────────────────────────

ui::success "Step 3 complete — all steps finished!"
ui::info   "You may want to reboot for all changes to take full effect."




#################################################################################

#################################################################################



# Remove sudo password requirement
cp /etc/sudoers /root/sudoers.bak
visudo

# Set root bash environment
rm /root/.bashrc
nano /root/.bashrc

# neovim
mkdir .config
ln -s /home/barkeep/.config/nvim /root/.config/nvim
exec bash
nvim










