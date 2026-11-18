#!/usr/bin/env bash
# Claude usage in the real 5h rate-limit window: limit %, tokens, cost, cache ratio, time to reset.
# Window: statusline tap cache (claude-rl-tap.sh), else the gated OAuth usage endpoint; tokens/cost from the local logs.
# Env (tests): CU_NOW CU_CACHE CU_STATE_DIR CU_PROJECTS CU_CREDS CU_PRICES CU_API_FIXTURE (no curl when set).
# `--render '<json {pct,tok,cost,ch,left,stale}>'` prints the block JSON for those values.
set -u
d=$(cd "$(dirname "$0")" && pwd)
err='{"icon":"ccusage","state":"Critical","text":"cc err"}'
now=${CU_NOW:-$(date +%s)}
cache=${CU_CACHE:-$HOME/.cache/claude-usage/rate_limits.json}
sdir=${CU_STATE_DIR:-$HOME/.cache/claude-usage}
creds=${CU_CREDS:-$HOME/.claude/.credentials.json}
prices=${CU_PRICES:-$d/claude-prices.json}

render() { # stdin {pct,tok,cost,ch,left,stale} -> block JSON
  jq -c '
    def r0: (. + 0.5 | floor | tostring);
    def f1: (. * 10 + 0.5 | floor / 10 | tostring) as $s | if ($s | test("\\.")) then $s else $s + ".0" end;
    def pad($n): tostring | (($n - length) as $k | if $k > 0 then (" " * $k) + . else . end);
    def dim: "<span foreground=\"#777777\">" + . + "</span>";
    .pct as $p | .tok as $t | .cost as $c | .left as $l
    | (if $p == null or .stale then "Idle" elif $p > 90 then "Critical" elif $p > 70 then "Warning" else "Good" end) as $st
    | ((if $p == null then "?%" else ($p | r0) + "%" end) as $s | (" " * (4 - ($s | length))) + (if .stale or $p == null then ($s | dim) else $s end)) as $pt
    | { icon: "ccusage", state: $st,
        text: ([ $pt,
          ((($t / 1e3 * 10 + 0.5 | floor) / 10) as $k | if $t >= 1e6 or $k >= 1000 then (($t / 1e6 | f1) | pad(5)) + "M" elif $t >= 1e3 then (($t / 1e3 | f1) | pad(5)) + "K" else (($t | floor | tostring) | pad(5)) + " " end),
          (if $c < 9.995 then "$" + (($c * 100 + 0.5 | floor) / 100 | tostring | if test("\\.") then (split(".") | .[0] + "." + (.[1] + "0" | .[0:2])) else . + ".00" end)
           elif $c < 99.95 then "$" + ($c | f1)
           elif $c < 999.5 then ("$" + ($c | r0) | pad(5))
           elif $c < 9950 then "$" + ($c / 1000 | f1) + "k"
           else ("$" + ([$c / 1000 | floor + 0.5 | floor, 999] | min | tostring) + "k" | pad(5)) end),
          ("cache" | dim),
          (([.ch | r0 | tonumber, 99] | min | tostring) + "%" | pad(3)),
          (if $l == null then "-h--m" else ((($l / 60) | floor) as $m | (($m / 60 | floor | tostring) + "h" + (($m % 60) | tostring | pad(2) | gsub(" "; "0")) + "m")) end)
        ] | join(" ") | length as $n | sub("^ +"; "") | . + (" " * ($n - length))) }'
}

if [ "${1:-}" = --render ]; then printf '%s' "${2:-}" | render || echo "$err"; exit 0; fi
command -v jq >/dev/null || { echo "$err"; exit 0; }

tmp=$(mktemp -d) || { echo "$err"; exit 0; }
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$sdir" 2>/dev/null

