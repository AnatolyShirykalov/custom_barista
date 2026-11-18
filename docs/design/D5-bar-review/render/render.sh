#!/bin/bash
# render.sh CONFIG WIDTH OUT.png [DISPNUM] : real i3bar + i3status-rs in Xvfb; status reads real :0 env
cfg=$1 w=$2 out=$3 n=${4:-77} wait=${WAIT:-9}
d=$(mktemp -d)
cat > $d/i3.conf <<EOC
font pango:PragmataPro Mono, Symbols Nerd Font Mono 18
ipc-socket $d/ipc.sock
bar {
  position bottom
  mode dock
  tray_output none
  font pango:PragmataPro Mono, Symbols Nerd Font Mono 18
  status_command env DISPLAY=:0 i3status-rs $cfg
}
EOC
Xvfb :$n -screen 0 ${w}x120x24 -nolisten tcp >/dev/null 2>&1 & xp=$!
sleep 1
echo "Xft.dpi: 96" | DISPLAY=:$n xrdb -merge
env -u I3SOCK DISPLAY=:$n i3 -c $d/i3.conf >/dev/null 2>&1 & ip=$!
sleep $wait
DISPLAY=:$n import -window root $d/full.png
magick $d/full.png -gravity south -crop ${w}x26+0+0 +repage "$out"
kill $ip 2>/dev/null; sleep 0.5; kill $xp 2>/dev/null; wait 2>/dev/null
rm -rf $d
