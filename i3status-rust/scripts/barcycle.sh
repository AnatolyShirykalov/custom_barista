#!/bin/bash
# Win+i: cycle bars off -> barista -> rs -> off by rewriting bars.conf (included by the i3 config) and
# reloading i3, so the tray follows the visible bar and the state survives an i3 restart.
# "rs" is two bars (bar-rs on DP-0 with the tray, bar-rs-small on DP-2), always switched together.
d=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=/dev/null
. "${BARS_ENV:-${XDG_CONFIG_HOME:-$HOME/.config}/custom_barista/bars.env}" || { echo "run install.sh first" >&2; exit 1; }

cur=$(sed -n 's/^# state: \([a-z]*\).*/\1/p' "$BARSCONF" 2>/dev/null | head -1)
case "$cur" in
  off)     next=barista ;;
  barista) next=rs ;;
  *)       next=off ;;
esac
"$d/barsconf.sh" "$next" >"$BARSCONF.new" || exit 1
cp -p "$BARSCONF" "$BARSCONF.prev" 2>/dev/null; mv "$BARSCONF.new" "$BARSCONF"
if command -v i3 >/dev/null && ! i3 -C -c "$I3CFG" >/dev/null 2>&1; then
  mv "$BARSCONF.prev" "$BARSCONF"; echo "barcycle: i3 -C failed for state $next, restored" >&2; exit 1
fi
i3-msg reload >/dev/null
