#!/usr/bin/env bash
# Chat — conversational Sally chat via API.
# Usage:
#   bash scripts/chat.sh "<message>" [lang]
#   bash scripts/chat.sh "<message>" [lang] [history_json]
# history_json: JSON array of previous messages, e.g. [{"role":"user","content":"hi"},{"role":"assistant","content":"hey"}]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/format.sh"

require_device_id
require_command curl
require_command jq

# --- Parse args ---
MESSAGE="${1:?Missing message}"
LANG=$(default_lang "${2:-}")
HISTORY="${3:-[]}"

# Validate history is valid JSON array
if ! echo "$HISTORY" | jq empty 2>/dev/null; then
  HISTORY="[]"
fi

# --- Build request ---
BODY=$(jq -n \
  --arg message "$MESSAGE" \
  --arg deviceId "$DEVICE_ID" \
  --arg lang "$LANG" \
  --arg source "$SALLY_SOURCE" \
  --argjson history "$HISTORY" \
  '{
    message: $message,
    deviceId: $deviceId,
    lang: $lang,
    source: $source,
    history: $history
  }')

# --- Call API ---
RAW=$(sally_post "/chat" "$BODY")
RESPONSE=$(parse_response "$RAW")

# --- Output ---
echo "$RESPONSE"
format_chat "$RESPONSE" >&2
