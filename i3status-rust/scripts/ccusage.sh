#!/usr/bin/env bash
# Active ccusage block summary. Env CCUSAGE_JSON=<file> reads a file instead of running npx (tests).
set -u
err='{"icon":"ccusage","state":"Critical","text":"cc err"}'
if [ -n "${CCUSAGE_JSON:-}" ]; then
  raw=$(cat "$CCUSAGE_JSON" 2>/dev/null)
else
  [ -n "${CCUSAGE_DEBUG:-}" ] && echo "$(date +%T) run" >> "${TMPDIR:-/tmp}/ccusage-runs.log"
  raw=$(timeout 30 npx -y ccusage@20.0.51 blocks --active --token-limit max --json 2>/dev/null)
fi
out=$(printf '%s' "$raw" | jq -c '
  (first(.blocks[]? | select(.isActive and (.isGap | not))) // null) as $b
  | if $b == null or ((($b.totalTokens // 0) == 0) and (($b.projection.totalTokens // 0) == 0)) then {text: ""} else
    ($b.totalTokens // 0) as $t
    | ($b.tokenLimitStatus.limit // 0) as $lim
    | (if $lim > 0 then $t / $lim * 100 else null end) as $pct
    | ($b.tokenCounts // {}) as $tc
    | (($tc.inputTokens // 0) + ($tc.cacheCreationInputTokens // 0) + ($tc.cacheReadInputTokens // 0)) as $den
    | (if $den > 0 then ($tc.cacheReadInputTokens // 0) / $den * 100 else 0 end) as $ch
    | ($b.projection.remainingMinutes // 0) as $rem
    | def r0: (. + 0.5 | floor | tostring);
      def f1: (. * 10 + 0.5 | floor / 10 | tostring) as $s | if ($s | test("\\.")) then $s else $s + ".0" end;
      def pad($n): tostring | (($n - length) as $k | if $k > 0 then (" " * $k) + . else . end);
      { icon: "ccusage",
        state: (if $pct == null then "Good" elif $pct > 90 then "Critical" elif $pct > 70 then "Warning" else "Good" end),
        text: ([
          (if $pct == null then "    " elif $pct < 1 then (($pct | f1) + "%" | pad(4)) else (($pct | r0) + "%" | pad(4)) end),
          ((($t / 1e3 * 10 + 0.5 | floor) / 10) as $k | if $t >= 1e6 or $k >= 1000 then (($t / 1e6 | f1) | pad(5)) + "M" elif $t >= 1e3 then (($t / 1e3 | f1) | pad(5)) + "K" else (($t | floor | tostring) | pad(5)) + " " end),
          ("CH " + (($ch | r0) + "%" | pad(4))),
          (($rem | floor) as $m | (($m / 60 | floor | tostring) + "h" + (($m % 60) | tostring | pad(2) | gsub(" "; "0")) + "m"))
        ] | join(" ")) }
    end' 2>/dev/null)
if [ -n "$out" ]; then echo "$out"; else echo "$err"; fi
exit 0
