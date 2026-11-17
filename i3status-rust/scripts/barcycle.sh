#!/bin/bash
# Win+i: cycle bars off -> barista -> rs -> off. Config default is barista (restart resets to it).
state_file="${XDG_RUNTIME_DIR:-/tmp}/barcycle.state"

mode_of() { i3-msg -t get_bar_config "$1" | grep -o '"mode": *"[a-z]*"' | grep -o '[a-z]*"$' | tr -d '"'; }

# Derive the current state from the real modes (a restart/reload resets them, the file may be stale).
b=$(mode_of bar-barista); r=$(mode_of bar-rs)
if [ "$b" = dock ]; then cur=barista
elif [ "$r" = dock ]; then cur=rs
elif [ "$b" = invisible ] && [ "$r" = invisible ]; then cur=off
else cur=$(cat "$state_file" 2>/dev/null); fi

case "$cur" in
  off)     next=barista; bm=dock;      rm=invisible ;;
  barista) next=rs;      bm=invisible; rm=dock ;;
  *)       next=off;     bm=invisible; rm=invisible ;;
esac
i3-msg "bar mode $bm bar-barista; bar mode $rm bar-rs" >/dev/null
echo "$next" > "$state_file"
