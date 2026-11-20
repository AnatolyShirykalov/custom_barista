# Widgets progress

## Fix GPU widget (2026-11-17)
- Cause confirmed: `nvidia-smi --query-gpu=temperature.gpu,memory.used` now prints `34.82, 462`; `strconv.Atoi` failed.
- Fix: pure `parseGpuStats` (ParseFloat, rounds, errors on `[N/A]`/wrong field count) + table test `nvidia/nvidia_test.go`.
- Errors now show a dim short reason: `GPU n/a` (no nvidia-smi), `GPU smi` (non-zero exit), `GPU parse`.
- Smoke: bar shows temp + `462 MiB`. Deployed.
- Note: smoke run needs a live stdin (`(sleep 6) | timeout 6 binary`), piping `head` gives `panic: EOF` in main.go:77.

## Click paths via home dir (2026-11-17)
- `clipboard` and `ltime` hardcoded `/home/anatolii/scripts/…`; now `utils.Script(name)` (`os.UserHomeDir()` + `filepath.Join`, relative `scripts/<name>` fallback on error, no panic). No other `anatolii` in Go code.
- Table test `utils/utils_test.go`. Build/vet/test green, smoke 0 ERR, deployed.

## Trial width bugs (2026-11-17)
- clip.sh: K sizes now <=5 chars (`99.9K`, `200K`, rolls to `1.0M` at >=999.5K after rounding). ccusage.sh: K/M unit chosen after rounding (999950 -> `1.0M`).
- test.sh: trap/mktemp order fixed, `$cj` quoted, failed ccwidth no longer counts as pass; added clip width rows (204800, 102300, 1048000, 1048575) and cc rows (999950, 200000). 28 pass.
- `gofmt -w kbdlayout/mods.go mem/mem.go`.

## Multi-GPU csv (2026-11-17)

`gpu.sh` and `nvidia.parseGpuStats` use only the first csv line when nvidia-smi prints several. Tests: `gpu_multi` fixture + `gpu3` row in test.sh; two-line row in `nvidia_test.go`. Not reproducible on this one-GPU machine beyond fixtures.

## Remove barista clipboard widget (2026-11-17)
Deleted `clipboard/`, its import and `Get()` in main.go; README module line and backlog "Clipboard polling" dropped. `utils.Script` kept (ltime). i3status-rust clip block untouched.

## 2026-11-18 DP-2 gap freq→mem
- Problem: freq.sh padded up to 6 trailing spaces (assumed 6 two-digit buckets) and mem eng(w:3) added a leading pad, a 6+ space gap on bar-small.
- Fix: freq.sh pad = int(cpus/10) - present two-digit counts (cpu count is constant, so width stays fixed; 32 threads: max 3, now 0-3 spaces); mem `w:3`→`w:2` (avail < 100 GB). test.sh freq rows lose trailing pad (fixtures have few cpus). 38/38 pass, both bars run clean, deployed.
- Caveat: a host with >=100 GB available would show 3 digits (width +1).

## Block explanations (2026-11-18)
Middle click on every block runs `scripts/explain.sh <name>` (names: kbd load temp freq mem disk io gpu net wifi battery sound ccusage clip time) -> detached `yad --mouse --undecorated --timeout 8` popup with an OK button. Middle button was unused on all blocks. `EXPLAIN_DRY=1` prints the text (used by test.sh: every name in config.toml known, <=6 lines, every block has one). Thresholds in the texts are copied from config.toml/scripts; update explain.sh when they change.

## S1 sound block off ALSA (2026-11-18)
- `driver = "alsa"` -> `"pulseaudio"` (PipeWire-pulse, follows default sink). Reason: alsa driver ran `alsactl monitor` per bar, holding card 3 open and blocking HDA codec reconfig. After deploy `pgrep -a alsactl` is empty.
- Old "first frame 0.0%" still occurs: 10 startup frames show the 0% icon, all within ~30 ms of start, then the real volume. Accepted, no hack. explain.sh text unchanged (still accurate). test.sh 54/54, both bars clean.

