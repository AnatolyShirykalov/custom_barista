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
