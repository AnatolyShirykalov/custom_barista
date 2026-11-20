# Backlog

Open work items that are not next. **Not read at session start**: `/roadmap` reads only docs/ROADMAP.md; this file is opened when "Queued next" there runs empty, at an intake of new requests, and by `/wrapup`, which moves the next 5-10 items into "Queued next". New items (follow-ups, proposals, ideas) are added here, under the fitting section, unless they are next. Done items never stay here: they go to `docs/roadmap-archive/` at wrapup.

Work items are checkboxes (`1. [ ]`): what, where, done condition, `→ agent-name`. The status line shows their count as "+N backlog".

_(empty: add new items here)_

## Bar blocks

- [ ] **U1c first-run placeholder**: on a fresh user (no statusline tap, empty ~/.cache/claude-usage) the usage block stays hidden for minutes until the first API poll lands (seen for anatolii 2026-11-18); show a dim `cc …` placeholder instead of hiding while no data has been fetched yet. Done: fixture row for empty cache → placeholder, width fixed. → `widget-builder`
- [ ] **install.sh stale deps**: drop `node`/`npx` from the dependency warnings (ccusage removed in U1). Done: no node/npx check, test.sh green. → `widget-builder`
