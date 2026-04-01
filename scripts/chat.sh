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

# --- Call API (handle 429 quota exhausted gracefully) ---
RAW=$(sally_post "/chat" "$BODY")

HTTP_CODE=$(echo "$RAW" | tail -1)
RESPONSE=$(echo "$RAW" | sed '$d')

# Quota exhausted: still parse and format (don't exit 1)
if [[ "$HTTP_CODE" == "429" ]]; then
  echo "$RESPONSE"
  format_chat "$RESPONSE" >&2
  exit 0
fi

# Other errors: fail normally
if [[ "$HTTP_CODE" -ge 400 ]]; then
  echo "{\"error\": \"HTTP $HTTP_CODE\", \"details\": $RESPONSE}" >&2
  exit 1
fi

# --- Success output ---
echo "$RESPONSE"
format_chat "$RESPONSE" >&2
