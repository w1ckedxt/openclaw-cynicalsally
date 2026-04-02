#!/usr/bin/env bash
# Now Playing — fetch what Sally is currently listening to.
# Usage: bash scripts/nowplaying.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/format.sh"

require_command curl
require_command jq

# --- Call API ---
RAW=$(sally_get "/now-playing")

HTTP_CODE=$(echo "$RAW" | tail -1)
RESPONSE=$(echo "$RAW" | sed '$d')

if [[ "$HTTP_CODE" -ge 400 ]]; then
  echo '{"tracks": []}'
  echo "Could not fetch now playing." >&2
  exit 1
fi

# --- Output ---
echo "$RESPONSE"
format_nowplaying "$RESPONSE" >&2
