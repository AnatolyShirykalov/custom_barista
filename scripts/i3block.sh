#!/usr/bin/env bash
# Writes the "# BEGIN/END custom_barista" block of BLOCK into FILE (the per-user i3 config.local): replaces
# the block where it is, else appends it; keeps all other lines; creates FILE and its directory if missing.
# Writes through a symlinked FILE in place (cat >), so the link and its target's location stay.
# Usage: i3block.sh [-n] FILE BLOCK [BACKUP]   -n: print the new content, write nothing.
# Prints "unchanged" or "updated" (BACKUP: copy of the old FILE made before the write, if FILE existed).
set -euo pipefail
dry=0; [ "${1:-}" = -n ] && { dry=1; shift; }
f=$1; b=$2; bak=${3:-}
old=; [ -e "$f" ] && old=$(cat "$f")
if grep -q '^# BEGIN custom_barista' <<<"$old"; then
  grep -q '^# END custom_barista' <<<"$old" || { echo "ERROR: $f has '# BEGIN custom_barista' without '# END custom_barista', not writing" >&2; exit 1; }
  new=$(awk -v bf="$b" '/^# BEGIN custom_barista/{while((getline l < bf)>0) print l; skip=1} !skip{print} /^# END custom_barista/{skip=0}' <<<"$old")
elif [ -n "$old" ]; then new=$old$'\n'$(cat "$b")
else new=$(cat "$b"); fi
[ $dry = 1 ] && { printf '%s\n' "$new"; exit 0; }
if [ -e "$f" ] && [ "$new" = "$old" ]; then echo unchanged; exit 0; fi
[ -n "$bak" ] && [ -e "$f" ] && cp -pL "$f" "$bak"
mkdir -p "$(dirname "$(readlink -m "$f")")"
printf '%s\n' "$new" >"$f"
echo updated
