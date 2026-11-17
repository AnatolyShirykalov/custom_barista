# Backlog

Open work items that are not next. **Not read at session start**: `/roadmap` reads only docs/ROADMAP.md; this file is opened when "Queued next" there runs empty, at an intake of new requests, and by `/wrapup`, which moves the next 5-10 items into "Queued next". New items (follow-ups, proposals, ideas) are added here, under the fitting section, unless they are next. Done items never stay here: they go to `docs/roadmap-archive/` at wrapup.

Work items are checkboxes (`1. [ ]`): what, where, done condition, `→ agent-name`. The status line shows their count as "+N backlog".

### Robustness

1. [ ] **Uniform error display**: widgets print bare "ERR"; show a short dim reason and log details to stderr. Done: shared helper in `utils`, used by all widgets. → `widget-builder`
1. [ ] **Unused modules**: `weather`, `music` packages exist but aren't wired in `main.go`; decide keep/remove (ask user). → `chore`

### Design

1. [ ] **Implement bar design audit option(s)** chosen by the user from D1 spec, then designer review. → `widget-builder` → `bar-designer`

- [ ] **Smoke run stdin EOF panic**: `go run . | head` panics with `EOF` at `main.go:77` when stdin closes; handle EOF gracefully, fix CLAUDE.md smoke command. → `widget-builder`
- [ ] **gofmt**: `clipboard/clipboard.go`, `kbdlayout/mods.go`, `mem/mem.go` not gofmt'd; format + add `gofmt -l .` to checks. → `chore`
