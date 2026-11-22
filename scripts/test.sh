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
e=$(mktemp -d -p "$gd"); o=$(CU_NOW=$NOW CU_PROJECTS=$e CU_CREDS=$e/none CU_CACHE=$e/rl.json CU_STATE_DIR=$e "$d/claude-usage.sh")
check u28 "$o" "cc …                                    " Idle
jq -r .text <<<"$o" | grep -q '^<span foreground="#777777">cc …' && [ "$(len "$o")" = "$base" ] && pass=$((pass+1)) || { echo "FAIL u28: placeholder dim/width"; fail=$((fail+1)); }
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
  rs=$(grep -cE 'status_command (.*hover-tee.py --output DP-[02] -- )?i3status-rs /x/conf/' "$gd/bars.conf"); wr=2
  if [ "$(grep -c '^bar {' "$gd/bars.conf")" = 2 ] && [ "$n$tb" = 11 ] && [ "$docks" = $wd ] && [ "$rs" = $wr ] && ! grep -q @ "$gd/bars.conf" \
     && { ! command -v i3 >/dev/null || { echo "include $gd/bars.conf" >"$gd/i3cfg"; i3 -C -c "$gd/i3cfg" >/dev/null 2>&1; }; }
  then pass=$((pass+1)); else echo "FAIL bars $st: tray on bar-main $n/$tb, dock $docks/$wd, rs commands $rs/$wr or i3 -C"; fail=$((fail+1)); fi
done
# barcycle: concurrent presses are serialized, each one counts (3 presses = off -> rs -> off -> rs), one reload per press
mkdir "$gd/bin"; printf '#!/bin/sh\necho "$@" >>"%s/i3msg.log"\n' "$gd" >"$gd/bin/i3-msg"; chmod +x "$gd/bin/i3-msg"
printf 'BARSCONF=%s/cyc.conf\nI3CFG=%s/cyccfg\n' "$gd" "$gd" >>"$gd/bars.env"; echo "include $gd/cyc.conf" >"$gd/cyccfg"
BARS_ENV=$gd/bars.env "$d/barsconf.sh" off >"$gd/cyc.conf"
for _ in 1 2 3; do PATH=$gd/bin:$PATH BARS_ENV=$gd/bars.env BARCYCLE_SETTLE=0 "$d/barcycle.sh" 2>>"$gd/cyc.err" & done; wait
if [ "$(head -1 "$gd/cyc.conf" | cut -d" " -f3)" = rs ] && [ "$(grep -c reload "$gd/i3msg.log")" = 3 ] && [ ! -s "$gd/cyc.err" ]
then pass=$((pass+1)); else echo "FAIL barcycle: 3 concurrent presses -> $(head -1 "$gd/cyc.conf" | cut -c1-20), reloads $(grep -c reload "$gd/i3msg.log"), stderr: $(head -2 "$gd/cyc.err")"; fail=$((fail+1)); fi
# hover-tee.py (T1a): h1 stdout byte-identical, h2 stdin forwarded + last click tapped, h3 unwritable tap dir, h4 child dies with the wrapper
fk=$t/hover/fake-status.sh; hd=$gd/hover; hin=$gd/fake.in
bash "$fk" </dev/null >"$gd/h.direct"
printf '[\n{"button":1}\n,{"button":9,"x":5}\n' | HOVER_DIR=$hd FAKE_IN=$hin "$d/hover-tee.py" --output DP-0 -- bash "$fk" >"$gd/h.out"; hrc=$?
cmp -s "$gd/h.direct" "$gd/h.out" && [ $hrc = 3 ] && pass=$((pass+1)) || { echo "FAIL h1: wrapper stdout differs or exit $hrc"; fail=$((fail+1)); }
printf '[\n{"button":1}\n,{"button":9,"x":5}\n' | cmp -s - "$hin" && [ "$(jq -c .click "$hd/DP-0.click.json")" = '{"button":9,"x":5}' ] && jq -e '.status[0].full_text == "c" and .output == "DP-0"' "$hd/DP-0.status.json" >/dev/null \
  && pass=$((pass+1)) || { echo "FAIL h2: stdin forwarding or tap files"; fail=$((fail+1)); }
