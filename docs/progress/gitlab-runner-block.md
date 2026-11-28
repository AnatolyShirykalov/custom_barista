# gitlab-runner queue block (G1)

## G1a research (2026-11-27)

**How the runner runs here** (read-only checks, no secrets read): user unit `~/.config/systemd/user/gitlab-runner.service` (active; drop-in `graceful-stop.conf` from the setup repo, KillSignal=SIGQUIT), `/usr/bin/gitlab-runner run --config ~/.gitlab-runner/config.toml`, v19.6.1. The other user (`anatolii`) runs its own process with `/home/anatolii/.gitlab-runner/config.toml`; the system `gitlab-runner.service` is disabled. Config: `concurrent = 4`, `check_interval = 0`, one `[[runners]]` (`name = "local-arch-pc"`, gitlab.com, `executor = "docker"`), **no `listen_address`** (metrics off), no `request_concurrency` (journal warns it defaults to 1).

**(1) Jobs running now: local sources**
| Source | How | Cost/poll | Notes |
|---|---|---|---|
| Metrics | add `listen_address = "127.0.0.1:<port>"` to config.toml + restart; `curl -s :<port>/metrics` → running-jobs gauge (`gitlab_runner_jobs`, not in the docs HELP list: confirm with `grep "# HELP"` once enabled), `gitlab_runner_concurrent` | one localhost GET (not measured, endpoint off) | best; no auth on endpoint, so each user needs their own port, and the block reads the port from its **own** config only |
| Journal | `journalctl --user -u gitlab-runner -n 50 -o cat`; last `Added/Removed job ... processing list builds=N` gives running count; `job_url`, `job_name` for hover | ~2 ms measured | works today with no config change; strip ANSI; only own `--user` journal is readable, so the other user cannot leak |
| Docker | `docker ps --filter label=com.gitlab.gitlab-runner.managed=true` (+ `...runner.id=<short token>`) | not measured (no job running) | daemon is shared: both users' containers show up; needs a filter on the short token, which is a token prefix, so avoid it |
| CLI | `gitlab-runner list` / `verify` | n/a | lists runners only, no job info |

**(2) Pending/queued jobs**: not local. Runner only learns of a job when it picks one up (`POST /api/v4/jobs/request`, runner auth token, usable for nothing else). `GET /runners/:id/jobs?status=running` lists running jobs, but per docs "statuses that a runner's jobs cannot have, such as pending, match no jobs", so the runner endpoint shows no queue. Pending jobs come from `GET /projects/:id/jobs?scope[]=pending` per project (PAT/project token with `read_api`, Reporter+), one call per project per poll, plus a filter on tags the runner can take. Runner id is in config.toml (`id =`).

**(3) Recommendation**: running count from journal (no change needed) or metrics (cleaner, needs the config line); poll every 5 s (`interval = 5`), or 10 s. Pending: only if the user gives a token, at 30-60 s, cached in `~/.cache`, separate from the running poll. Failure modes: unit inactive (`systemctl --user is-active gitlab-runner` → dim/"off"), metrics port closed (fall back to journal), network/DNS down (journal shows `Checking for jobs... failed`, seen 2026-11-27 → degraded), token missing/expired (hide pending part), other user: use only `$HOME/.gitlab-runner` and `--user` sources, never `/home/*` or a fixed port.

**Decisions for the user**
- A: running jobs only, from journal (no config change). B: A + `listen_address` metrics (edit config.toml, restart runner). C: B + pending via API token (`read_api` PAT in a 0600 file, list of project ids).

Sources: https://docs.gitlab.com/runner/monitoring/ , https://docs.gitlab.com/api/runners/ (List runner's jobs), https://docs.gitlab.com/api/jobs/ (scope pending), https://docs.gitlab.com/runner/executors/docker/ (managed label), https://gitlab.com/gitlab-org/gitlab-runner/-/merge_requests/2412 (job.id/runner.id labels).

## G1b spec (2026-11-27)

Spec `docs/design/G1-runner-queue/spec.md`, mocks `img/`, decision page `questions.html` (Q1 idle look; A recommended). New script `scripts/runner-queue.sh`, icon md-gitlab `\U000F0BA0` (renders in Symbols Nerd Font Mono), own group before the usage block. Text `r/c  +p` fixed width 7 for c=4; states off/ERR/net/stuck >15 min. Own port: `listen_address` from own config + `ss -p` pid match with the user unit MainPID. Pending: detached `refresh` under `flock`, TTL 60 s (600 s after 401), ≤10 projects, token via process substitution. Test rows rq1-rq20.

## G1c build (2026-11-27)

