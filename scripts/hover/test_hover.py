#!/usr/bin/env python3
# T1 hover core unit rows h5-h14, h17 (headless); prints FAIL lines and `pass=N fail=M`, called by test.sh.
import json, os, subprocess, sys
here = os.path.dirname(os.path.abspath(__file__)); repo = os.path.dirname(os.path.dirname(here))
sys.path.insert(0, here)
import layout, state

pas = fail = 0
def check(name, ok, msg=""):
    global pas, fail
    if ok: pas += 1
    else: fail += 1; print(f"FAIL {name}: {msg}")

FONT = "PragmataPro Mono, Symbols Nerd Font Mono 18"
fx = {n: json.load(open(f"{repo}/scripts/testdata/hover/{n}.json")) for n in ("dp0", "dp2")}

# h5/h6: computed edges = click-reported edges, every piece of the live capture
for row, n in (("h5", "dp0"), ("h6", "dp2")):
    f, b = fx[n], fx[n]["bar"]
    bad = []
    for s in f["samples"]:
        p = layout.layout(s["status"], b["x"], b["w"], b["h"], b["tray_n"], f["font"])[s["piece"]]
        if (p["instance"], p["x0"], p["x1"]) != (s["ref"]["instance"], s["ref"]["x0"], s["ref"]["x1"]):
            bad.append((s["piece"], p["x0"] - s["ref"]["x0"], p["x1"] - s["ref"]["x1"]))
    check(row, f["samples"] and not bad, f"{n} piece/dx0/dx1 {bad}")

# h7: tray 0 / 3 / 5 icons, bar h 34: width n*32+2, +4 gap
check("h7", [layout.statusline_right(100, 1000, 34, n) for n in (0, 3, 5)] == [1100, 1100 - 98 - 4, 1100 - 162 - 4],
      "right edge formula")

# h8: min_width int / string, separator_block_width default 9 and 0, no gap after last, empty skipped
def blk(t, inst, **kw): return {"full_text": t, "instance": inst, **kw}
w1 = layout.text_width("abc", False, FONT)
p = layout.layout([blk("abc", "0:"), blk("", "1:"), blk("abc", "2:", min_width=200), blk("abc", "3:", min_width="abcdef"),
                   blk("abc", "4:", separator_block_width=0), blk("abc", "5:")], 0, 2000, 34, 0, FONT)
w6 = layout.text_width("abcdef", False, FONT)
check("h8", len(p) == 5 and p[0]["x1"] - p[0]["x0"] == w1 and p[1]["x0"] == p[0]["x1"] + 9
      and p[1]["x1"] - p[1]["x0"] == 200 and p[2]["x1"] - p[2]["x0"] == w6 and p[3]["x0"] == p[2]["x1"] + 9
      and p[4]["x0"] == p[3]["x1"] + 0 and p[4]["x1"] == 2000, f"{[(q['x0'], q['x1']) for q in p]}")

# h9: hit test
regs = [{"index": 3, "x0": 10, "x1": 20}, {"index": 4, "x0": 29, "x1": 40}]
check("h9", [layout.hit(regs, x, 50) for x in (10, 19, 20, 25, 29, 39, 40, 50, 60, 5)] ==
      [3, 3, None, None, 4, 4, None, "tray", "tray", None], "hit")

# h10: every block index of both status fixtures and both configs has an explain key that runs
for n, cfg in (("dp0", "config.toml"), ("dp2", "compact.toml")):
    keys = layout.explain_keys(f"{repo}/{cfg}")
    idx = {layout.block_index(b["instance"]) for s in fx[n]["samples"] for b in s["status"]}
    missing = sorted(i for i in idx if i not in keys)
    check("h10", not missing, f"{cfg}: blocks without explain key {missing}")
    for k in sorted(set(keys.values())):
        r = subprocess.run([f"{repo}/scripts/explain.sh", k], env={**os.environ, "EXPLAIN_DRY": "1"}, capture_output=True, timeout=10)
        check("h10", r.returncode == 0 and r.stdout, f"explain.sh {k} rc {r.returncode}")

# h11: sound (icon + percent, same index) is one region
s = next(s for s in fx["dp0"]["samples"] if s["piece"] == 11)["status"]
b = fx["dp0"]["bar"]
pc = layout.layout(s, b["x"], b["w"], b["h"], b["tray_n"], FONT)
rg = layout.regions(pc)
snd = [q for q in pc if q["index"] == 12]
check("h11", len(snd) == 2 and len(rg) == len({q["index"] for q in pc})
      and [r for r in rg if r["index"] == 12] == [{"index": 12, "x0": snd[0]["x0"], "x1": snd[1]["x1"]}], "sound region")