# h2b: an earlier session's tap files are removed at start, the opening "[" is not tapped as a status
echo '{"v":1,"status":[]}' >"$hd/DP-2.status.json"; echo '{}' >"$hd/DP-2.click.json"
HOVER_DIR=$hd FAKE_STOP=1 "$d/hover-tee.py" --output DP-2 -- bash "$fk" </dev/null >/dev/null
[ ! -e "$hd/DP-2.status.json" ] && [ ! -e "$hd/DP-2.click.json" ] && pass=$((pass+1)) || { echo "FAIL h2b: stale or bare-[ tap file: $(head -c 80 "$hd/DP-2.status.json" 2>/dev/null)"; fail=$((fail+1)); }
HOVER_DIR=/proc/nope "$d/hover-tee.py" --output DP-0 -- bash "$fk" </dev/null >"$gd/h3.out" 2>/dev/null; hrc=$?
cmp -s "$gd/h.direct" "$gd/h3.out" && [ $hrc = 3 ] && pass=$((pass+1)) || { echo "FAIL h3: unwritable tap dir, exit $hrc"; fail=$((fail+1)); }
printf '#!/bin/sh\nsleep 4\n' >"$gd/hsleep"; chmod +x "$gd/hsleep"
{ (sleep 4 | HOVER_DIR=$hd "$d/hover-tee.py" --output DP-0 -- "$gd/hsleep" >/dev/null 2>&1) & } 2>/dev/null; sleep 0.5
hw=$(pgrep -f "[h]over-tee.py --output DP-0 -- $gd/hsleep"); kill -9 $hw; sleep 1
pgrep -f "[ ]$gd/hsleep" >/dev/null && { echo "FAIL h4: child survived wrapper kill"; fail=$((fail+1)); pkill -f "[ ]$gd/hsleep"; } || pass=$((pass+1))
# h15: both states wrap both commands with the outputs of the template; HOVER=0 gives plain commands
for st in rs off; do BARS_ENV=$gd/bars.env "$d/barsconf.sh" $st | grep status_command >"$gd/h15.$st"; done
printf 'CONFDIR=/x/conf\nHOVER=0\n' >"$gd/bars0.env"; BARS_ENV=$gd/bars0.env "$d/barsconf.sh" rs | grep status_command >"$gd/h15.0"
grep -q "hover-tee.py --output DP-0 -- i3status-rs /x/conf/config.toml" "$gd/h15.rs" && grep -q "hover-tee.py --output DP-2 -- i3status-rs /x/conf/compact.toml" "$gd/h15.rs" \
  && cmp -s "$gd/h15.rs" "$gd/h15.off" && ! grep -q hover-tee "$gd/h15.0" && grep -q 'status_command i3status-rs /x/conf/config.toml' "$gd/h15.0" \
  && pass=$((pass+1)) || { echo "FAIL h15: barsconf wrapping"; fail=$((fail+1)); }
# explain.sh: every key in hover/keys.toml has a text of at most 6 lines; every config block has a key
for n in $(grep '^key = ' "$d/hover/keys.toml" | cut -d'"' -f2); do
  o=$(EXPLAIN_DRY=1 "$d/explain.sh" $n 2>&1); [ -n "$o" ] && [ "$(wc -l <<<"$o")" -le 6 ] && pass=$((pass+1)) || { echo "FAIL explain $n"; fail=$((fail+1)); }
