#!/usr/bin/env bash
# Runs the spec test table against testdata/. Prints failures and a summary line.
d=$(cd "$(dirname "$0")" && pwd); t=$d/testdata; pass=0; fail=0
gd=$(mktemp -d); cj=$(mktemp); trap 'rm -f "$cj"; rm -rf "$gd"' EXIT
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
# claude-usage.sh (u1-u17): fixtures in testdata/u1, fixed NOW, CU_API_FIXTURE always set (no network)
U=$t/u1; NOW=1795003200; RES=1795009560; ucache=$gd/rl.json; find "$U/proj" -name '*.jsonl' -exec touch -d "@$NOW" {} +
fresh() { usd=$(mktemp -d -p "$gd"); }
wc_() { printf '{"ts":%s,"five_hour":{"pct":%s,"resets_at":%s},"seven_day":%s}\n' "$1" "$2" "$3" "${4:-null}" >"$ucache"; }
un() { CU_NOW=$NOW CU_PROJECTS=$U/proj CU_CREDS=${CRED:-$U/creds.json} CU_CACHE=$ucache CU_STATE_DIR=$usd CU_API_FIXTURE=${FX:-$U/api_000} "$d/claude-usage.sh"; }
body=" 3.4M \$1.85 cache 90% 1h46m"
sp7=" 7d  ?% "
fresh; wc_ $((NOW-60)) 53 $RES; o=$(un); check u1 "$o" "53%  $body$sp7" Idle
jq -r .text <<<"$o" | grep -q '#777777">7d  ?%' && pass=$((pass+1)) || { echo "FAIL u1: 7d unknown dim"; fail=$((fail+1)); }
jq -r .text <<<"$o" | grep -q '#777777">cache</span>' && pass=$((pass+1)) || { echo "FAIL u1: cache label not dim"; fail=$((fail+1)); }
wc_ $((NOW-60)) 70 $RES; check u2 "$(un)" "70%  $body$sp7" Idle
wc_ $((NOW-60)) 70.4 $RES; check u3 "$(un)" "70%  $body$sp7" Idle
w7() { wc_ $((NOW-60)) 53 $RES "{\"pct\":$1,\"resets_at\":$((NOW+86400))}"; }
w7 70; o=$(un); check u18 "$o" "53%  $body 7d 70% " Idle
jq -r .text <<<"$o" | grep -q '#777777">7d 70%' && pass=$((pass+1)) || { echo "FAIL u18: 7d dim"; fail=$((fail+1)); }
w7 71; o=$(un); check u19 "$o" "53%  $body 7d 71% " Idle
jq -r .text <<<"$o" | grep -q '#dddd66">7d 71%' && pass=$((pass+1)) || { echo "FAIL u19: 7d colour"; fail=$((fail+1)); }
w7 91; o=$(un); check u20 "$o" "53%  $body 7d 91% " Idle
jq -r .text <<<"$o" | grep -q '#dd6666">7d 91%' && pass=$((pass+1)) || { echo "FAIL u20: 7d colour"; fail=$((fail+1)); }
wc_ $((NOW-60)) 53 $RES '{"pct":91,"resets_at":1}'; check u21 "$(un)" "53%  $body$sp7" Idle
w7 0.3; check u22 "$(un)" "53%  $body 7d  0% " Idle
w7 100; check u23 "$(un)" "53%  $body 7d 99% " Idle
wc_ $((NOW-60)) 90 $RES; check u4a "$(un)" "90%  $body$sp7" Idle
wc_ $((NOW-60)) 95 $RES; check u4b "$(un)" "95%  $body$sp7" Idle
fresh; wc_ $((NOW-600)) 53 $RES; check u5 "$(FX=$U/api_200 un)" "37%  $body$sp7" Idle
[ "$(jq .next_at "$usd/api.json")" == $((NOW+180)) ] && pass=$((pass+1)) || { echo "FAIL u5: next_at"; fail=$((fail+1)); }
fresh; printf '{"ts_ok":%s,"next_at":%s,"status":"ok","five_hour":null}\n' $((NOW-900)) $((NOW+100)) >"$usd/api.json"
check u6 "$(FX=$U/api_200 un)" "53%  $body$sp7" Idle
fresh; check u7 "$(FX=$U/api_429 un)" "53%  $body$sp7" Idle
[ "$(jq .next_at "$usd/api.json")" == $((NOW+600)) ] && pass=$((pass+1)) || { echo "FAIL u7: next_at"; fail=$((fail+1)); }
fresh; cp "$U/creds.json" "$gd/creds"; touch -d @1000000000 "$gd/creds"; wc_ $((NOW-1200)) 53 $RES
o=$(FX=$U/api_401 CRED=$gd/creds un); check u8 "$o" "53%  $body$sp7" Idle
jq -r .text <<<"$o" | grep -q '#777777">53%</span>' && [ "$(jq -r .status "$usd/api.json")" == stale ] && pass=$((pass+1)) || { echo "FAIL u8: dim pct / stale status"; fail=$((fail+1)); }
check u9 "$(FX=$U/api_200 CRED=$gd/creds un)" "53%  $body$sp7" Idle
touch -d "@$NOW" "$gd/creds"; check u10 "$(FX=$U/api_200 CRED=$gd/creds un)" "37%  $body$sp7" Idle
fresh; wc_ $((NOW-60)) 53 $((NOW-60)); check u11 "$(un)" "" ""
fresh; rm -f "$ucache"; check u12 "$(un)" "?%   4.4M \$5.85 cache 69% -h--m 7d  ?%  " Idle
fresh; wc_ $((NOW-1200)) 53 $RES; check u13 "$(FX=$gd/nonexistent CRED=$U/creds_expired.json un)" "53%  $body$sp7" Idle
! grep -rq TESTTOKEN-u1 "$gd"/tmp.* && pass=$((pass+1)) || { echo "FAIL u14: token leaked into state"; fail=$((fail+1)); }
rm -f "$ucache"; o=$(CU_CACHE=$ucache "$d/claude-rl-tap.sh" <"$U/sl_rl.json")
[ -z "$o" ] && [ "$(jq -c '[.five_hour.pct,.five_hour.resets_at,(.ts|type)]' "$ucache")" == '[53,1795009560,"number"]' ] && pass=$((pass+1)) || { echo "FAIL u15: tap"; fail=$((fail+1)); }
sum=$(cksum <"$ucache"); o=$(CU_CACHE=$ucache "$d/claude-rl-tap.sh" <"$U/sl_norl.json")
[ -z "$o" ] && [ "$(cksum <"$ucache")" == "$sum" ] && pass=$((pass+1)) || { echo "FAIL u15: tap without rate_limits"; fail=$((fail+1)); }
check gpu1 "$("$d/gpu.sh" "$t/gpu_ok")" "34° 5.0GB" Idle
check gpu2 "$("$d/gpu.sh" "$t/gpu_bad")" "GPU ERR" Critical
check gpu3 "$("$d/gpu.sh" "$t/gpu_multi")" "34° 5.0GB" Idle
printf '99, 16303\n' > "$cj"; check gpu4 "$("$d/gpu.sh" "$cj")" "99°  17GB" Critical
# constant text length across small/large values
len() { jq -r .text <<<"$1" | strip | awk '{print length($0)}'; }
ub='{"pct":53,"tok":3400000,"cost":1.85,"ch":90,"left":6360,"stale":false,"w":null}'; base=$(len "$("$d/claude-usage.sh" --render "$ub")")
for kv in pct:0 pct:5 pct:100 pct:null tok:0 tok:5 tok:999 tok:999950 tok:200000 tok:53300000 cost:0 cost:9.994 cost:9.995 cost:99.96 cost:999.6 cost:1234 cost:12345 ch:0 ch:100 left:0 left:59 left:299 left:300 w:null w:70 w:71 w:99 w:150; do
  o=$("$d/claude-usage.sh" --render "$(jq -c --arg k "${kv%%:*}" --argjson v "${kv#*:}" '.[$k]=$v' <<<"$ub")")
  [ "$(len "$o")" == "$base" ] && [ "$base" == 40 ] && pass=$((pass+1)) || { echo "FAIL u16 $kv: '$(jq -r .text <<<"$o" | strip)' len $(len "$o")"; fail=$((fail+1)); }
done
# per-part colours (u24-u27): 5h 70/71/90/91, cache 69/70/89/90, 7d 92 -> state stays Idle; hex match config.toml
pc() { jq -r .text <<<"$1" | grep -q "foreground=\"$2\">$3<" && pass=$((pass+1)) || { echo "FAIL $4: '$3' not $2"; fail=$((fail+1)); }; }
for kv in 70:#66dd66 71:#dddd66 90:#dddd66 91:#dd6666; do
  o=$("$d/claude-usage.sh" --render "$(jq -c --argjson v "${kv%%:*}" '.pct=$v' <<<"$ub")"); pc "$o" "${kv#*:}" "${kv%%:*}%" u24
done
for kv in 69:#dd6666 70:#dddd66 89:#dddd66 90:#66dd66; do
  o=$("$d/claude-usage.sh" --render "$(jq -c --argjson v "${kv%%:*}" '.ch=$v' <<<"$ub")"); pc "$o" "${kv#*:}" "${kv%%:*}%" u25
done
o=$("$d/claude-usage.sh" --render "$(jq -c '.w=92' <<<"$ub")"); check u26 "$o" "53%   3.4M \$1.85 cache 90% 1h46m 7d 92% " Idle
for c in good_fg:66dd66 warning_fg:dddd66 critical_fg:dd6666 info_fg:777777; do grep -q "^${c%%:*} = \"#${c#*:}\"" "$d/../config.toml" && pass=$((pass+1)) || { echo "FAIL u27: ${c%%:*} differs from claude-usage fallback"; fail=$((fail+1)); }; done
o=$(EXPLAIN_DRY=1 "$d/explain.sh" ccusage); grep -q cache <<<"$o" && ! grep -q 'CH' <<<"$o" && pass=$((pass+1)) || { echo "FAIL u17: explain text"; fail=$((fail+1)); }
printf '99, 16303\n' > "$cj"; o=$("$d/gpu.sh" "$cj"); printf '9, 5\n' > "$cj"; o2=$("$d/gpu.sh" "$cj")
[ "$(len "$o")" == "$(len "$o2")" ] && pass=$((pass+1)) || { echo "FAIL gpuwidth"; fail=$((fail+1)); }
# compact.toml (DP-2 bar) is generated from config.toml and must be in sync and without the dropped parts
"$d/gen-compact.sh" - | cmp -s - "$d/../compact.toml" && pass=$((pass+1)) || { echo "FAIL compact: out of sync, run scripts/gen-compact.sh"; fail=$((fail+1)); }
grep -qE 'disk_space|disk_iostats|claude-usage\.sh|\$ip' "$d/../compact.toml" && { echo "FAIL compact: dropped block left"; fail=$((fail+1)); } || pass=$((pass+1))
[ "$(grep -cE 'disk_space|disk_iostats|claude-usage\.sh"|\$ip ' "$d/../config.toml")" == 4 ] && pass=$((pass+1)) || { echo "FAIL compact: config.toml patterns changed, update gen-compact.sh"; fail=$((fail+1)); }
# D5-R groups: 7 merge flags on DP-0 (6 separators), 5 on DP-2; memory must not glue onto gpu on DP-2
[ "$(grep -c '^merge_with_next = true$' "$d/../config.toml")" == 7 ] && [ "$(grep -c '^merge_with_next = true$' "$d/../compact.toml")" == 5 ] && pass=$((pass+1)) || { echo "FAIL groups: merge_with_next count"; fail=$((fail+1)); }
awk '/^\[\[block\]\]$/ { b = "" } /^block = / { b = $0 } /^merge_with_next/ && b ~ /memory/ { f = 1 } END { exit f }' "$d/../compact.toml" && pass=$((pass+1)) || { echo "FAIL compact: memory still merged"; fail=$((fail+1)); }
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