# --- OAuth fallback (only when the tap cache is missing/old and the gate allows) ---
api_refresh() {
  local st ok=0 next=0 status= cm cmt exp code ra= body backoff=0 nb
  st=$(cat "$sdir/api.json" 2>/dev/null); [ -n "$st" ] || st='{}'
  jq -e . >/dev/null 2>&1 <<<"$st" || st='{}'
  next=$(jq -r '.next_at // 0' <<<"$st"); status=$(jq -r '.status // ""' <<<"$st"); cm=$(jq -r '.cred_mtime // 0' <<<"$st")
  [ -f "$creds" ] || return 0
  cmt=$(stat -c %Y "$creds" 2>/dev/null || echo 0)
  [ "$status" = stale ] && [ "$cm" = "$cmt" ] && return 0     # 401/403 until the creds file changes
  [ "$next" -gt "$now" ] && return 0
  exp=$(jq -r '.claudeAiOauth.expiresAt // 0' "$creds" 2>/dev/null)
  if [ "${exp:-0}" -lt "$((now * 1000))" ] 2>/dev/null; then   # Claude Code refreshes it on next use
    jq -c --argjson c "$cmt" '.status = "stale" | .cred_mtime = $c' <<<"$st" >"$tmp/st" && mv "$tmp/st" "$sdir/api.json"; return 0
  fi
  exec 9>"$sdir/lock"; flock -n 9 || return 0
  if [ -n "${CU_API_FIXTURE:-}" ]; then
    code=$(head -1 "$CU_API_FIXTURE"); ra=$(grep -im1 '^retry-after:' "$CU_API_FIXTURE" | tr -dc '0-9')
    sed '1,/^$/d' "$CU_API_FIXTURE" >"$tmp/body"
  else
    local tok; tok=$(jq -r '.claudeAiOauth.accessToken // empty' "$creds" 2>/dev/null); [ -n "$tok" ] || return 0
    code=$(printf 'Authorization: Bearer %s\nanthropic-beta: oauth-2025-04-20\n' "$tok" | timeout 8 curl -s --max-time 5 -o "$tmp/body" -w '%{http_code}' -D "$tmp/hdrs" -H @- https://api.anthropic.com/api/oauth/usage 2>/dev/null)
    ra=$(grep -im1 '^retry-after:' "$tmp/hdrs" 2>/dev/null | tr -dc '0-9'); tok=
  fi
  case $code in
    200) jq -c --argjson now "$now" --argjson st "$st" '
           ((.five_hour.resets_at // null) | if . == null then null else (sub("\\.[0-9]+"; "") | sub("\\+00:00$"; "Z") | fromdateiso8601) end) as $r
           | $st + {ts_ok: $now, next_at: ($now + 180), backoff: 0, status: "ok",
                    five_hour: {pct: .five_hour.utilization, resets_at: $r}}' "$tmp/body" >"$tmp/st" 2>/dev/null && mv "$tmp/st" "$sdir/api.json" ;;
    429) backoff=$(jq -r '.backoff // 0' <<<"$st"); nb=$((backoff * 2)); [ "$nb" -gt 0 ] || nb=360
         [ "${ra:-0}" -gt "$nb" ] && nb=$ra; [ "$nb" -gt 1800 ] && nb=1800
         jq -c --argjson b "$nb" --argjson n "$((now + nb))" '.backoff = $b | .next_at = $n' <<<"$st" >"$tmp/st" && mv "$tmp/st" "$sdir/api.json" ;;
    401|403) jq -c --argjson c "$cmt" '.status = "stale" | .cred_mtime = $c' <<<"$st" >"$tmp/st" && mv "$tmp/st" "$sdir/api.json" ;;
    *) jq -c --argjson n "$((now + 300))" '.next_at = $n' <<<"$st" >"$tmp/st" && mv "$tmp/st" "$sdir/api.json" ;;
  esac
}

tap_ts=$(jq -r '.ts // 0' "$cache" 2>/dev/null); tap_ts=${tap_ts:-0}
if [ "$((now - ${tap_ts%.*}))" -gt 300 ]; then api_refresh 2>/dev/null; fi

