#!/usr/bin/env bash
# Runs the spec test table against testdata/. Prints failures and a summary line.
d=$(cd "$(dirname "$0")" && pwd); t=$d/testdata; pass=0; fail=0
gd=$(mktemp -d); cj=$(mktemp); trap 'rm -f "$cj"; rm -rf "$gd"' EXIT; head -c 2097152 /dev/zero | tr '\0' a >"$gd/data_2m"
strip() { sed 's/<[^>]*>//g'; }
check() { # name json expected_text expected_state
  jq -e . >/dev/null 2>&1 <<<"$2" || { echo "FAIL $1: invalid JSON: $2"; fail=$((fail+1)); return; }
  local txt st; txt=$(jq -r .text <<<"$2" | strip); st=$(jq -r '.state // ""' <<<"$2")
  if [ "$txt" == "$3" ] && { [ -z "$4" ] || [ "$st" == "$4" ]; }; then pass=$((pass+1))
  else echo "FAIL $1: got '$txt' [$st], want '$3' [$4]"; fail=$((fail+1)); fi; }
check freq1 "$("$d/freq.sh" "$t/freq1")" "1 0 0 2 1 0" Idle
check freq2 "$("$d/freq.sh" "$t/freq2")" "0 12 0 0 0 0" Idle
o=$("$d/freq.sh" "$t/freq3"); check freq3 "$o" "0 0 0 0 0 0 1" Idle
grep -q "#ff0000'>1</span> *\"" <<<"$o" && pass=$((pass+1)) || { echo "FAIL freq3: last color"; fail=$((fail+1)); }
check freq4 "$("$d/freq.sh" "$t/freq4")" "FREQ ERR" Critical
cc() { CCUSAGE_JSON=$t/$1 "$d/ccusage.sh"; }
check cc5 "$(cc cc_null.json)" "53.3M CH  96% 1h46m      " Good
check cc6 "$(cc cc_100m.json)" "53%  53.3M CH  96% 1h46m " Good
check cc7 "$(cc cc_60m.json)" "89%  53.3M CH  96% 1h46m " Warning
check cc8 "$(cc cc_55m.json)" "97%  53.3M CH  96% 0h40m " Critical
check cc9 "$(cc cc_empty.json)" "" ""
check cc10 "$(cc cc_bad.json)" "cc err" Critical
# clip text is right-padded to 5 chars (fixed width), so compare after trimming
cl() { CLIP_TARGETS=$t/$1 CLIP_DATA=${2:-/dev/null} "$d/clip.sh" | jq -c '.text |= gsub(" +$";"")'; }
check clip11 "$(cl targets_empty)" "empty" Info
check clip12 "$(cl targets_text $t/data_5)" "5B" Idle
check clip13 "$(cl targets_text $t/data_2k)" "2.0K" Idle
check clip14 "$(CLIP_TARGETS=$t/targets_img "$d/clip.sh" | jq -c '.text |= gsub(" +$";"")')" "img" Idle
for sz in 204800 1048000 1048575 102300; do head -c $sz /dev/zero | tr '\0' a >"$gd/d_$sz"
  o=$(CLIP_TARGETS=$t/targets_text CLIP_DATA=$gd/d_$sz "$d/clip.sh"); l=$(jq -r .text <<<"$o" | awk '{print length($0)}')
  [ "$l" == 5 ] && pass=$((pass+1)) || { echo "FAIL clipwidth $sz: '$(jq -r .text <<<"$o")'"; fail=$((fail+1)); }; done
check clip15 "$(cl targets_text "$gd/data_2m")" ">1M" Idle
check gpu1 "$("$d/gpu.sh" "$t/gpu_ok")" "34° 5.0GB" Idle
check gpu2 "$("$d/gpu.sh" "$t/gpu_bad")" "GPU ERR" Critical
check gpu3 "$("$d/gpu.sh" "$t/gpu_multi")" "34° 5.0GB" Idle
printf '99, 16303\n' > "$cj"; check gpu4 "$("$d/gpu.sh" "$cj")" "99°  17GB" Critical
# constant text length across small/large values
len() { jq -r .text <<<"$1" | strip | awk '{print length($0)}'; }
base=$(len "$(cc cc_100m.json)")
for v in '{"t":5,"c":0,"r":5}' '{"t":999,"c":3,"r":59}' '{"t":12345,"c":50,"r":61}' '{"t":999950,"c":50,"r":61}' '{"t":200000,"c":50,"r":61}' '{"t":53300000,"c":100,"r":299}'; do
  jq -c --argjson v "$v" '(.blocks[]|select(.isActive)) |= (.totalTokens=$v.t | .tokenLimitStatus.limit=100000000 | .tokenCounts.inputTokens=(100-$v.c) | .tokenCounts.cacheCreationInputTokens=0 | .tokenCounts.cacheReadInputTokens=$v.c | .projection.remainingMinutes=$v.r)' "$t/cc_100m.json" > "$cj"
  o=$(CCUSAGE_JSON=$cj "$d/ccusage.sh"); if [ "$(len "$o")" == "$base" ]; then pass=$((pass+1)); else echo "FAIL ccwidth $v: $(jq -r .text <<<"$o") len $(len "$o") want $base"; fail=$((fail+1)); fi
