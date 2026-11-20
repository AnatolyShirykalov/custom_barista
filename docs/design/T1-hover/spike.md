# T1 hover tooltips: spike (2026-11-20, widget-builder)

Question: can a daemon beside i3bar know which block the pointer is over, on both bars? **Verdict: go.**

## Method

Throwaway scripts in `scripts/spike/` (not installed, no test.sh rows):
- `tee-wrap.py`: temporary status_command wrapper (i3status-rs runs as usual) logging the latest status JSON line and every click event with the status line current at that moment. `~/.i3/bars.conf` was patched for the run and restored afterwards.
- `edges.py`: computes each piece's root-x edges from the status JSON like i3bar (libi3 `predict_text_width_pango`: PangoCairo, font `PragmataPro Mono, Symbols Nerd Font Mono 18`, resolution 96 from Xft.dpi, markup per piece; i3bar `xcb.c`: width = max(text, min_width), gap = `separator_block_width` (default 9, none after the last piece), right-aligned at bar width − tray width − 4 px when a tray exists; tray width = icons × (bar_h − 4 + 2) + 2). Then clicks each computed centre with `xdotool click 9` (no action bound anywhere) and reads the reported edges `x − relative_x` and `+ width`.
- `xbars.py`: finds the i3bar windows (WM_CLASS `i3bar`, viewable), geometry and mapped tray children; logs Enter/Leave/Motion.

Bars at test time: DP-0 bar root x 2560, w 3840, h 34, 3 tray icons (30 px); DP-2 bar x 0, w 2560, no tray.

## Error table (computed − reported, px; a piece = one JSON element, merged blocks give several)

### DP-0 (config.toml)

| name/instance | text | computed x0-x1 | reported x0-x1 | err left / right |
|---|---|---|---|---|
| 0/0: | 󰊚 0.18 0.41 | 3652-3814 | 3652-3814 | +0 / +0 |
| 0/1: | 󱃂 48° | 3814-3904 | 3814-3904 | +0 / +0 |
| 0/2: | 󰥛 25 2 2 3 0 0 | 3904-4126 | 3904-4126 | +0 / +0 |
| 1/3: | 󰍛 90GB | 4135-4237 | 4135-4237 | +0 / +0 |
| 1/4: | 󰋊 632GB | 4237-4351 | 4237-4351 | +0 / +0 |
| 1/5: | 󰓢 R 2.0kB W 322kB | 4351-4585 | 4351-4585 | +0 / +0 |
| 2/6: | 󰢮 36° 0.9GB | 4594-4756 | 4594-4756 | +0 / +0 |
| 3/8: | 󰈀 󰕒  11kB 󰇚 6.6kB 192.16 | 4765-5197 | 4765-5197 | +0 / +0 |
| 4/9: | 󰙴 13%  27.6M $20.4 cache | 5206-5740 | 5206-5740 | +0 / +0 |
| 5/10: | 󰌌 US | 5749-5827 | 5749-5827 | +0 / +0 |
| 5/12: | 󰕾 | 5827-5863 | 5827-5863 | +0 / +0 |
| 5/12: | 70% | 5863-5923 | 5863-5923 | +0 / +0 |
| 6/13: | 󰃭 Fri 2026-11-20 󰅐 19:55 | 5932-6298 | 5932-6298 | +0 / +0 |

### DP-2 (compact.toml)

| name/instance | text | computed x0-x1 | reported x0-x1 | err left / right |
|---|---|---|---|---|
| 0/0: | 󰊚 0.17 0.41 | 985-1147 | 985-1147 | +0 / +0 |
| 0/1: | 󱃂 48° | 1147-1237 | 1147-1237 | +0 / +0 |
| 0/2: | 󰥛 13 4 1 14 0 0 | 1237-1459 | 1237-1459 | +0 / +0 |
| 1/3: | 󰍛 90GB | 1468-1570 | 1468-1570 | +0 / +0 |
| 2/4: | 󰢮 36° 0.9GB | 1579-1741 | 1579-1741 | +0 / +0 |
| 3/6: | 󰈀 󰕒 4.2kB 󰇚 3.5kB | 1750-2002 | 1750-2002 | +0 / +0 |
| 4/7: | 󰌌 US | 2011-2089 | 2011-2089 | +0 / +0 |
| 4/9: | 󰕾 | 2089-2125 | 2089-2125 | +0 / +0 |
| 4/9: | 70% | 2125-2185 | 2125-2185 | +0 / +0 |
| 5/10: | 󰃭 Fri 2026-11-20 󰅐 19:55 | 2194-2560 | 2194-2560 | +0 / +0 |

Max error: 0 px on both bars (13 + 10 pieces). Every click landed on the expected name/instance.

## Event delivery

python-xlib `change_attributes(event_mask=Enter|Leave|PointerMotion)` on the i3bar windows delivers EnterNotify, MotionNotify and LeaveNotify on both bars (pointer moved with xdotool across DP-0 and DP-2). No polling needed. The bars are not override-redirect in dock mode (i3 manages them as dock clients). Tray icons are child windows: entering one gives a Leave (detail Inferior) on the bar, so the daemon should treat that as "over the tray", not as leaving the bar.

## Go / no-go: go

- Edges computed from the status JSON match i3bar's own hit-testing exactly (same Pango call, same layout rules, which `xcb.c` shows plainly).
- Events arrive without polling and without interfering with i3bar's own clicks (only ButtonPress is exclusive per window; we select none).
- Risks for the build: the daemon needs the status JSON, so status_command becomes a tee wrapper (as in the spike) or the daemon runs its own reader; short_text switching when the statusline overflows (not happening on these bars, but `adjust_statusline_length` would change widths); tray icon count changes (re-read children on MapNotify/UnmapNotify or on each Enter); Win+i swaps commands (the wrapper must follow barsconf.sh); `padding` in bars.conf (unset now) would shift x.
