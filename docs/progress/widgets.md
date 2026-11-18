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
