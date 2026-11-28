#!/usr/bin/env bash
# Applies the current setup for the user running it: pulls the repo,
# generates i3status-rs configs into ~/.config/custom_barista/, writes the bar blocks to bars.conf next to
# the i3 config (scripts/barsconf.sh, keeps the current Win+i state) and the include line, the $mod+i binding
# and the hover exec_always between "# BEGIN/END custom_barista" markers of ~/.config/i3/config.local
# (scripts/i3block.sh; ~/.i3/config itself is never written).
# Usage: install.sh [--dry-run] [--no-restart] [--yes (accepted, nothing asks any more)]    Safe to rerun.
set -euo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
dry=0; restart=1
for a in "$@"; do
  case $a in
    --dry-run) dry=1 ;;
    --no-restart) restart=0 ;;
    --yes) ;;
    *) echo "usage: $0 [--dry-run] [--no-restart] [--yes]" >&2; exit 2 ;;
  esac
done
say() { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
do_() { if [ $dry = 1 ]; then say "[dry-run] $*"; else "$@"; fi; }

# 1. update
if [ -d "$REPO/.git" ]; then
  if [ -n "$(git -C "$REPO" status --porcelain)" ]; then warn "repo has local changes, skipping git pull"
  else do_ git -C "$REPO" pull --ff-only || warn "git pull failed, continuing with the current checkout"; fi
fi

# 2. dependencies
command -v i3status-rs >/dev/null || warn "missing: i3status-rs (required for the bars)"
for c in jq flock curl nvidia-smi xdotool pavucontrol; do
  command -v "$c" >/dev/null || warn "missing: $c (used by bar blocks/click actions)"
done
command -v ddcutil >/dev/null || warn "M1: monitor block hidden, ddcutil missing: sudo pacman -S ddcutil"
if ! id -nG | tr ' ' '\n' | grep -qx i2c; then
  warn "M1: monitor block hidden, user not in group i2c: sudo usermod -aG i2c $(id -un), then log in again"
fi
[ -e /dev/i2c-0 ] || [ -d /sys/module/i2c_dev ] || warn "M1: monitor block hidden, i2c-dev not loaded: echo i2c-dev | sudo tee /etc/modules-load.d/i2c-dev.conf; sudo modprobe i2c-dev"
command -v yad >/dev/null || warn "missing: yad (optional, calendar popup)"
python3 -c 'import Xlib' 2>/dev/null || warn "missing: python-xlib (hover tooltips, scripts/hover-daemon.py)"
python3 -c 'import gi; gi.require_version("Gtk", "3.0"); from gi.repository import Gtk' 2>/dev/null || warn "missing: python-gobject with Gtk 3 (hover tooltips)"
[ -e "$HOME/scripts/open_calender.sh" ] || warn "missing ~/scripts/open_calender.sh (click action of a bar block; not part of this repo, copy it from the original user)"

# 3. i3status-rs configs: tracked files refer to ~/projects/custom_barista, generate copies with this checkout
CONFDIR=${XDG_CONFIG_HOME:-$HOME/.config}/custom_barista
do_ mkdir -p "$CONFDIR"; do_ chmod 700 "$CONFDIR" # G2: holds gitlab-token, runner-projects; never readable by other users
for f in config.toml compact.toml; do
  if [ $dry = 1 ]; then say "[dry-run] generate $CONFDIR/$f (~/projects/custom_barista -> $REPO)"
  else c=$(<"$REPO/$f"); printf '%s\n' "${c//'~/projects/custom_barista'/$REPO}" >"$CONFDIR/$f"; fi
done

# 3b. U1: tap Claude Code's statusline JSON (rate_limits) for scripts/claude-usage.sh; idempotent, marker-detected
SL=$HOME/.claude/bin/claude-statusline
if [ -f "$SL" ] && grep -q '^input=\$(cat)' "$SL"; then
  if grep -q 'custom_barista: rate_limits tap' "$SL"; then say "U1: statusline tap already installed"
  elif [ $dry = 1 ]; then say "[dry-run] insert the rate_limits tap into $SL"
  else
    [ -e "$SL.bak-u1" ] || cp -p "$SL" "$SL.bak-u1"
    SLR=$(readlink -f "$SL"); line="\"$REPO/scripts/claude-rl-tap.sh\" <<<\"\$input\" >/dev/null 2>&1 || true  # custom_barista: rate_limits tap"
    awk -v l="$line" '{ print } !done && /^input=\$\(cat\)/ { print l; done = 1 }' "$SLR" >"$SLR.tmp.$$" && cat "$SLR.tmp.$$" >"$SLR" && rm -f "$SLR.tmp.$$"
    say "U1: statusline tap installed"
  fi
else say "U1: statusline tap not installed (no ~/.claude/bin/claude-statusline input line); bar uses the API fallback"; fi

# 4. i3 config: ~/.i3/config is managed elsewhere (setup repo) and ends with "include ~/.config/i3/config.local";
# our block goes into that config.local, the main config is only read (validation, warnings), never written
cfg=
for c in "$HOME/.i3/config" "${XDG_CONFIG_HOME:-$HOME/.config}/i3/config"; do [ -f "$c" ] && { cfg=$c; break; }; done
[ -n "$cfg" ] || { warn "no i3 config found (~/.i3/config or ~/.config/i3/config), done without i3 changes"; exit 0; }
local_cfg=${XDG_CONFIG_HOME:-$HOME/.config}/i3/config.local
tl() { case $1 in "$HOME"/*) printf '~%s\n' "${1#"$HOME"}" ;; *) printf '%s\n' "$1" ;; esac; }  # ~ instead of /home/<user>
grep -q '^[[:space:]]*include[[:space:]].*i3/config\.local' "$cfg" || warn "$cfg has no 'include ~/.config/i3/config.local': the bar block there is not loaded"
grep -q '^# BEGIN custom_barista' "$cfg" && warn "$cfg still has an old custom_barista block (not edited here, the file is managed elsewhere): remove it there, the block now lives in $(tl "$local_cfg")"
ob=$(grep -n '^[[:space:]]*bar[[:space:]]*{' "$cfg" || true); [ -z "$ob" ] || warn "bar {} blocks in $cfg (lines $(cut -d: -f1 <<<"$ob" | paste -sd,)) show next to ours"
mod='$mod'; grep -q '^[[:space:]]*set[[:space:]]\+\$mod[[:space:]]' "$cfg" || { mod=Mod4; warn "no 'set \$mod' in $cfg, using Mod4"; }
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
b=$tmp/block
# our block binds Win+i; a second binding elsewhere (main config, or config.local outside our block) makes i3 -C fail
# with a bare "Duplicate keybinding": stop early and say where to remove it
bind_re='[[:space:]]*bindsym[[:space:]]+(\$mod|Mod4)\+i[[:space:]]'
dup=$(grep -nE "^$bind_re" "$cfg" | sed "s|^|$cfg:|" || true)
[ ! -f "$local_cfg" ] || dup+=$(awk '/^# BEGIN custom_barista/{s=1} !s{print FNR": "$0} /^# END custom_barista/{s=0}' "$local_cfg" | grep -E "^[0-9]+: $bind_re" | sed "s|^|$local_cfg:|" || true)
[ -z "$dup" ] || { printf '%s\n' "$dup" >&2; echo "ERROR: Win+i is already bound outside the custom_barista block (above): remove that bindsym in the setup repo (it is not edited here), the block binds it to barcycle.sh" >&2; exit 1; }
# bars live in bars.conf next to the main config (rewritten by barcycle.sh on Win+i); the env file gives the
# generator and barcycle.sh the paths of this install
barsconf=$(dirname "$cfg")/bars.conf
# HOVER (T1 tooltips, 0 = off): from the environment, else kept from the last install, else on; hover-run.sh
# (exec_always) and barsconf.sh (Win+i) read it from bars.env
[ -n "${HOVER:-}" ] || HOVER=$( { sed -n 's/^HOVER=//p' "$CONFDIR/bars.env" 2>/dev/null || true; } | head -1); [ "$HOVER" = 0 ] || HOVER=1
{ printf '%s=%q\n' CONFDIR "$CONFDIR" BARSCONF "$barsconf" I3CFG "$cfg" HOVER "$HOVER"; } >"$tmp/bars.env"
state=$( { sed -n 's/^# state: \([a-z]*\).*/\1/p' "$barsconf" 2>/dev/null || true; } | head -1); [ -n "$state" ] || state=rs  # a saved "barista" state is migrated to rs by barsconf.sh
BARS_ENV=$tmp/bars.env "$REPO/scripts/barsconf.sh" "$state" >"$tmp/bars.conf"
{ echo "# BEGIN custom_barista (generated by install.sh; bar blocks in bars.conf from i3/bars.conf.tmpl)"
  echo "include $(tl "$barsconf")"
  echo "bindsym $mod+i exec --no-startup-id $(tl "$REPO")/scripts/barcycle.sh"
  echo "exec_always --no-startup-id $(tl "$REPO")/scripts/hover-run.sh --replace"
  echo "# END custom_barista"; } >"$b"

if [ $dry = 1 ]; then
  "$REPO/scripts/i3block.sh" -n "$local_cfg" "$b" >"$tmp/new"
  if [ -f "$local_cfg" ] && cmp -s "$local_cfg" "$tmp/new"; then say "[dry-run] $local_cfg unchanged"
  else say "[dry-run] $local_cfg would change:"; diff -u "$( [ -f "$local_cfg" ] && echo "$local_cfg" || echo /dev/null)" "$tmp/new" | sed 's/^/    /' || true; fi
  if [ -f "$barsconf" ] && cmp -s "$barsconf" "$tmp/bars.conf"; then say "[dry-run] $barsconf (state $state) unchanged"
  else say "[dry-run] $barsconf (state $state) would change:"; { if [ -f "$barsconf" ]; then diff -u "$barsconf" "$tmp/bars.conf"; else diff -u /dev/null "$tmp/bars.conf"; fi; } | sed 's/^/    /' || true; fi
  cmp -s "$CONFDIR/bars.env" "$tmp/bars.env" || say "[dry-run] write $CONFDIR/bars.env"
  exit 0
fi
cp "$tmp/bars.env" "$CONFDIR/bars.env"
changed=0; stamp=$(date +%F-%H%M)
if cmp -s "$barsconf" "$tmp/bars.conf"; then say "bars.conf already up to date"; else
  [ -f "$barsconf" ] && cp -p "$barsconf" "$barsconf.bak-$stamp"
  cp "$tmp/bars.conf" "$barsconf"; changed=1; say "bars.conf written (state $state)"
fi
existed=0; [ -e "$local_cfg" ] && existed=1
bak=$local_cfg.bak-$stamp  # next to the (maybe symlinked) file, not in the link target's repo
wrote=0
res=$("$REPO/scripts/i3block.sh" "$local_cfg" "$b" "$bak") || { warn "writing $local_cfg failed (see above), nothing changed there"; exit 1; }
if [ "$res" = unchanged ]; then say "$(tl "$local_cfg") already up to date"
else changed=1; wrote=1; say "$(tl "$local_cfg") updated$([ $existed = 1 ] && echo ", backup: $bak")"; fi
if [ $changed = 1 ] && command -v i3 >/dev/null && ! i3 -C -c "$cfg" >"$tmp/val" 2>&1; then
  cat "$tmp/val" >&2
  if [ $wrote = 1 ]; then if [ $existed = 1 ]; then cat "$bak" >"$local_cfg"; else rm -f "$local_cfg"; fi; fi
  if [ -f "$barsconf.bak-$stamp" ]; then cp -p "$barsconf.bak-$stamp" "$barsconf"; else rm -f "$barsconf"; fi
  echo "ERROR: i3 config validation (i3 -C -c $cfg) failed, restored the previous config.local/bars.conf" >&2; exit 1
fi
if [ $restart = 1 ] && command -v i3-msg >/dev/null && i3-msg -t get_version >/dev/null 2>&1; then i3-msg restart >/dev/null && say "i3 restarted"; fi
say "done"
