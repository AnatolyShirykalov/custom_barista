#!/usr/bin/env bash
# Claude Code statusline tap: reads the statusline JSON on stdin and stores its rate_limits for claude-usage.sh.
# Prints nothing (the statusline shows stdout) and always exits 0. Env CU_CACHE overrides the cache file.
cache=${CU_CACHE:-$HOME/.cache/claude-usage/rate_limits.json}
{
  in=$(cat)
  out=$(jq -c --argjson now "${CU_NOW:-$(date +%s)}" 'select(.rate_limits.five_hour != null) | .rate_limits as $r
    | def w: if . == null then null else {pct: .used_percentage, resets_at: .resets_at} end;
      {ts: $now, five_hour: ($r.five_hour | w), seven_day: ($r.seven_day | w)}' <<<"$in") || out=
  if [ -n "$out" ]; then
    mkdir -p "$(dirname "$cache")" && tmp=$(mktemp "$cache.XXXXXX") && printf '%s\n' "$out" >"$tmp" && mv "$tmp" "$cache"
  fi
} >/dev/null 2>&1
exit 0
