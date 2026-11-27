# Roadmap and session handoff

**Read this first when starting a new Claude Code session.** It lists what is in flight, the next 5-10 items and which decisions are still open; it stays small (≤ ~8 KB). Later items live in `docs/BACKLOG.md` (not read at session start), finished items in `docs/roadmap-archive/`. Whoever starts or finishes a work item edits this file right away (in the same commit when it is tracked).

Scope: whole project: maintenance of the custom_barista i3 status bar (fixing widgets after system upgrades, dependency updates, design/clarity improvements). Background docs: `CLAUDE.md` (conventions and policy), `docs/progress/*.md` (per-workstream status), `docs/working-agreements.md` (user preferences).

## How we work

- The main session coordinates. Work goes to project agents (`.claude/agents/`, never `general-purpose`). Agents run in parallel when they don't conflict (no shared files, one deploy/bar restart at a time); no fixed limit (user, 2026-11-27).
- Split work into small tasks a fresh agent can finish in a small context. One item per agent; it stops after it.
- Each agent finishes its item fully, records status in `docs/progress/<workstream>.md`, updates this file, commits its code and **never pushes** (the main session reviews and pushes in batches).
- No waiting agents: long jobs run detached (`nohup … > log/<name>.log 2>&1 &`), capped (`timeout 30m` or an item limit), resumable and safe to kill, and leave a check item under "Background checks" with the check command and the command for the next chunk.
- Every change keeps `bash scripts/test.sh` green and the bar running (both bars show i3status-rs, no error blocks).
- New items go to `docs/BACKLOG.md` unless they are next. `/wrapup` moves finished items verbatim to `docs/roadmap-archive/` (look there for the history of done work) and refills "Queued next" from the backlog.
- My action items live in `docs/USER_TODO.html` (U-1, U-2, …; links, pictures); refresh it whenever an item on the user appears or is done, at every session start and at `/wrapup`.
- Deploy = `./install.sh --yes` (config-only edits: `i3-msg restart`); agents may do it without asking after the checks pass.

Work items are checkboxes (`- [ ]` / `1. [ ]`, `[x]` when done) so the status line can count them ("roadmap done/total +N backlog, M done").

## In flight

No agent running. Done recently (2026-11-27, session 5): code review, R1 reboot-needed block + R1a popup fix, I2 install hardening, git hygiene, dep updates, look pass, widget health. Earlier sessions (11-17…11-22): i3status-rust switch, usage block, D5 regroup, hover tooltips T1, config.local install. Archive: `docs/roadmap-archive/2026-11.md`.

### Queued next (one agent each, in order)

1. [x] **R1b fix reboot block "Invalid JSON"**: reboot-needed.sh now prints `{"text":""}` when nothing needed (json=true rejected empty output); rb4 checks valid JSON; both bars smoke clean. Details: docs/progress/reboot-block.md
2. [x] **Recurring: Agent roster** (done 2026-11-27): widget-builder now flags new visible blocks/clicks/popups without spec for bar-designer review, and requires `jq -e .` on every json custom block output path. Details: docs/progress/recurring.md
3. [x] **Recurring: Context diet** (last 2026-11-22): ask user per findings. → `context-auditor`
4. [x] **Recurring: Backlog tidy** (last 2026-11-22; backlog empty 2026-11-27, quick). → `chore`
5. [x] **G1a research gitlab-runner queue source**: done; running jobs from user journal or `listen_address` metrics, pending only via API token; user picks A/B/C (see docs/progress/gitlab-runner-block.md).
6. [x] **G1b spec runner queue block**: done; docs/design/G1-runner-queue/spec.md (build option A unless the user picks B/C in questions.html).
7. [x] **G1c build runner queue block**: done, deployed (no-token path, idle option A); scripts/runner-queue.sh, rows rq1-rq20; user still creates token + project files (see progress note). → `widget-builder`
8. [x] **G1d review runner queue block**: accepted, no fixes; live checks with a job and a token remain (see progress note).
9. [x] **G1f fix runner block review findings** (code review 2026-11-27 (2) in docs/progress/recurring.md): lock/cache dir mkdir, umask 077, refresh timeout vs per-project max-time, hover max lines, empty projects file, shellcheck, tests for spawn/flock + cache mode + api500, README entry + deps. → `widget-builder` Done (see docs/progress/gitlab-runner-block.md).
10. [ ] **G1e live acceptance checks for runner block** (ask when user has done U-3 + U-4 in docs/USER_TODO.html): spec acceptance 2, 3, 5, 6 — green `1/4` during a real job, token absent from `ps` during refresh, ≤1 API refresh per 60 s, yellow `net` on network drop; apply U-2 idle choice if not A. → `chore`
11. [ ] **G2 runner block for anatolii, private sources only** (constraint from user via setup session, 2026-11-27): anatolii's runner data must never be visible to other local users: no `listen_address`/metrics TCP port for anatolii's runner (any localhost port is readable by anatoly), no world-readable files (cache dir 700/files 600 already). Allowed: anatolii's own `journalctl --user` (current fallback), API token in a 600 file in anatolii's home. Spec check first: does runner-queue.sh with no listen_address already comply; make install.sh/docs never enable metrics for other users; test as anatolii. → `bar-designer` (spec) then `widget-builder`

