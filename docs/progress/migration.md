# Migration to i3status-rust (D3)

## 2026-11-17: D3 spec done (bar-designer)
- Output: `docs/design/D3-i3status-rust/spec.md` (block map in main.go order, verbatim `config.toml`, script I/O contracts, 15-row test table, i3 snippet for `bar-rs` at the top with Mod3, acceptance checks), `questions.html` + `img/` (mocks rendered with Symbols Nerd Font Mono: no tofu).
- User step: neither i3status-rust nor a Nerd Font is installed → `sudo pacman -S i3status-rust ttf-nerd-fonts-symbols-mono`.
- Icons: every block has a distinct glyph with a verified codepoint; GPU = md-expansion_card U+F08AE (the default md-monitor is vague).
- Found while speccing: barista's disk IO widget never shows (diskio asks for `cryptroot`, the kernel name is `dm-0`); the click paths use `/home/anatolii/...` (wrong user).
- Waste fixes: ccusage pinned `ccusage@20.0.51`, every 60 s instead of 5 s (measured about 2 CPU-s per run, so about 0.4 of a core before); clipboard checks TARGETS first, never reads images, reads text capped at 1 MiB, every 5 s.
- Questions for the user (3): GPU glyph, freq histogram vs average, music/weather. Defaults are the recommended answers; spec section 6 gives the exact edits for the other answers.
- Accepted losses (spec section 7): no separate urgent level, no red non-US layout, temp shows the max only.

## D3 build trial bar (widget-builder, 2026-11-17)

- Files: `i3status-rust/config.toml`, `scripts/{freq,ccusage,clip,gpu}.sh`, `scripts/test.sh` + `testdata/` (17 rows pass: 15 from spec + 2 gpu). Second bar `bar-rs` added to `~/.i3/config` (real i3 config; backup `~/.config/i3/config.bak-d3`). Both bars run (`bar-0`, `bar-rs`); screenshot `docs/design/D3-i3status-rust/img/trial.png`, no tofu.
- User picks applied: GPU md-expansion_card; freq histogram kept with icon md-sine_wave U+F095B (the cpu block default md-speedometer is too close to the load gauge md-gauge); no music/weather.
- Fixed widths: `.eng(w:N)` on temp (2), mem/disk (3), vol (3), battery (3), wifi signal (3), net/IO speeds (4), load (4); freq.sh pads leading spaces as before; clip.sh pads text to 5 chars; gpu.sh `%2d° %4dMiB`. Not fixed width: ssid, ip, ccusage text, date.
- Deviation: the `nvidia_gpu` block showed `0°` because the new driver prints temperature as a float (`34.34`; same class as A1 finding). Replaced by `scripts/gpu.sh` (nvidia-smi, rounds, Idle/Warning>60/Critical>70). `gpu` icon override moved to `[icons.overrides]`.
- Spec row 14 expectations for clip are compared after left-trim (padding). `i3status-rs` has no error blocks in 6 s run. Clicks (spec check 6) not exercised by hand.

## D3 review (bar-designer, 2026-11-17)

Verdict: **accept with fixes** (one small builder item, 5c). Screenshot of both bars docked (top 36 px of DP-0) compared with barista bar-0.

