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
  quota_remaining=$(echo "$json" | jq -r '.quota.remaining // "?"')
  quota_limit=$(echo "$json" | jq -r '.quota.limit // "?"')

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

  # Burn options
  local burn_count
  burn_count=$(echo "$json" | jq '.burn_options | length')
  if [[ "$burn_count" -gt 0 ]]; then
    echo "Shareable burns:"
    echo "$json" | jq -r '.burn_options[]? | "- [\(.tone)] \(.text)"'
    echo ""
  fi

  # Quota
  echo "Roasts remaining: ${quota_remaining}/${quota_limit}"

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

  local tier qr_remaining qr_limit

  tier=$(echo "$json" | jq -r '.tier // "free"')
  qr_remaining=$(echo "$json" | jq -r '.quota.qr.remaining // "?"')
  qr_limit=$(echo "$json" | jq -r '.quota.qr.limit // "?"')

  echo "Sally Account Status"
  echo "Tier: ${tier}"
  echo "Quick Roasts: ${qr_remaining}/${qr_limit} remaining today"

  if [[ "$tier" == "free" ]]; then
    echo ""
    echo "Upgrade to SuperClub for unlimited roasts: https://cynicalsally.com/superclub"
  fi
}
