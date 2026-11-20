#!/usr/bin/env bash
# Help text for a bar block, shown by the hover popup (i3bar has no tooltips). Usage: explain.sh <block>; EXPLAIN_DRY=1 is accepted and ignored.
# Block names = the keys of scripts/hover/keys.toml. Keep each text to 6 lines.
case ${1:-} in
  kbd)     t='Keyboard layout (US / RU).\nLeft click: switch layout.' ;;
  load)    t='CPU load average, 1 min and 15 min.\nYellow from 0.25, red from 0.5.' ;;
  temp)    t='CPU temperature, max of Tctl/Tccd1/Tccd2, deg C.\nDim from 60, yellow from 70.\nLeft click: toggle min / avg / max.' ;;
  freq)    t='CPU cores per frequency bucket (GHz, rounded):\none count per 1..6+ GHz, blue (1) to red (6+).\nNo state colours.' ;;
  mem)     t='Available memory, GB.\nYellow at 97.8% used, red at 98.9% used.' ;;
  disk)    t='Free space on /, GB.\nYellow below 100 GB, red below 30 GB.\nNot on the DP-2 bar.' ;;
  io)      t='Disk I/O of dm-0, kB/s: R read, W write.\nNot on the DP-2 bar.' ;;
  gpu)     t='GPU temperature (deg C) and VRAM used (GB), nvidia-smi.\nYellow above 60 C, red above 70 C.\nGPU ERR: nvidia-smi failed.' ;;
  net)     t='Ethernet: upload / download speed, kB/s.\nOn DP-0 also the IP address.\n"down" = no link.' ;;
  wifi)    t='Wi-Fi: SSID, signal %, upload / download kB/s.\nHidden when not connected.' ;;
  battery) t='Battery charge, %. Hidden without a battery.' ;;
  sound)   t='Output volume, %; MUT = muted.\nLeft click: open pavucontrol.' ;;
  ccusage) t='Claude usage, current 5h window: limit %, tokens, cost, cache (share\nof input read from cache), time to reset. Each part has its own colour.\nLimit %: green, yellow above 70, red above 90, grey = stale.\nCache: green from 90, yellow 70-89, red below 70.\n7d NN%: weekly limit; grey to 70, yellow above, red above 90; ?% = unknown.\ncc … = waiting for first data. Left click: refresh. DP-0 bar only.' ;;
  time)    t='Date and time.\nLeft click: open the calendar.' ;;
  *) echo "explain.sh: unknown block '${1:-}'" >&2; exit 1 ;;
esac
printf '%b\n' "$t"
