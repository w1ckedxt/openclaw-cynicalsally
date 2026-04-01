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

# --- Output ---
echo "$RESPONSE"

# User-friendly message
SENT=$(echo "$RESPONSE" | jq -r '.sent // false')
if [[ "$SENT" == "true" ]]; then
  echo "" >&2
  echo "Check your email for the login link." >&2
  echo "Once you click it, this device will be linked to your SuperClub account." >&2
  echo "Sally will remember everything from then on." >&2
fi