Built from the spec: `scripts/runner-queue.sh`, fixtures `scripts/testdata/runner/`, test.sh rows rq1-rq20 (+rq19b-e), block in config.toml before the usage block, icon `gitlab`, hover key `runner` + `explain.sh runner`, compact.toml regenerated. Deployed with idle option A (always shown, dim; the idle rule is the comment line before the final `emit` in `bar()`; B/C are one-line swaps).
- Runner setup done (no job running, builds=0, no containers): backup `~/.gitlab-runner/config.toml.bak-g1c`, added top-level `listen_address = "127.0.0.1:9252"` (only change), `systemctl --user restart gitlab-runner`. Metric names confirmed: `gitlab_runner_jobs`, `gitlab_runner_concurrent`; socket on 127.0.0.1 owned by the user unit pid. Other user untouched.
- Journal pitfall: every runner log line ends with `builds=N max_builds=M`, so the journal fallback matches `builds=` only at word start.
- Deviations: rq19 expects `+7 more` (headers count towards LIST_MAX=8: 2 headers + 5 rows + the more line); `METRICS_FILE` set but empty/missing means "no metrics" (journal fallback) in tests.
- Not done / user: token file `~/.config/custom_barista/gitlab-token` (0600) and `~/.config/custom_barista/runner-projects` do not exist; the block shows `r/c` without the pending slot until both exist. The pending path (refresh, `+?`, list) is tested with fixtures only, never against gitlab.com.
- Smoke: config.toml and compact.toml show dim fox icon `0/4`, no error blocks. `net` warning seen once right after the runner restart (journal `Checking for jobs... failed`), gone after.

## G1d review (2026-11-27, bar-designer): accepted, no fixes

| Check | Result |
|---|---|
| Icon / position | md-gitlab fox renders (no tofu), dim, own group before the usage block (DP-0) and before keyboard (DP-2); crops `docs/design/G1-runner-queue/img/review-dp{0,2}.png` |
| Idle colour | state `Info` = `info_fg #777777` (dim-icon), i.e. the spec's grey; live text `0/4` (no-token mode, slot dropped as specified) |
| Width | rq18 green (7 chars for every slotted state, 3 in no-token mode) |
| Pending path (fixture cache, no token created) | `0/4  +1` Warning; list shows running + pending rows, columns cut with `…`, ages `4m`/`12m` |
| Hover | `explain.sh runner`: 3 legend lines + `Running 0/4 (metrics)` + `Pending: no token (…)` |
| Clicks | left `refresh-now` without a token: exit 0, no cache, no error; right `open` covered by rq19e |
| Security | token sent via `-H @-` on stdin (not argv); metrics socket `127.0.0.1:9252` owned by the user unit pid; no `/home/` reads |
| Tests | `bash scripts/test.sh`: pass=217 fail=0, bar run 24 ms |

