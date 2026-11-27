#!/usr/bin/env bash
# GitLab runner queue block (this user's runner): "running/concurrent  +pending", json for i3status-rs custom block.
# Modes: (none) bar json | refresh (API fetch, detached by the bar run) | refresh-now (left click) | list (hover text) | open (right click)
# Running: own `journalctl --user` builds=N (no metrics port: any local user could read it). Pending: GitLab API, cached; see docs/design/G1-runner-queue/spec.md
# Test overrides: RUNNER_CONFIG UNIT_STATE JOURNAL_FILE QUEUE_CACHE TOKEN_FILE PROJECTS_FILE NOW NO_REFRESH API_DIR LIST_MAX OPEN_CMD
set -u
CFG=${RUNNER_CONFIG:-$HOME/.gitlab-runner/config.toml}
TOKEN_FILE=${TOKEN_FILE:-$HOME/.config/custom_barista/gitlab-token}
PROJECTS_FILE=${PROJECTS_FILE:-$HOME/.config/custom_barista/runner-projects}
CACHE=${QUEUE_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/custom_barista/runner-queue.json}
LOCK=${CACHE%.json}.lock
NOW=${NOW:-$(date +%s)}
LIST_MAX=${LIST_MAX:-8}
TTL=60; TTL_AUTH=600; STALE=300; STUCK=900
DIM='#777777'
SELF=$(readlink -f "$0")
mode=${1:-}

spawn() { # detached refresh; the lock lives in the cache dir, so create it first; timeout covers 10 projects x --max-time 4
  mkdir -p "$(dirname "$CACHE")" 2>/dev/null && chmod 700 "$(dirname "$CACHE")" 2>/dev/null
  setsid -f flock -n "$LOCK" timeout 60 "$SELF" refresh >/dev/null 2>&1; }
strip() { sed 's/\x1b\[[0-9;]*m//g'; }
journal() { # args for journalctl; JOURNAL_FILE replaces both reads
  if [ -n "${JOURNAL_FILE:-}" ]; then cat "$JOURNAL_FILE" 2>/dev/null; else timeout 3 journalctl --user -u gitlab-runner -o cat "$@" 2>/dev/null; fi | strip; }
