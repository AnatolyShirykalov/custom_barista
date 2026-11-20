#!/usr/bin/env bash
# Fake i3status-rs for hover-tee tests: i3bar header, 3 status lines, echoes stdin lines to $FAKE_IN, exits 3.
cat <&0 >"${FAKE_IN:-/dev/null}" &
echo '{"version":1,"click_events":true}'
echo '['
echo '[{"full_text":"a","instance":"0:x"}],'
sleep 0.2
echo ',[{"full_text":"b \"q\"","instance":"1:x"}]'
sleep 0.2
echo ',[{"full_text":"c"}]'
sleep 0.3
exit 3
