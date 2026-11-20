#!/usr/bin/env bash
# T1 hover daemon supervisor (spec 2.2): single instance (flock), restarts hover-daemon.py after a crash with
# backoff 1, 2, 4, 8, 16 s; more than 5 crashes in 10 min: give up until the next i3 (re)start. Exit 0 of the
# daemon (X gone, SIGTERM) stops. --replace (i3 exec_always): stop the running supervisor and its daemon first.
# HOVER=0 in bars.env (install.sh): stop a running one, remove the tap files, exit.
# Log: $dir/hover.log, cut to its last 200 lines at each daemon start.
# Tests: HOVER_DAEMON (daemon command), HOVER_RUN_SLEEP (fixed restart delay), BARS_ENV.
d=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=/dev/null
. "${BARS_ENV:-${XDG_CONFIG_HOME:-$HOME/.config}/custom_barista/bars.env}" 2>/dev/null
# same rule as hover/rundir.py: no XDG_RUNTIME_DIR = a private /tmp/custom_barista-$UID, refused if not ours
if [ -n "${HOVER_DIR:-}" ]; then dir=$HOVER_DIR
elif [ -n "${XDG_RUNTIME_DIR:-}" ]; then dir=$XDG_RUNTIME_DIR/custom_barista/hover
else
  base=/tmp/custom_barista-$UID; mkdir -m 0700 "$base" 2>/dev/null
  [ -d "$base" ] && [ ! -L "$base" ] && [ -O "$base" ] && [ "$(stat -c %a "$base")" = 700 ] || { echo "hover-run: $base is not a private dir of uid $UID" >&2; exit 1; }
  dir=$base/hover
fi
mkdir -p "$dir" && chmod 0700 "$dir" || exit 1
log=$dir/hover.log
# own process group, so --replace can stop supervisor and daemon together
[ "$(ps -o pgid= $$ | tr -d ' ')" = $$ ] || exec setsid "$0" "$@"
# stop the old supervisor only if the pid still is one (not a reused pid after a give-up exit)
if { [ "${1:-}" = --replace ] || [ "${HOVER:-1}" = 0 ]; } && old=$(cat "$dir/daemon.pid" 2>/dev/null) && [ -n "$old" ] && [ "$old" != $$ ] \
   && tr '\0' ' ' 2>/dev/null <"/proc/$old/cmdline" | grep -q 'hover-run\.sh'; then
  kill -TERM -- -"$old" 2>/dev/null
  for _ in 1 2 3 4 5 6 7 8 9 10; do kill -0 "$old" 2>/dev/null || break; sleep 0.1; done
  kill -0 "$old" 2>/dev/null && kill -9 -- -"$old" 2>/dev/null
fi
if [ "${HOVER:-1}" = 0 ]; then
  rm -f "$dir"/*.status.json "$dir"/*.click.json "$dir/daemon.pid"
  echo "$(date '+%F %T') hover-run: HOVER=0, not started" >>"$log"; exit 0
fi
exec 9>"$dir/daemon.lock"
flock -n 9 || exit 0
echo $$ >"$dir/daemon.pid"
child=
trap '[ -n "$child" ] && kill "$child" 2>/dev/null; exit 0' TERM INT
crashes=()
while :; do
  [ -f "$log" ] && { tail -n 200 "$log" >"$log.tmp" && mv "$log.tmp" "$log"; }
  ${HOVER_DAEMON:-python3 "$d/hover-daemon.py"} >>"$log" 2>&1 9>&- & child=$!
  wait $child; rc=$?; child=
  [ $rc = 0 ] && { echo "$(date '+%F %T') hover-run: daemon stopped" >>"$log"; exit 0; }
  now=$(date +%s); keep=()
  for t in "${crashes[@]}"; do [ $((now - t)) -lt 600 ] && keep+=("$t"); done
  crashes=("${keep[@]}" "$now")
  n=${#crashes[@]}
  [ $n -gt 5 ] && { echo "$(date '+%F %T') hover-run: $n crashes in 10 min, giving up until the next i3 restart" >>"$log"; exit 1; }
  delay=$((1 << (n - 1)))
  echo "$(date '+%F %T') hover-run: daemon exit $rc, restart in ${delay}s" >>"$log"
  sleep "${HOVER_RUN_SLEEP:-$delay}" & wait $!
done
