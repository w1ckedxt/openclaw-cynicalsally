#!/usr/bin/env bash
# Response formatting for messaging platforms.
# Converts Sally JSON responses to human-readable chat output.
# Source this file: source "$(dirname "$0")/lib/format.sh"

format_roast() {
  local json="$1"

  local score messages bright_side burns suggest_ftt quota_remaining quota_limit

  score=$(echo "$json" | jq -r '.scorecard // "?"')
  bright_side=$(echo "$json" | jq -r '.bright_side // empty')
  suggest_ftt=$(echo "$json" | jq -r '.suggest_ftt // false')
  quota_remaining=$(echo "$json" | jq -r 'if .quota then (.quota.remaining | tostring) else null end')
  quota_limit=$(echo "$json" | jq -r 'if .quota then (.quota.limit | tostring) else null end')

  # Score header
  echo "SALLY'S VERDICT: ${score}/100"
  echo ""

  # Messages (intro, observations, final)
  echo "$json" | jq -r '.messages[]? | .text' | while IFS= read -r line; do
    echo "$line"
    echo ""
  done

  # Bright side
  if [[ -n "$bright_side" ]]; then
    echo "Silver lining: ${bright_side}"
    echo ""
  fi

  # Burn options with card URLs
  local burn_count
  burn_count=$(echo "$json" | jq '.burn_options // [] | length')
  if [[ "$burn_count" -gt 0 ]]; then
    echo "Shareable burns:"
    echo "$json" | jq -r '.burn_options[]? | "- [\(.tone)] \(.text)\(if .cardUrl then "\n  Card: \(.cardUrl)" else "" end)"'
    echo ""
  fi

  # Quota
  if [[ -n "$quota_remaining" && "$quota_remaining" != "null" ]]; then
    if [[ "$quota_remaining" == "0" ]]; then
      echo "That was your last free roast today."
      echo "Already have SuperClub? Say: sally login your@email.com"
      echo "Or upgrade: https://cynicalsally.com/superclub"
    elif [[ "$quota_remaining" -le 1 ]]; then
      echo "Roasts remaining: ${quota_remaining}/${quota_limit}"
      echo "Tip: SuperClub members get unlimited roasts. Say: sally login your@email.com"
    else
      echo "Roasts remaining: ${quota_remaining}/${quota_limit}"
    fi
  fi

  # Suggest full truth
  if [[ "$suggest_ftt" == "true" ]]; then
    echo "Want the full truth? Say: sally truth <url>"
  fi
}

format_review() {
  local json="$1"

  local score mode files_reviewed quota_remaining quota_limit

  score=$(echo "$json" | jq -r '.data.score // "?"')
  mode=$(echo "$json" | jq -r '.meta.mode // "quick"')
  files_reviewed=$(echo "$json" | jq -r '.meta.files_reviewed // 0')
  quota_remaining=$(echo "$json" | jq -r '.quota.remaining // "?"')
  quota_limit=$(echo "$json" | jq -r '.quota.limit // "?"')

  # Header
  echo "SALLY'S CODE REVIEW: ${score}/100 (${mode}, ${files_reviewed} files)"
  echo ""

  # Voice summary
  local roast_voice
  roast_voice=$(echo "$json" | jq -r '.voice.roast // empty')
  if [[ -n "$roast_voice" ]]; then
    echo "$roast_voice"
    echo ""
  fi

  # Messages
  echo "$json" | jq -r '.data.messages[]? | "[\(.type)] \(.text)"' | while IFS= read -r line; do
    echo "$line"
    echo ""
  done

  # Bright side
  local bright
  bright=$(echo "$json" | jq -r '.voice.bright_side // empty')
  if [[ -n "$bright" ]]; then
    echo "Silver lining: ${bright}"
    echo ""
  fi

  # Actionable fixes (full truth only)
  local fixes_count
  fixes_count=$(echo "$json" | jq '.data.actionable_fixes // [] | length')
  if [[ "$fixes_count" -gt 0 ]]; then
    echo "Fix these:"
    echo "$json" | jq -r '.data.actionable_fixes[]? | "- \(.)"'
    echo ""
  fi

  # Quota
  echo "Reviews remaining: ${quota_remaining}/${quota_limit}"
}

