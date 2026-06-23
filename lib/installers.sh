#!/usr/bin/env bash
# lib/installers.sh — Reusable installer functions for step scripts
#
# ── HOW TO USE IN A STEP SCRIPT ─────────────────────────────────
#
#   1. Source this file at the top of your step script:
#        source "$SCRIPT_DIR/../lib/installers.sh"
#
#   2. Define a package list as a bash array:
#        PKGS=(firefox neovim tmux)
#
#   3. Call the appropriate installer function:
#        install::pacman "Install core packages?" "${PKGS[@]}"
#        install::aur    "Install AUR packages?"  "${PKGS[@]}"
#
#   4. To add a new install group, just repeat steps 2-3:
#        FONTS=(noto-fonts ttf-jetbrains-mono)
#        install::pacman "Install fonts?" "${FONTS[@]}"
#
# ── AVAILABLE FUNCTIONS ──────────────────────────────────────────
#
#   install::pacman  "Prompt text?" pkg1 pkg2 ...
#     → Prompts user, then runs: sudo pacman -S --needed pkg1 pkg2 ...
#     → Default answer is Y (just press Enter to accept)
#
#   install::aur  "Prompt text?" pkg1 pkg2 ...
#     → Prompts user, then runs: paru -S --skipreview pkg1 pkg2 ...
#     → Requires paru to be installed (step 1 handles this)
#
#   install::run_cmd  "Prompt text?" "Description" "command to run"
#     → Generic prompt for any shell command (git clone, curl, etc.)
#     → Use for one-off installs that don't fit pacman/AUR
#     → Example: install::run_cmd "Clone wg-tray?" "wg-tray" \
#                  "git clone https://github.com/example/wg-tray.git ~/.config/wg-tray"
#
# ── DRY RUN MODE ─────────────────────────────────────────────────
#
#   Set DRY_RUN=true to walk through the script without installing
#   anything. Every prompt still appears, but commands are printed
#   instead of executed.
#
#   Enable by passing it before the script:
#     DRY_RUN=true bash main.sh
#
#   Or export it in your shell session:
#     export DRY_RUN=true
#
# ── FAILURE BEHAVIOR ─────────────────────────────────────────────
#
#   For pacman and AUR installs:
#   - Each package is installed individually so one failure doesn't
#     block the rest
#   - Failed packages are collected and reported at the end
#   - The function returns 0 even if some packages failed, so the
#     step continues — check the summary output to see what failed
#
#   For install::run_cmd:
#   - If the command fails, a warning is printed but execution continues
#
# ────────────────────────────────────────────────────────────────

# Default DRY_RUN to false if not already set
DRY_RUN="${DRY_RUN:-false}"



# ── Internal helper: prompt yes/no ──────────────────────────────
# Usage: _install::prompt "Question?" && echo "yes" || echo "no"
# Returns 0 (yes) or 1 (no). Default is Y on empty input.
_install::prompt() {
  local question="$1"
  local answer
  echo >/dev/tty
  printf '  \e[0;36m%s\e[0m \e[2m[Y/n]\e[0m ' "$question" >/dev/tty
  read -r answer </dev/tty
  echo >/dev/tty
  # Empty input (just Enter) = yes
  [[ -z "$answer" || "$answer" =~ ^[Yy]$ ]]
}


