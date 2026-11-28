# M1 monitor brightness/contrast block: spec

User (2026-11-28): "add a widget to control the brightness and contrast on my monitors. Each monitor should have widget only for itself, not for both monitors."
Research: `docs/progress/monitor-ddc.md` (ddcutil 3.0.2 works without sudo; DP-0 = MSI G281UV, DP-2 = Ugreen AirPanel 16; VCP 0x10 brightness, 0x12 contrast, max 100; get/set about 0.45 s per call).
Decision page: `docs/design/M1-monitor-ddc/questions.html` (U-5). **The builder implements option B unless the user picks A or C**; the deltas for A and C are in section 9.

## 1. Options

| | Look (DP-0 example) | Interaction | Width | Verdict |
|---|---|---|---|---|
| **A** one block, mode toggle | ` 󰃠 93` or ` 󰃟 28` (only the active value) | left click toggles brightness/contrast, scroll changes the active one | 5 cells | against: hidden mode; you must read the icon before each scroll, and half the state is invisible |
| **B** two merged blocks (recommended) | ` 󰃠 93 󰃟 28` | scroll over the number you want to change; no mode | 9 cells | **recommended**: direct (point and scroll), both values visible, no state to remember; the bars have room (about 400 px free on DP-2) |
| **C** one block, both values, active one bold | ` 󰃠 93 28` (active bold white, other dim) | left click toggles which value scroll changes | 8 cells | against: still a mode, and bold vs dim reads like "good vs idle" in this bar's colour language |

Mocks: `img/b-two.png`, `img/a-bright.png`, `img/a-contrast.png`, `img/c-both.png`; states `img/s-*.png`. Today: `img/today-dp0.png`, `img/today-dp2.png`.

## 2. Placement and per-bar mapping

- Group: keyboard layout, battery, **brightness, contrast**, sound (display and audio controls next to each other). In `config.toml` insert the two blocks between the `battery` block and the `sound` block, both with `merge_with_next = true` (battery already has it). Result on DP-0: ` 󰌌 US  󰃠 93 󰃟 28  󰕾 80%`.
- `config.toml` names the DP-0 connector: `monitor-ddc.sh DP-0 ...`.
- `scripts/gen-compact.sh` rewrites the connector for the DP-2 bar: it reads the two `output` lines of `i3/bars.conf.tmpl` (the first = main bar, the second = small bar; same awk as `barsconf.sh`) and replaces `monitor-ddc.sh <main>` with `monitor-ddc.sh <small>` in every `command`/`cmd` line. Nothing is dropped. So DP-0's bar controls only the MSI, DP-2's only the AirPanel.
- Hover keys (`scripts/hover/keys.toml`): two rules before any generic custom rule, `command = "monitor-ddc.sh DP-0"` -> key `ddc-DP-0`, `command = "monitor-ddc.sh DP-2"` -> key `ddc-DP-2`.

## 3. Elements and values

Script: `scripts/monitor-ddc.sh` (bash, no jq in the render path). Glyphs (checked, render in `PragmataPro Mono, Symbols Nerd Font Mono 18`, no tofu):

