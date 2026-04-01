#!/usr/bin/env bash
# Quick Roast — roast a URL or image via Sally API.
# Usage:
#   bash scripts/roast.sh <url> [lang]
#   bash scripts/roast.sh --image <base64> <media_type> [lang]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/format.sh"

require_device_id
require_command curl
require_command jq

# --- Parse args ---
if [[ "${1:-}" == "--image" ]]; then
  # Image mode
  IMAGE_BASE64="${2:?Missing base64 image data}"
  MEDIA_TYPE="${3:?Missing media type (image/jpeg, image/png, image/gif, image/webp)}"
  LANG=$(default_lang "${4:-}")

  BODY=$(jq -n \
    --arg imageBase64 "$IMAGE_BASE64" \
    --arg imageMediaType "$MEDIA_TYPE" \
    --arg deviceId "$DEVICE_ID" \
    --arg lang "$LANG" \
    --arg source "$SALLY_SOURCE" \
    '{
      imageBase64: $imageBase64,
      imageMediaType: $imageMediaType,
      deviceId: $deviceId,
      lang: $lang,
      source: $source
    }')
else
  # URL mode
  URL="${1:?Missing URL to roast}"
  LANG=$(default_lang "${2:-}")

  BODY=$(jq -n \
    --arg url "$URL" \
    --arg deviceId "$DEVICE_ID" \
    --arg lang "$LANG" \
    --arg source "$SALLY_SOURCE" \
    '{
      url: $url,
      deviceId: $deviceId,
      lang: $lang,
      source: $source
    }')
fi

# --- Call API ---
RAW=$(sally_post "/roast" "$BODY")
RESPONSE=$(parse_response "$RAW")

# --- Output ---
# Raw JSON for agent parsing
echo "$RESPONSE"

# Formatted for chat display (on stderr so agent can choose)
format_roast "$RESPONSE" >&2
