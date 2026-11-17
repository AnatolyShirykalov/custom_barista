# Backlog

Open work items that are not next. **Not read at session start**: `/roadmap` reads only docs/ROADMAP.md; this file is opened when "Queued next" there runs empty, at an intake of new requests, and by `/wrapup`, which moves the next 5-10 items into "Queued next". New items (follow-ups, proposals, ideas) are added here, under the fitting section, unless they are next. Done items never stay here: they go to `docs/roadmap-archive/` at wrapup.

Work items are checkboxes (`1. [ ]`): what, where, done condition, `→ agent-name`. The status line shows their count as "+N backlog".

### Robustness

1. [ ] **Click paths /home/anatolii**: `clipboard/clipboard.go:64`, `ltime/ltime.go:21` (commit d6eceaa) point to `/home/anatolii/scripts/…`, scripts live in `/home/anatoly/scripts`; ask user, then build path from `os.UserHomeDir()`. Done: clicks open menu/calendar. → `widget-builder`
1. [ ] **Trial script widths**: `clip.sh:13` prints `200.0K`/`1023.4K` (6-7 chars, pad is 5) for ≥100K; `ccusage.sh:28` prints `1000.0K` for 999950-999999 tokens. Pick unit after rounding, `%3.0fK` above 99.9K; add test rows. → `widget-builder`
1. [ ] **test.sh fixes**: line 37 counts `pass` also on a ccwidth failure; `trap` (line 34) set after `mktemp -d` (line 4), `$cj` unquoted. Done: failure gives pass unchanged, temp dirs removed on any exit. → `chore`
1. [ ] **Multi-GPU csv**: `gpu.sh:5` and `nvidia/nvidia.go:44` give ERR when nvidia-smi prints >1 line; use first line, add test row each. Low (one GPU here). → `widget-builder`
1. [ ] **nvidia reason test**: error-to-text mapping (`GPU n/a`/`smi`/`parse`, `nvidia.go:56`) untested; extract a func, table test. → `widget-builder`
1. [ ] **Docs for trial bar**: README trial section lacks runtime deps (jq, xclip, node/npx, nvidia-smi, xdotool, pavucontrol); CLAUDE.md lacks i3status-rust (tree, check `bash i3status-rust/scripts/test.sh`, colors via `[theme.overrides]` mirroring the scheme, freq palette exception) and still says "go test once tests exist". Main session edits CLAUDE.md with user. → `chore`
1. [ ] **Uniform error display**: widgets print bare "ERR"; show a short dim reason and log details to stderr. Done: shared helper in `utils`, used by all widgets. → `widget-builder`
1. [ ] **Unused modules**: `weather`, `music` packages exist but aren't wired in `main.go`; decide keep/remove (ask user). → `chore`

### Design


1. [ ] **Implement bar design audit option(s)** chosen by the user from D1 spec, then designer review. → `widget-builder` → `bar-designer`

- [ ] **Smoke run stdin EOF panic**: `go run . | head` panics with `EOF` at `main.go:77` when stdin closes; handle EOF gracefully, fix CLAUDE.md smoke command. → `widget-builder`
- [ ] **gofmt**: `clipboard/clipboard.go`, `kbdlayout/mods.go`, `mem/mem.go` not gofmt'd; format + add `gofmt -l .` to checks. → `chore`
- [ ] **ccusage polling**: `npx ccusage@latest` every 5 s (Node start each time, unpinned); pin version, poll less often. (from A1 report) → `widget-builder`
- [ ] **Clipboard polling**: reads whole clipboard every 2 s just for size; cheaper check. (from A1 report) → `widget-builder`
- [ ] **Dead import path**: `barista.run` domain expired, upstream archived; builds only via Go proxy cache. Vendor or replace path. Only if we keep barista. → `dep-updater`

- [ ] **Widget health sweep**: run `timeout 5 go run .`, list every widget that prints ERR/empty after the upgrade (hwmon, vol, freq, batt…), one backlog item each. Done: table in `docs/progress/widgets.md`. → `widget-builder` (parked: i3status-rust migration)
- [ ] **Dependency survey + safe bumps**: go.mod (toolchain go1.24.5, system Go 1.27), barista.run, direct deps; commit safe bumps, backlog breaking ones. Done: builds, bar runs, versions in `docs/progress/deps.md`. → `dep-updater` (parked: i3status-rust migration)
- [ ] **Bar design audit** (spec mode): screenshot current bar, list clarity/look issues (grouping, widths jitter, colors, icons), 2-3 options for the top issues. Done: `docs/design/D1-bar-audit-spec.md`. → `bar-designer` (parked: i3status-rust migration)
- [ ] **Barista diskio + click paths**: diskio looks for `cryptroot` (kernel dev is `dm-0`), click scripts point to `/home/anatolii/...`. Only if barista stays past trial. (from D3 spec) → `widget-builder`
