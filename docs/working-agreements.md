# Working agreements

User preferences for how work runs in this repo. Commands and agents cite them by slug. On a change keep the old rule as "Earlier rule (date)".

## Specialist agents (`specialists`, workflow; 2026-11-17)
*Work goes to project agents, never general-purpose.*
The main session coordinates; each item goes to the matching agent in `.claude/agents/` (`widget-builder`, `dep-updater`, `bar-designer`, `chore`, `researcher`, `code-reviewer`, `agent-curator`, `repo-janitor`, `context-auditor`). Reports ≤10 lines. One item per agent.
**Why:** set up with /roadmap-init.
**How to apply:** no specialist fits → note it for the Agent roster check. [[one-at-a-time]]

## One agent at a time (`one-at-a-time`, workflow; 2026-11-17)
*Run agents one at a time (two at most).*
Small single-machine project; there is one live bar to test against.
**Why:** default chosen at setup; parallel runs hit the usage limit.
**How to apply:** wait for the final notification before the next agent. [[specialists]]

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
