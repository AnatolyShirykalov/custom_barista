# Recurring checks log

Dated notes from each recurring check (see the "Recurring checks" table in `docs/ROADMAP.md`).

## 2026-11-17 — Context diet (set up)

Disabled for this project in `.claude/settings.local.json` (personal): claude.ai Gmail, Google Calendar and Google Drive connectors (`deniedMcpServers`); skills docx, pptx, xlsx, pdf, google-workspace, morning, concerts, import-memory, deep-research (`skillOverrides: off`). Reason: unrelated to a Go i3 status bar. Re-enable by deleting the entries.
Kept: Claude Docs connector, web/image design skills, Chrome browser tools.
To confirm: run `/context` in the next session — whether project `skillOverrides` hides user/plugin skills and whether denied connectors drop out of the tool list.

## 2026-11-17 — Git hygiene

- Repo had no `.gitignore`; added one (binary `/custom_barista`, `/log/`, `*.log`, `*.bak*`, `*.test`, `.env*`, `*.swp`, `.claude/settings.local.json`, coverage/profiles).
- Nothing tracked needed removal: no binaries, logs, dumps, env files or keys (weather API key is passed as a parameter, not stored). Largest tracked: `i3status-rust/scripts/testdata/data_2m` (2 MB, used by test.sh clip15; kept, could be generated at test time instead), fonts (128/100 KB), PNGs all under 32 KB.
- No `git rm --cached` needed.

## 2026-11-17 — Code review + docs (3de417f..6b97023)

Checks: `go build/vet/test ./...` ok; `i3status-rust/scripts/test.sh` 22/22; shellcheck -S warning clean. Edge cases probed with scratch fixtures.

| Sev | Where | Problem | Fix |
|---|---|---|---|
| medium | clipboard/clipboard.go:64, ltime/ltime.go:21 | d6eceaa changed click paths to `/home/anatolii/scripts/…`; this user's scripts are in `/home/anatoly/scripts` -> clicks do nothing | `os.UserHomeDir()`; confirm intent with user |
| low | i3status-rust/scripts/clip.sh:13 | `%4.1fK` gives `200.0K`, `1023.4K` (6-7 chars, pad 5): width jumps | `%3.0fK` at >=100K, test row |
| low | i3status-rust/scripts/ccusage.sh:28 | 999950-999999 tokens -> `1000.0K` (7 chars) | choose unit after rounding |
| low | i3status-rust/scripts/test.sh:37 | ccwidth loop increments pass also on failure | else-branch |
| low | i3status-rust/scripts/test.sh:4,34 | temp dir made before trap; `$cj` unquoted in trap | trap right after mktemp |
| low | gpu.sh:5, nvidia/nvidia.go:44 | multi-GPU (several csv lines) -> ERR | first line only |
| low | nvidia/nvidia.go:56 | reason mapping untested | extract + table test |
| docs | README.md:78-104 | trial deps missing: jq, xclip, npx, nvidia-smi, xdotool, pavucontrol | add list |
| docs | CLAUDE.md:7 | "go test once tests exist" stale; no i3status-rust mention | add: tree, test.sh check, theme overrides mirror scheme, freq palette hex is the one exception (freq.sh:8, freq/freq.go:23) |
| info | docs/BACKLOG.md "Unused modules" | weather/music already deleted, item stale | mark done (Backlog tidy) |

No findings: barcycle.sh (derives state from real modes; concurrent presses compute the same target, benign), config.toml colors match `main.go` scheme, ccusage pinned and polled every 60 s, README module list matches `main.go` order, go.mod/go.sum tidy.
