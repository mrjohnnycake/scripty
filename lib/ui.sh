#!/usr/bin/env bash
# lib/ui.sh — Visual rendering library for MAIN
# Pure bash + tput. No dialog/whiptail dependency.

# ── Terminal capabilities ───────────────────────────────────────
UI_COLS=$(tput cols 2>/dev/null || echo 80)
UI_WIDTH=70  # fixed inner width for consistent layout

# ── Color helpers ───────────────────────────────────────────────
ui::color() {
  local color="$1"; shift
  local text="$*"
  case "$color" in
    red)     printf '\e[0;31m%s\e[0m' "$text" ;;
    green)   printf '\e[0;32m%s\e[0m' "$text" ;;
    yellow)  printf '\e[0;33m%s\e[0m' "$text" ;;
    blue)    printf '\e[0;34m%s\e[0m' "$text" ;;
    magenta) printf '\e[0;35m%s\e[0m' "$text" ;;
    cyan)    printf '\e[0;36m%s\e[0m' "$text" ;;
    white)   printf '\e[0;37m%s\e[0m' "$text" ;;
    bold)    printf '\e[1m%s\e[0m'    "$text" ;;
    dim)     printf '\e[2m%s\e[0m'    "$text" ;;
    *)       printf '%s' "$text" ;;
  esac
}

# ── Layout primitives ───────────────────────────────────────────
ui::clear() {
  clear
}

ui::divider() {
  local char="${1:-}"
  [[ -z "$char" ]] && char="─"
  printf '\e[2m'
  # tr doesn't handle multi-byte chars; use printf + sed instead
  local line
  line=$(printf '%*s' "$UI_WIDTH" '' | sed "s/ /${char}/g")
  printf '%s\e[0m\n' "$line"
}

ui::pad_center() {
  local text="$1"
  # Strip ANSI for length calculation
  local plain
  plain=$(printf '%s' "$text" | sed 's/\x1b\[[0-9;]*m//g')
  local len=${#plain}
  local pad=$(( (UI_WIDTH - len) / 2 ))
  printf '%*s%s\n' "$pad" '' "$text"
}

# ── Banner ──────────────────────────────────────────────────────
ui::banner() {
  echo
  ui::color cyan "$(cat <<'EOF'

                                ███             █████
                               ░░░             ░░███
     █████   ██████  ████████  ████  ████████  ███████   █████ ████
    ███░░   ███░░███░░███░░███░░███ ░░███░░███░░░███░   ░░███ ░███
   ░░█████ ░███ ░░░  ░███ ░░░  ░███  ░███ ░███  ░███     ░███ ░███
    ░░░░███░███  ███ ░███      ░███  ░███ ░███  ░███ ███ ░███ ░███
    ██████ ░░██████  █████     █████ ░███████   ░░█████  ░░███████
   ░░░░░░   ░░░░░░  ░░░░░     ░░░░░  ░███░░░     ░░░░░    ░░░░░███
                                     ░███                 ███ ░███
                                     █████               ░░██████
                                    ░░░░░                 ░░░░░░

EOF
)"
  echo " "
  echo
  ui::pad_center "$(ui::color dim "CachyOS · Hyprland · END-4 · Post-Install Dotfiles")"
  echo
  ui::divider "═"
  echo
}

ui::header() {
  local title="$1"
  echo
  ui::divider "─"
  ui::pad_center "$(ui::color bold "$title")"
  ui::divider "─"
  echo
}

ui::section() {
  local title="$1"
  echo
  printf '  %s %s\n' "$(ui::color cyan "▸")" "$(ui::color bold "$title")"
  ui::divider "·"
}

# ── Status table ────────────────────────────────────────────────
ui::status_label() {
  local status="$1"
  case "$status" in
    done)    ui::color green    "✔ done"    ;;
    running) ui::color yellow   "⟳ running" ;;
    error)   ui::color red      "✖ error"   ;;
    pending) ui::color dim      "· pending" ;;
    *)       ui::color dim      "· pending" ;;
  esac
}

ui::step_status_table() {
  local steps=("$@")
  local i=1
  printf '  %-40s %-16s\n' \
    "$(ui::color dim "STEP")" \
    "$(ui::color dim "STATUS")"
  ui::divider "·"
  for step_def in "${steps[@]}"; do
    IFS='|' read -r _script title _desc _reboot <<< "$step_def"
    local status
    status="$(state::get_status "step$i")"
    local label
    label="$(ui::status_label "$status")"
    printf '  %-38s %s\n' \
      "$title" \
      "$label"
    ((i++))
  done
  echo
}

# ── Notifications ───────────────────────────────────────────────
ui::info() {
  printf '  %s %s\n' "$(ui::color blue "ℹ")" "$*"
}

ui::success() {
  printf '  %s %s\n' "$(ui::color green "✔")" "$*"
}

ui::warn() {
  printf '  %s %s\n' "$(ui::color yellow "⚠")" "$*"
}

ui::error() {
  printf '  %s %s\n' "$(ui::color red "✖")" "$*" >&2
}

# ── Interactive prompts ─────────────────────────────────────────

# Simple numbered menu — no external deps
# Usage: ui::menu "Prompt" "key1" "label1" "key2" "label2" ...
# Returns the chosen key via stdout
ui::menu() {
  local prompt="$1"; shift
  # Build parallel arrays of keys and labels
  local -a keys=()
  local -a labels=()
  while [[ $# -ge 2 ]]; do
    keys+=("$1")
    labels+=("$2")
    shift 2
  done

  while true; do
    printf '  %s\n\n' "$(ui::color bold "$prompt")" >/dev/tty
    local idx=0
    for label in "${labels[@]}"; do
      printf '    %s  %b\n' "$(ui::color cyan "${keys[$idx]}")" "$label" >/dev/tty
      ((idx++))
    done
    echo >/dev/tty
    local input
    read -rp $'  \e[2mChoice:\e[0m ' input </dev/tty
    echo >/dev/tty

    # Validate against known keys
    for k in "${keys[@]}"; do
      if [[ "$input" == "$k" ]]; then
        printf '%s' "$input"
        return 0
      fi
    done
    ui::warn "Invalid choice. Try again." >/dev/tty
    echo >/dev/tty
  done
}

# Yes/No confirm — returns 0 for yes, 1 for no
ui::confirm() {
  local prompt="$1"
  printf '  %s %s ' "$(ui::color yellow "?")" "$prompt $(ui::color dim "[y/N]")"
  local answer
  read -r answer
  echo
  [[ "$answer" =~ ^[Yy]$ ]]
}

ui::pause() {
  printf '  %s' "$(ui::color dim "Press Enter to continue...")"
  read -r
}
