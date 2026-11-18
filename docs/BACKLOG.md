# Backlog

Open work items that are not next. **Not read at session start**: `/roadmap` reads only docs/ROADMAP.md; this file is opened when "Queued next" there runs empty, at an intake of new requests, and by `/wrapup`, which moves the next 5-10 items into "Queued next". New items (follow-ups, proposals, ideas) are added here, under the fitting section, unless they are next. Done items never stay here: they go to `docs/roadmap-archive/` at wrapup.

Work items are checkboxes (`1. [ ]`): what, where, done condition, `→ agent-name`. The status line shows their count as "+N backlog".

### Design (i3status-rust trial bars)

1. [ ] **DP-2 gap freq→mem** (D4 review 2026-11-17): freq's trailing pad plus mem's right-aligned eng(w:3) leave a wide gap on bar-small. Done: gap ≤ one separator width, test.sh widths still pass. → `widget-builder`
1. [ ] **rs icon color consistent**: only the time block dims its icons (`icons_format` #777); all other icons are white. Pick one rule (dim all icons, recommended). Done: one global setting, screenshot shows uniform icons. → `widget-builder`
1. [ ] **rs gap between icon and value**: fixed-width pads sit between icon and number (freq.sh 5 spaces, ccusage.sh 5, clip.sh 2, `eng(w:N)` pads), so values float away from icons. Move pad to the far side (after value or before icon) keeping width fixed. Done: test.sh width rows pass, screenshot shows value next to icon. → `widget-builder`
1. [ ] **rs disk io unlabeled**: `disk_iostats` shows `0.00kB 796kB` with no read/write markers and mixed decimals; net block uses up/down arrows. Add read/write glyphs and a fixed 3-digit format (or drop the block). Done: screenshot, width stable. → `widget-builder`
1. [ ] **rs mixed size units**: mem `70GiB`, disk `616GB`, GPU mem `1099MiB` (no label for GPU mem). One unit family, GPU mem in GiB with 1 decimal. Done: config/gpu.sh changed, test.sh row. → `widget-builder`
