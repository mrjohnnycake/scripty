#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║                       Post-Install TUI                       ║
# ║              CachyOS / Hyprland System Bootstrap             ║
# ╚══════════════════════════════════════════════════════════════╝
# Entry point. Checks deps, loads lib, draws the main menu.

set -euo pipefail

# ── Paths ──────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"
STEPS_DIR="$SCRIPT_DIR/steps"
STATE_FILE="$HOME/.cache/main/state.json"
LOG_FILE="$HOME/.cache/main/main.log"

# shellcheck source=lib/ui.sh
source "$LIB_DIR/ui.sh"
# shellcheck source=lib/state.sh
source "$LIB_DIR/state.sh"
# shellcheck source=lib/deps.sh
source "$LIB_DIR/deps.sh"

# ── Bootstrap ──────────────────────────────────────────────────
main::init() {
  mkdir -p "$(dirname "$STATE_FILE")"
  mkdir -p "$(dirname "$LOG_FILE")"
  state::init          # create state file if missing
  deps::check          # verify required tools are present
}

# ── Step registry ──────────────────────────────────────────────
# Each entry: "script_file|display_title|description|needs_reboot"
declare -a STEPS=(
  "step1_initial.sh|Step 1 — Initial Setup|Core packages, AUR helper, base config|yes"
  "step2_setups.sh|Step 2 — App & Dotfile Setup|User apps, dotfiles, shell config|yes"
  "step3_root_changes.sh|Step 3 — Root & System Tweaks|System-level changes, services, grub|no"
)

# ── Main menu ──────────────────────────────────────────────────
main::menu() {
  while true; do
    ui::clear
    ui::banner
    ui::step_status_table "${STEPS[@]}"
    ui::divider

    local options=()
    local i=1
    for step_def in "${STEPS[@]}"; do
      IFS='|' read -r _script title _desc _reboot <<< "$step_def"
      local status
      status="$(state::get_status "step$i")"
      local label
      case "$status" in
        done)    label="$(ui::color green "✔")  $title $(ui::color dim "(completed)")" ;;
        running) label="$(ui::color yellow "⟳")  $title $(ui::color dim "(in progress)")" ;;
        *)       label="$(ui::color cyan "→")  $title" ;;
      esac
      options+=("$i" "$label")
      ((i++))
    done

    options+=("e" "$(ui::color red "✕")  Exit")
    options+=("l" "$(ui::color magenta "⊟")  View Log")
    options+=("r" "$(ui::color yellow "↺")  Reset a Step")

    local choice
    choice="$(ui::menu "Select an action:" "${options[@]}")"

    case "$choice" in
      [1-9])
        local idx=$((choice - 1))
        if [[ $idx -lt ${#STEPS[@]} ]]; then
          main::run_step "$choice" "${STEPS[$idx]}"
        fi
        ;;
      e) ui::clear; echo "Goodbye."; exit 0 ;;
      l) main::view_log ;;
      r) main::reset_menu ;;
      *) : ;;
    esac
  done
}

# ── Run a step ─────────────────────────────────────────────────
main::run_step() {
  local step_num="$1"
  local step_def="$2"
  IFS='|' read -r script title desc needs_reboot <<< "$step_def"

  local step_key="step${step_num}"
  local current_status
  current_status="$(state::get_status "$step_key")"

  # Warn if already completed
  if [[ "$current_status" == "done" ]]; then
    if ! ui::confirm "'$title' is already marked done. Run it again?"; then
      return
    fi
  fi

  ui::clear
  ui::header "Running: $title"
  echo
  ui::info "$desc"
  echo
  if ! ui::confirm "Proceed with $title?"; then
    return
  fi

  # Mark running
  state::set_status "$step_key" "running"
  state::set_timestamp "$step_key" "started"

  echo
  ui::section "Output"
  echo

  local step_script="$STEPS_DIR/$script"
  if [[ ! -f "$step_script" ]]; then
    ui::error "Step script not found: $step_script"
    state::set_status "$step_key" "error"
    ui::pause
    return
  fi

  # Run the step script, tee output to log
  local exit_code=0
  bash "$step_script" 2>&1 | tee -a "$LOG_FILE" || exit_code=$?

  echo
  if [[ $exit_code -eq 0 ]]; then
    state::set_status "$step_key" "done"
    state::set_timestamp "$step_key" "completed"
    ui::success "$title completed successfully."

    if [[ "$needs_reboot" == "yes" ]]; then
      echo
      ui::warn "A reboot is recommended before running the next step."
      if ui::confirm "Reboot now?"; then
        ui::info "Rebooting in 3 seconds... Run 'main.sh' after login to continue."
        sleep 3
        systemctl reboot
      fi
    else
      ui::pause
    fi
  else
    state::set_status "$step_key" "error"
    ui::error "$title failed with exit code $exit_code. Check the log for details."
    ui::pause
  fi
}

# ── View log ───────────────────────────────────────────────────
main::view_log() {
  ui::clear
  ui::header "Log: $LOG_FILE"
  echo
  if [[ -f "$LOG_FILE" ]]; then
    less -R "$LOG_FILE"
  else
    ui::warn "No log file found yet."
    ui::pause
  fi
}

# ── Reset menu ─────────────────────────────────────────────────
main::reset_menu() {
  ui::clear
  ui::header "Reset a Step"
  echo

  local options=()
  local i=1
  for step_def in "${STEPS[@]}"; do
    IFS='|' read -r _script title _desc _reboot <<< "$step_def"
    local status
    status="$(state::get_status "step$i")"
    options+=("$i" "$title $(ui::color dim "($(ui::status_label "$status"))")")
    ((i++))
  done
  options+=("b" "Back")

  local choice
  choice="$(ui::menu "Which step to reset?" "${options[@]}")"

  case "$choice" in
    [1-9])
      if [[ $((choice - 1)) -lt ${#STEPS[@]} ]]; then
        if ui::confirm "Reset step $choice status to 'pending'?"; then
          state::set_status "step${choice}" "pending"
          ui::success "Step $choice reset."
          sleep 1
        fi
      fi
      ;;
    b|*) return ;;
  esac
}

# ── Entry ──────────────────────────────────────────────────────
main::init
main::open_helper
main::menu

# ── Installer helper note ───────────────────────────────────────
# Opens installer-helper.md in a new terminal window using cat so
# it stays visible while you work through the menu.
# Bash requires functions to be defined before they are called, but
# since open_helper is called from the entry block at the bottom of
# this file, the definition must come after — so we define it here
# and it is available because bash reads the whole file first.
main::open_helper() {
  local helper="$SCRIPT_DIR/files/installer-helper.md"
  if [[ ! -f "$helper" ]]; then
    ui::warn "installer-helper.md not found in files/ — skipping."
    return 0
  fi

  kwrite "$helper" &
}