# ── install::pacman ─────────────────────────────────────────────
# Install a group of pacman packages with a single prompt.
#
# Usage:
#   PKGS=(pkg1 pkg2 pkg3)
#   install::pacman "Install my packages?" "${PKGS[@]}"
#
install::pacman() {
  local prompt="$1"
  shift
  local packages=("$@")

  _install::prompt "$prompt" || {
    printf '  \e[2m  Skipping.\e[0m\n'
    return 0
  }

  if [[ "$DRY_RUN" == "true" ]]; then
    printf '  \e[0;35m  [DRY RUN] Would run: sudo pacman -S --needed %s\e[0m\n' "${packages[*]}"
    return 0
  fi

  local failed=()

  for pkg in "${packages[@]}"; do
    printf '  \e[2m→ Installing %s...\e[0m\n' "$pkg"
    if ! sudo pacman -S --needed --noconfirm "$pkg" 2>/dev/null; then
      failed+=("$pkg")
      printf '  \e[0;31m  ✖ Failed: %s\e[0m\n' "$pkg"
    fi
  done

  # Report any failures
  if [[ ${#failed[@]} -gt 0 ]]; then
    echo
    printf '  \e[0;33m  ⚠ The following packages failed to install:\e[0m\n'
    for pkg in "${failed[@]}"; do
      printf '      \e[2m• %s\e[0m\n' "$pkg"
    done
    echo
  else
    printf '  \e[0;32m  ✔ All packages installed.\e[0m\n'
  fi
}


# ── install::aur ────────────────────────────────────────────────
# Install a group of AUR packages with a single prompt.
# Requires paru to be available.
#
# Usage:
#   AUR_PKGS=(pkg1-bin pkg2-git)
#   install::aur "Install AUR packages?" "${AUR_PKGS[@]}"
#
install::aur() {
  local prompt="$1"
  shift
  local packages=("$@")

  # Check paru is available before prompting
  if ! command -v paru &>/dev/null; then
    printf '  \e[0;31m  ✖ paru not found — skipping AUR group: %s\e[0m\n' "$prompt"
    return 0
  fi

  _install::prompt "$prompt" || {
    printf '  \e[2m  Skipping.\e[0m\n'
    return 0
  }

  if [[ "$DRY_RUN" == "true" ]]; then
    printf '  \e[0;35m  [DRY RUN] Would run: paru -S --skipreview %s\e[0m\n' "${packages[*]}"
    return 0
  fi

  local failed=()

  for pkg in "${packages[@]}"; do
    printf '  \e[2m→ Installing %s...\e[0m\n' "$pkg"
    if ! paru -S --skipreview --noconfirm "$pkg" 2>/dev/null; then
      failed+=("$pkg")
      printf '  \e[0;31m  ✖ Failed: %s\e[0m\n' "$pkg"
    fi
  done

  # Report any failures
  if [[ ${#failed[@]} -gt 0 ]]; then
    echo
    printf '  \e[0;33m  ⚠ The following AUR packages failed to install:\e[0m\n'
    for pkg in "${failed[@]}"; do
      printf '      \e[2m• %s\e[0m\n' "$pkg"
    done
    echo
  else
    printf '  \e[0;32m  ✔ All AUR packages installed.\e[0m\n'
  fi
}


# ── install::run_cmd ────────────────────────────────────────────
# Run any arbitrary command with a prompt.
# Use for git clones, curl installs, or anything that doesn't fit
# pacman/AUR.
#
# Usage:
#   install::run_cmd \
#     "Clone wg-tray from GitHub?" \
#     "wg-tray" \
#     "git clone https://github.com/remigius-labs/wg-tray.git ~/.config/wg-tray"
#
# Arguments:
#   $1  — Prompt shown to the user
#   $2  — Short description (shown in output)
#   $3  — The command to run (as a string, passed to eval)
#
install::run_cmd() {
  local prompt="$1"
  local description="$2"
  local command="$3"

  _install::prompt "$prompt" || {
    printf '  \e[2m  Skipping %s.\e[0m\n' "$description"
    return 0
  }

  if [[ "$DRY_RUN" == "true" ]]; then
    printf '  \e[0;35m  [DRY RUN] Would run: %s\e[0m\n' "$command"
    return 0
  fi

  printf '  \e[2m→ Running: %s\e[0m\n' "$description"
  if eval "$command"; then
    printf '  \e[0;32m  ✔ %s complete.\e[0m\n' "$description"
  else
    printf '  \e[0;33m  ⚠ %s encountered errors — you may need to run it manually.\e[0m\n' "$description"
  fi
}