### Background checks

Long detached jobs started by agents: `check` command, done when, follow-up. Main session checks between agents, removes finished items.

_(none)_

## Recurring checks

After about every 3 feature tasks, run the check with the oldest last-run date (one agent each, dated note in `docs/progress/recurring.md`).

| Check | Agent | What | Last run |
|---|---|---|---|
| Agent roster | `agent-curator` | revise `.claude/agents/*`: tighten, split, merge, add specialists for upcoming work no agent fits, retire unused; evidence from recent reports and items that lacked a specialist | 2026-11-27 |
| Context diet | `context-auditor` | tools, MCP servers, connectors, plugins, skills, user agents loaded here but unused/unrelated; context cost; main session asks the user which to disable per project, applies, checks `/context` | 2026-11-27 |
| Git hygiene | `repo-janitor` | anything tracked that shouldn't be (build output, logs, dumps, caches, large binaries, local config, secrets); `.gitignore` gaps; safe `git rm --cached` | 2026-11-27 |
| Backlog tidy | `chore` | monthly: drop or merge stale, superseded or duplicate backlog items, check each still has an agent and a done condition; never touch the roadmap's queue | 2026-11-27 |
| Dependency updates | `dep-updater` | i3status-rs installed vs latest release, changelog breaking config changes grep'd in config.toml/scripts, script deps (jq, xclip, yad, nvidia-smi, xdotool, node) present and formats unchanged; fix keys, backlog the rest | 2026-11-27 |
| Look/usability pass | `bar-designer` | screenshot the bar; clarity, colors, stable widths, glyphs render; findings → backlog | 2026-11-27 |
| Widget health | `chore` | every block shows real data on this machine: `bash scripts/test.sh`, smoke `(sleep 6) \| timeout 6 i3status-rs $PWD/config.toml` (and compact.toml), grep `ERR`/`not found`/`error`; after system upgrades check nvidia-smi, hwmon, pulse, sysfs formats; failures → backlog for `widget-builder` | 2026-11-27 |
| Code review + docs | `code-reviewer` | review diffs since last run; README block list and CLAUDE.md match the code | 2026-11-27 |


## Decisions made

- 2026-11-27: G1 runner queue block data source C: running count from runner metrics (enable listen_address, restart runner) + pending jobs via GitLab API (read_api token in 0600 file, project id list).
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

- Post the upstream issue `docs/design/D3-i3status-rust/upstream-issue.md` (user action, from own GitHub account). asked 2026-11-17, still pending 2026-11-27
- G1 Q1 idle look of the runner block (A always grey `0/4  +0` rec., B hidden, C icon only): docs/design/G1-runner-queue/questions.html. asked 2026-11-27
