# M1 monitor DDC research (2026-11-28)

- Access OK without sudo: ddcutil 3.0.2 installed, i2c_dev loaded, user in group `i2c` (957), /dev/i2c-* root:i2c 0660+ACL, udev `60-ddcutil-i2c.rules` (uaccess) present. Nothing to install. (Fresh machine: `pacman -S ddcutil`, `usermod -aG i2c $USER`, `/etc/modules-load.d/i2c-dev.conf` with `i2c-dev`.)
- `ddcutil detect` (nvidia driver, works without --force-slave-address / NVreg options):
  | xrandr | DRM | bus | model | VCP |
  |---|---|---|---|---|
  | DP-0 3840x2160 | card1-DP-1 | /dev/i2c-3 | MSI G281UV | 2.1 |
  | DP-2 2560x1600 | card1-DP-2 | /dev/i2c-4 | Ugreen AirPanel 16 | 2.2 |
  Numbering differs between xrandr and DRM: map by EDID/resolution (or `xrandr --prop` EDID vs `ddcutil detect` serial), not by name. Bus numbers can change across boots; resolve by EDID serial/model at start (`ddcutil detect --brief`, or `--mfg/--model/--sn`).
- VCP 0x10 / 0x12 both supported: bus3 bright 93/100, contrast 28/100; bus4 bright 72/100, contrast 40/100.
- Latency (wall, one call): getvcp 0.5-0.7 s default; 0.33 s bus3 with `--sleep-multiplier .1`; bus4 ~0.45 s regardless; `--skip-ddc-checks` 0.24 s. setvcp `--noverify` 0.44-0.60 s (0.34 s with .1). Slow enough to lag if done per scroll tick. Sleep multiplier .1 worked on both (values read back correct).
- i3status-rs 0.40.1 `backlight` block supports ddcci monitors (options ddcci_sleep_multiplier, ddcci_max_tries_write_read, `device` regex), but it reads /sys/class/backlight which is empty here (needs ddcci-driver-linux kernel module; not installed, DKMS on a 7.3 arch kernel is fragile) and has no contrast. Not worth it.
- Recommendation: custom script block (like other scripts/ blocks), per-bar arg = connector -> bus resolved via EDID. State cached in a file under $XDG_RUNTIME_DIR (bright, contrast, mode); block output reads the cache only (instant); refresh from `getvcp` in the background every ~60 s. Scroll handler: update cache immediately (step 5, clamp 0-100), re-render, and kick a debounced background worker (one per monitor, flock; sleep ~0.3 s, then setvcp `--noverify --sleep-multiplier .1 --bus N` with the latest cache value, loop while the value changed). Click toggles brightness/contrast mode. Both codes can be set in one invocation chain; per-bus calls for the two monitors run in parallel (different buses).

## Spec (2026-11-28, bar-designer)
- `docs/design/M1-monitor-ddc/spec.md`: options A (one value + mode toggle), **B recommended** (brightness and contrast as two merged custom blocks, scroll over the one to change, left click re-reads), C (both values, active bold). Decision page `questions.html` + USER_TODO U-5.
- Placement: group kbd / battery / **bright / contrast** / sound; config.toml uses `monitor-ddc.sh DP-0`, gen-compact.sh rewrites to DP-2 from the bars.conf.tmpl `output` lines. Icons U+F00E0 / U+F00DF (render checked), `%3d` fixed 5-cell text; states Idle / Info (stale, unknown) / Critical (write failed) / hidden (no ddcutil, no i2c access, disconnected, no DDC).
- Backend: state file per connector in the runtime dir, render reads only it; scroll edits it (+seq) and starts a flock'd worker that coalesces setvcp (`--bus N --noverify --sleep-multiplier .1`); refresh = one `getvcp 10 12`, discarded if seq changed; bus resolved xrandr EDID -> /sys/class/drm edid -> `ddcutil detect --terse` DRM connector; signal 7 re-renders. Tests d1-d19, acceptance 1-8.
- Remains: user answer U-5, then widget-builder, then review.