| Check | Result |
|---|---|
| 13 widgets, order, glyphs | All present in main.go order (wifi + battery hidden as spec'd: no carrier / desktop). No tofu; GPU md-expansion_card, freq md-sine_wave, IO md-swap_vertical, ccusage sparkles, clipboard all render. Data matches barista (ip, mem, GPU °/MiB, ccusage text, clip size). |
| Widths over 20 s (101 updates) | Text length of every block identical in all 101 updates. |
| Unfixed widths | ip, ssid, date: fine (date is fixed by format; ip/ssid change only on reconnect). **ccusage jumps**: remaining `1h22m`→`59m`→`9m` (5/3/2 chars), tokens `999.9K`/`73.6M`/`100.0M`, `CH 100%`; it sits right of most blocks, so every change shifts everything left of it. **gpu.sh `%4dMiB`**: card has 16303 MiB, >9999 MiB used → 5 digits. |
| Clicks (check 6) | Exercised via stdin click events on a separate instance: layout us→ru→us OK; volume wheel 70→75→70 OK, right click → `MUT` yellow and back OK. pavucontrol, clipboard menu, calendar not launched (GUI); target scripts exist and are executable. |
| ccusage cost (check 7) | interval 60, pinned `ccusage@20.0.51`; 22 s run showed one run; 5-min pgrep sample running detached (roadmap Background checks). |
| nvidia_gpu → gpu.sh | **Accepted.** nvidia-smi 620.70 prints `34.59`; upstream block parses temperature as u32 (docs.rs nvidia_gpu.rs), so the field fails. Upstream issue → backlog. |
| Mod3 | `xmodmap -pm`: mod3 = ISO_Level5_Shift on keycode 203 only, a virtual key with no physical key. Hold-to-show is dead for **both** bars (pre-existing). Bars are reachable via `$mod+i` (`bar mode toggle`, toggles both); item 5b replaces this. |
| Minor | Layout shows `us`/`ru` lowercase (barista `US`); 1st frame of sound block shows `0.0%` at startup only. Not fixed (backlog). |

## 5b Win+i bar cycle (widget-builder, 2026-11-17)

- `~/.i3/config` (backup `config.bak-5b`): barista bar got `id bar-barista`, `mode dock`; bar-rs `mode invisible`; `modifier Mod3` removed from both (dead key); `$mod+i` runs `i3status-rust/scripts/barcycle.sh`.
- Script cycles off -> barista -> rs -> off; derives the current state from real bar modes (`get_bar_config`), so a restart/reload (which resets to config default = barista dock) never leaves a stale state file; `${XDG_RUNTIME_DIR:-/tmp}/barcycle.state` records the next state.
- Verified after `i3-msg reload`: 4 calls gave rs, off, barista, rs, all modes matching; left in barista.

## 5c D3 fix widths (widget-builder, 2026-11-17)

- `ccusage.sh`: pct padded to 4 (`%` incl.), tokens padded to 5 + unit (blank unit under 1K), `CH` pad 4, remaining always `%dh%02dm`; unknown pct and zero values keep their slots (no omitted parts). Text is now 25 chars always.
- `gpu.sh`: `%5dMiB` (fits 16303).
- `test.sh`: expectations updated; width rows vary tokens 5..53.3M, CH 0..100, remaining 5..299 min, GPU `99, 16303` vs `9, 5`. 22 pass, 0 fail.
- Trial bar not restarted (5b was changing bar modes); the new text shows at the next rs restart.
- 2026-11-17 ccusage cost sample: 3 runs/5 min on trial bar (was every 5 s). OK.

## Trial bar polish (#8, 2026-11-17)

- Layout: `[block.mappings]` with keys `"us (N/A)"`/`"ru (N/A)"` (xkbevent has no variant) gives `US`/`RU`; verified by toggling layout, width unchanged.
- Sound: first-frame `0.0%` came from the pulseaudio/auto driver (volume 0 before the first query; 10 frames at start). `driver = "alsa"` (pipewire-alsa Master) shows 70% from frame 1, 0 early `0.0%` frames. Trade-off: no >100% display (max_vol 100 anyway). Click/mute not re-tested with alsa.

## Clip fixture (#9, 2026-11-17)

- `scripts/test.sh` generates the 2 MB `data_2m` into a `mktemp -d` (removed on exit); tracked file git rm-ed, no .gitignore needed. `cl` now takes a full path for the data file. 22/22 pass.

## Upstream issue draft (#10, 2026-11-17)

- `docs/design/D3-i3status-rust/upstream-issue.md`: nvidia_gpu `temperature: u32` + `parse().unwrap_or_default()` (nvidia_gpu.rs L210/L258) turns float `44.79` into `0°`. No existing upstream issue (#1769 is the `[N/A]` case). User posts it.

## 2026-11-17: Per-monitor trial bars (2a, widget-builder)
- i3status-rust 0.40.1 has no config include/merge, so `i3status-rust/compact.toml` is generated from `config.toml` by `scripts/gen-compact.sh` (awk: drops `disk_space`, `disk_iostats`, the ccusage custom block, ` $ip ` in the `^en` net format). `test.sh` checks it is in sync and that config.toml still has the 4 patterns the generator keys on (31 pass).
- `barcycle.sh` sets `bar-rs` and `bar-rs-small` to the same mode (state still read from `bar-rs`). Cycle verified: barista -> rs (both dock) -> off -> barista.
- Barista left as is (one bar, no `output`, on both monitors): main.go has no flags, a per-output variant would need a CLI flag and module filtering; not cheap enough for the trial.
- `~/.i3/config` (separate git repo, no commits): `bar-rs` got `output DP-0`; new `bar-rs-small` block after it (same settings, `output DP-2`, `status_command i3status-rs ~/projects/custom_barista/i3status-rust/compact.toml`, `tray_output none`). Backup: `~/.i3/config.bak-2026-11-17-2005`. `i3 -C` clean; after restart 3 i3bars + 2 i3status-rs run, no error blocks.
- Remaining: 2b (tray follows Win+i, bars.conf).

## 2026-11-17: Tray follows Win+i (2b, widget-builder)
- Bars moved to generated `~/.i3/bars.conf` (`include` + `$mod+i` binding between the install.sh markers). One generator `i3status-rust/scripts/barsconf.sh <barista|rs|off>` (template `i3/bars.conf.tmpl`, paths from `~/.config/custom_barista/bars.env` written by install.sh); first line `# state: X` is the state on disk. Used by install.sh (keeps the current state) and barcycle.sh (writes next state, `.prev` copy, `i3 -C` with restore, `i3-msg reload`; reload does re-read the include and applies mode + tray_output).
- Live migration: `install.sh --yes` (backup `~/.i3/config.bak-2026-11-17-2015`, plus manual `config.bak-2026-11-17-2012`); old bar blocks removed, old binding commented, orphan DP-2 comment deleted by hand. Second `--dry-run`: no diffs.
- Verified: cycle rs -> off -> barista -> rs -> off -> barista, get_bar_config modes/tray_outputs match each state; screenshots of the DP-0 bar end: tray in barista (4 icons) and rs (3 icons); user also saw the tray on the rs bar (relayed by the main session). Restart in rs kept rs. Ended in barista (start state).
- Zoom's tray icon did not re-dock into the rs bar (back in barista): backlog.
- test.sh: generator rows per state (3 bars, dock count, one `tray_output DP-0` except off, no leftover tokens, `i3 -C`): 34 pass.

## 2026-11-17: Tray icons lost after Win+i (widget-builder)
- Diagnosis (ctypes Xlib helper for `_NET_SYSTEM_TRAY_S0` owner + docked windows, `i3bar --verbose` log, i3 4.25 / Qt 6 sources). No SNI watcher on the bus: Telegram (Qt 6.12), Zoom, nm-applet, neck-prompt all use xembed. On every reload i3bar kicks all icons (unmap, reparent to root, fake DestroyNotify + MANAGER) and they re-dock; reload does not restart i3bar.
- Cause 1 ("Zoom missing", reproduced on the first handoff): the tray moved between two live i3bar processes. neck-prompt reuses its icon window; the old i3bar still holds its event mask (ResizeRedirect is exclusive) on it, so the new i3bar's `change_window_attributes` fails with BadAccess, it never sees MapNotify and leaves that icon at the default rightmost slot, on top of the icon that belongs there (Zoom). X says both are docked and mapped. Only an i3 restart cleared it.
- Cause 2: concurrent Win+i presses ran barcycle.sh in parallel: same state read, presses lost (3 presses = 1 step), `mv: cannot stat bars.conf.new`, overlapping reloads.
- Telegram: was stuck before any test (re-created its icon window on each MANAGER, never docked; survived reload and i3 restart, so its Qt tracker pointed at a dead tray window). Only restarting Telegram cured it (done once: `Telegram -quit`, `i3-msg exec Telegram --`, window moved back to workspace 1). Not reproduced afterwards in ~190 handoffs of the old layout, so the trigger is unproven; the suspect is a tray owner destroyed during a handoff, which the new layout no longer does.
- Fix (a): one tray owner that never moves. `bars.conf.tmpl` now has two fixed bars, `bar-main` (DP-0, `tray_output DP-0` in every state) and `bar-small` (DP-2); `barsconf.sh` switches `mode`, `status_command` and font per state (barista: `custom_barista` on both, two processes instead of one; rs: config.toml / compact.toml; off: invisible, icons stay docked). i3bar restarts the status command on reload, so only one bar kind runs at a time (a switch takes the start-up time of the status program). Output lists cannot change on reload (i3bar appends), hence two bars with fixed outputs.
- barcycle.sh: `flock` on `bars.conf.lock` + 0.4 s settle (`BARCYCLE_SETTLE`). The settle is needed: raw reloads a few ms apart with a command switch freeze i3bar 4.25 (`killpg` before the new child's `setpgid`, then `waitpid` forever; seen in the stress test, recovered with SIGTERM to the status child).
- Verified: test.sh 36 pass (generator rows rewritten, new row: 3 concurrent presses, fails on the old script); `i3 -C` ok; `install.sh --dry-run` no diffs; 12 rounds of 1-5 overlapping presses: all 4 icons docked at distinct positions, right status processes, no blocked i3bar; full cycle barista -> rs -> off -> barista -> rs with 4 icons in each visible state (screenshots in scratch). Ended in rs. Backups: `~/.i3/config.bak-2026-11-17-tray`, `~/.i3/bars.conf.bak-2026-11-17-tray` (old three-bar layout).

