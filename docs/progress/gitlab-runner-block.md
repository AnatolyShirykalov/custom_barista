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