Deviations accepted: rq19 `+7 more` is the correct hidden count (spec's `+5` was an arithmetic slip, spec row fixed); empty/missing `METRICS_FILE` = no metrics is a test-hook detail, production (unset) uses the real port path.
Still open (need the user's token + project list): acceptance 2 (green `1/4` during a job), 3 (`ps` check during a live refresh), 5 (refresh ≤1/60 s log), 6 (net-down yellow). The script checks the token file mode only, not the dir mode; `~/.config/custom_barista` is 0755 today (file 0600 is enough).

## G1f review fixes (2026-11-27)
runner-queue.sh: `spawn()` creates the cache dir (700) before `flock`; refresh has `umask 077`; `--max-time 4` per call, `timeout 60` for the refresh (flock keeps one refresh running); hover list capped at LIST_MAX exactly (headers counted); empty project ids skipped; shellcheck SC1007/SC2034 clean (SC2016 info left). test.sh: rq21 (cold cache dir, refresh spawned, modes 600/700), rq22 (`api500` -> net), rq23 (empty projects file); `rq()` accepts QC/NR overrides. README: script entry and deps.

## G2a: metrics dropped (2026-11-27)
- runner-queue.sh: metrics source removed (port discovery, ss/MainPID, curl, METRICS_FILE); running = `journalctl --user` `builds=N`, concurrent = config.toml; hover header `Running r/c:`. Tests: metrics fixtures removed, `journal_b2` added, rq5/6/8/14/19b/19c adapted (220 pass).
- Machine: `listen_address` removed from ~/.gitlab-runner/config.toml (backup config.toml.bak-g2a), runner restarted while idle (builds=0, no containers); `ss -ltn` shows nothing on :9252. Other user's runner untouched.
- README/spec updated (spec carries a dated note; metrics sections historical).

## G2b journal ANSI fix + project-list message (2026-11-27)
- Real journal lines carry ANSI codes inside fields (`builds\e[0;m=0`); `journal()` strips them (strip helper). Fixtures journal_b2/b3/ok/net/jobs now use the real layout; rq19e asserts it (old code fails rq9, rq19c, rq19e).
- Hover: missing token -> "Pending: no token (path)"; missing runner-projects -> "Pending: no project list (path)"; test rq19d.

## G1g auto project list from runner log (2026-11-27)
- `auto_scan` (journal `--since -30d`, `repo_url=https://host/path.git` -> path, newest first, unique, max 10) runs only in the background `refresh`, writes `runner-queue.projects` beside the cache; `plist` merges `runner-projects` (first) + that file; bar/hover read only the small file (no 30d journal per tick). Cache now carries `.projects`.
- Hover "no project list" only when both empty; with a token but no list, the bar respawns refresh at most every 5 min.
- Tests rq24-rq29 (real ANSI fixtures journal_repos, journal_repos12). U-4 moved to Done in USER_TODO.html. Live: bar shows `0/4  +0` with 3 projects found (data_zentrum, smart_speaker, concerts).

## G2 spec check: private sources (2026-11-28, bar-designer, code reading only)
| Check | Result | Evidence |
|---|---|---|
| (a) no TCP port / metrics with no `listen_address` | pass | runner-queue.sh has no listen/ss/metrics code since G2a; only outbound `curl` to `$base/api/v4` (first runner url); running from `journalctl --user`, concurrent from own config.toml |
| (c) install.sh never enables metrics | pass | install.sh, i3block.sh, barsconf.sh, i3/ contain no `gitlab`/`listen_address`/`metrics`; never touches `~/.gitlab-runner` |
| (b) cache files | pass | `spawn()` mkdir + chmod 700 of the cache dir before `flock`; `refresh` `umask 077` → `runner-queue.json`, `.projects`, `mktemp -d` 600/700, written tmp + `mv`. Lock file is created by `flock` with the bar's umask (likely 644) but sits inside the 700 dir |
| (b) token | pass | script never writes it; refuses to use it if any group/other bit is set (`mode_ok`) |
| (b) hover files | pass | `$XDG_RUNTIME_DIR/custom_barista/hover` (or `/tmp/custom_barista-$UID`, refused unless own + 700); hover-tee writes under a 0700 dir |
| (b) config dir | fixed | `~/.config/custom_barista` was 0755 (install.sh `mkdir -p`); holds `runner-projects` (mode not checked by the script) → install.sh now `chmod 700` |
| argv | **leak → G2c** | `mount`: `/proc` without `hidepid`; refresh passes `--argjson prev "$prev"` (whole previous cache), `--arg ids` (project list) to jq and the project path in the curl URL; any local user can read them with `ps` while they run (each refresh, ~every 60 s). Token is safe (stdin). `bar()` `--arg t` carries counts only (low) |

Doc fix: spec "Runner setup" section marked historical / do not apply. Tests 257 pass. Live checks as anatolii: USER_TODO U-6 (modes, `ss -ltnp`, hover).

## G2c argv leak fixed (2026-11-28)
- `refresh`: previous cache and project list written to `$td/prev`, `$td/ids` (700 dir, umask 077) and read with `--slurpfile`/`--rawfile`; runner id via `RID` env (`$ENV.RID`); curl gets `header`+`url` on stdin with `-K -`. Remaining argv: counts, err word, temp paths (not private).
- Test rq30: fake curl/jq on PATH log argv; asserts no project path, token, job/ref name or host in the log, and the cache is still written. 258 pass. Deployed; both bars clean, runner block shows `0/4  +0`; config dir 700.

## G1h auto_scan keeps good list (2026-11-28)
- `auto_scan` reads the 30d journal itself (`timeout ${SCAN_TIMEOUT:-20} journalctl`), returns 1 on read failure or empty result; `refresh` then removes `.projects.new` and keeps the old `.projects`.
- SC2034 `src` removed; `DIM` read from `info_fg` in `../config.toml` (fallback `#777777`).
- Tests rq31 (empty journal), rq32 (failed read), rq33 (fake journalctl sleeping past SCAN_TIMEOUT=1); test helper `rq` now honors an empty `JF` (journalctl path). 266 pass; both bars no errors.

## G1e live checks, part 1 (2026-11-28)
- Token absent from `ps`: 5 forced `runner-queue.sh refresh` runs, `ps -eo args` polled every 0.1 s (49 polls) against the first 8 chars of the token (pattern read from a 600 file via `grep -F -f`, so the check does not match itself): 0 matches. (A first attempt with the pattern in grep's own argv gave a false 38/38 self-match; discarded.)
- API refresh rate with the bar running: cache `ts` watched for 200 s (1 s steps, no forced refresh): changes at +0, +62, +122, +182 s, i.e. one refresh per 60 s (TTL), never faster. Pass.
- Not run (need the user): green `1/4` during a real job, yellow `net` on a network drop.
