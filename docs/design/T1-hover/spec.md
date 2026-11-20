# T1 hover tooltips: spec (2026-11-20, bar-designer)

The user: "tooltips must appear on hover (middle-click popup is only a stopgap)". Inputs: `research.md` (option a), `spike.md` (go: computed edges = click edges at 0 px on both bars; Enter/Motion/Leave delivered). Decision page for the two user-facing choices: `questions.html` (defaults below apply until the user answers; nothing blocks the build).

## 1. Options

| | Option | Why / why not |
|---|---|---|
| **A (recommended)** | `status_command` tee wrapper writes the latest status line to a tmpfs file; a separate hover daemon (python-xlib + GTK3) watches the i3bar windows, computes edges on demand and shows its own popup | The bar's critical path gains only a ~60-line pass-through with no X/GTK imports; the daemon can crash, hang or be absent and the bar never notices. |
| B | Daemon runs its own i3status-rs copy to learn the text | Against: a second copy samples at other moments (widths differ from what i3bar draws, e.g. `R 2.0kB` vs `R 322kB`), doubles nvidia-smi and usage API calls. |
| C | Wrapper does the hover itself (one process) | Against: a GTK/Xlib import error, X disconnect or hang in the wrapper kills or freezes the status line; startup cost on every Win+i. |

Popup: own GTK popup window (A) rather than yad per hover (spawn ~150 ms + `--mouse` puts the window under the pointer, over the bar, which steals the pointer and fires Leave) or a notification (wrong place, stacks).

## 2. Components and files

| File | Role | Imports |
|---|---|---|
| `scripts/hover-tee.py` (from `spike/tee-wrap.py`) | status_command wrapper: `hover-tee.py --output DP-0 -- i3status-rs CONF` | os, sys, subprocess, threading, time only (no json parse of status lines, no gi, no Xlib) |
| `scripts/hover/layout.py` (from `spike/edges.py`) | pure: piece widths (PangoCairo), layout, hit test, block→explain key map, placement | gi Pango/PangoCairo, cairo, tomllib |
| `scripts/hover/state.py` | pure state machine, injected clock; events in, actions out | none |
| `scripts/hover-daemon.py` (X part from `spike/xbars.py`) | glue: X events, file watch, GTK popup, i3 IPC for bar config | Xlib, gi Gtk3, layout, state |
| `scripts/hover-run.sh` | single instance + supervisor (restart with backoff) | bash, flock |
| `scripts/hover/test_hover.py` | headless unit rows, called by `test.sh` | layout, state |
| `testdata/hover/` | fixtures: `dp0.json`, `dp2.json` (status line + bar geometry + click-reported edges), `fake-status.sh` | |

Delete `scripts/spike/` once T1c is accepted (T1 review).

### 2.1 Wrapper `hover-tee.py` (critical path: must never break the bar)
- Spawn the child (`argv` after `--`) with stdin/stdout pipes, stderr inherited, `bufsize=0`; in the child set `PR_SET_PDEATHSIG=SIGTERM` (ctypes `prctl(1, 15)`, inside try: failure ignored) so i3status-rs dies with the wrapper.
- stdout pump (main thread): each line from the child is written to our stdout and flushed **first**; then, if it starts with `[` or `,[`, tap it: write `{"v":1,"ts":<float>,"output":"DP-0","config":"<CONF>","status":<line without leading comma and trailing newline/comma>}` to `<dir>/<output>.status.json` via tmp file + `os.replace`. No JSON parsing in the wrapper (string concatenation only).
- stdin pump (thread): each line from i3bar is forwarded to the child and flushed **first**; then lines other than `[` are tapped to `<dir>/<output>.click.json` as `{"v":1,"ts":..,"click":<line without leading comma>}` (atomic, overwrite).
- `<dir>` = `$HOVER_DIR` or `${XDG_RUNTIME_DIR:-/tmp}/custom_barista/hover`, created 0700 on start.
- Any tap error (mkdir, write, replace): caught, tapping disabled for 60 s, one line to stderr. Never raises, never blocks: tap writes are local tmpfs writes, no sockets, no daemon contact.
- Child stdout EOF → `wait()` → exit with the child's code. SIGTERM/SIGINT to the wrapper → forward to the child, then the same exit path. i3bar's stop/cont signals go to the process group (wrapper and child share it): nothing to do; verify in acceptance 7.
- Kill switch: `HOVER=0` in `bars.env` makes `barsconf.sh` emit the plain command; it also does so when `python3` is missing.

