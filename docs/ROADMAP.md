# Roadmap and session handoff

**Read this first when starting a new Claude Code session.** It lists what is in flight, the next 5-10 items and which decisions are still open; it stays small (≤ ~8 KB). Later items live in `docs/BACKLOG.md` (not read at session start), finished items in `docs/roadmap-archive/`. Whoever starts or finishes a work item edits this file right away (in the same commit when it is tracked).

Scope: whole project: maintenance of the custom_barista i3 status bar (fixing widgets after system upgrades, dependency updates, design/clarity improvements). Background docs: `CLAUDE.md` (conventions and policy), `docs/progress/*.md` (per-workstream status), `docs/working-agreements.md` (user preferences).

## How we work

- The main session coordinates. Work goes to project agents (`.claude/agents/`, never `general-purpose`). One agent at a time (two at most): many in parallel hit the usage limit.
- Split work into small tasks a fresh agent can finish in a small context. One item per agent; it stops after it.
- Each agent finishes its item fully, records status in `docs/progress/<workstream>.md`, updates this file, commits its code and **never pushes** (the main session reviews and pushes in batches).
- No waiting agents: long jobs run detached (`nohup … > log/<name>.log 2>&1 &`), capped (`timeout 30m` or an item limit), resumable and safe to kill, and leave a check item under "Background checks" with the check command and the command for the next chunk.
- Every change keeps `bash scripts/test.sh` green and the bar running (both bars show i3status-rs, no error blocks).
- New items go to `docs/BACKLOG.md` unless they are next. `/wrapup` moves finished items verbatim to `docs/roadmap-archive/` (look there for the history of done work) and refills "Queued next" from the backlog.
- Deploy = `./install.sh --yes` (config-only edits: `i3-msg restart`); agents may do it without asking after the checks pass.

Work items are checkboxes (`- [ ]` / `1. [ ]`, `[x]` when done) so the status line can count them ("roadmap done/total +N backlog, M done").

## In flight

No agent running. Done recently (2026-11-18, session 2): sound block on pulseaudio (frees ALSA card 3 for smart_speaker), DP-2 freq→mem gap, middle-click explain popups, Claude usage block U1 (statusline tap + OAuth fallback, real 5h %, 7d mark), D5 design review v2, clipboard block removed, D5-R regrouping built (review pending), hover tooltips researched; widget health check ok; usage block per-part colours (U1d). Earlier 2026-11-18: switched to i3status-rust. Archive: `docs/roadmap-archive/2026-11.md`.

### Queued next (one agent each, in order)

1. [x] **D5-R regrouping review**: accepted, no deviations; tests 107 pass, all middle-click explains checked on both bars. Detail `docs/progress/design.md`.
2. [x] **T1 hover tooltips spike**: go. Computed edges = click-reported edges (0 px, both bars); python-xlib gets Enter/Leave/Motion on i3bar windows, no polling. `docs/design/T1-hover/spike.md`, scripts `scripts/spike/`.
3. [x] **T1 spec**: `docs/design/T1-hover/spec.md` (tee wrapper + separate hover daemon, 500 ms, GTK popup above the block, explain.sh text); questions page `questions.html` (Q1 middle-click, Q2 delay; defaults let the build start).
4. [x] **T1a hover wrapper**: `hover-tee.py` pass-through + tap files, barsconf wiring, `HOVER=0` fallback, rows h1-h4, h15; deployed, both bars run through it. Needs bar-designer review (in T1 review).
5. [x] **T1b hover core**: `scripts/hover/{layout,state,test_hover}.py`, live fixtures `testdata/hover/dp{0,2}.json`; rows h5-h14 green (23 pieces, 0 px vs clicks). Progress: design.md.
6. [x] **T1c hover daemon**: `hover-daemon.py`, `hover-run.sh`, install.sh `exec_always`, h16; deployed, acceptance 1-9 pass, crops `img/review-hover-*`. Progress: design.md. Needs bar-designer review (T1 review).
7. [x] **T1 review**: accepted; short-write fix in hover-tee.py, `scripts/spike/` deleted. Q1/Q2 still open. Progress: design.md.
8. [x] **T1d remove middle-click popups** (user Q1 B, 2026-11-20): per spec §3.3 move the explain-key mapping to `scripts/hover/keys.toml` (block type + distinguishing field, not block index), daemon reads it, drop button-2 explain.sh clicks from config.toml (compact.toml regenerated), h10 checks keys.toml; drop the backlog item about the tiled yad popup if explain.sh popups are gone; deploy. → `widget-builder` Done: see progress/design.md "T1d".
9. [x] **T1e hover hardening**: HOVER persisted + HOVER=0 stops daemon/clears taps, bare `[` not tapped, --replace pid check, private /tmp fallback, font default, shellcheck clean, rows h2b r1-r5; detail docs/progress/design.md. → `widget-builder`
10. [x] **T1f docs**: README.md block/script list (claude-usage.sh, explain.sh, hover files, install.sh, i3/), deps (python-xlib, python-gobject; drop node/npx), hover tooltips + HOVER=0 in README and CLAUDE.md:5 (after T1d). → `chore`
11. [x] **U1c first-run placeholder** (from backlog): fresh user (no statusline tap, empty ~/.cache/claude-usage) → usage block hidden for minutes; show dim `cc …` placeholder until first data. Done: fixture row for empty cache → placeholder, width fixed. → `widget-builder` Done 2026-11-20: see docs/progress/widgets.md.
12. [x] **Recurring: Git hygiene** (last 2026-11-20; due after T1d-f). → `repo-janitor`
13. [x] **Recurring: Look/usability pass** (last 2026-11-20; usage popup reflowed, 1 backlog item): screenshot both bars + hover popups; clarity, colours, stable widths, glyphs; findings → backlog. → `bar-designer`
14. [ ] **Hover: first popup missed once** (look pass 2026-11-20, from backlog): first hover on DP-0 load showed no popup, no log line; retries fine. Done: 20 scripted hovers on both bars all show a popup, or cause found + `test_hover.py` row. → `widget-builder`
8. [x] **Recurring: Dependency updates** (last run 2026-11-20; due after U1b, P4, D5-R). → `dep-updater`

