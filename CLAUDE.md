# custom_barista

**New session? Run `/roadmap`** (roadmap: `docs/ROADMAP.md`, later items in `docs/BACKLOG.md`): it lists what is done, in flight, next and open decisions. Update the roadmap whenever a work item starts or finishes.

Custom i3 status bar in Go on [barista.run](https://barista.run). One package per widget (`nvidia/`, `temp/`, `vol/`, `netm/`, …), wired in order in `main.go`; shared helpers in `utils/`. Colors only via `colors.Scheme(good|degraded|bad|dim-icon)`; icons from material/typicons fonts in `~/.fonts`.

- Checks: `go build ./... && go vet ./...` (`go test ./...` once tests exist).
- Smoke run: `timeout 5 go run . 2>&1 | head -c 4000` (i3bar JSON; grep for `ERR`).
- Deploy: `go install .` (binary in `$GOPATH/bin/custom_barista`), then `i3-msg restart`.

## Working agreements (from the user)

Full rules with reasons: `docs/working-agreements.md` (save new preferences there).
- Work goes to project agents in `.claude/agents/`, never general-purpose; one item per agent, small tasks, reports ≤10 lines.
- One agent at a time (two at most).
- Model tiers: top model only for the hardest ~10 % (hard diagnosis, retry after a failed fix); middle model for designer/reviewer/curator; sonnet for chore/mechanical runs.
- Context hygiene: no whole-file dumps; quiet test output.
- No waiting agents: long jobs detached, capped, resumable, with a "Background checks" item.
- Each agent: progress note in `docs/progress/` + roadmap update + commit. Agents never push; main session pushes in batches (~5 items, before `/clear`, at wrapup).
- Deploying (install + restart bar) needs no confirmation.
- Re-rank "Queued next" by value; a recurring check after about every 3 tasks.
- After the context warning, suggest `/clear` at a break.