done
! grep -q 'explain\.sh' "$d/../config.toml" && pass=$((pass+1)) || { echo "FAIL explain: middle-click popup back in config.toml"; fail=$((fail+1)); }
# hover core (T1b): rows h5-h14 in test_hover.py add their counts to ours
ho=$(python3 "$d/hover/test_hover.py" 2>&1); grep '^FAIL' <<<"$ho"
hp=$(grep -o '^pass=[0-9]*' <<<"$ho" | cut -d= -f2); hf=$(grep -o 'fail=[0-9]*$' <<<"$ho" | cut -d= -f2)
[ -n "$hp" ] && { pass=$((pass+hp)); fail=$((fail+hf)); } || { echo "FAIL h5-h14: test_hover.py did not run"; fail=$((fail+1)); }
# h16: hover daemon selftest (imports, key maps of both configs) without a display
hs=$(DISPLAY="" python3 "$d/hover-daemon.py" --selftest 2>&1); hrc=$?
[ $hrc = 0 ] && grep -q '^config.toml .*[0-9]:time' <<<"$hs" && grep -q '^compact.toml .*[0-9]:time' <<<"$hs" \
  && pass=$((pass+1)) || { echo "FAIL h16: hover-daemon.py --selftest rc=$hrc: $(head -c 200 <<<"$hs")"; fail=$((fail+1)); }
# hover-run.sh (T1e) with a fake daemon: r1 backoff 1..16 s then give-up after 6 crashes, r2 exit 0 stops,
# r3 second instance exits, --replace stops the first, r4 --replace leaves a non-hover-run pid alone, r5 HOVER=0
rd=$gd/run; fd="bash $t/hover/fake-daemon.sh"; printf 'HOVER=1\n' >"$gd/run1.env"; printf 'HOVER=0\n' >"$gd/run0.env"
hr() { HOVER_DIR=$rd BARS_ENV=$gd/run${2:-1}.env HOVER_DAEMON="$fd" HOVER_RUN_SLEEP=0.01 FAKE_RC=$1 FAKE_LOG=$gd/starts timeout 20 "$d/hover-run.sh" "${@:3}"; }
hr 1; hrc=$?; dl=$(grep -o 'restart in [0-9]*s' "$rd/hover.log" | grep -o '[0-9]*' | tr '\n' ' ')
[ $hrc = 1 ] && [ "$dl" = "1 2 4 8 16 " ] && [ "$(wc -l <"$gd/starts")" = 6 ] && grep -q '6 crashes in 10 min, giving up' "$rd/hover.log" \
  && pass=$((pass+1)) || { echo "FAIL r1: hover-run rc=$hrc delays '$dl' starts $(wc -l <"$gd/starts")"; fail=$((fail+1)); }