done
printf '99, 16303\n' > "$cj"; o=$("$d/gpu.sh" "$cj"); printf '9, 5\n' > "$cj"; o2=$("$d/gpu.sh" "$cj")
[ "$(len "$o")" == "$(len "$o2")" ] && pass=$((pass+1)) || { echo "FAIL gpuwidth"; fail=$((fail+1)); }
# compact.toml (DP-2 bar) is generated from config.toml and must be in sync and without the dropped parts
"$d/gen-compact.sh" - | cmp -s - "$d/../compact.toml" && pass=$((pass+1)) || { echo "FAIL compact: out of sync, run scripts/gen-compact.sh"; fail=$((fail+1)); }
grep -qE 'disk_space|disk_iostats|ccusage\.sh|\$ip' "$d/../compact.toml" && { echo "FAIL compact: dropped block left"; fail=$((fail+1)); } || pass=$((pass+1))
[ "$(grep -cE 'disk_space|disk_iostats|ccusage\.sh"|\$ip ' "$d/../config.toml")" == 4 ] && pass=$((pass+1)) || { echo "FAIL compact: config.toml patterns changed, update gen-compact.sh"; fail=$((fail+1)); }
# bars.conf generator: per state valid blocks (i3 -C when available); the tray never moves (bar-main, DP-0)
printf 'CONFDIR=/x/conf\n' >"$gd/bars.env"
for st in barista rs off; do  # barista = migrated to rs
  BARS_ENV=$gd/bars.env "$d/barsconf.sh" $st >"$gd/bars.conf" || { echo "FAIL bars $st: generator"; fail=$((fail+1)); continue; }
  n=$(grep -c 'tray_output DP-0' "$gd/bars.conf"); tb=$(grep -B8 'tray_output DP-0' "$gd/bars.conf" | grep -c 'id bar-main')
  docks=$(grep -c 'mode dock' "$gd/bars.conf"); wd=2; [ $st = off ] && wd=0
  rs=$(grep -c 'status_command i3status-rs /x/conf/' "$gd/bars.conf"); wr=2
  if [ "$(grep -c '^bar {' "$gd/bars.conf")" = 2 ] && [ "$n$tb" = 11 ] && [ "$docks" = $wd ] && [ "$rs" = $wr ] && ! grep -q @ "$gd/bars.conf" \
     && { ! command -v i3 >/dev/null || { echo "include $gd/bars.conf" >"$gd/i3cfg"; i3 -C -c "$gd/i3cfg" >/dev/null 2>&1; }; }
  then pass=$((pass+1)); else echo "FAIL bars $st: tray on bar-main $n/$tb, dock $docks/$wd, rs commands $rs/$wr or i3 -C"; fail=$((fail+1)); fi
done
# barcycle: concurrent presses are serialized, each one counts (3 presses = off -> rs -> off -> rs), one reload per press
mkdir "$gd/bin"; printf '#!/bin/sh\necho "$@" >>"%s/i3msg.log"\n' "$gd" >"$gd/bin/i3-msg"; chmod +x "$gd/bin/i3-msg"
printf 'BARSCONF=%s/cyc.conf\nI3CFG=%s/cyccfg\n' "$gd" "$gd" >>"$gd/bars.env"; echo "include $gd/cyc.conf" >"$gd/cyccfg"
BARS_ENV=$gd/bars.env "$d/barsconf.sh" off >"$gd/cyc.conf"
for i in 1 2 3; do PATH=$gd/bin:$PATH BARS_ENV=$gd/bars.env BARCYCLE_SETTLE=0 "$d/barcycle.sh" 2>>"$gd/cyc.err" & done; wait
if [ "$(head -1 "$gd/cyc.conf" | cut -d" " -f3)" = rs ] && [ "$(grep -c reload "$gd/i3msg.log")" = 3 ] && [ ! -s "$gd/cyc.err" ]
then pass=$((pass+1)); else echo "FAIL barcycle: 3 concurrent presses -> $(head -1 "$gd/cyc.conf" | cut -c1-20), reloads $(grep -c reload "$gd/i3msg.log"), stderr: $(head -2 "$gd/cyc.err")"; fail=$((fail+1)); fi
# explain.sh: every middle-click name used in config.toml has a text of at most 6 lines
for n in $(grep -o 'explain\.sh [a-z]*' "$d/../config.toml" | cut -d' ' -f2); do
  o=$(EXPLAIN_DRY=1 "$d/explain.sh" $n 2>&1); [ -n "$o" ] && [ "$(wc -l <<<"$o")" -le 6 ] && pass=$((pass+1)) || { echo "FAIL explain $n"; fail=$((fail+1)); }
done
[ "$(grep -c 'explain\.sh' "$d/../config.toml")" == "$(grep -c '^\[\[block\]\]' "$d/../config.toml")" ] && pass=$((pass+1)) || { echo "FAIL explain: block without middle-click explanation"; fail=$((fail+1)); }
echo "pass=$pass fail=$fail"; [ $fail -eq 0 ]
