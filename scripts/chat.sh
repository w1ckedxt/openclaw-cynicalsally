#!/usr/bin/env bash
# Chat — conversational Sally chat via API.
# Usage: bash scripts/chat.sh "<message>" [lang]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/format.sh"

require_device_id
require_command curl
require_command jq

# --- Parse args ---
MESSAGE="${1:?Missing message}"
LANG=$(default_lang "${2:-}")

# --- Build request ---
BODY=$(jq -n \
  --arg message "$MESSAGE" \
  --arg deviceId "$DEVICE_ID" \
  --arg lang "$LANG" \
  --arg source "$SALLY_SOURCE" \
  '{
    message: $message,
    deviceId: $deviceId,
    lang: $lang,
    source: $source
  }')

# --- Call API ---
RAW=$(sally_post "/chat" "$BODY")
RESPONSE=$(parse_response "$RAW")

# --- Output ---
echo "$RESPONSE"
format_chat "$RESPONSE" >&2
