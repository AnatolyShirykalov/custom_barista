#!/usr/bin/env python3
# T1 spike (throwaway): find the i3bar windows, print their geometry and tray width (`geom`),
# or log Enter/Leave/Motion events on them for SECS seconds (`events SECS`).
import json, sys, time
from Xlib import X, display

d = display.Display()
root = d.screen().root

def bars():
    out = []
    def walk(w):
        for c in w.query_tree().children:
            try:
                cls = c.get_wm_class()
                attrs = c.get_attributes()
            except Exception:
                continue
            if cls and cls[1] == "i3bar" and attrs.map_state == X.IsViewable:
                g = c.get_geometry()
                t = root.translate_coords(c, 0, 0)
                kids = [k for k in c.query_tree().children if k.get_attributes().map_state == X.IsViewable]
                tray = [dict(zip("xywh", (kg.x, kg.y, kg.width, kg.height)))
                        for kg in (k.get_geometry() for k in kids)]
                out.append({"win": c.id, "x": t.x, "y": t.y, "w": g.width, "h": g.height,
                            "override_redirect": bool(attrs.override_redirect), "tray": tray})
            else:
                walk(c)
    walk(root)
    return out

if sys.argv[1] == "geom":
    print(json.dumps(bars()))
else:
    secs = float(sys.argv[2])
    ws = {}
    for b in bars():
        w = d.create_resource_object("window", b["win"])
        w.change_attributes(event_mask=X.EnterWindowMask | X.LeaveWindowMask | X.PointerMotionMask)
        ws[b["win"]] = b["x"]
    d.flush()
    names = {X.EnterNotify: "enter", X.LeaveNotify: "leave", X.MotionNotify: "motion"}
    end = time.time() + secs
    while time.time() < end:
        while d.pending_events():
            e = d.next_event()
            if e.type in names:
                print(json.dumps({"t": round(time.time(), 3), "ev": names[e.type], "win": e.window.id,
                                  "root_x": e.root_x, "event_x": e.event_x}), flush=True)
        time.sleep(0.01)
