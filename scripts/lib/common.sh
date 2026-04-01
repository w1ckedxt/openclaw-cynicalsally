#!/usr/bin/env bash
# Shared constants and utilities for all Sally scripts.
# Source this file: source "$(dirname "$0")/lib/common.sh"

set -euo pipefail

# --- Config ---
SALLY_API_BASE="https://cynicalsally.com/api/v1"
SALLY_SOURCE="openclaw"
SALLY_ID_FILE="${HOME}/.sally-device-id"
DEVICE_ID="${SALLY_DEVICE_ID:-}"

# --- Validation ---
require_device_id() {
  # Auto-generate and persist if not set
  if [[ -z "$DEVICE_ID" ]]; then
    if [[ -f "$SALLY_ID_FILE" ]]; then
      DEVICE_ID=$(cat "$SALLY_ID_FILE")
    else
      DEVICE_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')
      echo "$DEVICE_ID" > "$SALLY_ID_FILE"
    fi
  fi
}

require_command() {
  local cmd="$1"
  if ! command -v "$cmd" &>/dev/null; then
    echo "{\"error\": \"Required command '$cmd' not found. Please install it.\"}" >&2
    exit 1
  fi
}

# --- HTTP ---
sally_post() {
  local endpoint="$1"
  local body="$2"

  curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Content-Type: application/json" \
    -d "$body" \
    "${SALLY_API_BASE}${endpoint}"
}

sally_get() {
  local endpoint="$1"

  curl -s -w "\n%{http_code}" \
    -X GET \
    -H "Content-Type: application/json" \
    "${SALLY_API_BASE}${endpoint}"
}

# --- Response parsing ---
parse_response() {
  local raw="$1"
  local body http_code

  http_code=$(echo "$raw" | tail -1)
  body=$(echo "$raw" | sed '$d')

  if [[ "$http_code" -ge 400 ]]; then
    echo "{\"error\": \"HTTP $http_code\", \"details\": $body}" >&2
    exit 1
  fi

  echo "$body"
}

# --- Defaults ---
default_lang() {
  echo "${1:-en}"
}
