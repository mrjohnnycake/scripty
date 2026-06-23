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

# Guard: paru must exist
deps::require_in_step "paru" "paru AUR helper" "Complete Step 1 first"


# ── Vivaldi ──────────────────────────────────────────────────────
ui::section "Setup Vivaldi and open default pages"

# Open first window for setup and a second window as the default set of tabs
vivaldi
sleep 3s
xargs vivaldi --new-window < "$(dirname "$0")/variables/vivaldi-urls.txt"
#vivaldi --new-window https://mail.google.com/mail/u/0/ https://calendar.google.com/calendar/u/0/r https://claude.ai/ https://messages.google.com/web https://start.mrjohnnycake.com






Obsidian CLI









# ── Dotfiles ───────────────────────────────────────────────
ui::section "Remove and replace existing dotfiles"

# Apps directory
cd ~/Dotfiles/Apps
rm -rf ~/.chirp
rm -rf ~/.config/dolphinrc
rm -rf ~/.local/share/user-places.xbel
rm -rf ~/.config/equibop/settings
rm -rf ~/.config/equibop/themes
rm -rf ~/.config/equibop/settings.json
rm -rf ~/.config/equibop/state.json
rm -rf ~/.config/feishin/config.json
rm -rf ~/.config/gramps
rm -rf ~/.local/share/gramps
rm -rf ~/.config/haruna
rm -rf ~/.config/katerc
rm -rf ~/.config/kate-externaltoolspluginrc
rm -rf ~/.config/kitty
rm -rf ~/.config/konversation.kmessagebox
rm -rf ~/.config/konversation.notifyrc
rm -rf ~/.config/konversationrc
rm -rf ~/.config/lazygit
rm -rf ~/.config/Numara/Local\ Storage
rm -rf ~/.config/Numara/Session\ Storage
rm -rf ~/.config/Numara/config
#rm -rf ~/.config/Plexamp/window-state-plexamp-main.json
rm -rf ~/.config/rofi
rm -rf ~/.local/share/Shortwave/Shortwave.db
rm -rf ~/.config/Signal\ Beta/ephemeral.json
rm -rf ~/.config/transmission
rm -rf ~/.config/zoomus.conf
stow -t ~/ chirp dolphin equibop feishin gramps haruna kate kitty konversation lazygit newsflash numara rofi shortwave signal syncthing transmission zoom
#stow -t ~/ easyeffects plexamp


cd ~/Dotfiles/Desktop/Dell/Scripts
stow -t ~/ downloads-folder
systemctl --user daemon-reload
systemctl --user enable --now organize-downloads.timer


ui::success "Personal dotfiles moved into position"


# ── 3. VPN Management ───────────────────────────────────────────────
ui::section "Setup Networking Tweaks and VPN Connections"

# Private Internet Access
mkdir PIA
cd PIA
wget https://www.privateinternetaccess.com/openvpn/openvpn.zip
unzip openvpn.zip
echo "Enter your Private Internet Access username:"
read PIA_USER
PIA_PASS="$(systemd-ask-password "Enter your Private Internet Access password:")"
nmcli connection import type openvpn file uk_manchester.ovpn
nmcli connection modify uk_manchester +vpn.data username="${PIA_USER}"
nmcli connection modify uk_manchester +vpn.secrets password="${PIA_PASS}"
nmcli connection modify uk_manchester connection.id "PIA (uk_manchester)"
cd ..
rm -rf PIA

# WireGuard VPN
sudo cp "$SCRIPT_DIR/../files/wg0.conf" /etc/wireguard/
sudo chown root:root /etc/wireguard/wg0.conf
wg_file='/etc/wireguard/wg0.conf'
sudo nmcli connection import type wireguard file "$wg_file"
sudo nmcli connection modify wg0 connection.id "Homelab VPN"
sudo nmcli connection modify "Homelab VPN" connection.autoconnect no
sudo nmcli connection down "Homelab VPN"
sleep 5

# WiFi and Ethernet script (shuts off wi-fi when ethernet is connected)
sudo tee /etc/NetworkManager/dispatcher.d/70-wifi-wired-exclusive.sh > /dev/null << "EOF"
#!/bin/bash
export LC_ALL=C

enable_disable_wifi ()
{
    result=$(nmcli dev | grep "ethernet" | grep -w "connected")
    if [ -n "$result" ]; then
        nmcli radio wifi off
    else
        nmcli radio wifi on
    fi
}

if [ "$2" = "up" ]; then
    enable_disable_wifi
fi

if [ "$2" = "down" ]; then
    enable_disable_wifi
fi
EOF

sudo chmod 744 /etc/NetworkManager/dispatcher.d/70-wifi-wired-exclusive.sh
sudo systemctl restart NetworkManager

# Let the wi-fi come back up before continuing
sleep 10

ui::success "Networking managed"



# ── 3. Fingerprint Setup ────────────────────────────────────
ui::section "Fingerprint setup"

fprintd-enroll --finger right-index-finger $USER

sudo cp /usr/lib/pam.d/polkit-1 /etc/pam.d/polkit-1

awk 'NR==3{print "auth sufficient pam_fprintd.so"; print ""} 1' /etc/pam.d/polkit-1 > tmp && sudo mv tmp /etc/pam.d/polkit-1

ui::success "Fingerprint setup complete"



# ── 3. Clean-Up ───────────────────────────────────────────────
ui::section "Basic Housekeeping"

# Update tealdeer cache
tldr -u

# Delete unused files


Check that these exist in new setup before removing

#sudo rm /usr/bin/kwrite
#sudo rm /usr/bin/kwriteconfig5
#sudo rm /usr/bin/kwriteconfig6
sudo rm /usr/share/applications/assistant.desktop
sudo rm /usr/share/applications/designer.desktop
sudo rm /usr/share/applications/java-java-openjdk.desktop
sudo rm /usr/share/applications/jconsole-java-openjdk.desktop
sudo rm /usr/share/applications/jshell-java-openjdk.desktop
sudo rm /usr/share/applications/linguist.desktop
sudo rm /usr/share/applications/org.cachyos.scx-manager.desktop
#sudo rm /usr/share/applications/org.kde.kwrite.desktop
sudo rm /usr/share/applications/qdbusviewer.desktop
sudo rm /usr/share/applications/qv4l2.desktop
sudo rm /usr/share/applications/qvidcap.desktop

sleep 3

ui::success "Housekeeping finished"

sleep 1

# ── 4. ── ADD YOUR COMMANDS HERE ─────────────────────────────────

ui::success "Step 2 complete — system will reboot."
