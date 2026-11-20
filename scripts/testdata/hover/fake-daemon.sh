#!/usr/bin/env bash
# Fake hover-daemon.py for hover-run.sh tests: logs each start to $FAKE_LOG, exits $FAKE_RC (sleep: runs until killed).
echo start >>"${FAKE_LOG:-/dev/null}"
[ "${FAKE_RC:-0}" = sleep ] && exec sleep 60
exit "${FAKE_RC:-0}"
