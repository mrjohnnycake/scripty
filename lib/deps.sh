#!/usr/bin/env bash
# lib/deps.sh — Runtime dependency checker for MAIN

# ── Required tools ───────────────────────────────────────────────
# Format: "command|human name|install hint"
_DEPS_REQUIRED=(
  "bash|Bash 4+|pre-installed"
  "tput|ncurses tput|pacman -S ncurses"
  "less|less pager|pacman -S less"
  "systemctl|systemd|pre-installed on CachyOS"
)

_DEPS_OPTIONAL=(
  "jq|jq (better state management)|jq"
  "kwrite|KWrite|kwrite"
)

# ── Check ────────────────────────────────────────────────────────
deps::check() {
  local missing=()

  for dep_def in "${_DEPS_REQUIRED[@]}"; do
    IFS='|' read -r cmd name hint <<< "$dep_def"
    if ! command -v "$cmd" &>/dev/null; then
      missing+=("$name ($hint)")
    fi
  done

  # Bash version check (need 4+ for associative arrays etc.)
  if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
    missing+=("Bash 4+ (current: $BASH_VERSION)")
  fi

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo
    printf '\e[0;31m  ✖ MAIN cannot start — missing required dependencies:\e[0m\n\n'
    for m in "${missing[@]}"; do
      printf '    \e[2m•\e[0m %s\n' "$m"
    done
    echo
    exit 1
  fi

  # Optional deps — prompt to install if missing
  for dep_def in "${_DEPS_OPTIONAL[@]}"; do
    IFS='|' read -r cmd name pacman_cmd <<< "$dep_def"
    if ! command -v "$cmd" &>/dev/null; then
      echo
      printf '\e[0;33m  ⚠ Optional dependency not found: %s\e[0m\n' "$name"
      read -rp $'  \e[2mInstall it now? [y/N]\e[0m ' answer
      echo
      if [[ "$answer" =~ ^[Yy]$ ]]; then
        sudo pacman -S --noconfirm "$cmd"
        if command -v "$cmd" &>/dev/null; then
          printf '\e[0;32m  ✔ %s installed.\e[0m\n' "$name"
        else
          printf '\e[0;31m  ✖ Install failed. Continuing without %s.\e[0m\n' "$name"
        fi
      else
        printf '  \e[2mSkipping %s — some features may be limited.\e[0m\n' "$name"
      fi
    fi
  done

  deps::check_usb_files
  deps::check_end4
  deps::offer_sysupdate
}

