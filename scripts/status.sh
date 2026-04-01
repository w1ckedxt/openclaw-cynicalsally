#!/usr/bin/env bash
# Status — check Sally quota and account tier.
# Usage: bash scripts/status.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/format.sh"

require_device_id
require_command curl
require_command jq

# --- Call API ---
RAW=$(sally_get "/entitlements?deviceId=${DEVICE_ID}")
RESPONSE=$(parse_response "$RAW")

# --- Output ---
echo "$RESPONSE"
format_status "$RESPONSE" >&2
