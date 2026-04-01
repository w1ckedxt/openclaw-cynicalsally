#!/usr/bin/env bash
# Login — link OpenClaw device to SuperClub account via magic link.
# Usage: bash scripts/login.sh "<email>"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

require_device_id
require_command curl
require_command jq

# --- Parse args ---
EMAIL="${1:?Missing email address}"

# --- Basic email validation ---
if ! echo "$EMAIL" | grep -qE '^[^@]+@[^@]+\.[^@]+$'; then
  echo '{"error": "Invalid email format."}' >&2
  exit 1
fi

# --- Request magic link ---
BODY=$(jq -n \
  --arg email "$EMAIL" \
  --arg deviceId "$DEVICE_ID" \
  '{
    email: $email,
    deviceId: $deviceId
  }')

RAW=$(sally_post "/auth/magic-link" "$BODY")
RESPONSE=$(parse_response "$RAW")

# --- Output JSON for machine consumption ---
echo "$RESPONSE"

# --- User-friendly output ---
SENT=$(echo "$RESPONSE" | jq -r '.sent // false')
if [[ "$SENT" == "true" ]]; then
  echo "" >&2
  echo "Magic link sent to ${EMAIL}." >&2
  echo "" >&2
  echo "Next steps:" >&2
  echo "  1. Check your email (and spam folder) for the login link" >&2
  echo "  2. Click the link — it opens in your browser, that's normal" >&2
  echo "  3. Come back here and say: sally status" >&2
  echo "     This confirms your device is linked to SuperClub" >&2
  echo "" >&2
  echo "After linking: unlimited chat, full memory, Sally remembers everything." >&2
else
  ERROR=$(echo "$RESPONSE" | jq -r '.error // .message // "Unknown error"')
  echo "" >&2
  echo "Could not send magic link: ${ERROR}" >&2
  echo "" >&2
  echo "Troubleshooting:" >&2
  echo "  - Double-check your email address" >&2
  echo "  - Make sure it's the email you used for SuperClub" >&2
  echo "  - Don't have SuperClub? Get it at https://cynicalsally.com/superclub" >&2
fi
