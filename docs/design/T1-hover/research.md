# T1 hover tooltips: research (2026-11-18, researcher)

i3bar protocol has no hover/motion events (https://i3wm.org/docs/i3bar-protocol.html). No existing i3bar tooltip project found.

| Option | Effort | Fragility | Notes |
|---|---|---|---|
| (a) hover daemon beside i3bar (recommended) | M | medium | python-xlib selects EnterNotify/LeaveNotify/MotionNotify on the i3bar windows (class `i3bar`), no polling. Block extents: tee the i3status-rs JSON, measure full_text with gi Pango in the bar font, max(text, min_width) + separator_block_width, laid out from the right minus tray width (tray icons are child windows; Win+i handled). Risk: font/DPI pixel drift growing leftwards; ground truth = click events (x - relative_x, width). Popup: in-process GTK window after ~600 ms, hide on leave, text from scripts/explain.sh. |
| (b) eww bar | L | low once built | native `:tooltip`; needs i3status-rs JSON → labels, FIFO for clicks back, workspaces/mode via i3 IPC, both monitors, tray via SNI (XEmbed apps need snixembed). AUR only (eww 0.6.0). |
| polybar / yambar / xmobar | - | - | no tooltips (polybar hover request #1064 open). waybar: Wayland only. |
| (c) patch i3bar | L | high | C fork + protocol extension. |

Installed: python-gi (Pango, Gtk3), pango-view, xdotool, yad, xprop. Missing: python-xlib, xorg-xinput (Arch extra).

Next step: spike for (a): install python-xlib, compute block edges, compare with click-reported edges on both bars; build if within a few px.
