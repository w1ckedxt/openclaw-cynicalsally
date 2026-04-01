#!/usr/bin/env bash
# Quick Roast — roast a URL, image, document, or PDF via Sally API.
# Usage:
#   bash scripts/roast.sh <url> [lang]
#   bash scripts/roast.sh --image <base64> <media_type> [lang]
#   bash scripts/roast.sh --document <text> [lang]
#   bash scripts/roast.sh --pdf <base64> [lang]

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

elif [[ "${1:-}" == "--document" ]]; then
  # Document mode (plain text content)
  DOC_TEXT="${2:?Missing document text}"
  LANG=$(default_lang "${3:-}")

  BODY=$(jq -n \
    --arg documentText "$DOC_TEXT" \
    --arg deviceId "$DEVICE_ID" \
    --arg lang "$LANG" \
    --arg source "$SALLY_SOURCE" \
    '{
      documentText: $documentText,
      deviceId: $deviceId,
      lang: $lang,
      source: $source
    }')

elif [[ "${1:-}" == "--pdf" ]]; then
  # PDF mode (base64 encoded PDF, server extracts text)
  PDF_BASE64="${2:?Missing PDF base64 data}"
  LANG=$(default_lang "${3:-}")

  BODY=$(jq -n \
    --arg documentBase64 "$PDF_BASE64" \
    --arg documentMediaType "application/pdf" \
    --arg deviceId "$DEVICE_ID" \
    --arg lang "$LANG" \
    --arg source "$SALLY_SOURCE" \
    '{
      documentBase64: $documentBase64,
      documentMediaType: $documentMediaType,
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

# --- Call API (handle 429 quota exhausted gracefully) ---
RAW=$(sally_post "/roast" "$BODY")

HTTP_CODE=$(echo "$RAW" | tail -1)
RESPONSE=$(echo "$RAW" | sed '$d')

# Quota exhausted: show upgrade/login hints instead of crashing
if [[ "$HTTP_CODE" == "429" ]]; then
  echo "$RESPONSE"
  echo "You've used all your free roasts today." >&2
  echo "" >&2
  echo "Already have SuperClub? Link your account:" >&2
  echo "  sally login your@email.com" >&2
  echo "" >&2
  echo "Don't have SuperClub? Get unlimited roasts:" >&2
  echo "  https://cynicalsally.com/superclub" >&2
  exit 0
fi

# Other errors: fail normally
if [[ "$HTTP_CODE" -ge 400 ]]; then
  echo "{\"error\": \"HTTP $HTTP_CODE\", \"details\": $RESPONSE}" >&2
  exit 1
fi

# --- Success output ---
# Raw JSON for agent parsing
echo "$RESPONSE"

# Formatted for chat display (on stderr so agent can choose)
format_roast "$RESPONSE" >&2
