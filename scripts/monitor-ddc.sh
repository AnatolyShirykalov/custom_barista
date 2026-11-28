#!/usr/bin/env bash
# Monitor brightness/contrast block over DDC/CI (ddcutil), one connector per bar.
# Usage: monitor-ddc.sh <conn> bright|contrast [up|down]   block json / scroll step (+-5, clamp 0..100)
#        monitor-ddc.sh <conn> refresh|info                re-read both values from the monitor / hover text
#        monitor-ddc.sh <conn> worker|refresh-run          internal (background)
# Render reads only the state file (instant); setvcp/getvcp run in flock'd background jobs, one ddcutil user per monitor.
# Spec: docs/design/M1-monitor-ddc/spec.md. Test overrides: DDC_STATE_DIR, DDC_CMD, XRANDR_CMD, DRM_DIR, DDC_I2C_GLOB,
# DDC_NOW (epoch), DDC_SIGNAL=0 (no pkill), DDC_FG=1 (refresh inline), DDC_CONFIG (config.toml for the dim colour).
set -u
conn=${1:-}; op=${2:-}; arg=${3:-}
self=$(readlink -f "$0")
ddc=${DDC_CMD:-ddcutil}; xr=${XRANDR_CMD:-xrandr}; drm=${DRM_DIR:-/sys/class/drm}
dir=${DDC_STATE_DIR:-}
if [ -z "$dir" ]; then
  if [ -n "${XDG_RUNTIME_DIR:-}" ]; then dir=$XDG_RUNTIME_DIR/custom_barista/ddc
  else dir=/tmp/custom_barista-$UID/ddc; fi
fi
[[ $conn =~ ^[A-Za-z0-9-]+$ ]] || { echo '{"text":"DDC ERR","state":"Critical"}'; exit 0; }
umask 077; mkdir -p "$dir" 2>/dev/null
[ -O "$dir" ] || { echo '{"text":"DDC ERR","state":"Critical"}'; exit 0; }
sf=$dir/$conn.state lock=$dir/$conn.lock wlock=$dir/$conn.worker.lock
now() { if [ -n "${DDC_NOW:-}" ]; then echo "$DDC_NOW"; else printf '%(%s)T' -1; fi; }
KEYS=(bright contrast seq read_ts try_ts read_err werr_bright werr_contrast abright acontrast bus model drm hidden resolve_ts)
declare -A S
load() { S=(); local k v; [ -r "$sf" ] || return 0
  while IFS='=' read -r k v; do [[ $k =~ ^[a-z_]+$ ]] && S[$k]=$v; done <"$sf"; }