## Build (2026-11-28, widget-builder, option B)
- Done: `scripts/monitor-ddc.sh` (render from state file, scroll step + debounced flock'd worker, refresh/resolve via xrandr EDID -> drm edid -> `ddcutil detect --terse`, `info`), 2 blocks in `config.toml` (signal 7), `gen-compact.sh` maps DP-0 -> DP-2 from the bars.conf.tmpl output lines, hover keys `ddc-DP-0`/`ddc-DP-2` + `explain.sh`, install.sh hint, README. test.sh rows d1-d19 (+d1c, d5c, d13b-style swapped check inside d13, d16b, d18b); merge-flag row now 9/7. 257 pass, 0 fail.
- Deviations: block text is 6 characters (space, icon, `%3d`, space), the spec's "5 cells" was a miscount; width is constant. Extra state keys `try_ts` (throttle: a stale-read refresh at most every 30 s), `abright`/`acontrast` (last value known on the monitor; worker only writes codes that differ). Resolve order: ddcutil missing, no i2c access, xrandr disconnected, then bus lookup. `od -v` needed for the EDID compare (od collapses repeated lines).
- Live (deployed): both bars run with no error blocks; DP-0 bus 3 (MSI), DP-2 bus 4 (AirPanel); one scroll up/down per monitor via the script returned the value (DP-0 95 -> 100 -> 95, DP-2 72 -> 77 -> 72, checked with `ddcutil getvcp`).
- Remains: bar-designer review (screenshots, hover popup, acceptance 3-6).

## Review (2026-11-28, bar-designer, commit 51a45a8): accepted with 2 small fixes
- Deviations accepted: 6-char text (the spec's 5 was a miscount of ` 󰃠 93 `; width constant, d2); `try_ts` (throttles stale-read refreshes, spec flow 1 had none); `abright`/`acontrast` (persisted form of spec flow 3's "last value this worker applied").
- Acceptance 3: crops of both bars show ` 󰃠 NN  󰃟 NN` between US and volume, no tofu; DP-0 95/43 = `ddcutil --bus 3 getvcp`, DP-2 72/40 = bus 4; each bar shows only its own monitor. 4: i3bar scroll on DP-2 brightness (xdotool, net zero 72 -> 77 -> 72, twice): number changes within ~0.2-0.4 s, getvcp confirms within 2 s, DP-0 untouched. 5: contrast icon x identical at 72/77 (0/100 covered by d2). 6: both popups correct (AirPanel 16 / DP-2, MSI G281UV / DP-0).
- Unrequested-write audit: setvcp only in `worker`, started only by `scroll` after `step` changed a known value (seq++); refresh/render/resolve/install/startup only read (`getvcp`, `detect`); code mapping bright->10, contrast->12 fixed in `apply`; worker skips codes equal to the last applied/read value. All test.sh rows go through `dx` with `DDC_CMD` = absolute fake path (d6 uses /nonexistent -> hidden), children inherit it. Evidence: DP-0 state `seq=17` = 17 scroll steps went through `step()` since the state file was created, so the 93 -> 78 -> 95 / contrast 28 -> 43 changes were scroll events (DP-2 seq 4 -> 8 = exactly this review's 4 ticks; install/restart changed nothing).
- Fix 1 (lost write, monitor-ddc.sh): a scroll during a refresh's getvcp started a worker that found worker.lock busy and quit; the refresh kept the wanted value but nobody applied it (no extra write, a missing one). refresh_run now releases the lock and starts the worker if seq changed. d14 now also requires `setvcp 10 98` (failed before the fix).
- Fix 2 (stale popup, hover-daemon.py): explain texts were cached until explain.sh's mtime changed, so the ddc popup showed the deploy-time values (93/28 at 12:33) forever; `ddc-*` keys are now re-run on each show (~10 ms). Deployed, popup shows live values.
- Note: a hover right after scrolling shows nothing until the pointer leaves the bar (click suppression, by design).
- Remains: acceptance 7-8 (no-i2c user, standby/unplug) not run live; d6/d7 cover them in tests.

## M1f review fixes (2026-11-28)
- read_ok keeps a wanted value while a change is pending (a<code> set, differs, no werr); test d14b. resolve probes outside the state lock (`resolve` fills R_*, `store_resolve` under lock; a new bus drops a*/werr). try_ts claimed inside the lock. Standby `clear_bus` sets resolve_ts (no detect for 300 s) and clears pending; test d20/d20b/d20c. Hover `ddc-` re-read test (h-ddc, imports hover-daemon, stub explain). shellcheck: no warnings left (only SC2329/SC2030 info).
- Dim colour: read `info_fg` from config.toml with the same sed as claude-usage.sh (DDC_CONFIG override), fallback `#777777`. runner-queue.sh left to G1h.
- README deps and CLAUDE.md block mention added. Deployed; both bars error-free, each own monitor; live net-zero scroll (up/down) on both monitors, bright+contrast, getvcp unchanged (93/28, 72/40).

## M1g write log (2026-11-28)
- `wlog` in monitor-ddc.sh appends to `<state dir>/<conn>.log` (600, last 200 lines): each worker setvcp (`ISO time conn setvcp code value seq=N rc=N`, per attempt) and each refresh read differing from the wanted/known value (`external code expected=N read=N`, only when no change is pending). No extra ddcutil calls, nothing on the render path. Tests d21-d21d (setvcp line, external line, no line on equal read, cap 200 + mode 600). Spec data-files list mentions the log.
- Deployed; both bars clean; live net-zero scroll on DP-2 (45 then 40) gave 2 setvcp lines, mode 600.
