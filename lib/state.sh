#!/usr/bin/env bash
# lib/state.sh — Step state persistence for MAIN
# Stores completion status in a JSON file at ~/.cache/main/state.json
# Uses jq if available; falls back to a simple key=value flat file.

STATE_FILE="${STATE_FILE:-$HOME/.cache/main/state.json}"
_STATE_USE_JQ=false

# ── Init ────────────────────────────────────────────────────────
state::init() {
  if command -v jq &>/dev/null; then
    _STATE_USE_JQ=true
  fi

  if [[ ! -f "$STATE_FILE" ]]; then
    if $_STATE_USE_JQ; then
      echo '{"steps":{}}' > "$STATE_FILE"
    else
      # Flat file fallback: KEY=VALUE lines
      touch "$STATE_FILE"
    fi
  fi
}

# ── Get status ──────────────────────────────────────────────────
# Usage: state::get_status "step1"
# Returns: pending | running | done | error
state::get_status() {
  local key="$1"
  if $_STATE_USE_JQ; then
    local val
    val=$(jq -r --arg k "$key" '.steps[$k].status // "pending"' "$STATE_FILE" 2>/dev/null)
    echo "${val:-pending}"
  else
    local line
    line=$(grep "^${key}_status=" "$STATE_FILE" 2>/dev/null | tail -1 | cut -d= -f2-)
    echo "${line:-pending}"
  fi
}

# ── Set status ──────────────────────────────────────────────────
# Usage: state::set_status "step1" "done"
state::set_status() {
  local key="$1"
  local status="$2"
  if $_STATE_USE_JQ; then
    local tmp
    tmp=$(mktemp)
    jq --arg k "$key" --arg s "$status" \
      '.steps[$k].status = $s' "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
  else
    # Remove old entry and append new one
    sed -i "/^${key}_status=/d" "$STATE_FILE"
    echo "${key}_status=${status}" >> "$STATE_FILE"
  fi
}

# ── Set timestamp ────────────────────────────────────────────────
# Usage: state::set_timestamp "step1" "started"
state::set_timestamp() {
  local key="$1"
  local event="$2"
  local ts
  ts=$(date '+%Y-%m-%d %H:%M:%S')
  if $_STATE_USE_JQ; then
    local tmp
    tmp=$(mktemp)
    jq --arg k "$key" --arg e "$event" --arg t "$ts" \
      '.steps[$k][$e] = $t' "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
  else
    sed -i "/^${key}_${event}=/d" "$STATE_FILE"
    echo "${key}_${event}=${ts}" >> "$STATE_FILE"
  fi
}

# ── Get timestamp ────────────────────────────────────────────────
state::get_timestamp() {
  local key="$1"
  local event="$2"
  if $_STATE_USE_JQ; then
    jq -r --arg k "$key" --arg e "$event" \
      '.steps[$k][$e] // ""' "$STATE_FILE" 2>/dev/null
  else
    grep "^${key}_${event}=" "$STATE_FILE" 2>/dev/null | tail -1 | cut -d= -f2-
  fi
}

# ── Dump state (for debugging) ───────────────────────────────────
state::dump() {
  if $_STATE_USE_JQ; then
    jq '.' "$STATE_FILE"
  else
    cat "$STATE_FILE"
  fi
}