: >"$gd/starts"; hr 0; hrc=$?
[ $hrc = 0 ] && [ "$(wc -l <"$gd/starts")" = 1 ] && tail -1 "$rd/hover.log" | grep -q 'daemon stopped' && pass=$((pass+1)) || { echo "FAIL r2: daemon exit 0, rc=$hrc"; fail=$((fail+1)); }
{ hr sleep & } 2>/dev/null; sleep 0.5; r1=$(cat "$rd/daemon.pid"); hr 0; hrc=$?
kill -0 "$r1" 2>/dev/null && [ $hrc = 0 ] && ok3=1 || ok3=
{ hr sleep "" --replace & } 2>/dev/null; sleep 1.5; r2=$(cat "$rd/daemon.pid")
[ -n "$ok3" ] && ! kill -0 "$r1" 2>/dev/null && [ "$r2" != "$r1" ] && kill -0 "$r2" 2>/dev/null && pass=$((pass+1)) || { echo "FAIL r3: single instance / --replace ($r1 -> $r2)"; fail=$((fail+1)); }
kill -TERM -- -"$r2" 2>/dev/null; sleep 0.3
sleep 30 & sp=$!; echo $sp >"$rd/daemon.pid"; hr 0 "" --replace
kill -0 $sp 2>/dev/null && pass=$((pass+1)) || { echo "FAIL r4: --replace killed a pid that is not hover-run.sh"; fail=$((fail+1)); }
kill $sp 2>/dev/null
echo '{}' >"$rd/DP-0.status.json"; echo '{}' >"$rd/DP-2.click.json"; : >"$gd/starts"; hr 1 0; hrc=$?
[ $hrc = 0 ] && [ ! -s "$gd/starts" ] && ! ls "$rd"/*.json >/dev/null 2>&1 && pass=$((pass+1)) || { echo "FAIL r5: HOVER=0 rc=$hrc, daemon started or tap files kept"; fail=$((fail+1)); }
# i1-i4: install.sh writes its block into ~/.config/i3/config.local of a temp HOME (repo copy without .git: no
# pull), never ~/.i3/config; i1 creates the file, i2 rerun idempotent, i3 symlinked file keeps the link and other
# lines, i4 an old block in ~/.i3/config is only warned about
ir=$gd/irepo; mkdir -p "$ir/scripts"; cp "$d/../install.sh" "$d/../config.toml" "$d/../compact.toml" "$ir"; cp -r "$d/../i3" "$ir"; cp "$d"/*.sh "$ir/scripts"
ih=$gd/ih; mkdir -p "$ih/.i3"; printf 'set $mod Mod4\nbindsym $mod+Return exec true\ninclude ~/.config/i3/config.local\n' >"$ih/.i3/config"; cp "$ih/.i3/config" "$gd/imain"
inst() { env -u XDG_CONFIG_HOME HOME=$ih "$ir/install.sh" --no-restart >"$gd/inst.out" 2>&1; }
ib() { grep -c '^# BEGIN custom_barista' "$1"; }
il=$ih/.config/i3/config.local
inst; irc=$?
[ $irc = 0 ] && [ -f "$il" ] && [ "$(ib "$il")" = 1 ] && grep -qx 'include ~/.i3/bars.conf' "$il" && ! grep -q "$ih" "$il" && cmp -s "$ih/.i3/config" "$gd/imain" \
  && [ ! -e "$ih/.config/i3/config" ] && [ -f "$ih/.i3/bars.conf" ] && pass=$((pass+1)) || { echo "FAIL i1: rc=$irc $(tail -3 "$gd/inst.out")"; fail=$((fail+1)); }
cp "$il" "$gd/il1"; inst; irc=$?
[ $irc = 0 ] && cmp -s "$il" "$gd/il1" && grep -q 'config.local already up to date' "$gd/inst.out" && pass=$((pass+1)) || { echo "FAIL i2: rerun rc=$irc not idempotent"; fail=$((fail+1)); }
{ echo 'bindsym $mod+v exec true'; echo '# BEGIN custom_barista'; echo "include /home/x/.i3/bars.conf"; echo '# END custom_barista'; echo 'bindsym $mod+m exec true'; } >"$gd/itarget"
rm "$il"; ln -s "$gd/itarget" "$il"; inst; irc=$?
[ $irc = 0 ] && [ -L "$il" ] && [ "$(readlink "$il")" = "$gd/itarget" ] && [ "$(ib "$gd/itarget")" = 1 ] && grep -qx 'include ~/.i3/bars.conf' "$gd/itarget" \
  && [ "$(head -1 "$gd/itarget")" = 'bindsym $mod+v exec true' ] && [ "$(tail -1 "$gd/itarget")" = 'bindsym $mod+m exec true' ] && cmp -s "$ih/.i3/config" "$gd/imain" \
  && pass=$((pass+1)) || { echo "FAIL i3: symlinked config.local rc=$irc $(ls -l "$il")"; fail=$((fail+1)); }
printf '# BEGIN custom_barista\ninclude /home/x/.i3/bars.conf\n# END custom_barista\n' >>"$ih/.i3/config"; cp "$ih/.i3/config" "$gd/imain"; inst; irc=$?
[ $irc = 0 ] && cmp -s "$ih/.i3/config" "$gd/imain" && grep -q 'still has an old custom_barista block' "$gd/inst.out" && pass=$((pass+1)) || { echo "FAIL i4: old block in ~/.i3/config rc=$irc"; fail=$((fail+1)); }
echo "pass=$pass fail=$fail"; [ $fail -eq 0 ]
