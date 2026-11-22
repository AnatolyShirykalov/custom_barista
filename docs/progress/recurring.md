# Recurring checks log

Dated notes from each recurring check (see the "Recurring checks" table in `docs/ROADMAP.md`).

## 2026-11-17 — Context diet (set up)

Disabled for this project in `.claude/settings.local.json` (personal): claude.ai Gmail, Google Calendar and Google Drive connectors (`deniedMcpServers`); skills docx, pptx, xlsx, pdf, google-workspace, morning, concerts, import-memory, deep-research (`skillOverrides: off`). Reason: unrelated to a Go i3 status bar. Re-enable by deleting the entries.
Kept: Claude Docs connector, web/image design skills, Chrome browser tools.
To confirm: run `/context` in the next session — whether project `skillOverrides` hides user/plugin skills and whether denied connectors drop out of the tool list.

## 2026-11-17 — Git hygiene

- Repo had no `.gitignore`; added one (binary `/custom_barista`, `/log/`, `*.log`, `*.bak*`, `*.test`, `.env*`, `*.swp`, `.claude/settings.local.json`, coverage/profiles).
- Nothing tracked needed removal: no binaries, logs, dumps, env files or keys (weather API key is passed as a parameter, not stored). Largest tracked: `i3status-rust/scripts/testdata/data_2m` (2 MB, used by test.sh clip15; kept, could be generated at test time instead), fonts (128/100 KB), PNGs all under 32 KB.
- No `git rm --cached` needed.

## 2026-11-17 — Code review + docs (3de417f..6b97023)

Checks: `go build/vet/test ./...` ok; `i3status-rust/scripts/test.sh` 22/22; shellcheck -S warning clean. Edge cases probed with scratch fixtures.

| Sev | Where | Problem | Fix |
|---|---|---|---|
| medium | clipboard/clipboard.go:64, ltime/ltime.go:21 | d6eceaa changed click paths to `/home/anatolii/scripts/…`; this user's scripts are in `/home/anatoly/scripts` -> clicks do nothing | `os.UserHomeDir()`; confirm intent with user |
| low | i3status-rust/scripts/clip.sh:13 | `%4.1fK` gives `200.0K`, `1023.4K` (6-7 chars, pad 5): width jumps | `%3.0fK` at >=100K, test row |
| low | i3status-rust/scripts/ccusage.sh:28 | 999950-999999 tokens -> `1000.0K` (7 chars) | choose unit after rounding |
| low | i3status-rust/scripts/test.sh:37 | ccwidth loop increments pass also on failure | else-branch |
| low | i3status-rust/scripts/test.sh:4,34 | temp dir made before trap; `$cj` unquoted in trap | trap right after mktemp |
| low | gpu.sh:5, nvidia/nvidia.go:44 | multi-GPU (several csv lines) -> ERR | first line only |
| low | nvidia/nvidia.go:56 | reason mapping untested | extract + table test |
| docs | README.md:78-104 | trial deps missing: jq, xclip, npx, nvidia-smi, xdotool, pavucontrol | add list |
| docs | CLAUDE.md:7 | "go test once tests exist" stale; no i3status-rust mention | add: tree, test.sh check, theme overrides mirror scheme, freq palette hex is the one exception (freq.sh:8, freq/freq.go:23) |
| info | docs/BACKLOG.md "Unused modules" | weather/music already deleted, item stale | mark done (Backlog tidy) |

No findings: barcycle.sh (derives state from real modes; concurrent presses compute the same target, benign), config.toml colors match `main.go` scheme, ccusage pinned and polled every 60 s, README module list matches `main.go` order, go.mod/go.sum tidy.

## 2026-11-17 — Look/usability pass (i3status-rust trial bars)

Screenshots (scratch, untracked): bar-rs on DP-0 (3840x34 at y=2126) and bar-rs-small on DP-2 (2560x34 at y=1566), 4 shots over 12 s; barista once for reference. Bar state restored to barista.

