#!/usr/bin/env python3
# T1 spike (throwaway): compute each status piece's x edges the way i3bar lays them out
# (libi3 font.c predict_text_width_pango + i3bar xcb.c predict_statusline_length), click each
# computed centre with button 9 (no action bound) and compare with the click-reported edges.
# Usage: edges.py LOGPREFIX BAR_INDEX  (BAR_INDEX into xbars.py geom output)
import json, subprocess, sys, time
import gi
gi.require_version("Pango", "1.0"); gi.require_version("PangoCairo", "1.0")
from gi.repository import Pango, PangoCairo
import cairo

FONT, DPI, SEP_DEFAULT = "PragmataPro Mono, Symbols Nerd Font Mono 18", 96, 9
pre, idx = sys.argv[1], int(sys.argv[2])
here = sys.path[0]

cr = cairo.Context(cairo.ImageSurface(cairo.FORMAT_ARGB32, 1, 1))
desc = Pango.FontDescription.from_string(FONT)

def width(text, markup):
    ctx = PangoCairo.create_context(cr); PangoCairo.context_set_resolution(ctx, DPI)
    lay = Pango.Layout.new(ctx); lay.set_font_description(desc)
    lay.set_markup(text, -1) if markup else lay.set_text(text, -1)
    return lay.get_pixel_size()[0]

def layout(status, bar):
    pieces = [b for b in status if b.get("full_text")]
    ws = []
    for i, b in enumerate(pieces):
        w = width(b["full_text"], b.get("markup") == "pango")
        w = max(w, b.get("min_width", 0)) if isinstance(b.get("min_width", 0), int) else w
        sep = b.get("separator_block_width", SEP_DEFAULT)
        ws.append((b, w, sep if i < len(pieces) - 1 else 0))
    total = sum(w + s for _, w, s in ws)
    tray = len(bar["tray"])
    tray_w = tray * (bar["h"] - 4 + 2) + 2 if tray else 0   # icon_size + tray_padding, + tray_loff_px
    x = bar["x"] + bar["w"] - tray_w - (4 if tray else 0) - total
    out = []
    for b, w, s in ws:
        out.append({"name": b.get("name"), "instance": b.get("instance"), "x0": x, "x1": x + w,
                    "text": b["full_text"]})
        x += w + s
    return out

bar = json.loads(subprocess.check_output([sys.executable, here + "/xbars.py", "geom"]))[idx]
status = json.loads(open(pre + ".out").read().lstrip(",").rstrip().rstrip(","))
comp = layout(status, bar)
y = bar["y"] + bar["h"] // 2
seen = len(open(pre + ".in").readlines()) if __import__("os").path.exists(pre + ".in") else 0
rows = []
for c in comp:
    cx = (c["x0"] + c["x1"]) // 2
    subprocess.run(["xdotool", "mousemove", str(cx), str(y), "click", "9"], check=True)
    time.sleep(0.25)
    lines = open(pre + ".in").readlines()
    new, seen = lines[seen:], len(lines)
    clicks = [json.loads(json.loads(l)["click"].lstrip(",")) for l in new if json.loads(l)["click"].strip() not in ("[", "")]
    if not clicks:
        rows.append((c, None)); continue
    k = clicks[-1]
    ref0 = k["x"] - k["relative_x"]
    rows.append((c, {"name": k["name"], "instance": k["instance"], "x0": ref0, "x1": ref0 + k["width"],
                     "status_same": json.loads(new[-1])["status"].lstrip(",").strip().rstrip(",") ==
                                    json.dumps(status)}))
for c, r in rows:
    label = __import__("re").sub("<[^>]+>", "", c["text"]).strip()[:24]
    if r is None:
        print(f"{c['name']}/{c['instance']}\t{label}\t{c['x0']}\t{c['x1']}\t-\t-\tno click"); continue
    match = "" if (r["name"], r["instance"]) == (c["name"], c["instance"]) else f" hit {r['name']}/{r['instance']}"
    print(f"{c['name']}/{c['instance']}\t{label}\t{c['x0']}\t{c['x1']}\t{r['x0']}\t{r['x1']}\t"
          f"{c['x0'] - r['x0']:+d}\t{c['x1'] - r['x1']:+d}{match}")