# h12: bar support
pcs = [{"x0": 1092}]; st = [{"short_text": "x"}]
check("h12", layout.bar_supported([{}], [{"x0": 100}], 0, None, {})[0], "no short_text on")
check("h12", not layout.bar_supported(st, [{"x0": 599}], 0, None, {})[0], "short_text near the left edge")
check("h12", layout.bar_supported(st, pcs, 0, None, {"x": 0})[0], "short_text far from the edge")
check("h12", not layout.bar_supported([{}], pcs, 0, ">", {})[0] and not layout.bar_supported([{}], pcs, 0, None, {"x": 3})[0],
      "separator_symbol / padding")

# h13: state machine
H = state.Hover
h = H(); h.over(1, 0)
check("h13", h.tick(499) == [] and h.tick(500) == [("show", 1)], "delay 500")
h = H(); h.over(1, 0); h.tick(500)
check("h13", h.over(2, 510) == [("show", 2)], "K->L instant")
h = H(); h.over(1, 0); h.tick(500); h.over(None, 600)
check("h13", h.over(2, 700) == [("show", 2)] and h.tick(900) == [], "gap 100 then L no hide")
h = H(); h.over(1, 0); h.tick(500); h.over(None, 600)
check("h13", h.tick(749) == [] and h.tick(750) == [("hide",)], "gap grace 150")
h = H(); h.over(1, 0); h.over(None, 200)
check("h13", h.tick(600) == [] and h.over(1, 700) == [] and h.tick(1199) == [] and h.tick(1200) == [("show", 1)], "gap while armed cancels")
h = H(); h.over(1, 0); h.tick(500)
check("h13", h.leave(600) == [("hide",)] and h.over(2, 800) == [("show", 2)], "leave hides, browse 300")
h = H(); h.over(1, 0); h.tick(500); h.leave(600)
check("h13", h.over(2, 901) == [] and h.deadline == 1401, "browse window over")
h = H(); h.over(1, 0); h.tick(500)
check("h13", h.leave(600, True) == [("hide",)] and h.enter(True) == [] and h.over(2, 1000) == [] and h.deadline == 1500,
      "leave inferior hides, enter inferior armed")
h = H(); h.over(1, 0); h.tick(500)
check("h13", h.over("tray", 600) == [("hide",)], "tray hides")
h = H(); h.over(1, 0); h.tick(500)
check("h13", h.click(1, 600) == [("hide",)] and h.over(1, 700) == [] and h.over(None, 800) == [] and h.over(1, 900) == []
      and h.deadline is None and h.over(2, 1000) == [] and h.deadline == 1500 and h.over(1, 1100) == [] and h.deadline == 1600,
      "click suppresses until another region")
h = H(); h.over(1, 0); h.tick(500); h.click(1, 600); h.leave(700)
check("h13", h.over(1, 800) == [] and h.deadline == 1300, "leaving the bar clears suppression")
h = H(); h.over(1, 0); h.tick(500)
check("h13", h.over(1, 600, relayout=True) == [("move", 1)] and h.over(2, 700, relayout=True) == [("show", 2)]
      and h.unmapped(800) == [("hide",)], "relayout move / unmapped")

# h14: placement
pl = lambda cx, **kw: layout.place(cx, 400, 100, 0, 2560, 1566, 34, kw.get("pos", "bottom"))
check("h14", pl(1000) == (800, 1462) and pl(50) == (4, 1462) and pl(2550) == (2560 - 4 - 400, 1462)
      and pl(1000, pos="top") == (800, 1566 + 34 + 4), f"{pl(1000)} {pl(50)} {pl(2550)}")

# h17: an X event that a timer handler's request reply moved into Xlib's queue is handled by that handler
# (the fd watch never fires for it: the first hover's Enter was lost until the next motion)
import importlib.util
sp = importlib.util.spec_from_file_location("hover_daemon", f"{repo}/scripts/hover-daemon.py")
hd = importlib.util.module_from_spec(sp); sp.loader.exec_module(hd)
class FakeX:
    def __init__(self, q): self.q = q
    def pending_events(self): return len(self.q)
    def next_event(self): return self.q.pop(0)
dm = hd.Daemon.__new__(hd.Daemon); dm.d, dm.bars, dm.tick_src, seen = FakeX(["enter"]), {}, None, []
dm.event, hd.log = seen.append, lambda *a: None
dm.tick()
check("h17", seen == ["enter"] and not dm.d.q, f"queued after tick: {dm.d.q}")

print(f"pass={pas} fail={fail}")
sys.exit(1 if fail else 0)
