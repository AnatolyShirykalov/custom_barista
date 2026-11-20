# Backlog

Open work items that are not next. **Not read at session start**: `/roadmap` reads only docs/ROADMAP.md; this file is opened when "Queued next" there runs empty, at an intake of new requests, and by `/wrapup`, which moves the next 5-10 items into "Queued next". New items (follow-ups, proposals, ideas) are added here, under the fitting section, unless they are next. Done items never stay here: they go to `docs/roadmap-archive/` at wrapup.

Work items are checkboxes (`1. [ ]`): what, where, done condition, `→ agent-name`. The status line shows their count as "+N backlog".

_(empty: add new items here)_

## Bar blocks

- [ ] **U1c first-run placeholder**: on a fresh user (no statusline tap, empty ~/.cache/claude-usage) the usage block stays hidden for minutes until the first API poll lands (seen for anatolii 2026-11-18); show a dim `cc …` placeholder instead of hiding while no data has been fetched yet. Done: fixture row for empty cache → placeholder, width fixed. → `widget-builder`
- [ ] **install.sh stale deps**: drop `node`/`npx` from the dependency warnings (ccusage removed in U1). Done: no node/npx check, test.sh green. → `widget-builder`
- [ ] **(medium) HOVER=0 does not stick**: `install.sh:78` writes bars.env without `HOVER`, so the next Win+i (`barcycle.sh` -> `barsconf.sh:13`) wraps the bars in hover-tee again; `install.sh:84` starts `hover-run.sh` anyway, and the daemon reads stale `$HOVER_DIR/*.status.json` from an earlier hover session (popups at old positions). Done: HOVER persisted in bars.env, no exec_always line (or daemon idle) with HOVER=0, stale status files ignored (age or removed at hover-tee start), test row. → `widget-builder`
- [ ] **(low) hover-tee taps the bare `[`**: `scripts/hover-tee.py:73` matches the protocol's opening `[` line, writing invalid `status.json` (`"status":[`) at every bar start (verified with a fake status). Done: skip `s == "["`, h2 asserts the tap is valid JSON. → `widget-builder`
- [ ] **(low) hover-run.sh --replace pid reuse**: `scripts/hover-run.sh:12-15` TERM/KILLs the process group of a stale `daemon.pid` (left after a give-up exit) without checking it is hover-run. Done: check `/proc/$old/cmdline` names hover-run.sh. → `widget-builder`
- [ ] **(low) hover /tmp fallback**: without XDG_RUNTIME_DIR, `hover-run.sh:8` (SC2174), `hover-tee.py:30`, `hover-daemon.py:16` use shared `/tmp/custom_barista/hover` (parent 0755, another user can pre-create it and feed tap files). Done: `/tmp/custom_barista-$UID`, owner check. → `widget-builder`
- [ ] **(low) hover-run.sh untested**: no row for backoff, give-up after 5 crashes, single instance, --replace; daemon only has `--selftest`. Done: daemon command overridable (env), rows with a fake daemon exiting 1/0. → `widget-builder`
- [ ] **(low) daemon bar config without font**: `scripts/hover-daemon.py:46` `conf["font"]` KeyError aborts the rediscover pass (bars after it are skipped). Done: `.get` with i3bar default font. → `widget-builder`
- [ ] **(low) shellcheck warnings**: `scripts/claude-usage.sh:53` unused `ok`, `body` (SC2034) and `status= ra=` (SC1007); `scripts/test.sh:105` unused `i`. Done: `shellcheck -S warning scripts/*.sh install.sh` clean. → `widget-builder`
- [ ] **(docs) README/CLAUDE.md out of date**: README:9 lists `ccusage.sh` (now `claude-usage.sh`, `claude-rl-tap.sh`), no `explain.sh`, hover files, `install.sh`, `i3/`; README:23 deps say `node`/`npx` (ccusage), miss python-xlib + python-gobject (hover); no section on hover tooltips, HOVER=0, `hover.log`. CLAUDE.md:5 scripts list misses hover (`hover-tee.py`, `hover/`, `hover-daemon.py`, `hover-run.sh`) and HOVER=0. Done: both match the code (after T1d). → `chore`