top() { awk '/^[ \t]*\[/ { exit } { print }' "$CFG"; }
first_runner() { # value of key $1 in the first [[runners]] table
  awk -v k="$1" '/^[ \t]*\[\[runners\]\]/ { in_r = 1; next } in_r && /^[ \t]*\[/ { exit }
    in_r { split($0, a, "="); gsub(/[ \t"]/, "", a[1]); if (a[1] == k) { v = substr($0, index($0, "=") + 1); gsub(/^[ \t]*"?|"?[ \t]*$/, "", v); print v; exit } }' "$CFG"; }
tokmode() { stat -c %a "$TOKEN_FILE" 2>/dev/null; }
mode_ok() { local m; m=$(tokmode); [[ $m =~ ^[0-7]+$ ]] && (( (8#$m & 077) == 0 )); }
unit_state() { echo "${UNIT_STATE:-$(timeout 2 systemctl --user is-active gitlab-runner 2>/dev/null)}"; }
net_down() { journal --since -30s | grep -q 'Checking for jobs\.\.\. failed'; }

# "r c src" from the journal (builds=N) and config (concurrent)
counts() {
  local r c
  r=$(journal -n 200 | grep -o '\(^\|[ ]\)builds=[0-9]*' | tail -1 | grep -o '[0-9]*$')
  c=$(top | awk -F= '$1 ~ /^[ \t]*concurrent[ \t]*$/ { gsub(/[ \t"]/, "", $2); print $2; exit }')
  [[ ${r:-} =~ ^[0-9]+$ ]] || r=0; [[ ${c:-} =~ ^[0-9]+$ ]] || c='?'
  echo "$r $c journal"
}

fmt_age() { # seconds -> 12s 4m 3h 2d
  local s=$1; [ "$s" -lt 0 ] && s=0
  if [ "$s" -lt 60 ]; then echo "${s}s"; elif [ "$s" -lt 3600 ]; then echo "$((s / 60))m"; elif [ "$s" -lt 86400 ]; then echo "$((s / 3600))h"; else echo "$((s / 86400))d"; fi; }

bar() {
  local r c src st
  [ -r "$CFG" ] || { echo '{"text":""}'; return; }
  emit() { jq -nc --arg t "$1" --arg s "$2" '{icon:"gitlab",state:$s,text:$t}'; }
  read -r r c src < <(counts)
  local w=$(( ${#c} * 2 + 1 )) slotted=1
  [ -e "$TOKEN_FILE" ] || [ -e "$PROJECTS_FILE" ] || slotted=
  [ -n "$slotted" ] && w=$((w + 4))
  pad() { printf '%-*s' "$w" "$1"; }
  st=$(unit_state)
  [ "$st" = failed ] && { emit "$(pad ERR)" Critical; return; }
  [ "$st" = active ] || { emit "$(pad off)" Info; return; }
  local rr; rr=$(printf '%*s' "${#c}" "$r")
  net_down && { emit "$(pad "$rr/$c net")" Warning; return; }
  # pending slot: p count, oldest created, dim "?" when unknown
  local p=0 oldest=0 unknown='' err ts ts_ok
  if [ -n "$slotted" ]; then
    if [ -e "$TOKEN_FILE" ] && [ -e "$PROJECTS_FILE" ] && mode_ok; then
      local row; row=$(jq -r '[(.err // "-"), (.ts // 0), (.ts_ok // 0), ([.pending[]?] | length), (([.pending[]?.created] | min) // 0)] | @tsv' "$CACHE" 2>/dev/null)
      if [ -n "$row" ]; then
        read -r err ts ts_ok p oldest <<<"$row"
        case $err in auth|mode|cfg) unknown=1 ;; esac
        [ $((NOW - ts_ok)) -gt $STALE ] && unknown=1
        local ttl=$TTL; [ "$err" = auth ] && ttl=$TTL_AUTH
        [ -z "${NO_REFRESH:-}" ] && [ $((NOW - ts)) -ge $ttl ] && spawn
      else
        unknown=1
        [ -z "${NO_REFRESH:-}" ] && spawn
      fi
    else unknown=1; fi
    [ -n "$unknown" ] && { p=0; oldest=0; }
  fi
  local slot=
  if [ -n "$slotted" ]; then
    if [ -n "$unknown" ]; then slot="  <span foreground=\"$DIM\">+?</span>"
    else [ "$p" -gt 99 ] && p=99; slot=" $(printf '%3s' "+$p")"; fi
  fi
  local text="$rr/$c$slot"
  local state=Info
  if [ "$p" -gt 0 ] && [ $((NOW - oldest)) -ge $STUCK ]; then state=Critical
  elif [ "$p" -gt 0 ]; then state=Warning
  elif [ "$r" -gt 0 ]; then state=Good; fi
  # idle rule (Q1): option A shows the dim block; B: echo '{"text":""}'; return   C: text=""
  emit "$text" "$state"
}

cache_age() { local t; t=$(jq -r '.ts // 0' "$CACHE" 2>/dev/null); echo $((NOW - ${t:-0})); }


# GitLab API fetch into the cache; one call per listed project, token via stdin (never in argv)
refresh() {
  [ -r "$CFG" ] && [ -r "$TOKEN_FILE" ] && [ -r "$PROJECTS_FILE" ] && mode_ok || return 0
  umask 077
  local base rid tok prev ids ignored id key n=0 code auth='' neterr=''
  base=$(first_runner url); rid=$(first_runner id)
  tok=$(head -n1 "$TOKEN_FILE" | tr -d '[:space:]')
  mkdir -p "$(dirname "$CACHE")"; td=$(mktemp -d -p "$(dirname "$CACHE")"); trap 'rm -rf "$td"' EXIT
  prev=$(jq -c . "$CACHE" 2>/dev/null) || prev=; [ -n "$prev" ] || prev='{"ts_ok":0,"pending":[],"running":[]}'
  ids=$(sed 's/#.*//; s/[[:space:]]//g; /^$/d' "$PROJECTS_FILE")
  ignored=$(( $(wc -l <<<"$ids") - 10 )); [ "$ignored" -gt 0 ] || ignored=0
  write() { # err
    jq -nc --argjson now "$NOW" --argjson prev "$prev" --arg err "$1" --argjson ign "$ignored" --slurpfile new <(cat "$td"/p*.json 2>/dev/null | jq -s '{pending: ([.[].pending[]]), running: ([.[].running[]])}') '
      ($new[0] // {pending: [], running: []}) as $n
      | if $err == "" then {ts: $now, ts_ok: $now, err: null, pending: $n.pending, running: $n.running, ignored: $ign}
        else {ts: $now, ts_ok: ($prev.ts_ok // 0), err: $err, pending: ($prev.pending // []), running: ($prev.running // []), ignored: $ign} end' >"$td/out" && mv "$td/out" "$CACHE"; }
  if net_down; then write net; return 0; fi
  while read -r id; do
    [ -n "$id" ] || continue
    n=$((n + 1)); [ "$n" -gt 10 ] && break
    key=${id//\//_}
    if [ -n "${API_DIR:-}" ]; then
      code=$(cat "$API_DIR/$key.status" 2>/dev/null); cp "$API_DIR/$key.json" "$td/body" 2>/dev/null
    else
      [[ $id =~ ^[0-9]+$ ]] || id=${id//\//%2F}
      code=$(printf 'PRIVATE-TOKEN: %s\n' "$tok" | timeout 6 curl -sg --max-time 4 -o "$td/body" -w '%{http_code}' -H @- "$base/api/v4/projects/$id/jobs?scope[]=pending&scope[]=running&per_page=50" 2>/dev/null)
    fi
    case $code in
      200) jq -c --argjson rid "${rid:-0}" '
             def proj: (.web_url | sub("^https?://[^/]+/"; "") | sub("/-/jobs/[0-9]+$"; ""));
             def j: {project: proj, ref: .ref, name: .name, created: ((.created_at | sub("\\.[0-9]+"; "") | fromdateiso8601?) // 0), url: .web_url};
             {pending: [.[] | select(.status == "pending") | j], running: [.[] | select(.status == "running" and .runner.id == $rid) | j]}' "$td/body" >"$td/p$n.json" 2>/dev/null || neterr=1 ;;
      401|403) auth=1; break ;;
      404) ;;
      *) neterr=1; break ;;
    esac
  done <<<"$ids"
  if [ -n "$auth" ]; then write auth; elif [ -n "$neterr" ]; then write net; else write ""; fi
}

# hover text: running and pending rows (headers count towards LIST_MAX)
list() {
  local st; st=$(unit_state)
  [ "$st" = active ] || { echo "runner unit: $st"; return; }
  [ -r "$CFG" ] || return
  local r c src; read -r r c src < <(counts)
  local meta; meta=$(jq -r '[(.err // "-"), (.ts // 0), (.ts_ok // 0)] | @tsv' "$CACHE" 2>/dev/null)
  local err=- ts=0 ts_ok=0; [ -n "$meta" ] && read -r err ts ts_ok <<<"$meta"
  local pstat='' usecache=''
  if [ ! -e "$TOKEN_FILE" ] || [ ! -e "$PROJECTS_FILE" ]; then pstat="Pending: no token (${TOKEN_FILE/#$HOME/\~})"
  elif ! mode_ok; then pstat="Pending: token file mode $(tokmode): chmod 600 ${TOKEN_FILE/#$HOME/\~}"
  elif [ "$err" = auth ]; then pstat="Pending: token rejected (401), next try in 10 min"
  elif [ -z "$meta" ]; then pstat="Pending: not fetched yet"
  elif [ "$err" = net ]; then pstat="Pending: network down, last good $(fmt_age $((NOW - ts_ok))) ago"
  else usecache=1; fi
  {
    echo "Running $r/$c:"
    if [ -n "$usecache" ] || [ "$err" = net ]; then jq -r --argjson now "$NOW" "$JQ_ROWS"'.running[]? | row' "$CACHE" 2>/dev/null
    else journal -n 1000 | awk '
        /Added job to processing list/ { j = ""; p = ""; for (i = 1; i <= NF; i++) { if ($i ~ /^job=/) j = substr($i, 5); if ($i ~ /^project_full_path=/) p = substr($i, 19) } if (j != "") { a[j] = p; o[++n] = j } }
        /Removed job from processing list/ { for (i = 1; i <= NF; i++) if ($i ~ /^job=/) delete a[substr($i, 5)] }
        END { for (i = 1; i <= n; i++) if (o[i] in a) printf "  %-16.16s %s\n", a[o[i]], "job " o[i] }'
    fi
    if [ -n "$usecache" ]; then
      echo "Pending $(jq '.pending | length' "$CACHE") (API, $(fmt_age $((NOW - ts_ok))) ago):"
      jq -r --argjson now "$NOW" "$JQ_ROWS"'.pending[]? | row' "$CACHE" 2>/dev/null
    else echo "$pstat"; fi
  } | awk -v max="$LIST_MAX" '
      { l[NR] = $0 }
      END { if (NR <= max) { for (i = 1; i <= NR; i++) print l[i]; exit }
            # keep headers (no leading space); job rows fill the rest, "+N more" is the last line, total max
            for (i = 1; i <= NR; i++) if (l[i] !~ /^  /) h++
            allow = max - h - 1; if (allow < 0) allow = 0
            for (i = 1; i <= NR; i++) { if (l[i] !~ /^  /) print l[i]; else if (++rows <= allow) print l[i]; else hidden++ }
            printf "  +%d more\n", hidden }'
}
JQ_ROWS='
  def fit($n): if length > $n then .[0:$n - 1] + "…" else . + (" " * ($n - length)) end;
  def age: ($now - .) as $s | (if $s < 60 then "\($s)s" elif $s < 3600 then "\($s / 60 | floor)m" elif $s < 86400 then "\($s / 3600 | floor)h" else "\($s / 86400 | floor)d" end);
  def row: "  \(.project | fit(16)) \(.ref | fit(12)) \(.name | fit(16)) \((.created | age) as $a | (" " * (4 - ($a | length))) + $a)";
  '

open_job() {
  local u; u=$(jq -r '(.running[0].url) // (.pending | sort_by(.created) | .[0].url) // empty' "$CACHE" 2>/dev/null)
  [[ $u =~ ^https?:// ]] && "${OPEN_CMD:-xdg-open}" "$u" >/dev/null 2>&1 &
  return 0
}

case $mode in
  refresh) refresh; exit 0 ;;
  refresh-now) [ "$(cache_age)" -ge 10 ] && spawn; exit 0 ;;
  list) list; exit 0 ;;
  open) open_job; exit 0 ;;
  *) command -v jq >/dev/null || { echo '{"icon":"gitlab","state":"Critical","text":"RUN ERR"}'; exit 0; }
     out=$(bar 2>/dev/null) && jq -e . >/dev/null 2>&1 <<<"$out" || out='{"icon":"gitlab","state":"Critical","text":"RUN ERR"}'
     echo "$out" ;;
esac
