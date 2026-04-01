#!/usr/bin/env bash
# Code Review — review code files via Sally API.
# Usage: bash scripts/review.sh <mode> <lang> <path1> <content1> [path2] [content2] ...
# mode: "quick" or "full_truth"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/format.sh"

require_device_id
require_command curl
require_command jq

# --- Parse args ---
MODE="${1:?Missing mode (quick or full_truth)}"
LANG=$(default_lang "${2:-}")
shift 2

# Build files array from remaining args (alternating path/content pairs)
FILES="[]"
while [[ $# -ge 2 ]]; do
  FILE_PATH="$1"
  FILE_CONTENT="$2"
  shift 2

  FILES=$(echo "$FILES" | jq \
    --arg path "$FILE_PATH" \
    --arg content "$FILE_CONTENT" \
    '. + [{ path: $path, content: $content }]')
done

if [[ $(echo "$FILES" | jq 'length') -eq 0 ]]; then
  echo '{"error": "No files provided. Pass alternating path/content pairs."}' >&2
  exit 1
fi

# --- Build request ---
BODY=$(jq -n \
  --argjson files "$FILES" \
  --arg mode "$MODE" \
  --arg deviceId "$DEVICE_ID" \
  --arg lang "$LANG" \
  --arg source "$SALLY_SOURCE" \
  '{
    files: $files,
    mode: $mode,
    deviceId: $deviceId,
    lang: $lang,
    source: $source
  }')

# --- Call API (handle 429 quota exhausted gracefully) ---
RAW=$(sally_post "/review" "$BODY")

HTTP_CODE=$(echo "$RAW" | tail -1)
RESPONSE=$(echo "$RAW" | sed '$d')

# Quota exhausted: show upgrade/login hints
if [[ "$HTTP_CODE" == "429" ]]; then
  echo "$RESPONSE"
  echo "You've used all your free reviews this month." >&2
  echo "" >&2
  echo "Already have SuperClub? Link your account:" >&2
  echo "  sally login your@email.com" >&2
  echo "" >&2
  echo "Don't have SuperClub? Get unlimited reviews:" >&2
  echo "  https://cynicalsally.com/superclub" >&2
  exit 0
fi

# Other errors: fail normally
if [[ "$HTTP_CODE" -ge 400 ]]; then
  echo "{\"error\": \"HTTP $HTTP_CODE\", \"details\": $RESPONSE}" >&2
  exit 1
fi

# --- Success output ---
echo "$RESPONSE"
format_review "$RESPONSE" >&2
