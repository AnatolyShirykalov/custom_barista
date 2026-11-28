# G1 gitlab-runner queue block: spec (bar-designer, 2026-11-27)

> **Update 2026-11-27 (G2a):** metrics dropped (privacy: any localhost TCP port is readable by every local user). Running comes only from `journalctl --user -u gitlab-runner` (`builds=N`), concurrent from `config.toml`; no `listen_address`, no `ss`/`curl` to /metrics, no `METRICS_FILE`, hover header `Running r/c:`. The metrics sections below are historical.

Source decision (2026-11-27): option C of G1a (docs/progress/gitlab-runner-block.md): running count from the
current user's runner metrics endpoint, pending jobs from the GitLab API (read_api token). Mocks: `img/`.
Open question for the user: only Q1 (idle visibility), page `questions.html`; build option A unless the answer says otherwise.

## Options (Q1: what the block does when the runner is idle and nothing is pending)

| | Idle look | Size/risk | Why not |
|---|---|---|---|
| **A (recommended)** always shown; idle = whole block dim `0/4  +0` | `img/a-idle.png` | S, none | |
| B hidden while idle (`{"text":""}`), shown on any running/pending job or fault | `img/b-idle-hidden.png` | S, layout shift | the right half of the bar jumps ~140 px each time a job starts or ends; "idle" cannot be told from "block broken" |
| C icon only while idle (dim fox, no numbers) | `img/c-idle-icon.png` | S, width shift | width changes on every job start/end (jitter); the numbers return exactly when you glance for them |

A keeps the width fixed in every state and shows runner health (off / net) at a glance; dim keeps idle quiet.

## Files and paths

| What | Path | Rules |
|---|---|---|
| Block script | `scripts/runner-queue.sh` | modes: none (bar json), `refresh` (API fetch, detached), `refresh-now` (left click: `refresh` unless cache < 10 s old), `list` (hover text), `open` (right click) |
| Runner config (read only) | `$HOME/.gitlab-runner/config.toml` (`RUNNER_CONFIG`) | never `/home/*`, never another user's file |
| API token | `~/.config/custom_barista/gitlab-token` (`TOKEN_FILE`) | one line, PAT or project token with `read_api`; dir 0700, file 0600 (or 0400). Any group/other bit set → treated as missing + hover says `token file mode NNN: chmod 600 <path>`. Outside the repo; install.sh never creates or reads it |
| Project list (G1g, 2026-11-27) | own runner log: `repo_url=https://host/group/project.git` lines of `journalctl --user -u gitlab-runner --since -30d` (ANSI stripped), unique, newest first, max 10; scanned only by the background refresh, stored in `runner-queue.projects` next to the cache | optional `runner-projects` below is merged in (file entries first, dedupe, cap 10); hover "no project list" only when both are empty |
| Project list file (optional extra) | `~/.config/custom_barista/runner-projects` (`PROJECTS_FILE`) | one project per line: numeric id or `group/sub/project` path (script URL-encodes `/` → `%2F`); `#` comments and blank lines ignored; first 10 used, rest ignored (hover says `+N projects ignored`) |
| Cache | `${XDG_CACHE_HOME:-$HOME/.cache}/custom_barista/runner-queue.json` (`QUEUE_CACHE`), lock `…/runner-queue.lock` | written atomically (tmp + `mv`); shared by the DP-0 and DP-2 bar processes |

## Runner setup (builder, once)

> **Historical, do NOT apply (G2a, 2026-11-27):** never add `listen_address` for any user; the steps below are kept only as a record.

1. Add top-level `listen_address = "127.0.0.1:9252"` to `~/.gitlab-runner/config.toml` (before `[[runners]]`; back up first), `systemctl --user restart gitlab-runner` (graceful: SIGQUIT drop-in; do it with no job running).
2. Confirm metric names: `curl -s 127.0.0.1:9252/metrics | grep '^# HELP gitlab_runner_\(jobs\|concurrent\) '`. If `gitlab_runner_jobs` is named differently, use the real name and note it in the progress file.
3. Other user (`anatolii`): not touched. If they want the block later they use a different port (suggest 9253) in their own config; the script never assumes a port.

## How the script finds its own metrics port (never the other user's)