# ── USB file pre-check ───────────────────────────────────────────
# Looks for a USB drive with a "Docs" folder, then checks for and
# moves required files/folders into script-dir/files/.
#
# Exits the script if:
#   - No USB with a Docs folder can be found
#   - Any required file/folder is missing
#   - The user answers no to any prompt
deps::check_usb_files() {
  local dest="$SCRIPT_DIR/files"
  mkdir -p "$dest"

  # ── Skip if files already copied from a previous run ─────────
  # Presence of all five expected items means the USB step is done.
  if [[ -f "$dest/wg0.conf" && -d "$dest/.ssh" && -f "$dest/70-wifi-wired-exclusive.sh" && -f "$dest/installer-helper.md" && -d "$dest/Dotfiles" ]]; then
    printf '  \e[0;32m  ✔ USB files already in place — skipping USB check.\e[0m\n'
    echo
    return 0
  fi

  # ── Locate USB mount with a Docs folder ──────────────────────
  local docs_dir=""
  for mount in /run/media/"$USER"/*/; do
    if [[ -d "${mount}Docs" ]]; then
      docs_dir="${mount}Docs"
      break
    fi
  done

  if [[ -z "$docs_dir" ]]; then
    echo
    printf '  \e[0;31m  ✖ Could not find a USB drive with a "Docs" folder.\e[0m\n'
    printf '  \e[2m    Make sure your USB is plugged in and mounted, then re-run the script.\e[0m\n'
    echo
    exit 1
  fi

  printf '  \e[0;32m  ✔ Found Docs folder at: %s\e[0m\n' "$docs_dir"
  echo

  # ── Helper: fatal missing item ────────────────────────────────
  _deps::usb_missing() {
    printf '  \e[0;31m  ✖ %s\e[0m\n' "$1"
    printf '  \e[2m    Resolve this and re-run the script.\e[0m\n'
    echo
    exit 1
  }

  # ── 1. WireGuard .conf file ───────────────────────────────────
  local conf_files=()
  while IFS= read -r -d '' f; do
    conf_files+=("$f")
  done < <(find "$docs_dir" -maxdepth 1 -name "*.conf" -print0)

  if [[ ${#conf_files[@]} -eq 0 ]]; then
    _deps::usb_missing "No .conf file found in Docs. Expected your WireGuard config."
  fi

  local conf_file
  if [[ ${#conf_files[@]} -eq 1 ]]; then
    conf_file="${conf_files[0]}"
    local conf_name
    conf_name="$(basename "$conf_file")"

    printf '  \e[0;36m  Is \e[1m%s\e[0m\e[0;36m your WireGuard config file?\e[0m \e[2m[Y/n]\e[0m ' "$conf_name"
    read -r answer </dev/tty
    echo
    if [[ -z "$answer" || "$answer" =~ ^[Yy]$ ]]; then
      :
    else
      _deps::usb_missing "WireGuard config not confirmed. Cannot continue without it."
    fi
  else
    printf '  \e[0;36m  Multiple .conf files found. Which one is your WireGuard config?\e[0m\n'
    echo
    local i=1
    for f in "${conf_files[@]}"; do
      printf '    \e[0;36m[%s]\e[0m  %s\n' "$i" "$(basename "$f")"
      ((i++))
    done
    echo

    local conf_choice
    while true; do
      printf '  \e[2mEnter number [1-%s]:\e[0m ' "${#conf_files[@]}"
      read -r conf_choice </dev/tty
      if [[ "$conf_choice" =~ ^[0-9]+$ ]] && [[ "$conf_choice" -ge 1 ]] && [[ "$conf_choice" -le "${#conf_files[@]}" ]]; then
        break
      fi
      printf '  \e[0;33m  Invalid choice, try again.\e[0m\n'
    done

    conf_file="${conf_files[$((conf_choice - 1))]}"
  fi

  cp "$conf_file" "$dest/wg0.conf"
  printf '  \e[0;32m  ✔ Copied "%s" as wg0.conf\e[0m\n' "$(basename "$conf_file")"
  echo

  # ── 2. .ssh folder ────────────────────────────────────────────
  local ssh_src="$docs_dir/.ssh"
  if [[ ! -d "$ssh_src" ]]; then
    _deps::usb_missing "No .ssh folder found in Docs."
  fi

  local ssh_file_count
  ssh_file_count="$(find "$ssh_src" -maxdepth 1 -type f | wc -l)"
  if [[ "$ssh_file_count" -eq 0 ]]; then
    _deps::usb_missing ".ssh folder exists but contains no files."
  fi

  cp -r "$ssh_src" "$dest/.ssh"
  printf '  \e[0;32m  ✔ Copied .ssh folder (%s files)\e[0m\n' "$ssh_file_count"
  echo

  # ── 3. 70-wifi-wired-exclusive.sh ────────────────────────────
  local nm_script="$docs_dir/70-wifi-wired-exclusive.sh"
  if [[ ! -f "$nm_script" ]]; then
    _deps::usb_missing "70-wifi-wired-exclusive.sh not found in Docs."
  fi

  cp "$nm_script" "$dest/70-wifi-wired-exclusive.sh"
  printf '  \e[0;32m  ✔ Copied 70-wifi-wired-exclusive.sh\e[0m\n'
  echo

  # ── 4. Installer helper .md file ─────────────────────────────
  local md_files=()
  while IFS= read -r -d '' f; do
    md_files+=("$(basename "$f")")
  done < <(find "$docs_dir" -maxdepth 1 -name "*.md" -print0)

  if [[ ${#md_files[@]} -eq 0 ]]; then
    _deps::usb_missing "No .md files found in Docs. Expected your installer helper note."
  fi

  printf '  \e[0;36m  Which file is your installer helper note?\e[0m\n'
  echo
  local i=1
  for f in "${md_files[@]}"; do
    printf '    \e[0;36m[%s]\e[0m  %s\n' "$i" "$f"
    ((i++))
  done
  echo

  local md_choice
  while true; do
    printf '  \e[2mEnter number [1-%s]:\e[0m ' "${#md_files[@]}"
    read -r md_choice </dev/tty
    if [[ "$md_choice" =~ ^[0-9]+$ ]] && [[ "$md_choice" -ge 1 ]] && [[ "$md_choice" -le "${#md_files[@]}" ]]; then
      break
    fi
    printf '  \e[0;33m  Invalid choice, try again.\e[0m\n'
  done

  local selected_md="${md_files[$((md_choice - 1))]}"
  cp "$docs_dir/$selected_md" "$dest/installer-helper.md"
  printf '  \e[0;32m  ✔ Copied "%s" as installer-helper.md\e[0m\n' "$selected_md"
  echo

  # ── 5. Dotfiles folder ────────────────────────────────────────
  local dotfiles_src="$docs_dir/Dotfiles"
  if [[ ! -d "$dotfiles_src" ]]; then
    _deps::usb_missing "No Dotfiles folder found in Docs."
  fi

  local dotfiles_count
  dotfiles_count="$(find "$dotfiles_src" -mindepth 1 | wc -l)"
  if [[ "$dotfiles_count" -eq 0 ]]; then
    _deps::usb_missing "Dotfiles folder exists but is empty."
  fi

  cp -r "$dotfiles_src" "$dest/Dotfiles"
  printf '  \e[0;32m  ✔ Copied Dotfiles folder (%s items)\e[0m\n' "$dotfiles_count"
  echo

  printf '  \e[0;32m  ✔ All USB files copied to %s\e[0m\n' "$dest"
  echo
}

# ── End-4 dotfiles pre-check ─────────────────────────────────────
# Checks for the End-4 installer sentinel file before the system
# update prompt. If missing, offers to open the installer.
deps::check_end4() {
  local sentinel="$HOME/.config/illogical-impulse/installed_true"
  if [[ ! -f "$sentinel" ]]; then
    echo
    printf '  \e[0;33m  ⚠ It looks like you haven'"'"'t run the End-4 Dotfiles Installer yet.\e[0m\n'
    printf '  \e[2m    Would you like me to open it now?\e[0m \e[2m[Y/n]\e[0m '
    read -r answer
    echo
    if [[ -z "$answer" || "$answer" =~ ^[Yy]$ ]]; then
      bash <(curl -s https://ii.clsty.link/get)
      echo
      printf '  \e[0;36m  ℹ End-4 installer launched. Re-run this script when it finishes.\e[0m\n'
      echo
      exit 0
    else
      echo
      printf '  \e[0;31m  ✖ The End-4 Dotfiles Installer must be run before setup can continue.\e[0m\n'
      printf '  \e[2m    Run it manually when ready:\e[0m\n'
      printf '  \e[2m    bash <(curl -s https://ii.clsty.link/get)\e[0m\n'
      echo
      exit 1
    fi
  fi
}

# ── Optional system update ────────────────────────────────────────
deps::offer_sysupdate() {
  echo
  printf '\e[0;36m  ℹ Would you like to run a full system update before continuing?\e[0m\n'
  printf '    \e[2m(sudo pacman -Syu)\e[0m\n'
  echo
  read -rp $'  \e[2mRun system update? [y/N]\e[0m ' answer
  echo
  if [[ "$answer" =~ ^[Yy]$ ]]; then
    printf '\e[1m  Updating system...\e[0m\n'
    echo
    if sudo pacman -Syu; then
      echo
      printf '\e[0;32m  ✔ System update complete.\e[0m\n'
    else
      echo
      printf '\e[0;31m  ✖ Update encountered errors. You may want to resolve them before continuing.\e[0m\n'
    fi
  else
    printf '  \e[2mSkipping system update.\e[0m\n'
  fi
  echo
}

# ── Step-level dep check ─────────────────────────────────────────
# Call inside a step script to verify tools it needs before running.
# Usage: deps::require_in_step "paru" "paru AUR helper" "see step 1"
deps::require_in_step() {
  local cmd="$1"
  local name="$2"
  local hint="${3:-install it first}"
  if ! command -v "$cmd" &>/dev/null; then
    printf '\e[0;31m  ✖ Required tool not found: %s\e[0m\n' "$name"
    printf '    Hint: %s\n' "$hint"
    exit 1
  fi
}
