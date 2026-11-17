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