save() { local k; { for k in "${KEYS[@]}"; do printf '%s=%s\n' "$k" "${S[$k]:-}"; done; } >"$sf.$$" && mv -f "$sf.$$" "$sf"; }
# locked <fn> args...: load, run fn (edits S), save, all under the state lock
locked() { ( flock -w 1 9 || exit 1; load; "$@"; save ) 9>"$lock"; }
setk() { while [ $# -ge 2 ]; do S[$1]=$2; shift 2; done; }   # setk k v [k v]... for use under `locked`
signal() { [ "${DDC_SIGNAL:-1}" = 0 ] || pkill -u "$UID" -RTMIN+7 -x i3status-rs 2>/dev/null; return 0; }
bg() { setsid "$@" </dev/null >/dev/null 2>&1 & }

render() { # $1 = bright|contrast
  local code=$1 icon v st=Idle n tn dim hid cfg=${DDC_CONFIG:-${self%/*}/../config.toml}
  tn=$(now); load
  hid=${S[hidden]:-}
  if [ -n "$hid" ]; then echo '{"text":""}'; need_refresh "$tn"; return; fi
  [ "$code" = bright ] && icon=$'\U000F00E0' || icon=$'\U000F00DF'
  v=${S[$code]:-}
  if [[ $v =~ ^[0-9]+$ ]]; then
    n=$(printf '%3d' "$v")
    if [ "${S[read_err]:-0}" = 1 ] || ! [[ ${S[read_ts]:-} =~ ^[0-9]+$ ]] || [ $((tn - S[read_ts])) -gt 300 ]; then st=Info; fi
  else n=' --'; st=Info; fi
  [ "${S[werr_$code]:-0}" = 1 ] && st=Critical
  dim=$(sed -n 's/^info_fg *= *"\(#[0-9a-fA-F]*\)".*/\1/p' "$cfg" 2>/dev/null | head -1)  # theme dim-icon, as claude-usage.sh
  printf '{"text":" <span foreground='"'%s'"'>%s</span>%s ","state":"%s"}\n' "${dim:-#777777}" "$icon" "$n" "$st"
  need_refresh "$tn"
}
need_refresh() { # background refresh when the bus is unresolved (every 300 s) or the read is older than 60 s (throttled to 30 s)
  local tn=$1 r=${S[read_ts]:-} t=${S[try_ts]:-} rs=${S[resolve_ts]:-}
  if [[ $t =~ ^[0-9]+$ ]] && [ $((tn - t)) -lt 30 ]; then return; fi
  if [ -z "${S[bus]:-}" ]; then
    [[ $rs =~ ^[0-9]+$ ]] && [ $((tn - rs)) -le 300 ] && return
  else
    [[ $r =~ ^[0-9]+$ ]] && [ $((tn - r)) -le 60 ] && return
  fi
  # claim the run inside the lock: another render may have claimed it since the check above
  [ "$( ( flock -w 1 9 || exit 1; load; t=${S[try_ts]:-}
          if [[ $t =~ ^[0-9]+$ ]] && [ $((tn - t)) -lt 30 ]; then echo 0; else S[try_ts]=$tn; save && echo 1; fi ) 9>"$lock")" = 1 ] && bg "$self" "$conn" refresh-run
}

step() { # $1 = code, $2 = up|down; under `locked`
  local v=${S[$1]:-} d=5
  [[ $v =~ ^[0-9]+$ ]] && [ -z "${S[hidden]:-}" ] || { STEPPED=0; return; }
  [ "$2" = down ] && d=-5
  v=$((v + d)); [ $v -lt 0 ] && v=0; [ $v -gt 100 ] && v=100
  [ -z "${S[a$1]:-}" ] && S[a$1]=${S[$1]}
  S[$1]=$v; S[seq]=$(( ${S[seq]:-0} + 1 )); STEPPED=1
}
scroll() {
  local out; out=$( ( flock -w 1 9 || exit 1; load; STEPPED=0; step "$1" "$2"; [ $STEPPED = 1 ] && save; echo $STEPPED ) 9>"$lock")
  [ "$out" = 1 ] && bg "$self" "$conn" worker
}

apply() { # $1 code name, $2 value: setvcp with one retry; returns 0 on success
  local c=10; [ "$1" = contrast ] && c=12
  for _ in 1 2; do
    timeout 10 "$ddc" --bus "${S[bus]}" --noverify --sleep-multiplier .1 setvcp $c "$2" >/dev/null 2>&1 && return 0
  done; return 1
}
worker() {
  exec 8>"$wlock"; flock -n 8 || exit 0
  sleep 0.2
  local code want seq0
  for _ in $(seq 30); do
    load; seq0=${S[seq]:-0}
    [ -n "${S[bus]:-}" ] || break
    for code in bright contrast; do
      want=${S[$code]:-}; [[ $want =~ ^[0-9]+$ ]] || continue
      [ "$want" = "${S[a$code]:-$want}" ] && continue
      if apply "$code" "$want"; then locked setk "a$code" "$want" "werr_$code" 0
      else locked setk "werr_$code" 1; fi
    done
    load; [ "${S[seq]:-0}" = "$seq0" ] && break
  done
  signal
}

edid_hex() { # hex of the first 128 bytes of the connector's EDID from xrandr
  timeout 5 "$xr" --prop 2>/dev/null | awk -v c="$conn" '
    $1 == c { f = 1; next } /^[^ \t]/ { f = 0 }
    f && /^\t+EDID:/ { g = 1; next } f && g && /^\t+[0-9a-fA-F]+$/ { gsub(/[ \t]/, ""); h = h $0; next } f && g { g = 0 }
    END { print tolower(substr(h, 1, 256)) }'
}
connected() { timeout 5 "$xr" --query 2>/dev/null | awk -v c="$conn" '$1 == c { print $2; exit }'; }
resolve() { # probes xrandr/ddcutil (slow, no lock); sets R_bus R_model R_drm R_hidden
  local hid='' edid='' f dn='' bus='' model='' blk k mfg ok
  if ! command -v "$ddc" >/dev/null 2>&1; then hid=no-ddcutil
  else
    ok=0; for f in ${DDC_I2C_GLOB:-/dev/i2c-*}; do [ -r "$f" ] && [ -w "$f" ] && { ok=1; break; }; done
    [ $ok = 1 ] || hid=no-i2c-access
  fi
  if [ -z "$hid" ]; then
    edid=$(edid_hex)
    if [ "$(connected)" != connected ] || [ ${#edid} -lt 256 ]; then hid=disconnected; fi
  fi
  if [ -z "$hid" ]; then
    dn=''; for f in "$drm"/card*-*/edid; do
      [ -r "$f" ] || continue
      [ "$(od -An -v -tx1 -N128 "$f" 2>/dev/null | tr -d ' \n')" = "$edid" ] && { dn=$(basename "$(dirname "$f")"); break; }
    done
    blk=$(timeout 15 "$ddc" detect --terse 2>/dev/null | awk '
      /^Display / { if (b != "") print b "|" d "|" m; b = d = m = "" }
      /I2C bus:/ { b = $NF; sub(/.*i2c-/, "", b) } /DRM connector:/ { d = $NF }
      /Monitor:/ { m = $0; sub(/^[^:]*:[ \t]*/, "", m) }
      END { if (b != "") print b "|" d "|" m }')
    if [ -n "$dn" ]; then bus=$(awk -F'|' -v d="$dn" '$2 == d { print $1 "|" $3; exit }' <<<"$blk"); fi
    if [ -z "$bus" ]; then  # fallback: EDID manufacturer id vs the Monitor: prefix, only when unique
      k=$(( (16#${edid:16:4}) )); mfg=$(printf "\\x$(printf %x $(( ((k >> 10) & 31) + 64 )))\\x$(printf %x $(( ((k >> 5) & 31) + 64 )))\\x$(printf %x $(( (k & 31) + 64 )))")
      bus=$(awk -F'|' -v m="$mfg:" 'index($3, m) == 1 { n++; r = $1 "|" $3 } END { if (n == 1) print r }' <<<"$blk")
    fi
    if [ -z "$bus" ]; then hid=no-ddc; else model=${bus#*|}; model=${model#*:}; model=${model%%:*}; bus=${bus%%|*}; fi
  fi
  R_hidden=$hid; R_bus=$bus; R_model=$model; R_drm=$dn
  [ -n "$hid" ] && R_bus=''
}
store_resolve() { # under `locked`; a new bus drops pending values meant for the old monitor
  [ "${S[bus]:-}" != "$R_bus" ] && setk abright "" acontrast "" werr_bright 0 werr_contrast 0
  setk resolve_ts "$(now)" hidden "$R_hidden" bus "$R_bus" model "$R_model" drm "$R_drm"
}
read_ok() { # $1 bright $2 contrast $3 seq0; under `locked`; a code with a change still pending (worker not failed) keeps the wanted value
  local c i=1 v
  S[read_ts]=$(now); S[read_err]=0
  [ "${S[seq]:-0}" = "$3" ] || return 0
  for c in bright contrast; do
    v=${!i}; i=$((i + 1))
    [ -n "${S[a$c]:-}" ] && [ "${S[a$c]}" != "${S[$c]:-}" ] && [ "${S[werr_$c]:-0}" != 1 ] && continue
    setk "$c" "$v" "a$c" "$v" "werr_$c" 0
  done
}
clear_bus() { setk bus "" resolve_ts "$(now)" abright "" acontrast "" werr_bright 0 werr_contrast 0; }  # standby: wait 300 s before detecting again
refresh_run() {
  load
  if [ -z "${S[bus]:-}" ]; then resolve; locked store_resolve; load; fi
  [ -n "${S[bus]:-}" ] || { signal; return; }
  exec 8>"$wlock"; flock -n 8 || return 0
  local seq0=${S[seq]:-0} out b='' c='' rc
  out=$(timeout 10 "$ddc" --bus "${S[bus]}" --sleep-multiplier .1 --brief getvcp 10 12 2>&1); rc=$?
  b=$(awk '$1 == "VCP" && $2 == "10" && $3 == "C" { print $4; exit }' <<<"$out")
  c=$(awk '$1 == "VCP" && $2 == "12" && $3 == "C" { print $4; exit }' <<<"$out")
  if [ $rc = 0 ] && [[ $b =~ ^[0-9]+$ ]] && [[ $c =~ ^[0-9]+$ ]]; then locked read_ok "$b" "$c" "$seq0"
  else
    locked setk read_err 1
    grep -qiE 'no such (file|device)|not found|unable to open' <<<"$out" && locked clear_bus
  fi
  # a scroll during the read started a worker that found worker.lock busy and quit: hand its value on
  exec 8>&-; load; [ "${S[seq]:-0}" != "$seq0" ] && bg "$self" "$conn" worker
  signal
}

info() {
  load; local hid=${S[hidden]:-} why t
  if [ -n "$hid" ]; then
    case $hid in
      no-ddcutil) why='ddcutil not installed' ;;
      no-i2c-access) why='no access to /dev/i2c-* (group i2c)' ;;
      disconnected) why="$conn not connected" ;;
      *) why='monitor has no DDC/CI' ;;
    esac
    echo "Hidden: $why"; return
  fi
  echo "${S[model]:-Monitor} on $conn: brightness / contrast over DDC/CI (bus /dev/i2c-${S[bus]:-?})."
  t=; [[ ${S[read_ts]:-} =~ ^[0-9]+$ ]] && t=$(date -d "@${S[read_ts]}" +%H:%M:%S)
  if [ -z "$t" ]; then echo "Not read yet."
  elif [ "${S[read_err]:-0}" = 1 ]; then echo "Not answering since $t (standby or busy); last known values."
  else echo "Brightness ${S[bright]:---}, contrast ${S[contrast]:---} (read $t)."; fi
  echo "Scroll: +-5 (0-100). Left click: read again from the monitor."
  echo "Grey: monitor not answering, last known values. Red: change not applied."
}

case $op in
  bright|contrast) if [ -z "$arg" ]; then render "$op"; else [[ $arg =~ ^(up|down)$ ]] && scroll "$op" "$arg"; fi ;;
  refresh) if [ "${DDC_FG:-}" = 1 ]; then refresh_run; else bg "$self" "$conn" refresh-run; fi ;;
  refresh-run) refresh_run ;;
  worker) worker ;;
  info) info ;;
  *) echo "usage: $0 <conn> bright|contrast [up|down] | refresh | info" >&2; exit 2 ;;
esac
exit 0
