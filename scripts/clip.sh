#!/usr/bin/env bash
# Clipboard size. Env CLIP_TARGETS / CLIP_DATA (files) replace the two xclip calls (tests).
set -u
emit() { jq -nc --arg s "$1" --arg t "$(printf '%-5s' "$2")" '{icon:"clipboard",state:$s,text:$t}'; }
if [ -n "${CLIP_TARGETS+x}" ]; then targets=$(cat "$CLIP_TARGETS"); else
  targets=$(timeout 2 xclip -o -selection clipboard -t TARGETS 2>/dev/null); fi
[ -z "$targets" ] && { emit Info empty; exit 0; }
grep -q '^image/' <<<"$targets" && { emit Idle img; exit 0; }
if [ -n "${CLIP_DATA+x}" ]; then n=$(head -c 1048577 "$CLIP_DATA" | wc -c); else
  n=$(timeout 2 xclip -o -selection clipboard 2>/dev/null | head -c 1048577 | wc -c); fi
if [ "$n" -eq 0 ]; then emit Info empty
elif [ "$n" -lt 1024 ]; then emit Idle "${n}B"
elif [ "$n" -lt 1048576 ]; then emit Idle "$(awk -v n="$n" 'BEGIN{k=n/1024; if(k<99.95) printf "%.1fK", k; else if(k<999.5) printf "%dK", k+0.5; else print "1.0M"}')"
else emit Idle ">1M"; fi
exit 0