1. `port` = value of top-level `listen_address` in `$RUNNER_CONFIG` (awk, lines before the first `[[`; accept `"127.0.0.1:N"`, `"localhost:N"`, `":N"`; any non-loopback host → use `127.0.0.1:N` anyway).
2. `pid` = `systemctl --user show -p MainPID --value gitlab-runner` (must be > 0).
3. Ownership check: `ss -Hltnp "sport = :$port"` must contain `pid=$pid,` (without root, `ss` shows process info only for the caller's own sockets, so a socket of another user never matches).
4. Only then `curl -s --max-time 1 http://127.0.0.1:$port/metrics`. Any step failing → journal fallback (below), hover line `running: journal (metrics off)`.

## Values

- **running** `r`: sum of all `gitlab_runner_jobs{…}` sample values (several label sets possible). Fallback: last `builds=N` in `journalctl --user -u gitlab-runner -n 200 -o cat` (strip ANSI), else 0.
- **concurrent** `c`: `gitlab_runner_concurrent`, fallback top-level `concurrent =` in config.toml, else `?`.
- **pending** `p`: from cache: count of jobs with `status == "pending"` across listed projects. Running jobs from the same calls (filtered `runner.id == <id from config.toml [[runners]] id =>`) feed the hover only.
- **net down**: any line matching `Checking for jobs\.\.\. failed` in `journalctl --user -u gitlab-runner --since -30s -o cat`.
- **oldest pending age**: `NOW - min(created_at)` of pending jobs.

## Text (plain, before markup; `W` = fixed width)

`r` right-aligned to the digits of `c`; pending slot is 3 chars, right-aligned (`%3s`), like `eng(w:3)` elsewhere. `W = len(c)*2 + 1 + 1 + 3` (7 for `c=4`). Every state is padded with trailing spaces to `W` (or `len(c)*2+1` in no-token mode), so the block never changes width.

| # | Condition (first match wins) | text | state | markup |
|---|---|---|---|---|
| S0 | `$RUNNER_CONFIG` missing | `` (empty) | — | block hidden (`hide_when_empty`) |
| S1 | unit `failed` | `ERR` padded | Critical | |
| S2 | unit not `active` (inactive, activating, …) | `off` padded | Info (dim) | |
| S3 | net down | `r/c net` | Warning | |
| S4 | p > 0 and oldest pending ≥ 15 min | `r/c  +p` | Critical | |
| S5 | p > 0 | `r/c  +p` | Warning | |
| S6 | r > 0 | `r/c  +0` | Good | |
| S7 | idle (r = 0, p = 0) | `0/c  +0` | Info (dim) | (option B: `{"text":""}`; option C: text = ``, icon only) |

Pending slot variants (apply inside S4-S7): no token file and no project file → slot dropped entirely (`r/c`, width `len(c)*2+1`, stable because it is configuration); token present but invalid (401/403), mode wrong, cache older than 5 min, or never fetched → `+?` in `<span foreground="#777777">` and the count is treated as 0 for the state; `p > 99` → `+99`.

Icon: `[icons.overrides] gitlab = "\U000F0BA0"` (md-gitlab, Symbols Nerd Font Mono; renders, checked), json `"icon":"gitlab"`, dim via `icons_format` like all blocks.

## Polling and the API (cheap, rate-safe, never blocks the bar)

- Block `interval = 5`. A bar run does: unit check, port check, one localhost GET (≤1 s timeout), one `journalctl --since -30s`, read cache. Budget < 100 ms; no network call in the bar run.
- If the cache is older than `TTL` (60 s; 600 s after a 401/403) and `TOKEN_FILE` + `PROJECTS_FILE` exist: `setsid -f flock -n <lock> timeout 20 runner-queue.sh refresh >/dev/null 2>&1` and print from the old cache. `flock -n` makes the two bar processes share one fetch.
- `refresh`: GitLab base = `url =` of the first `[[runners]]` in config.toml. Skip all calls (write `err:"net"`) if net down. Per project, one call: `curl -sS --max-time 5 -H @<(printf 'PRIVATE-TOKEN: %s\n' "$tok") "$base/api/v4/projects/$id/jobs?scope[]=pending&scope[]=running&per_page=50"` (token via process substitution, never in argv or the environment of other processes). At most 10 calls/min per user vs the gitlab.com 2000/min authenticated limit. Stop at the first 401/403 (`err:"auth"`); network/5xx → `err:"net"`, keep the previous job lists and `ts_ok`.
- Cache json: `{"ts":<epoch>,"ts_ok":<epoch of last good fetch>,"err":null|"auth"|"net"|"mode"|"cfg","pending":[J…],"running":[J…],"ignored":N}`, `J = {"project":"grp/proj","ref":"main","name":"build","created":<epoch>,"url":"…/-/jobs/123"}`; `project` = `web_url` path minus host and `/-/jobs/N`.
- Left click forces `refresh` if the cache is older than 10 s (cap), then `update = true`.

## Every json path is valid JSON

All bar output goes through `jq -nc --arg …` (no hand-built strings). Paths: S0 `{"text":""}`; S1-S7; script error trap (`trap … ERR` or `|| `) → `{"icon":"gitlab","state":"Critical","text":"RUN ERR"}` padded. `refresh`, `list`, `open` print no json (not bar paths) and always `exit 0`.

## config.toml (new group of its own, immediately before the claude-usage block; not merged)

```toml
[[block]]
block = "custom"
command = "~/projects/custom_barista/scripts/runner-queue.sh"
json = true
interval = 5
hide_when_empty = true
[[block.click]]
button = "left"
cmd = "~/projects/custom_barista/scripts/runner-queue.sh refresh-now"
update = true
[[block.click]]
button = "right"
cmd = "~/projects/custom_barista/scripts/runner-queue.sh open"
```

compact.toml (DP-2): kept, unchanged by gen-compact.sh; it lands between the ethernet block and keyboard. Merge-flag counts in test.sh stay 7 / 5.
`open`: `xdg-open` the url of the first own running job, else the oldest pending job, else do nothing.

## Hover (`scripts/hover/keys.toml` key `runner`, command `runner-queue.sh`; `explain.sh runner`)

Legend (3 lines) + `runner-queue.sh list` (≤ 8 lines, `LIST_MAX`, last line `  +N more` when cut); total ≤ 11 like `reboot`:

```
GitLab runner (this user): running/concurrent, +pending in listed projects.
Green running, yellow pending or no network, red stuck >15 min or unit failed; grey idle/off.
Left click: refresh pending now. Right click: open the first job.
Running 1/4 (metrics):
  grp/proj        main        build:linux      4m
Pending 2 (API, 35 s ago):
  grp/proj2       feat/x      test            12m
```

Columns: project ≤ 16, ref ≤ 12, job name ≤ 16 (cut with `…`), age right-aligned (`s/m/h/d`). Status lines instead of lists: `Pending: no token (~/.config/custom_barista/gitlab-token)`, `Pending: token rejected (401), next try in 10 min`, `Pending: token file mode 644: chmod 600 …`, `Pending: network down, last good 6m ago`, `running: journal (metrics off)`, `runner unit: inactive`. Running list without a token: journal `job_url` (project path + job id), no ref.

## Test hooks (no network, no systemd in tests)

Env: `RUNNER_CONFIG`, `UNIT_STATE` (skips systemctl), `METRICS_FILE` (skips port check + curl), `JOURNAL_FILE` (used for both journal reads), `QUEUE_CACHE`, `TOKEN_FILE`, `PROJECTS_FILE`, `NOW`, `NO_REFRESH=1` (never spawn), `API_DIR` (`refresh` reads `$API_DIR/<id>.json` and `$API_DIR/<id>.status` instead of curl). Fixtures in `scripts/testdata/runner/`.

## Test table (test.sh rows `rq1…`; text after `strip`, trailing spaces kept; `c = 4`)

| id | setup | text | state |
|---|---|---|---|
| rq1 | config missing | `` | — (json `{"text":""}`) |
| rq2 | unit failed | `ERR    ` | Critical |
| rq3 | unit inactive | `off    ` | Info |
| rq4 | active, metrics jobs 0, cache p=0 | `0/4  +0` | Info |
| rq5 | metrics two label sets 1+1 | `2/4  +0` | Good |
| rq6 | cache 3 pending, newest 1 min | `2/4  +3` | Warning |
| rq7 | cache 1 pending created 20 min ago | `0/4  +1` | Critical |
| rq8 | journal has `Checking for jobs... failed` | `2/4 net` | Warning |
| rq9 | no METRICS_FILE, journal `builds=3` | `3/4  +0` | Good |
| rq10 | cache `err:"auth"` | `0/4  +?` (`+?` in dim span) | Info |
| rq11 | cache ts 6 min old | `0/4  +?` | Info |
| rq12 | no token, no projects file | `0/4` | Info |
| rq13 | token file mode 644 | `0/4  +?` | Info |
| rq14 | cache 150 pending | `4/4 +99` | Warning |
| rq15 | `refresh` with `API_DIR` (2 projects, 1 pending + 1 own running + 1 foreign running) | cache: 1 pending, 1 running, `err:null` | |
| rq16 | `refresh`, project status 401 | cache `err:"auth"` | |
| rq17 | every rq1-rq14 output passes `jq -e .` | | |
| rq18 | width: `len` equal for rq2-rq11, rq13, rq14 | | |
| rq19 | `list` with 12 jobs, `LIST_MAX=8` (headers count) | 8 lines: 2 headers + 5 rows + `  +7 more` | |
| rq20 | explain runner ≤ 11 lines; keys.toml has `runner` | | |

## Acceptance checks (review, G1d)

1. DP-0 and DP-2 crops: fox icon renders (no tofu), dim; block sits as its own group before the usage block (DP-0) / before keyboard (DP-2).
2. Idle shows dim `0/4  +0`; start a job: green `1/4`, width unchanged (screenshot both).
3. `ps -eo args | grep -c PRIVATE` is 0 during a refresh; token file 0600; nothing under the repo holds the token or project ids.
4. `ss -ltnp` shows the metrics socket on 127.0.0.1 only; the script never reads `/home/anatolii`.
5. Cache refreshed at most once per 60 s with both bars running (cache `ts` deltas in a 5-min log).
6. Pull the network (or block gitlab.com): block turns yellow `net` within 30 s, no bar freeze; restore: back to normal.
7. `bash scripts/test.sh` green; compact.toml regenerated and in sync.

## Out of scope

Tag filtering of pending jobs (pending counts every pending job in the listed projects; list only projects this runner serves); `request_concurrency` tuning; the other user's runner.