| Check | Result |
|---|---|
| Glyphs | all render (material-nf + PragmataPro), no tofu |
| Stable widths | status left edge fixed at x=816 (DP-0) / x=521 (DP-2) in all 4 shots |
| DP-2 fit | compact bar uses ~2040 of 2560 px, ~500 px free, no truncation |
| Colors | overrides match scheme; load 73/43 on 32 cores and temp 76° red correctly; ccusage green; freq palette is the agreed exception |
| Order | kbd, load, temp, freq, mem, disk, io, gpu, net, vol, ccusage, clip, time: CPU group then memory/storage then net/audio, sensible |

Findings → `docs/BACKLOG.md` Design (5): no tray on rs bars (barista tray with Telegram/Zoom disappears), only time icons dimmed, pad gap between icon and value (freq/ccusage/clip), disk io numbers unlabeled, mixed GiB/GB/MiB units.

## 2026-11-17 — Backlog tidy

Kept 12 (4 rs design items; 8 barista-only items regrouped under "barista (only if we keep it)"), merged 0, dropped 4.
Dropped: "gofmt" (`gofmt -l .` clean), "ccusage polling" (pinned, 60 s), "Implement bar design audit option(s)" and "Bar design audit" (superseded by the 2026-11-17 look pass, whose findings are the rs Design items). All kept items have an agent and a done condition (some older items state the fix only; wording kept).

## 2026-11-18 — Agent roster (after switch to i3status-rust)

Evidence: agent mentions in progress/roadmap/archive: widget-builder 27, bar-designer 7, chore 6, dep-updater 3 (never run), researcher 2, agent-curator 2, code-reviewer/repo-janitor/context-auditor 1 each, general-purpose 1. No `.claude/bin/agent-usage`. Go bar removed (205704b, 38468cb).

| Agent | Change | Why |
|---|---|---|
| widget-builder | rewritten for rs: native blocks first, custom scripts, gen-compact, test.sh rows, `i3status-rs $PWD/config.toml` smoke, `./install.sh --yes` deploy; name kept | most-used agent; keeping the name avoids a next-session load gap for item 9 and backlog refs |
| dep-updater | repurposed: i3status-rs version vs release, changelog breaking keys, script deps; `model: sonnet`; never installs packages | go.mod/barista.run gone; survey is mechanical |
| bar-designer | description/prompt: blocks, bottom-bar crops per monitor, `[theme.overrides]`, config.toml snippets | Go/pango/top-bar assumptions |
| code-reviewer | shell-script checks, test.sh, shellcheck, compact.toml sync | no Go to review |
| others | unchanged (no Go assumptions) | |

Recurring table: Dependency updates and Widget health rewritten for rs; Widget health moves to `chore` (mechanical run, failures → backlog for widget-builder); Code review says "README block list".

## Widget health 2026-11-18
test.sh pass=87 fail=0. Smoke config.toml and compact.toml (6 s): no ERR/not found/error. All blocks show plausible data: kbd US, load, temp 60-71C, cpu, mem 85GB, disk 595GB, io, gpu 33C/1.1GB (nvidia-smi 0%, 33.22C, 1013MiB matches), net, sound 100% (pactl 100%, pulseaudio driver ok), claude-usage 57% $69.1 cache 96%, clip, clock. hwmon0-9 present; no battery supply, block hidden. No failures, no backlog items.

## Dependency updates 2026-11-20
i3status-rs installed 0.40.1-2 = latest upstream release 0.40.1 (08 Nov; checked via GitHub releases page, gh unauthenticated). No upgrade, no breaking changes to grep. Script deps present: jq, xclip, yad, nvidia-smi (34.56C, 907MiB, format as parsed), xdotool, node, python3 with Xlib and gi (Gtk 3.0, Pango). test.sh pass=107 fail=0. No backlog items.

## 2026-11-20 — Code review + docs (6b97023..a623aab)