| element | value |
|---|---|
| brightness icon | U+F00E0 nf-md-brightness_7 `󰃠`, wrapped in `<span foreground='#777777'>` (dim-icon, like `icons_format`) |
| contrast icon | U+F00DF nf-md-brightness_6 `󰃟` (half disc), same dim span |
| number | `printf '%3d'` right after the icon, no extra space: `󰃠 93`, `󰃠100`, `󰃠  0`; unknown = ` --` |
| block text | `" " + icon + number + " "` -> always 5 cells, never changes width |
| state | json `state` (no explicit colour on the number): `Idle` ok, `Info` stale/unknown (theme `info_fg` #777777 = dim), `Critical` write failed (theme `critical_fg` #dd6666 = bad). No `Good`/`Warning` state: brightness has no good/bad level |
| step | 5 per scroll tick, clamp 0..100 (values not on a multiple of 5 move by 5 from where they are: 93 -> 98 -> 100) |
| scroll | `up` = +5, `down` = -5 |
| left click | re-read both values from the monitor now (after using the monitor's own OSD buttons) |
| right/middle click | nothing |
| json | `{"text":"...","state":"Idle"}`; hidden = `{"text":""}` (with `hide_when_empty = true`) |

Config (paste into `config.toml`; the contrast block is the same with `contrast` instead of `bright`):

```toml
[[block]]
block = "custom"
command = "~/projects/custom_barista/scripts/monitor-ddc.sh DP-0 bright"
json = true
interval = 5
signal = 7
hide_when_empty = true
merge_with_next = true
[[block.click]]
button = "up"
cmd = "~/projects/custom_barista/scripts/monitor-ddc.sh DP-0 bright up"
update = true
[[block.click]]
button = "down"
cmd = "~/projects/custom_barista/scripts/monitor-ddc.sh DP-0 bright down"
update = true
[[block.click]]
button = "left"
cmd = "~/projects/custom_barista/scripts/monitor-ddc.sh DP-0 refresh"
update = true
```

## 4. States

| # | condition | text (bright block) | state | mock |
|---|---|---|---|---|
| S1 ok | value known, last read or write succeeded, `read_ts` within 300 s | ` 󰃠 93 ` | Idle | s-ok |
| S2 stale | value known, but the last read failed (monitor in standby, DDC busy) or `read_ts` older than 300 s | ` 󰃠 93 ` | Info (dim) | s-stale |
| S3 unknown | no value yet (first read pending or failing) | ` 󰃠 -- ` | Info | s-unknown |
| S4 write failed | the worker's setvcp for this code failed twice in a row | ` 󰃠 60 ` (the wanted value) | Critical (red) | s-fail |
| S5 hidden | `ddcutil` not on PATH, no access to `/dev/i2c-*`, connector not connected in xrandr, or the monitor has no DDC (bus not found) | empty | - | - |

S4 clears on the next successful write or read of that code (a read replaces the wanted value with the monitor's real one). S5 is environmental, not an error: e.g. the second user without the `i2c` group, or the AirPanel unplugged. The reason for S5 is kept in the state file (`hidden=<reason>`) and shown by `monitor-ddc.sh <conn> info`.

## 5. Cache, locks and worker

State dir: `$XDG_RUNTIME_DIR/custom_barista/ddc/`; no `XDG_RUNTIME_DIR` -> `/tmp/custom_barista-$UID/ddc/` with the same ownership check as `scripts/hover/rundir.py`. Test override: `DDC_STATE_DIR`.

Per connector (`<conn>` = `DP-0`):
- `<conn>.state`: `key=value` lines, parsed with `while IFS== read` (never `source`d): `bright`, `contrast` (wanted values, empty = unknown), `seq` (incremented by every scroll), `read_ts` (epoch of last successful read), `read_err` (0/1), `werr_bright`, `werr_contrast` (0/1), `bus`, `model`, `drm`, `hidden` (empty or reason), `resolve_ts`.
- `<conn>.lock`: guards read-modify-write of the state file (held a few ms; `flock -w 1`).
- `<conn>.log` (mode 600, last 200 lines): one line per worker setvcp (`time conn setvcp code value seq=N rc=N`) and per refresh read differing from the state (`external code expected=N read=N`, the monitor changed outside the bar); worker/refresh only, never the render path.
- `<conn>.worker.lock`: one ddcutil user per monitor (worker and refresh); `flock -n`, skip if busy.

Flows:
1. **Render** (`monitor-ddc.sh <conn> bright|contrast`, every 5 s and on signal 7): read state file, print json; no ddcutil, no xrandr, under 30 ms. If `bus` is empty and `resolve_ts` is older than 300 s, or `read_ts` is older than 60 s: start a background refresh (step 4). Background children always `setsid ... </dev/null >/dev/null 2>&1 &` (a child holding stdout would stall the block).
2. **Scroll** (`... bright up|down`): under `<conn>.lock`: value = clamp(value ± 5) (unknown value: do nothing), `seq++`, write state. Then start the worker in the background and return. Must return in under 100 ms with ddcutil never called in the foreground. `update = true` re-renders right away, so the new number shows before the monitor changes.
3. **Worker** (`... worker`, internal): `flock -n <conn>.worker.lock` or exit (the running one picks the new value up). Sleep 0.2 s (debounce). Loop: snapshot `bright`, `contrast`, `seq`; for each code whose wanted value differs from the last value this worker applied (start: from the last read), run `ddcutil --bus N --noverify --sleep-multiplier .1 setvcp 10|12 <v>`; on failure retry once, then set `werr_<code>=1`; on success set `werr_<code>=0`. If `seq` changed meanwhile, loop again; else exit. Bursts of scroll ticks thus coalesce: at most one setvcp in flight per monitor, always with the latest value. Before exit: `pkill -u "$UID" -RTMIN+7 -x i3status-rs` (both bars re-render; harmless). Cap: 30 loop rounds.
4. **Refresh** (`... refresh`, left click and stale render): background; resolve the bus if needed (step 5), then under `flock -n <conn>.worker.lock`: note `seq`, run `ddcutil --bus N --sleep-multiplier .1 --brief getvcp 10 12` (one call, both codes; parse `VCP 10 C <cur> <max>`), then under `<conn>.lock`: if `seq` is unchanged write `bright`, `contrast`, `read_ts=now`, `read_err=0`, clear `werr_*`; if `seq` changed (user scrolled meanwhile) only set `read_ts`, keep the wanted values. Failure: `read_err=1`, values kept; if the error says the bus is gone, clear `bus` so the next render resolves again. Signal 7 at the end.
5. **Resolve** (connector -> bus; bus numbers can change across boots, xrandr and DRM names differ on nvidia):
   1. `xrandr --prop`: the connector's `EDID:` hex (first 128 bytes); not connected -> `hidden=disconnected`.
   2. Find `/sys/class/drm/card*-*/edid` whose first 128 bytes (hex) equal it -> DRM name (`card1-DP-1`).
   3. `ddcutil detect --terse`: the display whose `DRM connector:` equals it -> `I2C bus: /dev/i2c-N` and `Monitor:` (model). No match -> fall back to matching the EDID manufacturer+product id against `Monitor:`; still none -> `hidden=no-ddc`.
   4. `ddcutil` missing -> `hidden=no-ddcutil`; no read/write access to any `/dev/i2c-*` -> `hidden=no-i2c-access`.
   Test overrides: `DDC_CMD` (ddcutil), `XRANDR_CMD`, `DRM_DIR` (default `/sys/class/drm`), `DDC_NOW` (epoch), `DDC_SIGNAL=0` (no pkill).

## 6. Hover tooltip

`explain.sh` gains `ddc-DP-0|ddc-DP-2) t=$(printf '%s' "$(timeout 5 "$(dirname "$0")/monitor-ddc.sh" "${1#ddc-}" info)")`. `info` prints at most 5 lines, from the state file only (fast):

```
MSI G281UV on DP-0: brightness / contrast over DDC/CI (bus /dev/i2c-3).
Brightness 93, contrast 28 (read 12:03:15).
Scroll: +-5 (0-100). Left click: read again from the monitor.
Grey: monitor not answering, last known values. Red: change not applied.
```
Line 2 variants: `Not answering since 12:03:15 (standby or busy); last known values.` / `Not read yet.`; S5: one line `Hidden: <reason>` (`ddcutil not installed`, `no access to /dev/i2c-* (group i2c)`, `DP-2 not connected`, `monitor has no DDC/CI`).

## 7. Install

`install.sh`: if `ddcutil` is missing or the user cannot open `/dev/i2c-*`, print one hint line (`M1: monitor block hidden: pacman -S ddcutil; usermod -aG i2c $USER; i2c-dev module`) and continue (exit status unchanged).

## 8. Test table (`scripts/test.sh`, fixtures in `scripts/testdata/ddc/`, fake `ddcutil`/`xrandr` scripts that log their argv and sleep `FAKE_SLEEP`)

| id | setup | expect |
|---|---|---|
| d1 | state bright=93 contrast=28 read_ts=now | `bright` -> text strip ` 󰃠 93 `, Idle; `contrast` -> ` 󰃟 28 `, Idle |
| d2 | bright = 0, 5, 93, 100, unknown | stripped text length identical for all five |
| d3 | read_err=1 | Info, number kept |
| d3b | read_ts = now-301 | Info |
| d4 | no state file | ` 󰃠 -- `, Info; a background refresh was started (fake ddcutil log has `getvcp`) |
| d5 | werr_bright=1 | bright block Critical, contrast block Idle |
| d6 | DDC_CMD=/nonexistent, refresh | state `hidden=no-ddcutil`; render -> `{"text":""}` |
| d7 | xrandr fixture without DP-2 connected, refresh | `hidden=disconnected`, empty text |
| d8 | bright=93: up, up | 98 then 100; bright=3: down -> 0; unknown: up -> still unknown, no worker |
| d9 | FAKE_SLEEP=2, `bright up` | returns in < 0.3 s; no ddcutil call before it returns |
| d10 | FAKE_SLEEP=0.4, 6 x `bright up` from 50 within 0.3 s, wait for worker.lock to free (timeout 10 s) | setvcp 10 called 1..3 times, last value 80 |
| d11 | d10's log | every setvcp has `--bus 3 --noverify --sleep-multiplier .1`; no setvcp 12 |
| d12 | `contrast down` from 40 | only `setvcp 12 35` |
| d13 | fixture EDIDs: DP-0 = card1-DP-1 on i2c-3, DP-2 = card1-DP-2 on i2c-4 | resolve DP-0 -> bus 3, DP-2 -> bus 4 |
| d13b | same, detect fixture with the buses swapped | DP-0 -> bus 4 |
| d14 | refresh with fake getvcp sleeping 0.5 s, one `bright up` during it | wanted value kept (not overwritten by the read) |
| d15 | fake getvcp exits 1 | read_err=1, values kept, Info |
| d16 | fake setvcp fails twice | werr_bright=1, Critical; a later successful refresh clears it |
| d17 | `compact.toml` / `config.toml` | compact has `monitor-ddc.sh DP-2` 8 times and no `DP-0`; config the reverse (see note) |
| d18 | explain keys | both configs map the ddc blocks to `ddc-DP-0` / `ddc-DP-2`; `explain.sh ddc-DP-0` with a fixture state prints <= 6 lines |
| d19 | render timing | `bright` render under 50 ms (median of 5) |

d17 note: per monitor 2 `command` + 4 scroll `cmd` + 2 left-click `cmd` = 8 occurrences; the test counts what config.toml has and requires the same count with the other connector in compact.toml. Existing rows to update: the D5-R merge-flag counts (DP-0 7 -> 9, DP-2 5 -> 7) and the compact pattern-count row if it changes.

## 9. Option A / C deltas (only if the user picks them)

- **A**: one block per bar, `command = "... monitor-ddc.sh DP-0 active"`; state file key `mode=bright|contrast` (default bright); text shows the active code's icon and value; `up`/`down` cmds `... DP-0 active up|down`; left click `... DP-0 toggle` (flips `mode`, `update = true`); refresh moves to right click. Merge flags +1 instead of +2. Tooltip line 3: `Scroll: +-5 the shown value. Left click: switch brightness/contrast. Right click: read again.`
- **C**: like A, but text ` 󰃠 93 28`: icon of the active code, active value in default colour with `<b>`, the other value in `<span foreground='#777777'>`; 8 cells fixed.

## 10. Acceptance checks

1. `bash scripts/test.sh | tail -5`: fail=0, rows d1-d19 present.
2. `grep -c 'monitor-ddc.sh DP-0' config.toml` = `grep -c 'monitor-ddc.sh DP-2' compact.toml` > 0, and `grep -c 'monitor-ddc.sh DP-2' config.toml` = `grep -c 'monitor-ddc.sh DP-0' compact.toml` = 0.
3. After `./install.sh`: screenshot crops of both bars show ` 󰃠 NN 󰃟 NN` between `US` and the volume, no tofu boxes; the DP-0 values equal `ddcutil --bus 3 getvcp 10 12`, the DP-2 values `--bus 4` (resolved bus, whatever its number).
4. Scrolling up 3 ticks on the DP-2 brightness: the number changes on each tick at once; within 2 s `ddcutil --bus <DP-2 bus> getvcp 10` reports the new value; DP-0's monitor and DP-0's block are unchanged.
5. Block width does not change while scrolling from 90 to 100 and down to 0 (compare crop x-positions of the volume icon: identical).
6. Hover over the DP-0 block: popup shows the 4-line tooltip naming MSI G281UV / DP-0; over DP-2: Ugreen AirPanel 16 / DP-2.
7. `sudo -iu anatolii` style check without i2c access (or `DDC_CMD=/nonexistent monitor-ddc.sh DP-0 refresh; monitor-ddc.sh DP-0 bright`): empty text, `info` names the reason; the rest of the bar unaffected.
8. Monitor in standby/unplug test: DP-2 block hides when DP-2 is disconnected (xrandr), dims when DDC stops answering; i3bar never freezes (render stays < 50 ms).
