#!/usr/bin/env bash

# ─────────────────────────────────────────────────────────────────
# This step will be marked "done" only if this script
# exits 0. A non-zero exit marks it "error" and stops the reboot.
#
# Available helpers (sourced by main.sh before calling this):
#   ui::info "message"     — blue info line
#   ui::success "message"  — green success line
#   ui::warn "message"     — yellow warning
#   ui::error "message"    — red error (stderr)
#   ui::section "heading"  — section header
# ─────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/deps.sh"
source "$SCRIPT_DIR/../lib/ui.sh"
source "$SCRIPT_DIR/../lib/installers.sh"

# Guard: paru must exist
deps::require_in_step "paru" "paru AUR helper" "Complete Step 1 first"


# ── Vivaldi ──────────────────────────────────────────────────────
ui::section "Setup Vivaldi and open default pages"

install::run_cmd \
  "Launch Vivaldi and open default tabs?" \
  "Vivaldi setup" \
  'vivaldi &&
   sleep 3s &&
   xargs vivaldi --new-window < "$SCRIPT_DIR/variables/vivaldi-urls.txt"'


# ── GitHub CLI ─────────────────────────────────────────────────────
#ui::section "Setup GitHub CLI"

#install::run_cmd \
#  "Run the GitHub CLI setup?" \
#  "GitHub CLI setup" \
#  'gh auth login'


# I DON'T KNOW IF AUTH NEEDS TO BE RUN SINCE I SAVED THE DOTFILES. IF IT'S WORKING PROPERLY AFTER THE NEXT INSTALL JUST DELETE THIS SECTION


# ── Dotfiles ───────────────────────────────────────────────
ui::section "Remove and replace existing dotfiles"

install::run_cmd \
  "Remove conflicting configs and stow Apps dotfiles?" \
  "Apps dotfiles" \
  'cd ~/Dotfiles/Desktop/Apps &&
   rm -rf ~/.config/1Password/settings/settings.json &&
   rm -rf ~/.chirp &&
   rm -rf ~/.config/dolphinrc &&
   rm -rf ~/.local/share/user-places.xbel &&
   rm -rf ~/.config/equibop/settings &&
   rm -rf ~/.config/equibop/themes &&
   rm -rf ~/.config/equibop/settings.json &&
   rm -rf ~/.config/equibop/state.json &&
   rm -rf ~/.config/feishin/config.json &&
   rm -rf ~/.config/gramps &&
   rm -rf ~/.local/share/gramps &&
   rm -rf ~/.config/haruna &&
   rm -rf ~/.config/katerc &&
   rm -rf ~/.config/kate-externaltoolspluginrc &&
   rm -rf ~/.config/kitty &&
   rm -rf ~/.config/konversation.kmessagebox &&
   rm -rf ~/.config/konversation.notifyrc &&
   rm -rf ~/.config/konversationrc &&
   rm -rf ~/.config/MQTT-Explorer/settings.json &&
   rm -rf ~/.config/Numara/Local\ Storage &&
   rm -rf ~/.config/Numara/Session\ Storage &&
   rm -rf ~/.config/Numara/config &&
   rm -rf ~/.config/obsidian/obsidian.json &&
   rm -rf ~/.config/pomodorolm/config.toml &&
   rm -rf ~/.config/rofi &&
   rm -rf ~/.local/share/Shortwave/Shortwave.db &&
   rm -rf ~/.config/Signal/ephemeral.json &&
   rm -rf ~/.config/transmission &&
   rm -rf ~/.config/wgtray/config.toml &&
   rm -rf ~/.config/zoomus.conf &&
   stow -t ~/ 1password chirp dolphin equibop feishin gramps haruna kate kitty konversation mqtt-explorer numara obsidian pomodorolm rofi shortwave signal transmission wgtray zoom'
   # stow -t ~/ newsflash

install::run_cmd \
  "Stow downloads-folder script and enable its timer?" \
  "downloads-folder organizer" \
  'cd ~/Dotfiles/Desktop/Hyprland-End4 &&
   stow -t ~/ systemd &&
   systemctl --user daemon-reload &&
   systemctl --user enable --now organize-downloads.timer'

ui::success "Personal dotfiles moved into position"


# ── 3. VPN Management ───────────────────────────────────────────────
ui::section "Setup Networking Tweaks and VPN Connections"