format_truth() {
  local json="$1"

  local score summary

  score=$(echo "$json" | jq -r '.report.scorecard // "?"')
  summary=$(echo "$json" | jq -r '.report.executive_summary // empty')

  # Header
  echo "SALLY'S FULL TRUTH: ${score}/100"
  echo ""

  # Executive summary
  if [[ -n "$summary" ]]; then
    echo "$summary"
    echo ""
  fi

  # Score breakdown
  local breakdown_count
  breakdown_count=$(echo "$json" | jq '.report.score_breakdown // [] | length')
  if [[ "$breakdown_count" -gt 0 ]]; then
    echo "Breakdown:"
    echo "$json" | jq -r '.report.score_breakdown[]? | "  \(.category): \(.score)/100 - \(.summary)"'
    echo ""
  fi

  # Top issues
  local issues_count
  issues_count=$(echo "$json" | jq '.report.top_issues // [] | length')
  if [[ "$issues_count" -gt 0 ]]; then
    echo "Top issues:"
    echo "$json" | jq -r '.report.top_issues[]? | "  [\(.severity)] \(.title): \(.description)"'
    echo ""
  fi

  # Roadmap
  local roadmap_count
  roadmap_count=$(echo "$json" | jq '.report.roadmap // [] | length')
  if [[ "$roadmap_count" -gt 0 ]]; then
    echo "Roadmap:"
    echo "$json" | jq -r '.report.roadmap[]? | "  [\(.priority)] \(.action) (impact: \(.impact), effort: \(.effort))"'
    echo ""
  fi

  # Bright side
  local bright
  bright=$(echo "$json" | jq -r '.report.bright_side // empty')
  if [[ -n "$bright" ]]; then
    echo "Silver lining: ${bright}"
    echo ""
  fi

  # Hardest sneer
  local sneer
  sneer=$(echo "$json" | jq -r '.report.hardest_sneer // empty')
  if [[ -n "$sneer" ]]; then
    echo "Hardest sneer: ${sneer}"
  fi
}

format_status() {
  local json="$1"

  local is_sc tier email qr_remaining

  is_sc=$(echo "$json" | jq -r '.isSuperClub // false')
  tier=$(echo "$json" | jq -r 'if .isSuperClub then "SuperClub" else "free" end')
  email=$(echo "$json" | jq -r '.email // empty')
  qr_remaining=$(echo "$json" | jq -r '.quotaRemaining // 0')

  echo "Sally Account Status"
  echo "===================="

  if [[ "$is_sc" == "true" ]]; then
    echo "Tier: SuperClub"
    if [[ -n "$email" ]]; then
      echo "Linked to: ${email}"
    fi
    echo "Quick Roasts: unlimited"
    echo "Chat: unlimited"
    echo "Memory: full (Sally remembers everything)"
  else
    echo "Tier: Free"
    echo "Quick Roasts: ${qr_remaining}/3 remaining today"
    echo "Chat: 10 messages/day"
    echo "Memory: basics only (name, age, location)"

    if [[ -n "$email" ]]; then
      echo ""
      echo "Device linked to: ${email}"
      echo "But no active SuperClub subscription found."
      echo "Subscribe: https://cynicalsally.com/superclub"
    else
      echo ""
      echo "Already have SuperClub? Link your account:"
      echo "  sally login your@email.com"
      echo ""
      echo "Don't have SuperClub? Get unlimited everything:"
      echo "  https://cynicalsally.com/superclub"
    fi
  fi
}

format_chat() {
  local json="$1"

  local reply quota_remaining quota_limit error_code

  reply=$(echo "$json" | jq -r '.reply // empty')
  error_code=$(echo "$json" | jq -r '.code // empty')
  quota_remaining=$(echo "$json" | jq -r 'if .quota then (.quota.remaining | tostring) else null end')
  quota_limit=$(echo "$json" | jq -r 'if .quota then (.quota.limit | tostring) else null end')

  # Quota exhausted (429 response parsed by chat.sh)
  if [[ "$error_code" == "chat_quota_exhausted" ]]; then
    echo "You've hit your daily chat limit (${quota_limit} messages)."
    echo ""
    echo "Already have SuperClub? Link your account:"
    echo "  sally login your@email.com"
    echo ""
    echo "Don't have SuperClub yet? Get unlimited chat:"
    echo "  https://cynicalsally.com/superclub"
    return
  fi

  if [[ -n "$reply" ]]; then
    echo "$reply"
  fi

  if [[ -n "$quota_remaining" && "$quota_remaining" != "null" ]]; then
    echo ""
    if [[ "$quota_remaining" == "0" ]]; then
      echo "That was your last free message today."
      echo "Already have SuperClub? Say: sally login your@email.com"
      echo "Or upgrade: https://cynicalsally.com/superclub"
    elif [[ "$quota_remaining" -le 3 ]]; then
      echo "Chat: ${quota_remaining}/${quota_limit} remaining today"
      echo "Tip: SuperClub members get unlimited chat. Say: sally login your@email.com"
    else
      echo "Chat: ${quota_remaining}/${quota_limit} remaining today"
    fi
  fi
}
