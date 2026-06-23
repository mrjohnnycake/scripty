#!/usr/bin/env bash
# steps/step1_initial.sh — Initial setup: packages, dotfiles, system config
#
# ── HOW TO CREATE A NEW STEP ────────────────────────────────────
#
#   1. Copy this file to steps/stepN_yourname.sh
#   2. Register it in main.sh by adding to the STEPS array:
#        STEPS=(
#          "step1_initial.sh|Step 1 — Initial Setup|...|yes"
#          "stepN_yourname.sh|Step N — Your Name|...|no"
#        )
#   3. Fill in your install groups below using the installer functions.
#      See lib/installers.sh for full documentation.
#
# ── AVAILABLE INSTALLER FUNCTIONS ───────────────────────────────
#
#   install::pacman "Prompt?"  pkg1 pkg2 ...   → sudo pacman -S
#   install::aur    "Prompt?"  pkg1 pkg2 ...   → paru -S
#   install::run_cmd "Prompt?" "Label" "cmd"   → any shell command
#
# ────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/deps.sh
source "$SCRIPT_DIR/../lib/deps.sh"
# shellcheck source=../lib/ui.sh
source "$SCRIPT_DIR/../lib/ui.sh"
# shellcheck source=../lib/installers.sh
source "$SCRIPT_DIR/../lib/installers.sh"


# ── AUR helper (paru) ───────────────────────────────────────────
# Must come first — AUR installs below depend on it.
ui::section "AUR helper (paru)"
if ! command -v paru &>/dev/null; then
  install::run_cmd \
    "Install paru (AUR helper)?" \
    "paru" \
    'sudo pacman -S --needed --noconfirm base-devel git &&
     local_tmp=$(mktemp -d) &&
     git clone https://aur.archlinux.org/paru.git "$local_tmp/paru" &&
     (cd "$local_tmp/paru" && makepkg -si --noconfirm) &&
     rm -rf "$local_tmp"'
else
  ui::info "paru already installed, skipping"
fi


# ── Core pacman packages ─────────────────────────────────────────
# To add/remove packages: edit the array below.
# To add a new group: copy this whole block, change the array name,
# prompt text, and package list.
ui::section "Core packages"

##########################
## Install explanations ##
##########################

# `ark` is a file archiver / unarchiver
# `bat` is a `cat` alternative
# `blueman` is the better bluetooth manager
# `chirp-next` is for managing Baofeng radios
# `cpio` is needed for hyprpm
# `easyeffects` is an eq app but it messes with stuff so don't install it
# `fisher` is a plugin system for fish shell
# `fprintd` is for fingerprint authenication
# `fuse` is for AppImages
# `gwenview-no-purpose` is a stripped down version because the original wants to install a bunch of unnecessary dependencies
# `hyprpolkitagent` is for 1Password authenication
# `kcharselect` is a Unicode character viewer / selector
# `konversation` is an IRC client used for finding ebooks
# Language servers are for Kate and any other IDE
# `lemminx` is a language server for Kate
# `lnav` is a terminal log viewer
# `lsd` is a shell command to replace `ls`
# `marksman` is a language server for Kate
# `newsflash` is an RSS feed reader
# `okular-no-purpose` is a stripped down version of KDE's PDF viewer without all the unnecessary dependencies
# `p7zip` is for Lutris
# `plasma-systemmonitor` is the system monitor that End-4 defaults to
# `rmw` is a terminal app for sending files to the Trash instead of full deletion
# `shellcheck` is for Kate and any other IDE
# `shfmt` is for Kate language support
# `sshpass` is for shell scripting
# `sshs` is a command line tool to connect to servers
# `superfile` is a TUI file manager
# `sysd-manager` is a systemd units viewer/manager
# `tenacity` is an Audacity fork
# `tealdeer` is for command line man pages
# `thefuck` is for adding sudo to the last command
# `udiskie` is for automounting USB devices
# `usbimager` is a Balena Etcher alternative but is kinda more trouble than it's worth
# `wev` is an app to help figure out behind the scenes system commands
# `zoxide` is for remembering `cd` commands

CORE_PKGS=(
  ansible
  ark
  bash-language-server
  bat
  blueman
  cpio
  equibop
  etcher-bin
  feishin
  fisher
  fuse
  gimp
  gnome-chess
  gnome-mahjongg
  gnome-sudoku
  gramps
  gwenview
  haruna
  kate
  kcharselect
  kmines
  konversation
  kpat
  krename
  kruler
  lazygit
  lnav
  lsd
  lutris
  marksman
  neovim
  newsflash
  obsidian
  okular
  partitionmanager
  plasma-systemmonitor
  python-lsp-server
  rofi
  shellcheck
  shfmt
  shortwave
  signal-desktop
  sqlitebrowser
  sshpass
  sshs
  steam
  stow
  superfile
  syncthing
  tealdeer
  tenacity
  thefuck
  tmux
  transmission-qt
  typescript-language-server
  vivaldi
  vscode-json-languageserver
  wev
  wireguard-tools
  yaml-language-server
  zoxide
)

# Temporarily disabled:
# CORE_PKGS=(
#   hyprpolkitagent
#   lua-language-server
# )

install::pacman "Install core CachyOS repo packages?" "${CORE_PKGS[@]}"


# ── AUR packages ────────────────────────────────────────────────
ui::section "AUR packages"

