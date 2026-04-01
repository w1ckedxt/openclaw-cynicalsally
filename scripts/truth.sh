#!/usr/bin/env bash
# Full Truth — deep analysis via Sally API (async with polling).
# Usage:
#   bash scripts/truth.sh <url> [lang]
#   bash scripts/truth.sh --document <text> [lang]
#   bash scripts/truth.sh --pdf <base64> [lang]
# Polls until result is ready (typically 10-30 seconds).

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/format.sh"

require_device_id
require_command curl
require_command jq

POLL_INTERVAL=3
MAX_POLLS=40  # 3s * 40 = 2 min max

# --- Parse args ---
if [[ "${1:-}" == "--document" ]]; then
  # Document text mode
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
  # PDF base64 mode
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
  URL="${1:?Missing URL for Full Truth analysis}"
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

# --- Enqueue job (handle 429 quota exhausted gracefully) ---
RAW=$(sally_post "/truth" "$BODY")

HTTP_CODE=$(echo "$RAW" | tail -1)
ENQUEUE_RESPONSE=$(echo "$RAW" | sed '$d')

# Quota exhausted at enqueue time
if [[ "$HTTP_CODE" == "429" ]]; then
  echo "$ENQUEUE_RESPONSE"
  echo "You've used all your free Full Truth analyses." >&2
  echo "" >&2
  echo "Already have SuperClub? Link your account:" >&2
  echo "  sally login your@email.com" >&2
  echo "" >&2
  echo "Don't have SuperClub? Get unlimited analyses:" >&2
  echo "  https://cynicalsally.com/superclub" >&2
  exit 0
fi

# Other enqueue errors
if [[ "$HTTP_CODE" -ge 400 ]]; then
  echo "{\"error\": \"HTTP $HTTP_CODE\", \"details\": $ENQUEUE_RESPONSE}" >&2
  exit 1
fi

JOB_ID=$(echo "$ENQUEUE_RESPONSE" | jq -r '.jobId // empty')
if [[ -z "$JOB_ID" ]]; then
  echo "$ENQUEUE_RESPONSE"
  exit 1
fi

echo "Job queued: ${JOB_ID}" >&2
echo "Waiting for Sally's full analysis..." >&2

# --- Poll for result ---
POLLS=0
while [[ $POLLS -lt $MAX_POLLS ]]; do
  sleep "$POLL_INTERVAL"
  POLLS=$((POLLS + 1))

  RAW=$(sally_get "/truth/${JOB_ID}/status?deviceId=${DEVICE_ID}")
  STATUS_RESPONSE=$(parse_response "$RAW")

  STATUS=$(echo "$STATUS_RESPONSE" | jq -r '.status // "unknown"')

  case "$STATUS" in
    complete)
      echo "$STATUS_RESPONSE"
      format_truth "$STATUS_RESPONSE" >&2
      exit 0
      ;;
    error)
      echo "$STATUS_RESPONSE" >&2
      exit 1
      ;;
    queued|processing)
      echo "Still working... (${POLLS}/${MAX_POLLS})" >&2
      ;;
    *)
      echo "{\"error\": \"Unknown status: ${STATUS}\"}" >&2
      exit 1
      ;;
  esac
done

echo '{"error": "Timed out waiting for Full Truth result. Try again later."}' >&2
exit 1