### 2.2 bars.conf, install.sh, Win+i
- `barsconf.sh`: `mc="$d/hover-tee.py --output DP-0 -- i3status-rs $CONFDIR/config.toml"`, `sc="$d/hover-tee.py --output DP-2 -- i3status-rs $CONFDIR/compact.toml"` (outputs as in `i3/bars.conf.tmpl`; keep one source: add `@MAIN_OUT@`/`@SMALL_OUT@` tokens or read them from the template's `output` lines, builder's choice, test row h15 pins the result). Same command in both states, so Win+i still only swaps `mode` (the wrapper path never differs between states).
- `install.sh` i3 block (between the markers) gains `exec_always --no-startup-id $REPO/scripts/hover-run.sh --replace`. `exec_always` runs on start and on `i3-msg restart`, so `./install.sh` (which restarts i3) always loads new daemon code. Dependency warning: `python-xlib` (`python3 -c 'import Xlib'`), python-gobject with Gtk 3.
- `hover-run.sh [--replace]`: lock `$dir/daemon.lock` with `flock -n`; with `--replace`, first `kill` the PID in `$dir/daemon.pid` (wait ≤ 1 s, then `-9`), then take the lock. Loop: run `hover-daemon.py`; exit code 0 = stop (X gone / replaced); non-zero = restart after 1, 2, 4, 8, 16 s; more than 5 crashes in 10 min → log and give up until the next i3 restart. Log `$dir/hover.log`, truncated to its last 200 lines at each daemon start.
- Win+i off: the bars are unmapped (`mode invisible`), the daemon sees no viewable bar and idles; on: bars remap, the daemon picks them up (2.3 rediscovery). No barcycle.sh change.

### 2.3 Daemon `hover-daemon.py`
- **Bars**: walk the tree for viewable windows with WM_CLASS `i3bar`; output from WM_NAME `i3bar for output <OUT>`; geometry via `translate_coords`. Bar config via `i3-msg -t get_bar_config <id>` (match `outputs`): `font` (strip `pango:`), `padding`, `separator_symbol`, `position`. DPI: `Xft.dpi` from `xrdb -query`, else 96.
- **Rediscover** on: root `SubstructureNotify` events (debounced 500 ms), any X error on a bar window, and a 10 s timer. Per bar select `EnterWindow|LeaveWindow|PointerMotion|StructureNotify|SubstructureNotify` (never ButtonPress: i3bar owns it, BadAccess).
- **Tray**: count = viewable children of the bar window; re-read on every Enter, on child Map/Unmap/Destroy (SubstructureNotify) and on ConfigureNotify. Width = `n × (h − 4 + 2) + 2`, statusline right edge = `bar_x + w − tray_w − (4 if n else 0)` (spike formula, 0 px).
- **Layout** (lazy): re-read `<OUT>.status.json` only when its mtime changed, checked on Enter, on Motion (stat per event, throttled to 1 per 50 ms) and on the 250 ms tick while armed/shown. Port i3bar's `predict_statusline_length` / block rendering from i3 4.25 `i3bar/src/xcb.c` faithfully: width = max(text width, `min_width`: int px, or width of the string when it is a string), plus `border_left`+`border_right` only where i3bar adds them; gap = `separator_block_width` (default 9), none after the last piece; skip empty `full_text`.
- **Blocks**: a piece's block index = `instance` up to the `:` (i3status-rs: `name` = merge group, `instance` = `<block index>:<widget>`). Pieces with the same index form one hover region (union; e.g. sound = icon + `70%`). Explain key = the `explain.sh <key>` argument of any `[[block.click]]` `cmd` of `blocks[index]` in the config file named in the status file (tomllib, so compact.toml indices are right). No key → no popup for that region.
- **Hit**: `[x0, x1)` per region; gaps, workspace buttons, padding → none; x ≥ statusline right edge or Leave detail Inferior → tray.
- **Unsupported → bar off** (no popups on that bar, one log line per change): `separator_symbol` set, non-zero `padding`, or any piece with `short_text` while the full layout's left edge is < `bar_x + 600` (i3bar may switch to short texts; widths unknowable without the workspace button widths). Today: no `short_text` in either config, left edges at +1092 (DP-0) and +985 (DP-2).
- **Self-check**: on a new `<OUT>.click.json`, compare the clicked region's computed edges (current layout and tray) with `x − relative_x` / `width`; log any difference; two consecutive differences > 2 px on a bar → bar off until the next status layout change that passes a later click check (log).
- **Text**: `EXPLAIN_DRY=1 scripts/explain.sh <key>` (plain text, ≤ 6 lines), cached per key, cache dropped when explain.sh's mtime changes. Shown with `set_text` (no markup parsing).
- **Main loop**: GTK main loop; Xlib display fd via `GLib.io_add_watch`; drain `pending_events()` in the callback. Every handler wrapped: an exception is logged and the event dropped; X connection closed → exit 0.