AUR_PKGS=(
  1password # only install method that works well, maintained by 1Password
  chirp-next # cloudflare blocks scraping so I'm unable to install it via script
  pomodorolm-bin # didn't work when installing via script but this package is maintained by the app author so no real worries as long as the app is still being developed
  #rmw
  #mqtt-explorer # installed via GitHub instead to lessen deps on AUR
  #numara-bin # installed via GitHub instead to lessen deps on AUR
  #plexamp-bin is breaking bluetooth and other audio functions because of needing to uninstall `jack` and install `pipewire-jack` and ALSO it doesn't have mpris support.
  #plezy-bin # installed via GitHub instead to lessen deps on AUR
  #sysd-manager # installed via GitHub instead to lessen deps on AUR
  #usbimager
  #wgtray
)

install::aur "Install AUR packages?" "${AUR_PKGS[@]}"


# ── Dotfiles ─────────────────────────────────────────────────────
ui::section "Dotfiles"

install::run_cmd \
  "Copy Dotfiles folder to \$HOME?" \
  "Dotfiles placement" \
  'cp -r "$SCRIPT_DIR/../files/Dotfiles" "$HOME/Dotfiles"'

install::run_cmd \
  "Stow the first set of Linux dotfiles (git nvim rmw scripts superfile tealdeer zoxide)?" \
  "Linux dotfiles" \
  'cd ~/Dotfiles/Linux
   stow -t ~/ fish git nvim personal rmw scripts starship superfile tealdeer zoxide'

install::run_cmd \
  "Set up Syncthing and apply Stow configs?" \
  "Syncthing" \
  'cd ~/Dotfiles/Apps
   sudo systemctl enable --now syncthing@barkeep.service
   sleep 5
   rm /home/barkeep/.local/state/syncthing/config.xml
   stow -t ~/ syncthing'


# ── GitHub / manual installs ─────────────────────────────────────
# Use install::run_cmd for anything that isn't pacman or AUR.
# Each gets its own prompt so you can skip individually.
ui::section "GitHub installs"

install::run_cmd \
  "Install MQTT Explorer?" \
  "mqtt-explorer" \
  'cd "$HOME/Dotfiles/Linux/scripts/.scripts/github-installs"
   ./mqtt-explorer.sh'

install::run_cmd \
  "Install Numara?" \
  "numara" \
  'cd "$HOME/Dotfiles/Linux/scripts/.scripts/github-installs"
   ./numara.sh'

install::run_cmd \
  "Install Plezy?" \
  "plezy" \
  'cd "$HOME/Dotfiles/Linux/scripts/.scripts/github-installs"
   ./plezy.sh'

install::run_cmd \
  "Install rmw?" \
  "rmw" \
  'cd "$HOME/Dotfiles/Linux/scripts/.scripts/github-installs"
   ./rmw.sh'

install::run_cmd \
  "Install SysD Manager?" \
  "sysd-manager" \
  'cd "$HOME/Dotfiles/Linux/scripts/.scripts/github-installs"
   ./sysd-manager.sh'

install::run_cmd \
  "Install wgtray?" \
  "wgtray" \
  'cd "$HOME/Dotfiles/Linux/scripts/.scripts/github-installs"
   ./wgtray.sh'


# ── Hyprland plugins ─────────────────────────────────────────────
ui::section "Hyprland Setup"

#install::run_cmd \
  #"Install hyprfocus plugin?" \
  #"hyprfocus" \
  #'hyprpm update
  #hyprpm add https://github.com/daxisunder/hyprfocus
  #hyprpm enable hyprfocus'

install::run_cmd \
  "Install your personal Hyprland dotfiles?" \
  "Hyprland dotfiles" \
  'cd "$HOME/Dotfiles/Desktop/Dell/Hyprland"
   rm "$HOME/.config/illogical-impulse/config.json"
   rm "$HOME/.config/hypr/hypridle.conf"
   rm "$HOME/.config/hypr/custom/env.lua
   rm "$HOME/.config/hypr/custom/execs.lua
   rm "$HOME/.config/hypr/custom/general.lua
   rm "$HOME/.config/hypr/custom/keybinds.lua
   rm "$HOME/.config/hypr/custom/rules.lua
   rm "$HOME/.config/hypr/custom/variables.lua
   stow -t ~/ hypr-end4'


# ── App setup ────────────────────────────────────────────────────
ui::section "App setup"

install::run_cmd \
  "Set up 1Password browser integration?" \
  "1Password" \
  'sudo mkdir -p /etc/1password
   echo "vivaldi" | sudo tee /etc/1password/custom_allowed_browsers
   sudo chown root:root /etc/1password/custom_allowed_browsers
   sudo chmod 755 /etc/1password/custom_allowed_browsers'

install::run_cmd \
  "Launch Neovim to trigger plugin install?" \
  "Neovim first run" \
  'nvim'


# ── Home folder ──────────────────────────────────────────────────
ui::section "Home folder setup"

install::run_cmd \
  "Set SSH permissions?" \
  "SSH permissions" \
  'cp -r "$SCRIPT_DIR/../files/.ssh" "$HOME/"
   chmod 600 ~/.ssh/*
   chmod 700 ~/.ssh'

install::run_cmd \
  "Replace home dirs with symlinks to /mnt/Homer?" \
  "Home folder symlinks" \
  'sudo rm -rf /home/barkeep/{Documents,Downloads,Music,Pictures,Projects,Public,Templates,Videos}
  ln -s /mnt/Homer/Documents /home/barkeep/Documents
  ln -s /mnt/Homer/Downloads /home/barkeep/Downloads
  ln -s /mnt/Homer/Music /home/barkeep/Music
  ln -s /mnt/Homer/Pictures /home/barkeep/Pictures
  ln -s /mnt/Homer/Projects /home/barkeep/Projects
  ln -s /mnt/Homer/Videos /home/barkeep/Videos'

ui::success "Step 1 complete — system will reboot."
