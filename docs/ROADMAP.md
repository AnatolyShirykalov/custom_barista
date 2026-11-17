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

_(no agent running)_ Done recently (2026-11-17): GPU float fix, alternatives report (→ i3status-rust trial), D3 spec/build/review, Win+i cycle, widths, README, polish, fixture, upstream issue draft, git hygiene + code review checks. Archive: `docs/roadmap-archive/2026-11.md`.

### Queued next (one agent each, in order)

1. [ ] **Click paths via home dir** (user 2026-11-17): `clipboard/clipboard.go:64`, `ltime/ltime.go:21` point to `/home/anatolii/scripts/…`; build with `os.UserHomeDir()`; `go install .` + `i3-msg restart`. → `widget-builder`
2. [ ] **Per-monitor trial bars** (user request): DP-0 (3840, 4K) keeps all blocks; DP-2 (2560x1600) hides ccusage, disk space, disk IO, and the IP address (in the net blocks). Two i3 `bar {}` blocks with `output DP-0` / `output DP-2`, ids `bar-rs` / `bar-rs-small`, `i3status-rust/compact.toml` (keep the shared parts in one place if the 0.40 config allows it, else generate from config.toml); barista likewise per output if cheap; barcycle.sh switches all bars of a state together; tray follows Win+i (user 2026-11-17): bar blocks move to generated `~/.i3/bars.conf` (`include` in `~/.i3/config`, i3 4.25); barcycle.sh rewrites it per state (visible bar `mode dock` + `tray_output DP-0` — primary HDMI-0 is disconnected; others `mode invisible` + `tray_output none`), then `i3-msg reload`; state survives restart; template for bars.conf lives in repo `i3status-rust/i3/`; backup `~/.i3/config` first. → `widget-builder`
3. [ ] **Trial width bugs** (code review 2026-11-17): clip.sh `200.0K`/`1023.4K` overflow the 5-char pad; ccusage.sh `1000.0K` → pick the unit after rounding; test.sh counts a failed width check as a pass, trap set after mktemp, `$cj` unquoted. → `widget-builder`
4. [ ] **Docs for trial bar**: README trial section lacks runtime deps (jq, xclip, node/npx, nvidia-smi, xdotool, pavucontrol); CLAUDE.md lacks i3status-rust (tree, check `bash i3status-rust/scripts/test.sh`, colors via `[theme.overrides]` mirroring the scheme, freq palette exception) and still says "go test once tests exist". Main session edits CLAUDE.md with user. → `chore`
5. [ ] **Multi-GPU csv**: `gpu.sh:5` and `nvidia/nvidia.go:44` give ERR when nvidia-smi prints >1 line; use first line, add test row each. Low (one GPU here). → `widget-builder`
6. [ ] **Block explanations** (user asked for tooltips; i3bar has no hover): middle-click every trial-bar block → `yad` popup at mouse (`--mouse --undecorated --timeout 8`, closes on click; no notification daemon running, so no notify-send) with what it shows, units, color thresholds, click actions; one script `i3status-rust/scripts/explain.sh <block>`; check middle button unused, else pick another. → `widget-builder`
7. [ ] **Switch to i3status-rust** after ~1 week trial (ask when 2026-11-24; trial watch: sound block on alsa driver — mute/wheel and Bluetooth/headphone sink switch): remove barista bar, decide repo fate. → `widget-builder`

### Background checks

Long detached jobs started by agents: `check` command, done when, follow-up. Main session checks between agents, removes finished items.

_(none)_

## Recurring checks

After about every 3 feature tasks, run the check with the oldest last-run date (one agent each, dated note in `docs/progress/recurring.md`).

| Check | Agent | What | Last run |
|---|---|---|---|
| Agent roster | `agent-curator` | revise `.claude/agents/*`: tighten, split, merge, add specialists for upcoming work no agent fits, retire unused; evidence from recent reports and items that lacked a specialist | 2026-11-17 (set up) |
| Context diet | `context-auditor` | tools, MCP servers, connectors, plugins, skills, user agents loaded here but unused/unrelated; context cost; main session asks the user which to disable per project, applies, checks `/context` | 2026-11-17 (set up) |
| Git hygiene | `repo-janitor` | anything tracked that shouldn't be (build output, logs, dumps, caches, large binaries, local config, secrets); `.gitignore` gaps; safe `git rm --cached` | 2026-11-17 |
| Backlog tidy | `chore` | monthly: drop or merge stale, superseded or duplicate backlog items, check each still has an agent and a done condition; never touch the roadmap's queue | never |
| Dependency updates | `dep-updater` | `go list -m -u all`, barista.run upstream, Go toolchain; bump what is safe, backlog the rest | never |
| Look/usability pass | `bar-designer` | screenshot the bar; clarity, colors, stable widths, glyphs render; findings → backlog | never |
| Widget health | `widget-builder` | every widget shows real data on this machine (`timeout 5 go run .`, grep `ERR`); after system upgrades check nvidia-smi, hwmon, pulse, sysfs formats | never |
| Code review + docs | `code-reviewer` | review diffs since last run; README module list and CLAUDE.md match the code | 2026-11-17 |


## Decisions made

- 2026-11-17: barista click paths → `os.UserHomeDir()`; tray follows Win+i (generated `~/.i3/bars.conf`); both bars at bottom.
- 2026-11-17: hide on DP-2 (2.5K): ccusage, disk space, disk IO, IP address.
- 2026-11-17: upstream nvidia_gpu issue — agent drafts, user posts.
- 2026-11-17: delete unused `weather/`, `music/`; README covers both bars during trial.
- 2026-11-17 D3 picks: GPU md-expansion_card U+F08AE; keep freq histogram but with a better icon (cpu block's default icon or better); leave music/weather out; all numbers fixed width (no jumps 1↔2 digits). Packages installed.
- 2026-11-17: trial i3status-rust as second bar, then switch (A1 report). Barista-only items (health sweep, dep survey, design audit, dead import path) parked in backlog.

## Open decisions (ask the user)

Each line carries `asked <date>` or `ask when <trigger>`; `/wrapup` asks those whose trigger has passed.

- Post the upstream issue `docs/design/D3-i3status-rust/upstream-issue.md` (user action, from own GitHub account). asked 2026-11-17
