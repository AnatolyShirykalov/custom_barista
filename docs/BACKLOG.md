# Backlog

Open work items that are not next. **Not read at session start**: `/roadmap` reads only docs/ROADMAP.md; this file is opened when "Queued next" there runs empty, at an intake of new requests, and by `/wrapup`, which moves the next 5-10 items into "Queued next". New items (follow-ups, proposals, ideas) are added here, under the fitting section, unless they are next. Done items never stay here: they go to `docs/roadmap-archive/` at wrapup.

Work items are checkboxes (`1. [ ]`): what, where, done condition, `→ agent-name`. The status line shows their count as "+N backlog".

_(empty: add new items here)_

## Bar blocks

1. [ ] **R1a reboot block click + popup** (look pass 2026-11-27): (a) left click runs `notify-send`, but no notification daemon is running or activatable here ("ServiceUnknown: not activatable") so the click does nothing; replace with a yad popup of `reboot-needed.sh list` (reuse the hover popup look) or drop the click and the "Left click: notify" line in explain.sh. (b) Hover popup shows `list | head -3` = kernel line + "Need reboot:" + 1 of 14 linux-firmware split pkgs, hiding nvidia-open and pipewire (relogin); in `list`, collapse packages sharing name prefix and version into one line (`linux-firmware +13  20261019-1 → 20261124-1`), use `→` like the bar text, put the list before the legend, cap 8 lines with `… N more`. Done: click visibly shows the list (or no click), popup today shows kernel, linux-firmware (+13), nvidia-open, pipewire; test.sh rows for collapse/cap; compact.toml regenerated. → widget-builder


