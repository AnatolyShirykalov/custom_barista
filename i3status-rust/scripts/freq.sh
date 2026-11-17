#!/usr/bin/env bash
# CPU frequency histogram, parity with freq/freq.go. Arg 1: cpu sysfs root (tests).
set -u
root=${1:-/sys/devices/system/cpu}
files=("$root"/cpu[0-9]*/cpufreq/scaling_cur_freq)
out=
[ -r "${files[0]}" ] && out=$(cat "${files[@]}" 2>/dev/null | awk '
  BEGIN { split("#4a9eff #5bc0de #5cb85c #f0ad4e #ff8c42 #d9534f", col, " ") }
  /^[0-9]+$/ { b = int(($1 + 500000) / 1000000); if (b > 0) { c[b]++; if (b > max) max = b } n++ }
  END {
    if (!n) exit 1
    L = max < 6 ? 6 : max
    for (i = 1; i <= L; i++) if (c[i] >= 10) two++
    # pad: 1 space per missing digit (fixed width), counts right-aligned by the pad only
    pad = (L < 6 ? L : 6) - two
    s = sprintf("%" pad "s", "")
    for (i = 1; i <= L; i++) {
      color = i <= 6 ? col[i] : "#ff0000"
      s = s (i > 1 ? " " : "") "<span color=\047" color "\047>" c[i] + 0 "</span>"
    }
    print s
  }')
if [ -n "$out" ]; then
  jq -nc --arg t "$out" '{icon:"cpu_freq",state:"Idle",text:$t}'
else
  echo '{"icon":"cpu_freq","state":"Critical","text":"FREQ ERR"}'
fi
exit 0
