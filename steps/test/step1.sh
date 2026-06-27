#!/usr/bin/env bash

set -euo pipefail

sudo pacman -Syu
sudo pacman -S ansible ark bash-language-server bat blueman cpio equibop etcher-bin feishin fisher fuse gimp github-cli gnome-chess gnome-mahjongg gnome-sudoku gramps gwenview haruna kate kcharselect kmines konversation kpat krename kruler lazygit lnav lsd lutris marksman neovim obsidian okular partitionmanager plasma-systemmonitor python-lsp-server rofi shellcheck shfmt shortwave signal-desktop spotify-launcher sqlitebrowser sshpass sshs steam stow superfile syncthing tealdeer tenacity thefuck tmux transmission-qt typescript-language-server vivaldi vscode-json-languageserver wev wireguard-tools yaml-language-server zoxide

paru -S 1password chirp-next pomodorolm-bin

sudo mkdir -p /media/usb
sudo mount UUID="2238-ADA8" /media/usb
cp -r /media/usb/Docs/.ssh
chmod 600 ~/.ssh/*
chmod 700 ~/.ssh

GIT_SSH_COMMAND="ssh -i /home/barkeep/.ssh/github-administrator" git clone git@github.com:mrjohnnycake/hyprland-dms-dots.git
mv ~/hyprland-dms-dots ~/Dotfiles
