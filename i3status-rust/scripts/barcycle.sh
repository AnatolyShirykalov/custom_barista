#!/bin/bash
# Win+i: cycle bars off -> barista -> rs -> off by rewriting bars.conf (included by the i3 config) and
# reloading i3: the two bars (bar-main on DP-0 with the tray, bar-small on DP-2) switch mode and
# status_command together, the tray never changes owner, and the state survives an i3 restart.
d=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=/dev/null
. "${BARS_ENV:-${XDG_CONFIG_HOME:-$HOME/.config}/custom_barista/bars.env}" || { echo "run install.sh first" >&2; exit 1; }

# One press at a time: Win+i presses in quick succession used to run concurrently, read the same state
# (presses lost, "mv: cannot stat bars.conf.new").
exec 9>"$BARSCONF.lock" && flock 9 || exit 1

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
# Hold the lock until i3bar has restarted the status command and re-docked the tray icons. Do not drop this:
# i3bar 4.25 freezes (killpg before the new child's setpgid, then waitpid forever) when a second command
# switch arrives right after the first.
sleep "${BARCYCLE_SETTLE:-0.4}"