### Background checks

Long detached jobs started by agents: `check` command, done when, follow-up. Main session checks between agents, removes finished items.

_(none)_

## Recurring checks

After about every 3 feature tasks, run the check with the oldest last-run date (one agent each, dated note in `docs/progress/recurring.md`).

| Check | Agent | What | Last run |
|---|---|---|---|
| Agent roster | `agent-curator` | revise `.claude/agents/*`: tighten, split, merge, add specialists for upcoming work no agent fits, retire unused; evidence from recent reports and items that lacked a specialist | 2026-11-18 |
| Context diet | `context-auditor` | tools, MCP servers, connectors, plugins, skills, user agents loaded here but unused/unrelated; context cost; main session asks the user which to disable per project, applies, checks `/context` | 2026-11-17 (set up) |
| Git hygiene | `repo-janitor` | anything tracked that shouldn't be (build output, logs, dumps, caches, large binaries, local config, secrets); `.gitignore` gaps; safe `git rm --cached` | 2026-11-20 |
| Backlog tidy | `chore` | monthly: drop or merge stale, superseded or duplicate backlog items, check each still has an agent and a done condition; never touch the roadmap's queue | 2026-11-17 |
| Dependency updates | `dep-updater` | i3status-rs installed vs latest release, changelog breaking config changes grep'd in config.toml/scripts, script deps (jq, xclip, yad, nvidia-smi, xdotool, node) present and formats unchanged; fix keys, backlog the rest | 2026-11-20 |
| Look/usability pass | `bar-designer` | screenshot the bar; clarity, colors, stable widths, glyphs render; findings → backlog | 2026-11-20 |
| Widget health | `chore` | every block shows real data on this machine: `bash scripts/test.sh`, smoke `(sleep 6) \| timeout 6 i3status-rs $PWD/config.toml` (and compact.toml), grep `ERR`/`not found`/`error`; after system upgrades check nvidia-smi, hwmon, pulse, sysfs formats; failures → backlog for `widget-builder` | 2026-11-18 |
| Code review + docs | `code-reviewer` | review diffs since last run; README block list and CLAUDE.md match the code | 2026-11-20 |


## Decisions made

- 2026-11-20: T1 picks: Q1 B remove middle-click popups (hover only), Q2 A 500 ms delay then instant while sliding.
- 2026-11-18: D5 picks: regrouping only (from option B), no P2/P3/P5 ("enough space"), clipboard block removed entirely; 7d usage mark always visible.
- 2026-11-18: Claude usage block: statusline rate_limits cache + OAuth usage endpoint fallback; show window tokens, colour from real 5h %, reset time, window cost, cache ratio; ccusage dropped.
- 2026-11-18: tooltips must appear on hover (middle-click popup is only a stopgap); sound block uses pulseaudio driver.
- 2026-11-18: switch to i3status-rust now; flatten rs setup to repo root; Win+i toggles off <-> rs; repo keeps name custom_barista.
- 2026-11-17: barista clipboard widget removed for both users.
- 2026-11-17: barista click paths → `os.UserHomeDir()`; tray follows Win+i (generated `~/.i3/bars.conf`); both bars at bottom.
- 2026-11-17: hide on DP-2 (2.5K): ccusage, disk space, disk IO, IP address.
- 2026-11-17: upstream nvidia_gpu issue — agent drafts, user posts.
- 2026-11-17: delete unused `weather/`, `music/`; README covers both bars during trial.
- 2026-11-17 D3 picks: GPU md-expansion_card U+F08AE; keep freq histogram but with a better icon (cpu block's default icon or better); leave music/weather out; all numbers fixed width (no jumps 1↔2 digits). Packages installed.
- 2026-11-17: trial i3status-rust as second bar, then switch (A1 report). Barista-only items (health sweep, dep survey, design audit, dead import path) parked in backlog.

## Open decisions (ask the user)

Each line carries `asked <date>` or `ask when <trigger>`; `/wrapup` asks those whose trigger has passed.

- Post the upstream issue `docs/design/D3-i3status-rust/upstream-issue.md` (user action, from own GitHub account). asked 2026-11-17
