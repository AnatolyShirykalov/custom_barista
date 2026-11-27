---
description: Continue a roadmap in a fresh session (run right after /clear); optional arg = roadmap name
argument-hint: "[roadmap name] [notes]"
---

Pick the roadmap: the only roadmap is `docs/ROADMAP.md`. If the first word of the arguments below names one of them, use it; if they name none and there are several, list them (with their "In flight" line) and ask which. Start your first reply with the line `Roadmap restored: <path relative to the project root>` (the status line reads it to show done/total items).

Let's continue to follow it: "In flight", "Queued next", "Background checks"; open the backlog (`docs/BACKLOG.md`) only when "Queued next" is empty or new requests come in; slot recurring checks per its "Recurring checks" table.

- Don't do the work yourself: run project agents from `.claude/agents/`; wait for each agent's final "completed" notification. Pass the roadmap path in every agent prompt. Small tasks, one item per agent. Run non-conflicting agents in parallel (no shared files, only one deploying/restarting the bar at a time); wait for an agent's final notification before starting one that depends on it.
- Models by task kind, three tiers: the top model only for the hardest ~10 % of judgement items (diagnosis, hard-to-undo or flow-critical decisions, specs many items build on, a second try after a failed fix); mark them `(top)` in the roadmap and pass `model:` on the Agent call. The middle model by default for judgement agents (designers, analysts, reviewers, curator); sonnet for mechanical roles (runners, fetchers, scoped builders). Split an agent whose prompt mixes judgement and running. Before each judgement item state its tier in one line.
- Design items go designer (spec) → builder → designer (review). When I must choose between options, the designer (or you) writes a decision page `docs/design/<code>/questions.html` from the skill template `decision-page.html`; give me its path (and link it from the USER_TODO file, if there is one); I answer in chat.
- Never end a turn idle. The "completed" notification is final even if the agent's report is empty, "pending" or odd: check `git log`/`git status` and the progress note at once, then review, push and start the next item in the same turn. End a turn only with an agent confirmed running, or with a question to the user.
- Never use `general-purpose` (or other built-in catch-all) agents. Pick the closest specialist and put item-specific detail in the prompt. If no specialist fits, note it for the next "Agent roster" check (or run that check now if several items need the missing role); a new agent file loads only in the next session.
- First run the Background checks (one cheap command each) and update or remove the items.
- After each agent: review its commit(s), push in batches (about every 5 reviewed items; always before /clear, at wrapup, when I need a build, before a tag; never leave reviewed work unpushed), keep the roadmap current.
- If an agent stops saying it is "waiting on background work", check the process yourself (`ps`, log tail; by PID with `kill -0 $pid` or a `[p]attern`, since plain `pgrep -f` matches itself; stop stale wait loops); if it is done or dead, message the agent to finish, or run the item's checks and finish it in a follow-up agent.
- While an agent runs, commit your own edits by named paths only (`git add <paths>`), never `git commit -a` / `git add -A`: the agent's half-done files would land in your commit.
- At intake and at each start, re-rank "Queued next" by value/cost with a short reason (quick fixes, unblockers and test enablers first); the order my requests came in means nothing.
- After about every 3 feature tasks, slot the recurring check with the oldest "Last run" date.
- If a decision is genuinely mine, add it to "Open decisions" and ask me; don't block other items on it.
- Keep `docs/USER_TODO.html` (my action items U-1, U-2, … with links and pictures) current: at session start check it against "Open decisions" and the roadmap; whenever an item needs me, or I finish one, update it in the same turn (done items move to its Done section with the date, numbers are never reused) and give me its full path.
- When the context hook warns, finish the current item, make sure everything is committed and pushed and the roadmap is current, then tell me it's a good moment to `/clear` + `/roadmap <name>`.
- Context diet results come back as a list: ask me with AskUserQuestion (multiSelect) which to disable, apply them to `.claude/settings.local.json` (or `settings.json` if I say shared), and set the row date.
- After a block or design change is merged: `./install.sh --yes` (no need to ask), then check both bars run i3status-rs with no error blocks.

$ARGUMENTS
