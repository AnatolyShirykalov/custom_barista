# Design workstream

## 2026-11-18 D5-R regroup spec
- Spec `docs/design/D5-bar-review/spec-regroup.md`: option B order without clip, 7 merge flags (DP-0 11 → 6 separators, −45 px; DP-2 8 → 5, −27 px); gen-compact gets a generic rule (dropped group end strips the kept block's flag: memory on DP-2); 7d mark always shown, dim ≤70 (M1), `7d  ?%` unknown.
- Verified on 0.40.1: merged blocks keep their own `instance`, middle-click cmd runs per block; an empty next block passes the merge on (laptop without `^en`: wifi glues onto usage, accepted).
- Whole change applied in a scratch repo copy: test.sh pass=94 fail=0 (sp7, u12, u18 edits, u22/u23, 2 group rows). Renders `img/r-dp0-1.png`, `img/r-dp0-2.png`, `img/r-dp2.png`.

## 2026-11-18 D5 page v2 (picture per proposal)
- User: old page hard to work with, needs more pictures. Rebuilt `docs/design/D5-bar-review/questions.html`: one section per decision (F1-F8 with their P fix, options B/A/C), BEFORE/AFTER pairs for DP-0 and DP-2, full bars as two 1x halves, small regions 2x, click to enlarge; radio for A/B/C + checkboxes P2-P5 feed the answer line.
- BEFORE: live crops 21:10 (bar up 5 min after the U1b redeploy, no restart caught). AFTER: real i3bar + i3status-rs in Xvfb with temp config copies (`render/render.sh CFG WIDTH OUT`, status_command `env DISPLAY=:0` so kbd/clip/sound read the real session; i3 needs its own `ipc-socket` and `env -u I3SOCK`). No hand mocks.
- F1/F2 marked resolved by U1 (P1 dropped). Measured: P2 -84 px DP-0 / -48 px DP-2, P4 -12 px, A -276 px, B -330 px (6 separators instead of 12), B DP-2 -145 px.
- Observed: the U1b fixed 7-cell slot leaves a wide gap after `0h09m` while the mark is off; under option B (usage+clip merged) it reads as a hole. Candidate follow-up, not on the page as a pick.
- Remaining: user picks → widget-builder spec.

## 2026-11-18 D5 bar design review (spec/investigation)
- Screenshots of both real bars (import -window root, crops in `docs/design/D5-bar-review/img/today-*.png`); mocks A/B/C rendered with pango (PragmataPro Mono + Symbols Nerd Font Mono 18). Note: magick `-gravity` before `pango:` rotates glyphs; set it only after.
- Findings F1-F8: ccusage green when limit unknown (state Good on `$pct == null`); cryptic "CH"; "B" unit on 7 values; static IP 15 cells; clip pad 5 → 41 px vs 17 px before separator; scattered controls; 13 equal separators; DP-2 year.
- Verified on 0.40.1: `eng(hide_unit:true)` prints "89G"; `merge_with_next` accepted.
- freq→mem gap on DP-2 after b5c2eb5: 29 px vs 17 px for other blocks, extra 12 px = 1 space (pad 1 of max 3; worst 36 px). Slightly over i3's 9 px separator gap; kept for stable width.
- Decision page `docs/design/D5-bar-review/questions.html`: A polish (S), B polish + regroup with merge_with_next (M, recommended), C quiet dim bar (L); picks P1-P5. Edge case for B: gen-compact drops disk/io/ccusage on DP-2, so merge flags must still end on the right block there.
- Remaining: user pick → spec for widget-builder.

## 2026-11-18 U1 Claude usage block (spec)
- Spec `docs/design/U1-usage-block/spec.md`: option A (one 33-cell line `53%   3.4M $1.85 cache 90% 1h46m`, dim "cache" label for D5 F2, Idle when stale/unknown for D5 F1) over B (pct+time only) and C (click toggle). No decision page: layout detail inside the user's picks.
- Sources: repo-owned `scripts/claude-rl-tap.sh`, install.sh inserts one marker line into `~/.claude/bin/claude-statusline` (no copy of that file); OAuth usage fallback gated (180 s, 429 backoff to 1800 s, 401 stale until creds mtime changes, token only via `curl -H @-`).
- Cost from a repo pricing table `scripts/claude-prices.json` (platform pricing page 2026-11-18); statusline `cost.total_cost_usd` rejected (per session, not per window).
- Measured: local log scan of the 5h window (77 files of 1.4 GB) about 0.1 s with find -newermt + grep + one jq pass; 1140 duplicate msg/req groups, all identical usage, so keep-first dedupe is exact.
- Bar screenshot not possible this run (fullscreen window over the DP-0 bar); review takes before/after crops.
- Remaining: widget-builder implements, bar-designer review.

### U1 review (bar-designer, 2026-11-18): accepted, no fixes
- Tests 87/87; live `time claude-usage.sh` 0.15 s; strip width 33 for live, stale, unknown (`?%`) and max values.
- Bar crops 3 min apart (img/review-width.png): separators and neighbours aligned, `cache` dim, icon and glyphs render.
- Token: no part of the access token in ~/.cache/claude-usage (api.json, rate_limits.json, lock); no `set -x`/`Bearer $` in argv; header fed by builtin printf to `curl -H @-`.
- Statusline output identical to `.bak-u1` for the same input; second `./install.sh --yes` keeps exactly one marker line.
- Acceptance 6 replaced by an independent jq recompute (group_by dedupe, own price lookup): 118.95M / $67.34 vs bar 119.0M / $67.4 (gap = haiku >100K tier, which the one-off ignored).
- Deviation, accepted: dim on API `stale` only when the newest data is also older than 300 s (fresh tap data is not dimmed by an old 401); better than the spec's literal rule.

## D5-R regrouping review (2026-11-20): accepted
- Diff 5959269 matches spec-regroup.md: block order §2 exact, 7 flags each right after `block =`, gen-compact awk verbatim, compact.toml 5 flags (none in memory), `gen-compact.sh - | cmp` clean; 7d mark M1 logic kept by later U1d (ea08b4f, colours now read from theme overrides).
- `bash scripts/test.sh`: pass=107 fail=0 (94 + U1d rows). Both bars run i3status-rs 0.40.1, no error blocks; deployed configs equal the repo (install only expands paths).
- Middle-click check: dry-run harness (scratch config copies, explain.sh path swapped for an `EXPLAIN_DRY=1` wrapper, click JSON on stdin). DP-0: load, temp, freq, mem, disk, io, gpu, net, ccusage, kbd, sound, time each gave its own text; DP-2: load, temp, freq, mem, gpu, net, kbd, sound, time (+ hidden battery) likewise. Texts match the thresholds in config.toml.
- Live crops: `docs/design/D5-bar-review/img/review-dp0.png` (left/right halves), `review-dp2.png`: DP-0 6 separators, DP-2 5, dim `7d 49%`, no tofu.
- Deviations: none. No backlog items.

## T1 hover spike (2026-11-20)
- Spike scripts `scripts/spike/` (tee-wrap.py, edges.py, xbars.py; throwaway, not installed). bars.conf temporarily wrapped, restored, i3 restarted; all spike processes gone.
- Edge error 0 px on all 13 (DP-0) + 10 (DP-2) pieces, clicks with button 9. Enter/Leave/Motion delivered by python-xlib (dock windows not override-redirect). Verdict go; table and risks in `docs/design/T1-hover/spike.md`. Next: T1 spec (bar-designer).

## T1 hover spec (2026-11-20)
- `docs/design/T1-hover/spec.md`: option A (tee wrapper writes the latest status line + last click to tmpfs files; separate python-xlib + GTK3 daemon; the wrapper never talks to the daemon, so a daemon crash cannot touch the bar). Against B (own i3status-rs copy: different samples, double API/nvidia-smi calls) and C (hover inside the wrapper: GTK/X failure kills the status line).
- Findings while specifying: i3status-rs `name` = merge group, `instance` = `<block index>:<widget>`, so the explain key comes from block index → `explain.sh <key>` click cmd in the config named by the wrapper; i3bar WM_NAME `i3bar for output <OUT>` maps windows to bars; `get_bar_config` gives font/padding/separator_symbol (all default now). Middle-click yad popup opens tiled by i3 (backlog item).
- Defaults: 500 ms delay, instant browse, 150 ms gap grace, popup PragmataPro Mono 16, #1d1d1d bg, theme idle_fg text, info_fg border, 4 px above the block, clamped to the monitor. Self-check against real click edges; short_text / separator_symbol / padding → that bar's hover off.
- Split into T1a (wrapper), T1b (pure core + fixtures), T1c (daemon, supervisor, install), T1 review. Questions page `docs/design/T1-hover/questions.html` (Q1 middle-click, Q2 delay); mock `img/mock-popup-dp2.png`.

## T1a hover wrapper (2026-11-20, widget-builder)
- `scripts/hover-tee.py` pass-through (writes line to stdout first, then taps `<dir>/<OUT>.status.json` / `.click.json`, atomic, tap errors pause 60 s); `barsconf.sh` wraps both commands, outputs read from the `output` lines of `i3/bars.conf.tmpl` (no template change); `HOVER=0` in bars.env or no python3 = plain commands. `testdata/hover/fake-status.sh` fixture.
- test.sh rows h1-h4, h15 added (existing bars-state row regex extended for the wrapper); 112 pass, 0 fail.
- Live: both bars run through the wrapper, no ERR/Critical blocks, status files update each second, button-9 xdotool clicks on both bars reach i3status-rs and land in `.click.json`.
- Not done (T1b/T1c): layout, state machine, daemon, hover-run.sh, install.sh exec_always.

## T1b hover core (2026-11-20)
- Files: `scripts/hover/layout.py` (edge maths promoted from `spike/edges.py`: Pango text width, min_width int/string, border, tray, regions, hit, `explain_keys` via tomllib, `bar_supported`, `place`), `scripts/hover/state.py` (injected-clock machine: `over/leave/click/unmapped/tick`, actions show/move/hide, `deadline`), `scripts/hover/test_hover.py` (rows h5-h14, called from `test.sh`, counts added).
- Fixtures `scripts/testdata/hover/dp0.json`, `dp2.json`: one sample per piece (status line + click-reported edges from button-9 clicks via the T1a tap files; tray 3 on DP-0, 0 on DP-2). Edge error: 0 px for all 23 pieces (13 + 10), computed with Pango without a display.
- Findings: `name` is the merge group, `instance` `<n>:` is the config block index (spec holds; sound = two pieces sharing 12). `bar_supported` takes the status too (short_text check merged into it). The state machine applies the 300 ms browse window after Leave/tray/unmapped, not after a grace-timer hide; a click keeps suppression across gaps and clears it on tray/Leave.
- Open for T1c: the daemon must call `over(k, now)` after `enter()`; font/DPI/padding/separator come from i3 bar config (`layout` takes the font string without `pango:`). `test.sh` total now 162.

## T1c hover daemon (2026-11-20, widget-builder)
- Files: `scripts/hover-daemon.py` (python-xlib events on both i3bar windows, found under the i3 frames by WM_CLASS; bar config via `i3-msg get_bar_config`; lazy status/click reads; one GTK3 POPUP; one GLib timer for state deadlines / 250 ms tick only while armed or shown; every handler guarded, X errors → rediscover; `--selftest`; `HOVER_DEBUG=1` logs actions and Leave details), `scripts/hover-run.sh` (own process group via setsid, flock single instance, `--replace` TERMs the old group then -9 after 1 s, backoff 1-16 s, gives up after >5 crashes in 10 min, log cut to 200 lines). install.sh: `exec_always ... hover-run.sh --replace` in the marker block, python-xlib / Gtk 3 warnings. test.sh: row h16 (selftest without DISPLAY); h1's direct fake run now reads `</dev/null` (its background `cat` held the test pipe open when stdin was a live pipe). 163 pass.
- Fixes found live: (1) the popup's preferred size is 200x200 until the label is shown; (2) the widget-level empty input shape does not stick, the popup took the pointer when it shrank (Leave Nonlinear on the bar, popup flicker while sliding): set on the GdkWindow after every show, plus one resize+move per show; (3) a bar mapped under a resting pointer (Win+i on) gets its Enter before our event mask: query the pointer when a bar is added.
- Acceptance: 1 pass (every block on both bars shows its text above the block, DP-2 time clamped right; crops `img/review-hover-{load,sound,time}-dp{0,2}.png`, `ccusage-dp0`); 2 pass (slide 6 px steps load→time: 12 shows, 0 hides; gap 100 ms → next shown at once, `slide-dp0`); 3 pass (tray icon: Leave Inferior → hide, back → shown, `tray-dp0`); 4 pass (left click on time: hide, calendar opens, no popup while on time, sound shows after, `click-dp0`); 5 pass (kill -9: back in 1.1 s, status ts advancing, hover works); 6 pass (off: no popups; on: popup 0.63 s after Win+i incl. the 500 ms delay, `winon-dp0`; after `install.sh` + 2× `i3-msg restart` exactly 1 daemon); 7 pass (off: wrappers and i3status-rs all `Tl`); 8 pass (60 s idle: daemon 0.01 % CPU, RSS 72 MB; wrappers 0.23 / 0.16 % vs i3status-rs 0.10 / 0.08 %); 9 pass (test.sh 163/0, no tofu). Button-9 self-check clicks on both bars: 0 px.
- Open: Q1/Q2 unanswered (delay stays `state.DELAY` 500); T1 review deletes `scripts/spike/`. Needs bar-designer review.

## T1 review (2026-11-20, bar-designer)
- Verdict: accepted. Wrapper has no X/GTK/JSON on the critical path, tap errors pause 60 s, PDEATHSIG set; daemon handlers all guarded, X loss → exit 0; hover-run.sh flock + setsid group + `--replace` → 1 daemon after `i3-msg restart` (checked). `HOVER_DEBUG` is env-gated, no leftover prints.
- Live spot-check (fresh crops in scratch, not committed): DP-0 gpu centred above the block, slide gpu→net shown in 150 ms (browse), time near tray; DP-2 load, time clamped right 4 px from the edge; popups 4 px above the bar, #1d1d1d / #777777 border / white PragmataPro, no tofu. Pointer parked off the bars after.
- Fixed: `hover-tee.py` stdout write now loops on short writes (a signal such as i3bar's SIGSTOP can cut a blocking pipe write and would have dropped the rest of a status line). Deleted `scripts/spike/`. test.sh 163/0. Nothing backlogged.
- Open: Q1/Q2 (`questions.html`) still with the user.

## T1d remove middle-click popups (2026-11-20, widget-builder)
- Q1 B: `scripts/hover/keys.toml` maps blocks to explain.sh keys (`block` type + `command` substring / `device`, first match wins); `layout.explain_keys` reads it (daemon and h10 unchanged otherwise). All button-2 explain.sh clicks removed from `config.toml`, `compact.toml` regenerated.
- `scripts/explain.sh` now only prints the text (yad path removed, nothing else used it; EXPLAIN_DRY accepted). test.sh explain rows now iterate keys.toml and assert no explain.sh left in config.toml; backlog item about the tiled yad popup deleted. test.sh 163/0.
- Live after `install.sh --yes`: both bars no ERR; xdotool middle click on DP-2 and DP-0 blocks opens no yad; hover shows temp+mem on DP-2 and temp+freq on DP-0 with the right text (screenshots).
- T1e hardening untouched.

## T1e hover hardening (2026-11-20, widget-builder)
- HOVER persisted in bars.env (`install.sh`: env, else the last install's value, else 1), so Win+i (`barsconf.sh`) keeps it. `exec_always hover-run.sh --replace` stays; with HOVER=0 hover-run stops a running supervisor, removes `*.status.json`/`*.click.json` and exits without a daemon. `hover-tee.py` removes its output's tap files at start (an earlier session's files are never read).
- `hover-tee.py` taps only `[...]` status lines (the protocol's opening `[` was written as `"status":[`).
- `hover-run.sh --replace` kills the old group only if `/proc/<pid>/cmdline` names hover-run.sh (daemon.pid holds the supervisor's pid, not the daemon's) and it is not ourselves.
- Without XDG_RUNTIME_DIR: private `/tmp/custom_barista-$UID` (0700, refused if not our own dir/mode or a symlink), new `scripts/hover/rundir.py` for tee + daemon, same rule in shell in hover-run.sh.
- Daemon: bar config without `font` falls back to `monospace 8`. Shellcheck -S warning clean on `scripts/*.sh install.sh` (also install.sh:43 one-item loop, test.sh:137 `DISPLAY=`).
- test.sh: h2b (stale tap files removed, bare `[` not tapped; fake-status `FAKE_STOP=1`), r1-r5 for hover-run.sh with `scripts/testdata/hover/fake-daemon.sh` via `HOVER_DAEMON`/`HOVER_RUN_SLEEP` (backoff 1-16 s + give-up after 6 crashes, exit 0 stops, single instance + --replace, foreign pid left alive, HOVER=0). 169 pass.
- Live: `install.sh --yes` → 1 daemon, 2 tees, 2 bars, hover on both; popups for keyboard (DP-0, DP-2) and date (DP-2). `HOVER=0 install.sh --yes` + Win+i twice: no tee in bars.conf, no daemon, tap files gone; restored HOVER=1.

## T1f docs (2026-11-20, chore)
- README.md: script/file list (claude-usage, claude-rl-tap, explain, hover-*, hover/, install.sh, i3/), deps (python-xlib, python-gobject, curl, flock; node/npx dropped: nothing uses them, also removed from install.sh dep check), new Hover tooltips section. CLAUDE.md:5 got the hover clause + HOVER=0. Backlog line removed.

## Hover: first popup missed once (2026-11-22, widget-builder)
- Symptom (look pass 2026-11-20): the first hover, on the DP-0 load block, showed no popup and logged nothing; a retry worked.
- Not reproduced: 48 hovers right after `i3-msg restart` (both bars, waits 0.5-5 s; each one a fresh daemon's first popup) and 250 hovers without restart, all popups up (latency 503-510 ms, first popup included). Scripts: xdotool warp + Xlib check for the daemon's mapped override-redirect window.
- Cause found in the code: python-xlib moves events that arrive while a request waits for its reply (query_pointer, get_geometry, query_tree) into its own queue; the GLib fd watch never fires for them, so they sat there until the next X event. The timers did such requests: rediscover (every 10 s) could swallow the first Enter of a pointer that then rests (a xdotool warp: no further motion), tick (relayout's query_pointer) swallowed a Leave on 22 of the first ~70 hovers measured with a log line.
- Fix (`scripts/hover-daemon.py`): `drain()` (the on_x loop) also runs at the end of `tick()` and `rediscover()`. A rediscover drain that finds events logs `rediscover: N queued X events handled` (tick drains only with HOVER_DEBUG: common). test_hover.py h17 (fails on the old daemon). test.sh pass=176 fail=0; deployed, both bars i3status-rs, smoke of both configs clean.
