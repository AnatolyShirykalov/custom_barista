#!/usr/bin/env bash
# "Reboot needed" block: prints {"text":""} (hidden) when nothing applies. No root. Arg `list` prints the triggering packages (hover popup).
#   1. running kernel's /usr/lib/modules dir gone (kernel upgraded) -> Critical "reboot: kernel old->new"
#   2. BOOT_PKGS upgraded/installed in pacman.log after boot -> Warning "reboot"
#   3. SESSION_PKGS changed after the i3 process started -> Info (dim) "relogin"
# Edit the two package lists here (shell globs, space separated).
BOOT_PKGS='nvidia* linux-firmware* amd-ucode intel-ucode systemd glibc dbus* mkinitcpio cryptsetup'
SESSION_PKGS='xorg-server i3-wm mesa pipewire wireplumber picom'
# Test overrides: UNAME_R, MODULES_DIR, PACMAN_LOG, BTIME (epoch), SESSION_START (epoch, else the i3 process start), INSTALLED_KVER, NOW
set -u
mode=${1:-}
uname_r=${UNAME_R:-$(uname -r)}
mods=${MODULES_DIR:-/usr/lib/modules/$uname_r}
log=${PACMAN_LOG:-/var/log/pacman.log}
now=${NOW:-$(date +%s)}
btime=${BTIME:-$(awk '$1 == "btime" {print $2}' /proc/stat 2>/dev/null)}
err() { echo '{"icon":"reboot","state":"Critical","text":"REBOOT ERR"}'; exit 0; }
[[ $btime =~ ^[0-9]+$ ]] || err
sess=${SESSION_START:-}
if [ -z "$sess" ]; then
  pid=$(timeout 2 pgrep -xo i3 2>/dev/null); et=
  [ -n "$pid" ] && et=$(timeout 2 ps -o etimes= -p "$pid" 2>/dev/null | tr -d ' ')
  [[ $et =~ ^[0-9]+$ ]] && sess=$((now - et)) || sess=$now
fi
# packages whose upgrade/install is logged after epoch $2, matching globs $1: "name old -> new" lines
pkgs_since() {
  [ -r "$log" ] || return 0
  awk -v pats="$1" -v thr="$(date -d "@$2" +%Y-%m-%dT%H:%M:%S)" '
    BEGIN { n = split(pats, p, " "); for (i = 1; i <= n; i++) { gsub(/\*/, ".*", p[i]); p[i] = "^" p[i] "$" } }
    $3 ~ /^(upgraded|installed|reinstalled)$/ && substr($1, 2, 19) > thr {
      for (i = 1; i <= n; i++) if ($4 ~ p[i]) { v = $0; sub(/^[^(]*\(/, "", v); sub(/\)$/, "", v); last[$4] = v; break } }
    END { for (k in last) print k, last[k] }' "$log" | sort
}
kern=
if [ ! -d "$mods" ]; then
  inst=${INSTALLED_KVER:-$(timeout 3 pacman -Q linux 2>/dev/null | awk '{print $2}' | sed 's/\.arch.*//')}
  [ -z "$inst" ] && inst=$(ls -1 "$(dirname "$mods")" 2>/dev/null | sort -V | tail -1 | sed 's/-.*//')
  kern="kernel ${uname_r%%-*}→${inst:-?}"
fi
boot=$(pkgs_since "$BOOT_PKGS" "$btime")
rel=$(pkgs_since "$SESSION_PKGS" "$sess")
# "name old -> new" lines -> one line per family (name minus last -segment) sharing a version: "linux-firmware (14 pkgs) old→new"
collapse() {
  awk '{ N[++t] = $1; v = $2; for (i = 3; i <= NF; i++) v = v " " $i; gsub(/ -> /, "→", v); V[t] = v; has[$1 SUBSEP v] = 1 }
       END { for (j = 1; j <= t; j++) { k = N[j]; sub(/-[^-]+$/, "", k); par[k SUBSEP V[j]] = 1 }
             for (j = 1; j <= t; j++) { k = N[j]; if (!((k SUBSEP V[j]) in par)) sub(/-[^-]+$/, "", k)
               if (!((k SUBSEP V[j]) in has)) k = k "*"   # no base package: family of siblings
               id = k SUBSEP V[j]; if (!(id in cnt)) { ord[++m] = id; key[id] = k; ver[id] = V[j]; first[id] = N[j] }
               cnt[id]++ }
             for (i = 1; i <= m; i++) { id = ord[i]; k = key[id]
               if (k ~ /\*$/ && cnt[id] == 1) printf "  %s %s\n", first[id], ver[id]
               else if (cnt[id] > 1) { sub(/\*$/, "", k); printf "  %s (%d pkgs) %s\n", k, cnt[id], ver[id] }
               else printf "  %s %s\n", first[id], ver[id] } }'
}
if [ "$mode" = list ]; then
  {
    [ -n "$kern" ] && echo "$kern"
    [ -n "$boot" ] && { echo "Need reboot:"; collapse <<<"$boot"; }
    [ -n "$rel" ] && { echo "Need relogin:"; collapse <<<"$rel"; }
  } >"${TMPDIR:-/tmp}/rb.$$"
  max=${LIST_MAX:-8}; tot=$(wc -l <"${TMPDIR:-/tmp}/rb.$$")
  if [ "$tot" -gt "$max" ]; then head -n $((max - 1)) "${TMPDIR:-/tmp}/rb.$$"; echo "  +$((tot - max + 1)) more"
  else cat "${TMPDIR:-/tmp}/rb.$$"; fi
  rm -f "${TMPDIR:-/tmp}/rb.$$"
  exit 0
fi
if [ -n "$kern" ]; then echo "{\"icon\":\"reboot\",\"state\":\"Critical\",\"text\":\"reboot: $kern\"}"
elif [ -n "$boot" ]; then echo '{"icon":"reboot","state":"Warning","text":"reboot"}'
elif [ -n "$rel" ]; then echo '{"icon":"reboot","state":"Info","text":"relogin"}'
else echo '{"text":""}'   # json block: empty output is "Invalid JSON"; empty text is hidden by hide_when_empty
fi
exit 0
