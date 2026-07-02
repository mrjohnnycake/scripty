#!/usr/bin/env bash

set -euo pipefail

sudo pacman -Syu
sudo pacman -S ansible ark bash-language-server bat blueman cpio equibop etcher-bin feishin fisher fuse gimp github-cli gnome-chess gnome-mahjongg gnome-sudoku gramps gwenview haruna kate kcharselect kmines konversation kpat krename kruler lazygit lnav lsd lutris marksman neovim obsidian okular partitionmanager plasma-systemmonitor python-lsp-server rofi shellcheck shfmt shortwave signal-desktop spotify-launcher sqlitebrowser sshpass sshs steam stow superfile syncthing tealdeer tenacity thefuck tmux transmission-qt typescript-language-server vivaldi vscode-json-languageserver wev wireguard-tools yaml-language-server zoxide

paru -S 1password chirp-next pomodorolm-bin

sudo mkdir -p /media/usb
sudo mount UUID="2238-ADA8" /media/usb
cp -r /run/media/barkeep/Ventoy/Docs/.ssh ~/
chmod 600 ~/.ssh/*
chmod 700 ~/.ssh

cd ~/
GIT_SSH_COMMAND="ssh -i /home/barkeep/.ssh/github-administrator" git clone git@github.com:mrjohnnycake/hyprland-dms-dots.git
mv hyprland-dms-dots ~/Dotfiles

cd ~/Dotfiles/Linux
rm -rf ~/.config/fish
stow -t ~/ fish git lazygit nvim rmw superfile tealdeer zoxide
mkdir ~/.config/fish/completions

echo "Linux Dotfiles complete"

cd ~/Dotfiles/Desktop/Apps
sudo systemctl enable --now syncthing@"$USER".service
sleep 5
sudo systemctl stop syncthing@"$USER".service
rm "$HOME/.local/state/syncthing/config.xml"
rm "$HOME/.local/state/syncthing/config.xml.v0"
stow -t ~/ syncthing
sudo systemctl start syncthing@"$USER".service

echo "Syncthing section complete"


cd "$HOME/Dotfiles/Desktop/Scripts/desktop/.scripts/desktop/github-installs/apps"
./mqtt-explorer.sh
./numara.sh
./plezy.sh
./rmw.sh
./sysd-manager.sh
./wgtray.sh

echo "GitHub Apps section done"


cd "$HOME/Dotfiles/Desktop/Hyprland-End4"
rm "$HOME/.config/hypr/hypridle.conf"
rm "$HOME/.config/hypr/custom/env.lua"
rm "$HOME/.config/hypr/custom/execs.lua"
rm "$HOME/.config/hypr/custom/general.lua"
rm "$HOME/.config/hypr/custom/keybinds.lua"
rm "$HOME/.config/hypr/custom/rules.lua"
rm "$HOME/.config/hypr/custom/variables.lua"
stow -t ~/ hyprland

echo "My Hyprland dots in place"


cd "$HOME/Dotfiles/Desktop/Scripts/desktop/.scripts/desktop/hypr/updating/end-4_overwrites/scripts"
./hypr-hyprland-general.sh
./hypr-hyprland-keybinds.sh
./hypr-hyprland-variables.sh

echo "End-4 lua files commented out as needed"


sudo mkdir -p /etc/1password
echo "vivaldi" | sudo tee /etc/1password/custom_allowed_browsers
sudo chown root:root /etc/1password/custom_allowed_browsers
sudo chmod 755 /etc/1password/custom_allowed_browsers

echo "1Password ready to setup"
sleep 2s

nvim

ln -s /mnt/Homer/Documents /home/"$USER"/Documents
ln -s /mnt/Homer/Downloads /home/"$USER"/Downloads
ln -s /mnt/Homer/Music /home/"$USER"/Music
ln -s /mnt/Homer/Pictures /home/"$USER"/Pictures
ln -s /mnt/Homer/Projects /home/"$USER"/Projects
ln -s /mnt/Homer/Videos /home/"$USER"/Videos

echo "Home folder symlinking complete"
