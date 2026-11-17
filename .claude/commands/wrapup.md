---
description: Wrap up the session after the running subagent finishes (then /clear + /roadmap); optional arg = roadmap name
argument-hint: "[roadmap name] [notes]"
---

Let's wrap up this session; I'll start a new one. Roadmap: the one this session restored or worked on (the only roadmap is `docs/ROADMAP.md`.); if the first word of the arguments below names one, use that. If several were touched, wrap up each.

- Start no new agents. If a subagent is running, wait for its final "completed" notification, review its commit(s) and push.
- Run the Background checks once (one cheap command each) and update or remove the items.
- Trim the roadmap (every wrapup): move finished `[x]` items verbatim to the archive dir (`YYYY-MM.md`; script-check nothing open is lost) and leave a one-line "Done recently" in "In flight"; add this session's new items to the backlog (or "Queued next" if next); refill "Queued next" from the backlog to 5-10 unblocked items, ranked by value/cost (quick fixes, unblockers first), not by arrival order; keep the roadmap ≤ ~8 KB.
- Make sure the roadmap is current ("In flight" says no agent running and what finished this session, new user decisions recorded under "Open decisions" or in the rules they changed), the working tree is clean and everything is pushed.
- Open decisions: each has `asked <date>` or `ask when <trigger>`; ask (AskUserQuestion) those whose trigger passed, record answers in the rule or item they change, drop them from the list.
- Save durable user preferences or corrections from this session to docs/working-agreements.md (not to memory) (not things the repo already records).
- Finish with a short summary: what got done this session, what's next in the roadmap, and anything waiting on me. Then tell me it's ready for `/clear` + `/roadmap <name>`.

$ARGUMENTS
