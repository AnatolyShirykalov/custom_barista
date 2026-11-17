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
