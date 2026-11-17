# Backlog

Open work items that are not next. **Not read at session start**: `/roadmap` reads only docs/ROADMAP.md; this file is opened when "Queued next" there runs empty, at an intake of new requests, and by `/wrapup`, which moves the next 5-10 items into "Queued next". New items (follow-ups, proposals, ideas) are added here, under the fitting section, unless they are next. Done items never stay here: they go to `docs/roadmap-archive/` at wrapup.

Work items are checkboxes (`1. [ ]`): what, where, done condition, `→ agent-name`. The status line shows their count as "+N backlog".

### Robustness

1. [ ] **Uniform error display**: widgets print bare "ERR"; show a short dim reason and log details to stderr. Done: shared helper in `utils`, used by all widgets. → `widget-builder`
1. [ ] **Unused modules**: `weather`, `music` packages exist but aren't wired in `main.go`; decide keep/remove (ask user). → `chore`

### Design

1. [ ] **Upstream issue i3status-rust nvidia_gpu**: block shows 0° because nvidia-smi 620.x prints float temperature (`34.59`), block parses u32. File issue (user's call) so gpu.sh can go. → `researcher`
1. [ ] **Trial bar polish**: layout `us`/`ru` → `US`/`RU` via `[block.mappings]`; sound block shows `0.0%` on first frame. → `widget-builder`

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
