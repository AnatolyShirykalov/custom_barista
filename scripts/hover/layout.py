#!/usr/bin/env python3
# T1 hover core, pure layout: where i3bar draws each status piece (libi3 font.c
# predict_text_width_pango + i3bar xcb.c predict_statusline_length), hit test, block -> explain
# key map, bar support check, popup placement. No X, no GTK window (Pango text measuring only).
import re, tomllib
import gi
gi.require_version("Pango", "1.0"); gi.require_version("PangoCairo", "1.0")
from gi.repository import Pango, PangoCairo
import cairo

SEP_DEFAULT = 9      # i3bar separator_block_width default
SHORT_TEXT_LEFT = 600  # a short_text piece with the left edge nearer than this: widths unknowable
_cr = cairo.Context(cairo.ImageSurface(cairo.FORMAT_ARGB32, 1, 1))

def text_width(text, markup, font, dpi=96):
    ctx = PangoCairo.create_context(_cr); PangoCairo.context_set_resolution(ctx, dpi)
    lay = Pango.Layout.new(ctx); lay.set_font_description(Pango.FontDescription.from_string(font))
    lay.set_markup(text, -1) if markup else lay.set_text(text, -1)
    return lay.get_pixel_size()[0]

def tray_width(n, bar_h):
    # icon_size (h - 4) + tray_padding 2 per icon, + 2 left offset; 0 without icons
    return n * (bar_h - 4 + 2) + 2 if n else 0

def statusline_right(bar_x, bar_w, bar_h, tray_n):
    return bar_x + bar_w - tray_width(tray_n, bar_h) - (4 if tray_n else 0)

def block_index(instance):
    m = re.match(r"(\d+):", instance or "")
    return int(m.group(1)) if m else None

def layout(status, bar_x, bar_w, bar_h, tray_n, font, dpi=96):
    """Pieces [{name, instance, index, x0, x1, text}] in drawing order; x1 exclusive."""
    pieces = [b for b in status if b.get("full_text")]
    ws = []
    for i, b in enumerate(pieces):
        w = text_width(b["full_text"], b.get("markup") == "pango", font, dpi)
        mw = b.get("min_width", 0)
        if isinstance(mw, str):
            mw = text_width(mw, b.get("markup") == "pango", font, dpi)
        w = max(w, mw)
        if b.get("border") or any(k in b for k in ("border_left", "border_right")):
            w += b.get("border_left", 1) + b.get("border_right", 1)
        sep = b.get("separator_block_width", SEP_DEFAULT) if i < len(pieces) - 1 else 0
        ws.append((b, w, sep))
    x = statusline_right(bar_x, bar_w, bar_h, tray_n) - sum(w + s for _, w, s in ws)
    out = []
    for b, w, s in ws:
        out.append({"name": b.get("name"), "instance": b.get("instance"),
                    "index": block_index(b.get("instance")), "x0": x, "x1": x + w,
                    "text": b["full_text"]})
        x += w + s
    return out

def regions(pieces):
    """One hover region per block index: union of its pieces (pieces of a block are adjacent)."""
    out = []
    for p in pieces:
        if out and out[-1]["index"] == p["index"] and p["index"] is not None:
            out[-1]["x1"] = p["x1"]
        else:
            out.append({"index": p["index"], "x0": p["x0"], "x1": p["x1"]})
    return out

def hit(regs, x, right):
    """Region index under x, "tray" at or right of the statusline right edge, None for gaps/outside."""
    if x >= right:
        return "tray"
    for r in regs:
        if r["x0"] <= x < r["x1"]:
            return r["index"]
    return None

def explain_keys(config_path):
    """{block index: explain.sh key} from the first [[block.click]] cmd naming explain.sh."""
    with open(config_path, "rb") as f:
        blocks = tomllib.load(f).get("block", [])
    keys = {}
    for i, b in enumerate(blocks):
        for c in b.get("click", []):
            m = re.search(r"explain\.sh\s+(\w+)", c.get("cmd", ""))
            if m:
                keys[i] = m.group(1)
                break
    return keys

def bar_supported(status, pieces, bar_x, separator_symbol, padding):
    """(ok, reason). Off: separator_symbol, non-zero padding, short_text pieces near the left edge."""
    if separator_symbol:
        return False, "separator_symbol set"
    if any(padding.get(k, 0) for k in ("x", "y", "width", "height")):
        return False, "non-zero padding"
    if pieces and any(b.get("short_text") for b in status) and pieces[0]["x0"] < bar_x + SHORT_TEXT_LEFT:
        return False, "short_text near the left edge"
    return True, ""

def place(cx, popup_w, popup_h, mon_x, mon_w, bar_y, bar_h, position):
    """Popup top-left: centred on cx, clamped into the monitor, 4 px off the bar."""
    x = min(max(cx - popup_w // 2, mon_x + 4), mon_x + mon_w - 4 - popup_w)
    y = bar_y - 4 - popup_h if position == "bottom" else bar_y + bar_h + 4
    return x, y