# --- pick the window: newer of tap cache and API data ---
sel=$(jq -nc --argjson now "$now" --slurpfile t <(cat "$cache" 2>/dev/null; true) --slurpfile a <(cat "$sdir/api.json" 2>/dev/null; true) '
  ($t[0] // {}) as $t | ($a[0] // {}) as $a
  | [ (if $t.five_hour != null and $t.ts != null then {ts: $t.ts, pct: $t.five_hour.pct, resets: $t.five_hour.resets_at, api: false} else empty end),
      (if ($a.ts_ok // null) != null and $a.five_hour != null then {ts: $a.ts_ok, pct: $a.five_hour.pct, resets: $a.five_hour.resets_at, api: true} else empty end) ]
  | sort_by(.ts) | last as $s
  | if $s == null then {none: true}
    else {none: false, pct: $s.pct, resets: $s.resets, age: ($now - $s.ts),
          astale: (($a.status // "") == "stale")} end' 2>/dev/null) || { echo "$err"; exit 0; }

none=$(jq -r .none <<<"$sel")
if [ "$none" = true ]; then
  start=$((now - 18000)); end=$((now + 1)); pct=null; left=null; stale=true
else
  resets=$(jq -r '.resets // 0' <<<"$sel"); resets=${resets%.*}
  if [ "$resets" -le "$now" ]; then echo '{"text":""}'; exit 0; fi
  start=$((resets - 18000)); end=$resets; pct=$(jq -c .pct <<<"$sel"); left=$((resets - now))
  stale=$(jq -r '(.age > 900) or (.astale and .age > 300)' <<<"$sel")
fi
siso=$(date -u -d "@$start" +%FT%T.000Z); eiso=$(date -u -d "@$end" +%FT%T.000Z)

# --- tokens, cost, cache ratio from the local logs ---
dirs=()
if [ -n "${CU_PROJECTS:-}" ]; then dirs=("$CU_PROJECTS"); else
  for p in "$HOME/.config/claude/projects" "$HOME/.claude/projects"; do [ -d "$p" ] && dirs+=("$p"); done; fi
sums='{"tok":0,"cost":0,"ch":0}'
if [ ${#dirs[@]} -gt 0 ]; then
  sums=$(timeout 10 find "${dirs[@]}" -name '*.jsonl' -newermt "@$start" -print0 2>/dev/null | xargs -0 -r grep -h '"usage"' 2>/dev/null \
    | jq -nR --arg s "$siso" --arg e "$eiso" --slurpfile P "$prices" '
      $P[0] as $P
      | def rate($m; $prompt):
          (($P.models | to_entries | map(. as $e | select($m | startswith($e.key))) | sort_by(.key | length) | last | .value) // $P.default) as $r
          | if $r.big != null and $prompt > 100000 then $r.big else $r end;
      [inputs | fromjson? | select(type == "object" and .type == "assistant" and (.message.usage? != null) and .message.model != "<synthetic>"
                                   and (.timestamp // "") >= $s and (.timestamp // "") < $e)] as $all
      | ([$all[] | select(.message.id != null and .requestId != null)] | unique_by(.message.id + ":" + .requestId)) + [$all[] | select((.message.id != null and .requestId != null) | not)]
      | map(.message as $m | $m.usage as $u
            | ($u.input_tokens // 0) as $in | ($u.output_tokens // 0) as $o | ($u.cache_creation_input_tokens // 0) as $cc | ($u.cache_read_input_tokens // 0) as $cr
            | (if $u.cache_creation != null then [($u.cache_creation.ephemeral_5m_input_tokens // 0), ($u.cache_creation.ephemeral_1h_input_tokens // 0)] else [$cc, 0] end) as $w
            | rate($m.model // ""; $in + $cc + $cr) as $r
            | {tok: ($in + $o + $cc + $cr), den: ($in + $cc + $cr), cr: $cr,
               cost: (($in * $r.in + $w[0] * $r.w5 + $w[1] * $r.w1 + $cr * $r.r + $o * $r.out) / 1e6 * (if $u.inference_geo == "us" then 1.1 else 1 end))})
      | {tok: (map(.tok) | add // 0), cost: (map(.cost) | add // 0), den: (map(.den) | add // 0), cr: (map(.cr) | add // 0)}
      | {tok, cost, ch: (if .den > 0 then .cr / .den * 100 else 0 end)}' 2>/dev/null) || sums=
fi
[ -n "$sums" ] || { echo "$err"; exit 0; }

jq -c --argjson p "$pct" --argjson l "$left" --argjson st "$stale" '. + {pct: $p, left: $l, stale: $st}' <<<"$sums" | render || echo "$err"
exit 0
