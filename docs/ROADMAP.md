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

No agent running. Done recently (2026-11-27, session 6): G2a runner metrics dropped for both users (journal only) + G2b fixture/hover fix, R1b reboot "Invalid JSON" fix, G1 GitLab runner queue block (research, spec, build, review, review fixes G1f; live checks G1e wait for the user), USER_TODO page, parallel agents rule, agent roster, context diet, backlog tidy, code review. Session 5 and earlier: see archive `docs/roadmap-archive/2026-11.md`.

### Queued next (one agent each, in order)

1. [x] **G1g auto project list from runner log** (user agreed 2026-11-27): runner-queue.sh takes projects to watch from own `journalctl --user` `repo_url=` lines (unique paths, newest first, max 10, ANSI stripped); `~/.config/custom_barista/runner-projects` becomes an optional extra; hover "no project list" only when both are empty; tests with real-format fixtures; spec note; then drop U-4 from docs/USER_TODO.html (Done, superseded). → `widget-builder` Done 2026-11-27: see docs/progress/gitlab-runner-block.md.
2. [ ] **G2 runner block for anatolii, private sources only** (constraint from user via setup session, 2026-11-27): anatolii's runner data must never be visible to other local users: no metrics at all (G2a), no `listen_address` TCP port (any localhost port is readable by anatoly), no world-readable files (cache dir 700/files 600 already). Allowed: anatolii's own `journalctl --user` (current fallback), API token in a 600 file in anatolii's home. Spec check first: does runner-queue.sh with no listen_address already comply; make install.sh/docs never enable metrics for other users; test as anatolii. → `bar-designer` (spec) then `widget-builder`. Progress 2026-11-27: user ran as anatolii (token 600 created, metrics never enabled): block shows ` 0/16  +0` with `XDG_RUNTIME_DIR` set; under plain `sudo -iu` it shows `off` (no user bus) — real session fine. Remaining: confirm no world-readable files/ports for anatolii, install.sh never enables metrics, hover in anatolii's X session.
3. [ ] **G1e live acceptance checks for runner block** (after G1g; U-2 = A, already built): spec acceptance 2, 3, 5, 6 — green `1/4` during a real job, token absent from `ps` during refresh, ≤1 API refresh per 60 s, yellow `net` on network drop; apply U-2 idle choice if not A. → `chore`

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

- 2026-11-27: G1 Q1 idle look = A (always shown, grey `0/4  +0`, fixed width); already built.
- 2026-11-27: runner block project list comes from the runner log (repo_url), the projects file is only an optional extra; U-4 dropped.
- 2026-11-27: drop runner metrics for both users (replaces the metrics part of G1 option C): running count from `journalctl --user`, concurrent from config.toml, pending via API token; no TCP port.
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

- Post the upstream issue `docs/design/D3-i3status-rust/upstream-issue.md` (user action, from own GitHub account). asked 2026-11-17, still pending 2026-11-27 (USER_TODO U-1)
