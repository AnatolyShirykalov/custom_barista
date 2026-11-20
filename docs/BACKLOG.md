# Backlog

Open work items that are not next. **Not read at session start**: `/roadmap` reads only docs/ROADMAP.md; this file is opened when "Queued next" there runs empty, at an intake of new requests, and by `/wrapup`, which moves the next 5-10 items into "Queued next". New items (follow-ups, proposals, ideas) are added here, under the fitting section, unless they are next. Done items never stay here: they go to `docs/roadmap-archive/` at wrapup.

Work items are checkboxes (`1. [ ]`): what, where, done condition, `→ agent-name`. The status line shows their count as "+N backlog".

_(empty: add new items here)_

## Bar blocks

1. [ ] **Hover: first popup missed once** (look pass 2026-11-20): pointer warped from a window straight onto the DP-0 load block (x 3670) showed no popup after 1.3 s; 3 later tries (same x, also from off-bar) showed it, no log line. Done when a scripted run of 20 xdotool warps (off-bar → block, 1.0 s wait, popup detected by screenshot) on both bars shows 20/20, or the cause is found and a row is added to `test_hover.py`. → `widget-builder`

- Doubtful, git hygiene 2026-11-20 (no action taken): `docs/design/D5-bar-review/img/f5-p4-dp0.png` and `f5-p4-dp2.png` are byte-identical (design evidence, keep or drop one?); 94 design PNGs total about 1.4 MB, largest 44 KB, so no size problem.
