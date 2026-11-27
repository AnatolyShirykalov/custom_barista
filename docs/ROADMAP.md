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

R1a reboot click+popup → widget-builder (running). Done 2026-11-27: code review, R1 reboot-needed block, I2 install hardening, git hygiene, dep updates, look pass. Done recently (2026-11-22, session 4): install.sh writes i3 lines to ~/.config/i3/config.local (setup repo owns ~/.i3/config; verified both users), hover first-popup fix (X queue drain), recurring widget health, backlog tidy, agent roster, context diet (chrome + gopls off). (2026-11-20, session 3): D5-R review accepted; hover tooltips T1 (spike, spec, wrapper, core, daemon, review), middle-click popups removed (T1d), hover hardening from code review (T1e), README/CLAUDE.md docs (T1f); usage `cc …` first-run placeholder (U1c); recurring dep updates, code review, git hygiene, look pass. Earlier: 2026-11-18 i3status-rust switch, usage block U1/U1d, D5 regroup. Archive: `docs/roadmap-archive/2026-11.md`.

### Queued next (one agent each, in order)

1. [x] **Recurring: Code review + docs** (done 2026-11-27, 6 findings → I2; note in recurring.md): review 60bc4a6 (install.sh/i3block.sh config.local), 58750f0 (hover-daemon drain), 7211676 (agent files); README/CLAUDE.md match. Reviewer has no write tools: main session writes the note. → `code-reviewer`
2. [x] **R1 reboot-needed block** (request 2026-11-27 via setup session): custom block, hidden when nothing applies. Rules (no root, cheap, interval ~60 s): (1) `/usr/lib/modules/$(uname -r)` missing → bad/red "⟳ reboot: kernel 7.3.5→7.3.6" (new ver from `pacman -Q linux`); (2) boot-time pkgs upgraded in /var/log/pacman.log after boot (btime from /proc/stat): nvidia*, linux-firmware*, amd-ucode/intel-ucode, systemd, glibc, dbus*, mkinitcpio, cryptsetup → degraded "reboot"; (3) optional, session pkgs after session start (xorg-server, i3-wm, mesa, pipewire, wireplumber, picom) → dim "relogin". Package lists in one editable place; click/hover lists triggering pkgs. Done: shows kernel case live now (running 7.3.5, modules dir gone; build before reboot), test.sh fakes uname/modules dir/pacman.log for rules 1-2. BUILT 2026-11-27 (rules 1-3, hover+click list, rb1-rb6; progress: widgets.md).
3. [x] **I2 install hardening** (code review 2026-11-27, see recurring.md): install.sh warn/stop on existing `bindsym $mod+i`/`Mod4+i` in ~/.i3/config (tell user to remove in setup repo); i3block.sh exit 1 on BEGIN without END; install.sh:107 capture i3block.sh output with `|| exit`; i3block.sh mkdir via `readlink -m`; test rows i5 (rollback on dup binding) i6 (missing END); hover rediscover() drain test. → `widget-builder` Done 2026-11-27: all 6 fixes + tests i5/i6, h18 (note in install.md).
4. [x] **Recurring: Git hygiene** (last 2026-11-27): check `config.local.bak-*`/install backups never land in the repo; .gitignore gaps. → `repo-janitor`
5. [x] **Recurring: Dependency updates** (last 2026-11-27, clean): i3status-rs release, python-xlib (hover drain relies on pending_events/next_event behaviour). → `dep-updater`
6. [x] **Recurring: Look/usability pass** (done 2026-11-27: bars OK; reboot click dead + popup truncated → backlog R1a): both bars + hover popups for both users (anatolii uses usage API fallback, no statusline tap). → `bar-designer`
7. [ ] **R1a reboot block click + popup** (look pass 2026-11-27): (a) left click runs `notify-send`, but no notification daemon is running or activatable here ("ServiceUnknown: not activatable") so the click does nothing; replace with a yad popup of `reboot-needed.sh list` (reuse the hover popup look) or drop the click and the "Left click: notify" line in explain.sh. (b) Hover popup shows `list | head -3` = kernel line + "Need reboot:" + 1 of 14 linux-firmware split pkgs, hiding nvidia-open and pipewire (relogin); in `list`, collapse packages sharing name prefix and version into one line (`linux-firmware +13  20261019-1 → 20261124-1`), use `→` like the bar text, put the list before the legend, cap 8 lines with `… N more`. Done: click visibly shows the list (or no click), popup today shows kernel, linux-firmware (+13), nvidia-open, pipewire; test.sh rows for collapse/cap; compact.toml regenerated. → widget-builder Click: remove the notify-send click (hover is the list, per T1 decision "hover only"); no daemon dependency.

### Background checks

Long detached jobs started by agents: `check` command, done when, follow-up. Main session checks between agents, removes finished items.

_(none)_

## Recurring checks

After about every 3 feature tasks, run the check with the oldest last-run date (one agent each, dated note in `docs/progress/recurring.md`).

| Check | Agent | What | Last run |
|---|---|---|---|
| Agent roster | `agent-curator` | revise `.claude/agents/*`: tighten, split, merge, add specialists for upcoming work no agent fits, retire unused; evidence from recent reports and items that lacked a specialist | 2026-11-22 |
| Context diet | `context-auditor` | tools, MCP servers, connectors, plugins, skills, user agents loaded here but unused/unrelated; context cost; main session asks the user which to disable per project, applies, checks `/context` | 2026-11-22 |
| Git hygiene | `repo-janitor` | anything tracked that shouldn't be (build output, logs, dumps, caches, large binaries, local config, secrets); `.gitignore` gaps; safe `git rm --cached` | 2026-11-27 |
| Backlog tidy | `chore` | monthly: drop or merge stale, superseded or duplicate backlog items, check each still has an agent and a done condition; never touch the roadmap's queue | 2026-11-22 |
| Dependency updates | `dep-updater` | i3status-rs installed vs latest release, changelog breaking config changes grep'd in config.toml/scripts, script deps (jq, xclip, yad, nvidia-smi, xdotool, node) present and formats unchanged; fix keys, backlog the rest | 2026-11-27 |
| Look/usability pass | `bar-designer` | screenshot the bar; clarity, colors, stable widths, glyphs render; findings → backlog | 2026-11-27 |
| Widget health | `chore` | every block shows real data on this machine: `bash scripts/test.sh`, smoke `(sleep 6) \| timeout 6 i3status-rs $PWD/config.toml` (and compact.toml), grep `ERR`/`not found`/`error`; after system upgrades check nvidia-smi, hwmon, pulse, sysfs formats; failures → backlog for `widget-builder` | 2026-11-22 |
| Code review + docs | `code-reviewer` | review diffs since last run; README block list and CLAUDE.md match the code | 2026-11-27 |


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

- Post the upstream issue `docs/design/D3-i3status-rust/upstream-issue.md` (user action, from own GitHub account). asked 2026-11-17, still pending 2026-11-22