install::run_cmd \
  "Set up Private Internet Access (PIA) OpenVPN connection?" \
  "PIA VPN setup" \
  'mkdir -p "$HOME/PIA" &&
   cd "$HOME/PIA" &&
   wget https://www.privateinternetaccess.com/openvpn/openvpn.zip &&
   unzip openvpn.zip &&
   echo "Enter your Private Internet Access username:" &&
   read PIA_USER &&
   PIA_PASS="$(systemd-ask-password "Enter your Private Internet Access password:")" &&
   nmcli connection import type openvpn file uk_manchester.ovpn &&
   nmcli connection modify uk_manchester +vpn.data username="${PIA_USER}" &&
   nmcli connection modify uk_manchester +vpn.secrets password="${PIA_PASS}" &&
   nmcli connection modify uk_manchester connection.id "PIA (uk_manchester)" &&
   cd "$HOME" &&
   rm -rf "$HOME/PIA"'

install::run_cmd \
  "Import WireGuard VPN config from USB files?" \
  "WireGuard VPN setup" \
  'sudo cp "$SCRIPT_DIR/../files/wg0.conf" /etc/wireguard/ &&
   sudo chown root:root /etc/wireguard/wg0.conf &&
   wg_file="/etc/wireguard/wg0.conf" &&
   sudo nmcli connection import type wireguard file "$wg_file" &&
   sudo nmcli connection modify wg0 connection.id "Homelab VPN" &&
   sudo nmcli connection modify "Homelab VPN" connection.autoconnect no &&
   sudo nmcli connection down "Homelab VPN" &&
   sleep 5'

install::run_cmd \
  "Install wifi/wired-exclusive NetworkManager dispatcher script?" \
  "wifi-wired-exclusive dispatcher" \
  'sudo cp "$SCRIPT_DIR/../files/70-wifi-wired-exclusive.sh" /etc/NetworkManager/dispatcher.d/70-wifi-wired-exclusive.sh &&
   sudo chown root:root /etc/NetworkManager/dispatcher.d/70-wifi-wired-exclusive.sh &&
   sudo chmod 744 /etc/NetworkManager/dispatcher.d/70-wifi-wired-exclusive.sh &&
   sudo systemctl restart NetworkManager &&
   sleep 10'

ui::success "Networking managed"



# ── 3. Fingerprint Setup ────────────────────────────────────
ui::section "Fingerprint setup"

install::run_cmd \
  "Enroll fingerprint and enable it for polkit prompts?" \
  "Fingerprint setup" \
  'fprintd-enroll --finger right-index-finger "$USER" &&
   sudo cp /usr/lib/pam.d/polkit-1 /etc/pam.d/polkit-1 &&
   awk '"'"'NR==3{print "auth sufficient pam_fprintd.so"; print ""} 1'"'"' /etc/pam.d/polkit-1 > /tmp/polkit-1.tmp &&
   sudo mv /tmp/polkit-1.tmp /etc/pam.d/polkit-1'

ui::success "Fingerprint setup complete"




# ── 3. Clean-Up ───────────────────────────────────────────────
ui::section "Basic Housekeeping"

install::run_cmd \
  "Update tealdeer cache?" \
  "tealdeer cache update" \
  'tldr -u'

# NOTE: Verify each of these still exists on a fresh install before
# enabling — package contents change between CachyOS/distro versions.
install::run_cmd \
  "Remove unused .desktop entries?" \
  "Remove unused desktop entries" \
  'sudo rm -f /usr/share/applications/assistant.desktop
   sudo rm -f /usr/share/applications/designer.desktop
   sudo rm -f /usr/share/applications/java-java-openjdk.desktop
   sudo rm -f /usr/share/applications/jconsole-java-openjdk.desktop
   sudo rm -f /usr/share/applications/jshell-java-openjdk.desktop
   sudo rm -f /usr/share/applications/linguist.desktop
   sudo rm -f /usr/share/applications/org.cachyos.scx-manager.desktop
   sudo rm -f /usr/share/applications/qdbusviewer.desktop
   sudo rm -f /usr/share/applications/qv4l2.desktop
   sudo rm -f /usr/share/applications/qvidcap.desktop'

ui::success "Housekeeping finished"

# ── 4. ── ADD YOUR COMMANDS HERE ─────────────────────────────────

ui::success "Step 2 complete — system will reboot."
