#!/usr/bin/env bash
# Middle-click help popup for a bar block (i3bar has no tooltips). Usage: explain.sh <block>; EXPLAIN_DRY=1 prints the text only.
# Block names = the ones used in config.toml click actions. Keep each text to 6 lines.
case ${1:-} in
  kbd)     t='Keyboard layout (US / RU).\nLeft click: switch layout.' ;;
  load)    t='CPU load average, 1 min and 15 min.\nYellow from 0.25, red from 0.5.' ;;
  temp)    t='CPU temperature, max of Tctl/Tccd1/Tccd2, deg C.\nDim from 60, yellow from 70.\nLeft click: toggle min / avg / max.' ;;
  freq)    t='CPU cores per frequency bucket (GHz, rounded):\none count per 1..6+ GHz, blue (1) to red (6+).\nNo state colors.' ;;
  mem)     t='Available memory, GB.\nYellow at 97.8% used, red at 98.9% used.' ;;
  disk)    t='Free space on /, GB.\nYellow below 100 GB, red below 30 GB.\nNot on the DP-2 bar.' ;;
  io)      t='Disk I/O of dm-0, kB/s: R read, W write.\nNot on the DP-2 bar.' ;;
  gpu)     t='GPU temperature (deg C) and VRAM used (GB), nvidia-smi.\nYellow above 60 C, red above 70 C.\nGPU ERR: nvidia-smi failed.' ;;
  net)     t='Ethernet: upload / download speed, kB/s.\nOn DP-0 also the IP address.\n"down" = no link.' ;;
  wifi)    t='Wi-Fi: SSID, signal %, upload / download kB/s.\nHidden when not connected.' ;;
  battery) t='Battery charge, %. Hidden without a battery.' ;;
  sound)   t='Output volume, %; MUT = muted.\nLeft click: open pavucontrol.' ;;
  ccusage) t='Claude Code usage of the active 5h block:\nlimit %, tokens, cache hit (CH), time left.\nGreen, yellow above 70%, red above 90%.\nLeft click: refresh. DP-0 bar only.' ;;
  clip)    t='Clipboard content size (B / K / >1M, img, empty).\nLeft click: open the clipboard menu.' ;;
  time)    t='Date and time.\nLeft click: open the calendar.' ;;
  *) echo "explain.sh: unknown block '${1:-}'" >&2; exit 1 ;;
esac
[ -n "${EXPLAIN_DRY:-}" ] && { printf '%b\n' "$t"; exit 0; }
# detached so the bar never waits for the popup; any click on the button closes it
setsid yad --mouse --undecorated --timeout 8 --on-top --skip-taskbar --borders 8 \
  --text "$(printf '%b' "$t" | sed 's/&/\&amp;/g; s/</\&lt;/g')" --button=OK:0 >/dev/null 2>&1 &
exit 0
