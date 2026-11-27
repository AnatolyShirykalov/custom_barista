# Working agreements

User preferences for how work runs in this repo. Commands and agents cite them by slug. On a change keep the old rule as "Earlier rule (date)".

## Specialist agents (`specialists`, workflow; 2026-11-17)
*Work goes to project agents, never general-purpose.*
The main session coordinates; each item goes to the matching agent in `.claude/agents/` (`widget-builder`, `dep-updater`, `bar-designer`, `chore`, `researcher`, `code-reviewer`, `agent-curator`, `repo-janitor`, `context-auditor`). Reports ≤10 lines. One item per agent.
**Why:** set up with /roadmap-init.
**How to apply:** no specialist fits → note it for the Agent roster check. [[one-at-a-time]]

## Parallel agents when no conflict (`parallel-ok`, workflow; 2026-11-27, replaces one-at-a-time from 2026-11-17)
*Run agents in parallel, no fixed limit, as long as they don't conflict.*
**Why:** user: "you can run things in parallel, no limits if the subagents don't conflict".
**How to apply:** parallel only for items with disjoint files; only one agent deploys/restarts the bar at a time; dependent items still wait for the final notification. The main session commits only named paths while agents run. [[specialists]]

## Batched push (`batched-push`, git; 2026-11-17)
*Agents commit, never push; main session pushes in batches.*
Push about every 5 reviewed items, and always before `/clear`, at wrapup, before a tag. Reviewed work is never left unpushed.
**Why:** user picked "Batched push, deploy freely".
**How to apply:** agents' commit rule says "Do not push unless the prompt says so". [[deploy-freely]]

## Deploy freely (`deploy-freely`, deploy; 2026-11-17)
*Installing and restarting the live bar needs no confirmation.*
After checks pass: `./install.sh --yes` (config-only edits: `i3-msg restart`); verify both bars run i3status-rs with no error blocks.
**Why:** user picked "Batched push, deploy freely".
**How to apply:** builders deploy their own finished item. [[batched-push]]

## Model tiers (`model-tiers`, workflow; 2026-11-17)
*Top model only for the hardest ~10 % of judgement items; middle model for judgement agents; sonnet for mechanical ones.*
Top: hard diagnosis, second try after a failed fix, specs many items build on (mark `(top)` in the roadmap). Sonnet: `chore`, `dep-updater`-style runs.
**Why:** set up with /roadmap-init.
**How to apply:** state the tier in one line before each judgement item.

## Recurring checks (`recurring-checks`, workflow; 2026-11-17)
*After about every 3 tasks run the recurring check with the oldest date.*
Rows: Agent roster, Git hygiene, Context diet, Backlog tidy (monthly), Dependency updates, Look/usability pass, Widget health, Code review + docs.
**Why:** user chose all four optional checks at setup.
**How to apply:** table in `docs/ROADMAP.md`, log in `docs/progress/recurring.md`.

## Decision pages open in the browser (2026-11-17)
*When a decision page (`docs/design/<code>/questions.html`) is ready, open it automatically with `xdg-open <path>` (detached) before asking.*
**Why:** user found the HTML page much easier to answer from and asked for it to open on its own next time.
**How to apply:** main session (or designer agent) runs `setsid xdg-open <path> >/dev/null 2>&1 &` right after writing it, then asks in chat.

## Bar look preferences (2026-11-17)
*Icons must be specific and descriptive per widget (top design criterion); every number fixed width (no jumps 1↔2 digits); bars at the bottom; the tray goes with the visible bar.*
**Why:** user's main pain was vague or missing icons (GPU had none); jumping widths and a top bar bother them; they asked for the tray to follow Win+i.
**How to apply:** every bar design/build item checks glyph choice, padding and position; designers name the exact glyph and codepoint.

## Decision pages: a picture per proposal (2026-11-18)
*Every finding, fix and option on a decision page gets its own readable before/after image of the real bar (rendered, not hand-drawn where possible), one decision per section.*
**Why:** user found a text-heavy page with few mocks "hard to work with" and could not pick from it.
**How to apply:** designers render AFTER images (Xvfb + temporary config copies, see `docs/design/D5-bar-review/render/`), zoom small regions 2x, click to enlarge.

## Don't push back a request the user is waiting on (2026-11-18)
*A request the user already asked for and is waiting on keeps its place; new requests don't jump ahead of it without asking.*
**Why:** user had to remind twice about the tooltips after a new design request was put ahead of them.
**How to apply:** when re-ranking, a waited-on item stays first unless the user agrees; run independent new work alongside it instead.

## Tooltips mean hover (2026-11-18)
*"Tooltip" = text on mouse hover; a click-to-open popup does not count.*
**Why:** middle-click popups were built and the user still saw "no tooltips".
**How to apply:** check what an interaction word means on this desktop (i3bar has no hover) and say so before building a substitute.

## After /wrapup: queue, don't start (2026-11-18)
*Once the session is wrapped up, new requests are only added to the roadmap/backlog; no new agents are started.*
**Why:** user wanted a post-wrapup request scheduled, and an agent was launched instead.
**How to apply:** after `/wrapup`, write the item into "Queued next" (or backlog), commit, push, and say it is queued for the next session.

## Full file paths in replies (`full-paths`, communication; 2026-11-20)
*Every file mentioned to the user is given as a full absolute path.*
**Why:** user asked: "I always need full paths when you mention files".
**How to apply:** write `/home/anatoly/projects/custom_barista/docs/...`, never `docs/...` or a bare filename; ask agents for full paths in their reports.

## User action items page (`user-todo`, process; 2026-11-27)
*Everything waiting on the user is in `docs/USER_TODO.html`: numbered U-1, U-2, … with links and pictures where needed, refreshed regularly.*
**Why:** user asked for one page with their action items and for it to be refreshed as part of the process.
**How to apply:** add an item the moment something needs the user (decision page, token, file, post); move it to Done with the date when finished (numbers never reused); check it at `/roadmap` start and refresh at `/wrapup`; give its full path.

## Ask before using the user's accounts (`ask-accounts`, safety; 2026-11-27)
*Before calling the user's external accounts or CLIs (glab, gh, cloud CLIs) for anything beyond what they offered them for, ask first.*
**Why:** a `glab api projects?membership=true` lookup (to find project ids) listed projects the user did not expect this account to reach.
**How to apply:** state the exact command and what it reads, wait for an OK; prefer letting the user pick ids/paths themselves.

## Stay in scope (`scope`, workflow; 2026-11-27)
*This project is the i3 status bar. Account security, work-employer access and PC hardening belong to the setup session/roadmap, not here.*
**Why:** user: "you can forget about distribusion, not your scope".
**How to apply:** hand such findings to the setup session (SendMessage) and drop them from this roadmap, USER_TODO and progress notes.