## U1 Claude usage block built (2026-11-18)
- `scripts/claude-usage.sh` replaces ccusage.sh (spec option A); `claude-rl-tap.sh` + install.sh step 3b insert one marked line after `input=$(cat)` in ~/.claude/bin/claude-statusline (backup `.bak-u1`, rerun adds nothing); `claude-prices.json`; ccusage.sh and cc_*.json removed; explain text, gen-compact pattern, test.sh rows u1-u17 (87/87 pass, no network).
- Live: one real OAuth call succeeded during verification (56%, gate next_at = +180 s); bar shows `56% 117.0M $66.3 cache 96% 0h28m`, run time 0.16 s. After crop: `docs/design/U1-usage-block/img/after.png` (bar is at the bottom of DP-0). No before crop (old script needed npx, 30 s).
- Deviations: none in behaviour; test rows u17 (explain) and u18 (compact) are the existing explain/compact checks plus the renamed pattern; install.sh also warns on missing flock/curl. Acceptance 6 (ccusage comparison) not done.

## U1b 7-day limit mark (2026-11-18)
- `claude-usage.sh`: new field `w` (seven_day pct from the newest of tap/API cache; ignored when its resets_at passed). Mark `7d NN%` as the last 6-char slot (spaces when <= 70 or unknown), yellow > 70, red > 90 (hex = theme warning/critical); block state Critical when 7d > 90 (not when Idle). API cache now also stores seven_day from the same response (no extra calls). Block width 33 -> 40.
- explain.sh text updated; test.sh rows u18-u21 (70, 71, 91, expired), u16 width loop includes w values; 98/98 pass. Deployed; bars show no errors.

## D5-P4 clipboard block removed (2026-11-18)
- Removed clip block + clipboard icon from config.toml, scripts/clip.sh, its fixtures (targets_*, data_*), test rows clip11-15 and width loop, explain.sh `clip` case; install.sh/README drop xclip and clipboard_menu.sh (xclip used nowhere else). Usage block untouched.

## D5-R regrouping built (2026-11-18)
- Built per docs/design/D5-bar-review/spec-regroup.md: config.toml reordered (14 blocks, 7 merge_with_next), gen-compact.sh awk drops the merge flag before a dropped group end (compact.toml: 5 flags), claude-usage.sh 7d mark always shown (dim up to 70), explain.sh ccusage text, test.sh u1/u12/u18 edits + u22/u23 + groups/compact rows.
- test.sh pass=94 fail=0; both configs smoke clean; deployed with install.sh --yes; middle-click on a merged block raises no error (all 14 blocks keep their explain click).
- After crops: docs/design/D5-bar-review/img/live-after-dp0.png, live-after-dp2.png. Awaiting bar-designer review.

## U1d per-part colours (2026-11-18)
- claude-usage.sh: block state always Idle; 5h %, cache %, 7d coloured by own value via pango spans (5h >70 yellow >90 red; cache >=90 green, 70-89 yellow, <70 red; 7d dim/yellow/red). Hex read from config.toml `[theme.overrides]` (CU_CONFIG override, fallback same scheme). Stale 5h stays dim; widths unchanged.
- test.sh: u1-u23 states now Idle, new u24-u27 (boundaries 70/71/90/91, cache 69/70/89/90, 7d 92 Idle, config hex match); explain.sh text updated. pass=107 fail=0, deployed.

## U1c first-run placeholder (2026-11-20)
- claude-usage.sh: when no tap/API window exists and local logs have 0 tokens, prints a dim `cc …` padded to the normal text width (measured from a render at runtime, 40 chars). With local usage but no window it still shows tokens with `?%`.
- explain.sh ccusage text: "cc … = waiting for first data" (kept to 6 lines). test.sh u28 (empty temp cache dir: text, Idle, dim, width = normal). pass=171 fail=0, deployed; both bars no errors, real block shows real data.
