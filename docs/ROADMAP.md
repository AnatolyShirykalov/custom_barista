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

No agent running. Done recently (2026-11-18): switched to i3status-rust (Go barista bar removed, rs setup flattened to repo root, Win+i toggles off <-> rs), agent roster rewritten for rs; 2026-11-17: D4 polish, tray fix, install.sh, per-monitor bars, clipboard removal. Archive: `docs/roadmap-archive/2026-11.md`.

### Queued next (one agent each, in order)

1. [x] **DP-2 gap freq→mem**: freq pad now = (cpu count/10) minus present two-digit counts (was fixed 6), mem eng w:3→w:2. Gap 6+ spaces → ~2-3. See progress/widgets.md.
2. [x] **Block explanations** (user asked for tooltips; i3bar has no hover): middle-click every trial-bar block → `yad` popup at mouse (`--mouse --undecorated --timeout 8`, closes on click; no notification daemon running, so no notify-send) with what it shows, units, color thresholds, click actions; one script `scripts/explain.sh <block>`; check middle button unused, else pick another. → `widget-builder` DONE 2026-11-18: middle button was free everywhere; see progress/widgets.md.
3. [ ] **D5 bar design review**: questions page ready `docs/design/D5-bar-review/questions.html` (options A polish / B regroup, rec. / C quiet; picks P1-P5); freq gap now 1 cell, keep. Awaits user pick → widget-builder. Detail: `docs/progress/design.md`. → `bar-designer`
4. [ ] **U1 Claude usage block** (user picks 2026-11-18): replace npx ccusage. Source: statusline `rate_limits` cache (official) + fallback `GET api.anthropic.com/api/oauth/usage` (undocumented; poll ≥3 min, back off 429/401, never refresh the OAuth token, 'stale' on 401). Show: total tokens of the current real 5h window (window start = five_hour.resets_at − 5h, summed from local logs), color from real 5h % (good/degraded/bad), time to reset, cost and cache-hit ratio of that window. Research: researcher report 2026-11-18 (statusline v2.1.80+ `rate_limits.*.used_percentage/resets_at`; existing `~/.claude/bin/claude-statusline`). Flow: `bar-designer` spec → `widget-builder` → `bar-designer` review.

### Background checks

Long detached jobs started by agents: `check` command, done when, follow-up. Main session checks between agents, removes finished items.

_(none)_

## Recurring checks

After about every 3 feature tasks, run the check with the oldest last-run date (one agent each, dated note in `docs/progress/recurring.md`).

| Check | Agent | What | Last run |
|---|---|---|---|
| Agent roster | `agent-curator` | revise `.claude/agents/*`: tighten, split, merge, add specialists for upcoming work no agent fits, retire unused; evidence from recent reports and items that lacked a specialist | 2026-11-18 |
| Context diet | `context-auditor` | tools, MCP servers, connectors, plugins, skills, user agents loaded here but unused/unrelated; context cost; main session asks the user which to disable per project, applies, checks `/context` | 2026-11-17 (set up) |
| Git hygiene | `repo-janitor` | anything tracked that shouldn't be (build output, logs, dumps, caches, large binaries, local config, secrets); `.gitignore` gaps; safe `git rm --cached` | 2026-11-17 |
| Backlog tidy | `chore` | monthly: drop or merge stale, superseded or duplicate backlog items, check each still has an agent and a done condition; never touch the roadmap's queue | 2026-11-17 |
| Dependency updates | `dep-updater` | i3status-rs installed vs latest release, changelog breaking config changes grep'd in config.toml/scripts, script deps (jq, xclip, yad, nvidia-smi, xdotool, node) present and formats unchanged; fix keys, backlog the rest | never |
| Look/usability pass | `bar-designer` | screenshot the bar; clarity, colors, stable widths, glyphs render; findings → backlog | 2026-11-17 |
| Widget health | `chore` | every block shows real data on this machine: `bash scripts/test.sh`, smoke `(sleep 6) \| timeout 6 i3status-rs $PWD/config.toml` (and compact.toml), grep `ERR`/`not found`/`error`; after system upgrades check nvidia-smi, hwmon, pulse, sysfs formats; failures → backlog for `widget-builder` | never |
| Code review + docs | `code-reviewer` | review diffs since last run; README block list and CLAUDE.md match the code | 2026-11-17 |


## Decisions made

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

- D5 bar review: pick direction A/B/C and P1-P5 on `docs/design/D5-bar-review/questions.html`. asked 2026-11-18
- Post the upstream issue `docs/design/D3-i3status-rust/upstream-issue.md` (user action, from own GitHub account). asked 2026-11-17
