#!/usr/bin/env bash
# Runs the spec test table against testdata/. Prints failures and a summary line.
d=$(cd "$(dirname "$0")" && pwd); t=$d/testdata; pass=0; fail=0
strip() { sed 's/<[^>]*>//g'; }
check() { # name json expected_text expected_state
  jq -e . >/dev/null 2>&1 <<<"$2" || { echo "FAIL $1: invalid JSON: $2"; fail=$((fail+1)); return; }
  local txt st; txt=$(jq -r .text <<<"$2" | strip); st=$(jq -r '.state // ""' <<<"$2")
  if [ "$txt" == "$3" ] && { [ -z "$4" ] || [ "$st" == "$4" ]; }; then pass=$((pass+1))
  else echo "FAIL $1: got '$txt' [$st], want '$3' [$4]"; fail=$((fail+1)); fi; }
check freq1 "$("$d/freq.sh" "$t/freq1")" "      1 0 0 2 1 0" Idle
check freq2 "$("$d/freq.sh" "$t/freq2")" "     0 12 0 0 0 0" Idle
o=$("$d/freq.sh" "$t/freq3"); check freq3 "$o" "      0 0 0 0 0 0 1" Idle
grep -q "#ff0000'>1</span>\"" <<<"$o" || { echo "FAIL freq3: last color"; fail=$((fail+1)); }
check freq4 "$("$d/freq.sh" "$t/freq4")" "FREQ ERR" Critical
cc() { CCUSAGE_JSON=$t/$1 "$d/ccusage.sh"; }
check cc5 "$(cc cc_null.json)" "53.3M CH 96% 1h46m" Good
check cc6 "$(cc cc_100m.json)" "53% 53.3M CH 96% 1h46m" Good
check cc7 "$(cc cc_60m.json)" "89% 53.3M CH 96% 1h46m" Warning
check cc8 "$(cc cc_55m.json)" "97% 53.3M CH 96% 40m" Critical
check cc9 "$(cc cc_empty.json)" "" ""
check cc10 "$(cc cc_bad.json)" "cc err" Critical
# clip text is padded to 5 chars (fixed width), so compare after trimming
cl() { CLIP_TARGETS=$t/$1 CLIP_DATA=$t/${2:-/dev/null} "$d/clip.sh" | jq -c '.text |= gsub("^ +";"")'; }
check clip11 "$(cl targets_empty)" "empty" Info
check clip12 "$(cl targets_text data_5)" "5B" Idle
check clip13 "$(cl targets_text data_2k)" "2.0K" Idle
check clip14 "$(CLIP_TARGETS=$t/targets_img "$d/clip.sh" | jq -c '.text |= gsub("^ +";"")')" "img" Idle
check clip15 "$(cl targets_text data_2m)" ">1M" Idle
check gpu1 "$("$d/gpu.sh" "$t/gpu_ok")" "34° 4781MiB" Idle
check gpu2 "$("$d/gpu.sh" "$t/gpu_bad")" "GPU ERR" Critical
echo "pass=$pass fail=$fail"; [ $fail -eq 0 ]
