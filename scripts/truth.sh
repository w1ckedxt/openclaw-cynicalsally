#!/usr/bin/env bash
# Full Truth — deep analysis via Sally API (async with polling).
# Usage: bash scripts/truth.sh <url> [lang]
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
URL="${1:?Missing URL for Full Truth analysis}"
LANG=$(default_lang "${2:-}")

# --- Enqueue job ---
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

RAW=$(sally_post "/truth" "$BODY")
ENQUEUE_RESPONSE=$(parse_response "$RAW")

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
