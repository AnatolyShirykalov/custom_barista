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