## 3. Behaviour

### 3.1 States (`state.py`, times in ms, injected clock)

| State | Event | Next / action |
|---|---|---|
| idle | pointer over region K | armed(K), timer 500 |
| armed(K) | motion inside K | unchanged (timer not restarted) |
| armed(K) | over region L | armed(L), timer 500 restarted |
| armed(K) | gap / ws buttons / tray / Leave | idle, timer cancelled |
| armed(K) | timer fires | shown(K) |
| shown(K) | over region L | shown(L) at once (browse) |
| shown(K) | gap | hide after 150 ms grace unless a region is entered first (then shown(that) at once) |
| shown(K) | Leave (not Inferior), tray (Leave Inferior or x in tray), bar unmapped | hidden at once → browse window 300 ms: a region entered within it is shown at once |
| any | click on region K (new click file) | hide; suppressed(K) until the pointer is over another region or leaves the bar |
| shown(K) | layout change (new status, tray change) | re-hit the pointer x (`query_pointer`); same K → move the popup to the new centre; else as a move |
| hover off bar | any | idle, nothing shown |

No auto-hide timeout while hovering. Hover delay 500 ms, grace 150, browse 300 are constants at the top of `state.py` (Q2 may change the delay).

### 3.2 Popup

| Element | Value |
|---|---|
| Window | `Gtk.Window(type=POPUP)` (override-redirect, no focus, no taskbar), empty input shape (click-through), keep above |
| Font | PragmataPro Mono 16 |
| Colors | text `idle_fg` (#ffffff), border 1 px `info_fg` (#777777, dim-icon), background #1d1d1d; read `idle_fg`/`info_fg` from the config's `[theme.overrides]` |
| Padding | 10 px; width = text width, no wrapping, max 6 lines |
| Horizontal | centred on the region's centre, clamped to `[mon_x + 4, mon_x + mon_w − 4 − popup_w]` of the bar's monitor |
| Vertical | bottom bar: popup bottom = `bar_y − 4`; top bar: popup top = `bar_y + bar_h + 4` |
| Content | explain text only (no live values) |

Mock (DP-2 right half, temp block hovered, left-clamped): `img/mock-popup-dp2.png`.

### 3.3 Middle-click
Default (Q1 A): keep the middle-click yad popups; they are the fallback when the daemon is down and the explain-key source (2.3). If the user picks Q1 B, T1c removes them and moves the key mapping to `scripts/hover/keys.toml` (block index-independent: block type + distinguishing field), checked by test row h10.

## 4. Edge cases

| Case | Behaviour |
|---|---|
| Pointer onto a tray icon | bar gets Leave detail Inferior → tray → hide; back onto the bar: Enter detail Inferior → normal hit |
| Tray icon appears/disappears | SubstructureNotify → tray count re-read → layout shifts; shown popup re-placed (3.1) |
| short_text / separator_symbol / padding | bar off (2.3), logged; the other bar unaffected |
| Two monitors | per-bar state keyed by output; only one popup in the whole daemon; pointer moving DP-2 → DP-0 bar = Leave + Enter |
| Daemon crash / hang / absent | bar unaffected (no link wrapper → daemon); hover-run.sh restarts; middle-click still works |
| Wrapper tap dir unwritable / full | pass-through unaffected, tapping paused 60 s |
| Status file missing or invalid JSON | no popups on that bar until a valid one arrives |
| Win+i off / on | bars unmapped → hide, idle; remapped → rediscovered within 0.5 s (10 s worst case) |
| i3 restart / `./install.sh` | `--replace` → exactly one daemon, new code |
| Block without an explain key (future block) | no popup; test row h10 fails until explain.sh has the key |
| Text width changes under a shown popup | popup follows the region centre (re-place, no flicker: move, not re-create) |

## 5. Test rows (`bash scripts/test.sh`, all headless; `test_hover.py` prints `pass=N fail=M` lines that test.sh adds to its totals)

| Row | Check |
|---|---|
| h1 | wrapper + `fake-status.sh`: our stdout byte-identical to the child's |
| h2 | stdin lines (header `[`, 2 clicks with leading comma) reach the child byte-identical; `.click.json` holds the last click |
| h3 | `HOVER_DIR=/proc/nope`: h1 still identical, exit code = child's (fake exits 3 → 3) |
| h4 | `kill -9` wrapper → child gone within 1 s (PDEATHSIG) |
| h5 | `dp0.json`: computed edges = reported edges for every piece (0 px) |
| h6 | `dp2.json` (no tray) likewise |
| h7 | tray 0 / 3 / 5 icons: right edge per formula |
| h8 | min_width int and string; `separator_block_width` default 9 and 0; no gap after the last piece; empty `full_text` skipped |
| h9 | hit: inside → index; gap → none; `x == x1` → not that region; x in tray → tray |
| h10 | every block index present in config.toml and compact.toml status fixtures maps to a key, and `EXPLAIN_DRY=1 explain.sh <key>` exits 0 |
| h11 | sound (two pieces, same index) → one region = union |
| h12 | short_text near the left edge → bar off; far from it → on; separator_symbol / padding → off |
| h13 | state machine: 499 ms no show, 500 show; K→L instant; gap 100 ms then L → no hide; gap 200 → hidden; Leave → hide; Leave Inferior → hide; Enter Inferior → armed; click → hide, suppressed until another region; browse window 300 ms |
| h14 | placement: centred; clamped left and right; bottom bar 4 px above; top bar 4 px below |
| h15 | `barsconf.sh rs` and `off`: both status_commands wrapped with `--output DP-0` / `--output DP-2`, identical between states; `HOVER=0` → plain `i3status-rs` |
| h16 | `hover-daemon.py --selftest`: imports, parses both configs, prints the key map, exit 0, no display needed |

Fixtures h5/h6 are captured live once in T1b with the spike method (button-9 clicks, `edges.py`), storing the status line, bar geometry, tray count and reported edges.

## 6. Acceptance (live, T1c; screenshots in `img/`)

1. Each block on both bars: hover → its explain text after ~0.5 s, popup above the block, inside the monitor (crops `review-hover-<block>-dp0/dp2.png` for load, ccusage, sound, time at least).
2. Sliding along the bar after the first popup: texts switch with no delay, no flicker on the 9 px gaps.
3. Tray icons: no popup; back to the bar works.
4. Left click on time (calendar) hides the popup; no popup reappears until the pointer moves to another block.
5. `pkill -9 -f '[h]over-daemon.py'`: bars keep updating; daemon back within 2 s; hover works.
6. Win+i off then on: no popup while off, hover works within 1 s after on; `i3-msg restart` → `pgrep -fc '[h]over-daemon.py'` = 1.
7. Off state: `ps -o stat` of wrapper and i3status-rs both show the same state (both stopped or both running).
8. Idle cost: daemon CPU < 0.5 % over 60 s with the pointer off the bars; RSS < 80 MB; wrapper CPU within 0.2 % of plain i3status-rs.
9. `bash scripts/test.sh` green; no tofu in popups.

## 7. Builder sub-items (one widget-builder run each, in order)

| Item | Scope | Done when |
|---|---|---|
| T1a | `hover-tee.py`, barsconf.sh wiring + `HOVER=0`/no-python fallback, `fake-status.sh`, rows h1-h4, h15; deploy | bars run through the wrapper on both monitors, tap files update, rows green |
| T1b | `hover/layout.py`, `hover/state.py`, live fixture capture, `test_hover.py` rows h5-h14 | rows green; no X or GTK window code |
| T1c | `hover-daemon.py`, `hover-run.sh`, install.sh `exec_always` + dep warnings, h16, deploy, acceptance 1-9 with screenshots; Q1 B changes if the user picked it | acceptance passes |
| T1 review | bar-designer review mode against this spec; deletes `scripts/spike/` | accepted |
