# Roadmap and session handoff

**Read this first when starting a new Claude Code session.** It lists what is in flight, the next 5-10 items and which decisions are still open; it stays small (≤ ~8 KB). Later items live in `docs/BACKLOG.md` (not read at session start), finished items in `docs/roadmap-archive/`. Whoever starts or finishes a work item edits this file right away (in the same commit when it is tracked).

Scope: whole project: maintenance of the custom_barista i3 status bar (fixing widgets after system upgrades, dependency updates, design/clarity improvements). Background docs: `CLAUDE.md` (conventions and policy), `docs/progress/*.md` (per-workstream status), `docs/working-agreements.md` (user preferences).

## How we work

- The main session coordinates. Work goes to project agents (`.claude/agents/`, never `general-purpose`). One agent at a time (two at most): many in parallel hit the usage limit.
- Split work into small tasks a fresh agent can finish in a small context. One item per agent; it stops after it.
- Each agent finishes its item fully, records status in `docs/progress/<workstream>.md`, updates this file, commits its code and **never pushes** (the main session reviews and pushes in batches).
- No waiting agents: long jobs run detached (`nohup … > log/<name>.log 2>&1 &`), capped (`timeout 30m` or an item limit), resumable and safe to kill, and leave a check item under "Background checks" with the check command and the command for the next chunk.
- Every change keeps `go build ./... && go vet ./...` (plus `go test ./...` once tests exist) and the bar running green.
- New items go to `docs/BACKLOG.md` unless they are next. `/wrapup` moves finished items verbatim to `docs/roadmap-archive/` (look there for the history of done work) and refills "Queued next" from the backlog.
- Deploy = `go install .` + `i3-msg restart`; agents may do it without asking after the checks pass.

Work items are checkboxes (`- [ ]` / `1. [ ]`, `[x]` when done) so the status line can count them ("roadmap done/total +N backlog, M done").

## In flight



### Queued next (one agent each, in order)

1. [x] **Fix GPU widget** (`nvidia/nvidia.go`): shows "GPU ERR" since the last upgrade. Likely cause: `nvidia-smi --query-gpu=temperature.gpu` now prints `39.70` (float), `strconv.Atoi` fails. Parse floats, add a parser table test, show a short reason on error. Done: bar shows temp + VRAM on the RTX 5070 Ti, deployed. → `widget-builder` Done 2026-11-17, see docs/progress/widgets.md.
2. [ ] **Alternatives report** (user request): challenge the custom-barista approach. Compare alternatives (i3status, i3status-rust, i3blocks, bumblebee-status, py3status, polybar, waybar/sway path, yambar, keep barista, others found) on: features we use (nvidia, hwmon temps, freq, vol, clipboard, ccusage, netm), migration cost, maintenance after upgrades, upstream activity, resources, theming. Recommendation. Done: local `docs/design/A1-alternatives/report.html`. → `researcher`
3. [ ] **Widget health sweep**: run `timeout 5 go run .`, list every widget that prints ERR/empty after the upgrade (hwmon, vol, freq, batt…), one backlog item each. Done: table in `docs/progress/widgets.md`. → `widget-builder`
4. [ ] **Dependency survey + safe bumps**: go.mod (toolchain go1.24.5, system Go 1.27), barista.run, direct deps; commit safe bumps, backlog breaking ones. Done: builds, bar runs, versions in `docs/progress/deps.md`. → `dep-updater`
5. [ ] **Bar design audit** (spec mode): screenshot current bar, list clarity/look issues (grouping, widths jitter, colors, icons), 2-3 options for the top issues. Done: `docs/design/D1-bar-audit-spec.md`. → `bar-designer`
6. [ ] **README refresh**: module list stale (missing clipboard, freq, vol, weather, music; ccusage described as CPU usage); Go version prereq. Done: README matches `main.go`. → `chore`

### Background checks

Long detached jobs started by agents: `check` command, done when, follow-up. Main session checks between agents, removes finished items.

_(none)_

## Recurring checks

After about every 3 feature tasks, run the check with the oldest last-run date (one agent each, dated note in `docs/progress/recurring.md`).

| Check | Agent | What | Last run |
|---|---|---|---|
| Agent roster | `agent-curator` | revise `.claude/agents/*`: tighten, split, merge, add specialists for upcoming work no agent fits, retire unused; evidence from recent reports and items that lacked a specialist | 2026-11-17 (set up) |
| Context diet | `context-auditor` | tools, MCP servers, connectors, plugins, skills, user agents loaded here but unused/unrelated; context cost; main session asks the user which to disable per project, applies, checks `/context` | 2026-11-17 (set up) |
| Git hygiene | `repo-janitor` | anything tracked that shouldn't be (build output, logs, dumps, caches, large binaries, local config, secrets); `.gitignore` gaps; safe `git rm --cached` | never |
| Backlog tidy | `chore` | monthly: drop or merge stale, superseded or duplicate backlog items, check each still has an agent and a done condition; never touch the roadmap's queue | never |
| Dependency updates | `dep-updater` | `go list -m -u all`, barista.run upstream, Go toolchain; bump what is safe, backlog the rest | never |
| Look/usability pass | `bar-designer` | screenshot the bar; clarity, colors, stable widths, glyphs render; findings → backlog | never |
| Widget health | `widget-builder` | every widget shows real data on this machine (`timeout 5 go run .`, grep `ERR`); after system upgrades check nvidia-smi, hwmon, pulse, sysfs formats | never |
| Code review + docs | `code-reviewer` | review diffs since last run; README module list and CLAUDE.md match the code | never |


## Open decisions (ask the user)

Each line carries `asked <date>` or `ask when <trigger>`; `/wrapup` asks those whose trigger has passed.

- Keep or remove unused `weather`/`music` packages — ask when the README refresh runs.