Checks: `scripts/test.sh` pass=163 fail=0; `compact.toml` in sync with `gen-compact.sh -`; shellcheck -S warning: claude-usage.sh:53, test.sh:105, hover-run.sh:8 (SC2174). Focus: T1 hover (tee, core, daemon, supervisor, install/barsconf, rows h1-h16), U1d, D5-R. Findings are backlog items (Bar blocks).

| Sev | Where | Problem |
|---|---|---|
| medium | install.sh:78, barsconf.sh:13, install.sh:84 | HOVER=0 lost at the next Win+i; daemon still started and reads stale status files |
| low | hover-tee.py:73 | bare `[` line tapped as invalid status.json (verified) |
| low | hover-run.sh:12-15 | --replace kills a stale pid's group without checking it |
| low | hover-run.sh:8, hover-tee.py:30, hover-daemon.py:16 | shared /tmp fallback dir |
| low | hover-run.sh | no test rows (backoff, give-up, --replace) |
| low | hover-daemon.py:46 | `conf["font"]` KeyError aborts rediscover |
| low | claude-usage.sh:53, test.sh:105 | shellcheck SC2034/SC1007 |
| docs | README.md:9,23; CLAUDE.md:5 | ccusage.sh/npx stale; hover, HOVER=0, python deps, explain.sh missing |

No findings: U1d per-part colours (read from `[theme.overrides]`, padding before markup, width constant), D5-R gen-compact merge rule (drop chains handled), hover state machine and layout (rows h5-h14 against live captures), hover-tee short-write loop and pdeathsig. Last reviewed commit: a623aab.

## Git hygiene 2026-11-20
- 193 tracked files; no logs, caches, .pyc, secrets, .env, or large binaries tracked (largest 44 KB PNG). `__pycache__`, `log/`, `settings.local.json` correctly ignored.
- `.gitignore`: added `*.pyc`, `node_modules/`, `coverage/`, `*.core`. Nothing needed `git rm --cached`.
- Doubtful (listed in BACKLOG): duplicate `f5-p4-dp0/dp2.png` in D5-bar-review. Design images kept.

## Look/usability pass 2026-11-20
Screenshots of both bars + 8 hover popups (DP-0 load, net, usage, clock; DP-2 freq, gpu, sound, clock); crops in `docs/design/look-2026-11-20/`. Pointer parked at 3000,800 afterwards.
- Widths: 32 samples over 32 s per bar, every block's plain-text length constant (DP-0 13 pieces, DP-2 10). No jitter.
- Colours: status line uses only `#777777` (dim-icon), the theme good/degraded/bad and the freq palette (agreed exception). Usage parts green/dim as specified.
- Glyphs: all Material icons render on both bars, no tofu; tray icons fine.
- Popups: readable, dark box with grey border, placed above the block; at the right edges (DP-0 clock next to tray, DP-2 clock at the monitor edge) they are clamped inside the screen.
- Fixed: usage popup line 5 was ~105 chars (popup ~1180 px wide); reflowed to 6 lines of at most 75 chars (`scripts/explain.sh`), freq text "colors" → "colours" for one spelling. test.sh pass=171 fail=0; deployed with `./install.sh --yes`, re-shot.
- Backlog: one unreproduced miss of the first DP-0 load popup ("Hover: first popup missed once", widget-builder).

## Widget health 2026-11-22
- `bash scripts/test.sh`: pass=176 fail=0.
- Smoke 6 s each: config.toml (57 lines), compact.toml (48), hover-tee DP-0 (57) and DP-2 (48) as in bars.conf: 0 matches for ERR / not found / error.
- Real data in every block: load, temp 47-50 C, usage parts, mem 95GB, disk 686GB, disk I/O, nvidia-smi 38 C 0.5GB, net with IP, claude usage, kbd US, pulse 70%, date/time. compact has the same minus disk, I/O, IP, claude usage (as designed).
- Live: two hover-tee wrappers + two i3status-rs (DP-0, DP-2) and hover-daemon running.
- Note: the last JSON line of each smoke is cut by timeout (jq parse error on it only); not a bar bug.
- No failures, nothing added to BACKLOG.
