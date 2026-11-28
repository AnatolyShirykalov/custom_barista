#!/usr/bin/env python3
# T1 hover daemon (spec 2.3, 3.2): Enter/Leave/Motion on the i3bar windows, the latest status line from
# hover-tee.py's tap files, layout/state from scripts/hover/, a GTK popup with the explain.sh text above the
# hovered block. Separate from the bar: a crash or hang here never touches i3bar (hover-run.sh restarts us).
# Usage: hover-daemon.py [--selftest]   (selftest: imports, both configs' key maps, no display needed)
import json, os, signal, subprocess, sys, time, tomllib
here = os.path.dirname(os.path.abspath(__file__)); repo = os.path.dirname(here)
sys.path.insert(0, os.path.join(here, "hover"))
import layout, rundir, state
from Xlib import X, display, error
import gi
gi.require_version("Gtk", "3.0"); gi.require_version("Gdk", "3.0")
from gi.repository import Gtk, Gdk, GLib
import cairo

DIR = rundir.hover_dir()
EXPLAIN = os.path.join(here, "explain.sh")
REDISCOVER_DEBOUNCE, REDISCOVER_EVERY, TICK, MOTION_STAT = 500, 10000, 250, 50  # ms
DEBUG = os.environ.get("HOVER_DEBUG")  # 1: log every popup action
CHECK_PX = 2  # self-check tolerance vs i3bar's click-reported edges
EVENTS = X.EnterWindowMask | X.LeaveWindowMask | X.PointerMotionMask | X.StructureNotifyMask | X.SubstructureNotifyMask

def log(*a):
    print(time.strftime("%F %T"), *a, file=sys.stderr, flush=True)

def ms():
    return time.monotonic() * 1000

def i3(*args):
    return json.loads(subprocess.run(["i3-msg", *args], capture_output=True, text=True, timeout=2).stdout)

def theme(path):
    with open(path, "rb") as f:
        o = tomllib.load(f).get("theme", {}).get("overrides", {})
    return o.get("idle_fg", "#ffffff"), o.get("info_fg", "#777777")

def selftest():
    for c in ("config.toml", "compact.toml"):
        print(c, " ".join(f"{i}:{k}" for i, k in sorted(layout.explain_keys(os.path.join(repo, c)).items())))
    print("theme", *theme(os.path.join(repo, "config.toml")))
    return 0

class Bar:
    def __init__(self, win, out, conf):
        self.win, self.out = win, out
        self.font = conf.get("font", "monospace 8").removeprefix("pango:")  # no font in the bar config: a plain default
        self.sep, self.padding, self.position = conf.get("separator_symbol"), conf.get("padding", {}), conf.get("position", "bottom")
        self.hv = state.Hover()
        self.mtime = self.stat_at = 0
        self.status = self.config = None
        self.regs, self.pieces, self.right, self.ok, self.supported = [], [], 0, False, None
        c = self._click(); self.click_ts = c[0] if c else 0  # old clicks are not news
        self.bad = 0      # consecutive failed click checks
        self.tray_n = 0
        self.geom()

    def geom(self):
        g, tree = self.win.get_geometry(), self.win.query_tree()
        t = tree.root.translate_coords(self.win, 0, 0)
        self.x, self.y, self.w, self.h = t.x, t.y, g.width, g.height
        self.tray_n = sum(1 for c in tree.children if c.get_attributes().map_state == X.IsViewable)

    def _click(self):
        try:
            with open(os.path.join(DIR, f"{self.out}.click.json")) as f:
                c = json.load(f)
            return c["ts"], c["click"]
        except (OSError, ValueError, KeyError):
            return None

    def refresh(self, force=False):
        """Re-read the status file if its mtime changed (or force: geometry/tray changed). True if the layout changed."""
        try:
            mt = os.stat(os.path.join(DIR, f"{self.out}.status.json")).st_mtime
        except OSError:
            mt = 0
        if mt == self.mtime and not force:
            return False
        if mt != self.mtime:
            self.mtime = mt
            try:
                with open(os.path.join(DIR, f"{self.out}.status.json")) as f:
                    s = json.load(f)
                self.status, self.config = s["status"], s["config"]
            except (OSError, ValueError, KeyError):
                self.status = None
        old = (self.regs, self.ok)
        if self.status is None:
            self.regs, self.pieces, ok, why = [], [], False, "no valid status file"
        else:
            self.right = layout.statusline_right(self.x, self.w, self.h, self.tray_n)
            self.pieces = layout.layout(self.status, self.x, self.w, self.h, self.tray_n, self.font, DPI)
            self.regs = layout.regions(self.pieces)
            ok, why = layout.bar_supported(self.status, self.pieces, self.x, self.sep, self.padding)
        if ok != self.supported:
            self.supported = ok; log(f"{self.out}: hover {'on' if ok else 'off: ' + why}")
        self.ok = ok and self.bad < 2
        return (self.regs, self.ok) != old

    def hit(self, x):
        return layout.hit(self.regs, x, self.right) if self.ok else None

    def check_click(self):
        """New click file: (index, x) of the click, after comparing its piece with our layout (self-check)."""
        c = self._click()
        if not c or c[0] == self.click_ts:
            return None
        self.click_ts, c = c
        p = next((p for p in self.pieces if p["instance"] == c.get("instance")), None)
        if p is not None and "relative_x" in c:
            d0, dw = p["x0"] - (c["x"] - c["relative_x"]), (p["x1"] - p["x0"]) - c["width"]
            if abs(d0) > CHECK_PX or abs(dw) > CHECK_PX:
                self.bad += 1
                log(f"{self.out}: click check {c.get('instance')} dx0={d0} dw={dw} ({self.bad})")
                if self.bad == 2:
                    log(f"{self.out}: hover off until a click check passes"); self.ok = False
            else:
                if d0 or dw:
                    log(f"{self.out}: click check {c.get('instance')} dx0={d0} dw={dw}")
                if self.bad >= 2:
                    log(f"{self.out}: hover back on")
                self.bad = 0; self.refresh(force=True)
        return layout.block_index(c.get("instance"))

class Popup:
    def __init__(self, fg, border):
        self.win = Gtk.Window(type=Gtk.WindowType.POPUP)
        self.win.set_keep_above(True); self.win.set_accept_focus(False)
        self.label = Gtk.Label(xalign=0); self.label.set_line_wrap(False)
        self.win.add(self.label); self.label.show()   # a hidden child makes the preferred size the 200x200 default
        css = Gtk.CssProvider()
        css.load_from_data((f'window {{ background-color: #1d1d1d; border: 1px solid {border}; }}'
                            f'label {{ color: {fg}; font-family: "PragmataPro Mono"; font-size: 16pt; padding: 10px; }}').encode())
        Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
        self.shown = None  # (bar, index)

    def show(self, text, bar, k, mon):
        self.label.set_text(text)
        self.shown = (bar, k)
        self.place(mon)
        self.win.show_all()
        self.win.get_window().input_shape_combine_region(cairo.Region(), 0, 0)  # click-through (the widget-level call does not stick)

    def place(self, mon):
        bar, k = self.shown
        r = next((r for r in bar.regs if r["index"] == k), None)
        if r is None:
            return self.hide()
        n = self.win.get_preferred_size()[1]
        x, y = layout.place((r["x0"] + r["x1"]) // 2, n.width, n.height, mon[0], mon[1], bar.y, bar.h, bar.position)
        self.win.resize(n.width, n.height); self.win.move(x, y)   # one configure: never overlaps the bar

    def hide(self):
        self.shown = None
        self.win.hide()

class Daemon:
    def __init__(self):
        self.d = display.Display()
        self.root = self.d.screen().root
        self.root.change_attributes(event_mask=X.SubstructureNotifyMask)
        self.d.set_error_handler(self.xerror)
        self.bars = {}          # window id -> Bar
        self.texts, self.texts_mt = {}, 0
        self.popup = Popup(*theme(os.path.join(repo, "config.toml")))
        self.mons = {}
        self.redisc_src = self.tick_src = None
        self.rediscover()
        GLib.io_add_watch(self.d.fileno(), GLib.PRIORITY_DEFAULT, GLib.IO_IN | GLib.IO_HUP | GLib.IO_ERR, self.on_x)
        GLib.timeout_add(REDISCOVER_EVERY, self.guard, self.rediscover, True)
        try:
            gi.require_version("GLibUnix", "2.0"); from gi.repository import GLibUnix
            sigadd = GLibUnix.signal_add
        except (ValueError, ImportError):
            sigadd = GLib.unix_signal_add
        for s in (signal.SIGTERM, signal.SIGINT):
            sigadd(GLib.PRIORITY_DEFAULT, s, self.quit)

    def quit(self, *_):
        Gtk.main_quit(); return False

    def guard(self, f, *a):
        """Run a handler; an exception is logged and dropped (the event is lost, the daemon lives)."""
        try:
            r = f(*a[:-1]) if a else f()
        except (error.ConnectionClosedError, BrokenPipeError):
            log("X connection closed"); Gtk.main_quit(); return False
        except error.XError as e:     # mostly a bar window destroyed under us (i3 reload): find the bars again
            log(f"{getattr(f, '__name__', f)}: {type(e).__name__}"); self.later_rediscover()
            r = None
        except Exception as e:
            log(f"{getattr(f, '__name__', f)}: {type(e).__name__}: {e}")
            r = None
        return a[-1] if a else r

    def xerror(self, err, req):
        log(f"X error {type(err).__name__}"); self.later_rediscover()

    # --- bars -------------------------------------------------------------------------------------------
    def rediscover(self):
        self.redisc_src = None
        found = {}
        for f in self.root.query_tree().children:          # i3 frames; i3bar windows are their children
            try:
                kids = f.query_tree().children
            except error.XError:
                continue
            for c in kids:
                try:
                    cls = c.get_wm_class()
                    if cls and cls[1] == "i3bar" and c.get_attributes().map_state == X.IsViewable:
                        found[c.id] = c
                except error.XError:
                    pass
        for wid in list(self.bars):
            if wid not in found:
                b = self.bars.pop(wid); log(f"{b.out}: bar gone"); self.apply(b, b.hv.unmapped(ms()))
        if any(wid not in self.bars for wid in found):
            confs = {}
            for bid in i3("-t", "get_bar_config"):
                c = i3("-t", "get_bar_config", bid)
                for o in c.get("outputs") or []:
                    confs[o] = c
            self.mons = {o["name"]: (o["rect"]["x"], o["rect"]["width"]) for o in i3("-t", "get_outputs") if o.get("active")}
            for wid, w in found.items():
                if wid in self.bars:
                    continue
                out = (w.get_wm_name() or "").removeprefix("i3bar for output ")
                if out not in confs:
                    log(f"no bar config for output {out!r}"); continue
                w.change_attributes(event_mask=EVENTS)
                b = self.bars[wid] = Bar(w, out, confs[out]); b.refresh()
                log(f"{out}: bar {hex(wid)} at {b.x},{b.y} {b.w}x{b.h} tray {b.tray_n}")
                x = self.pointer_x(b)   # mapped under a resting pointer: its Enter came before our event mask
                if x is not None:
                    self.apply(b, b.hv.over(b.hit(x), ms()))
        else:
            for b in self.bars.values():   # periodic: geometry or tray may have moved without an event we saw
                g = (b.x, b.y, b.w, b.h, b.tray_n); b.geom()
                if g != (b.x, b.y, b.w, b.h, b.tray_n):
                    self.relayout(b, force=True)
        self.d.flush()
        self.drain("rediscover")
        self.schedule()
        return True

    def later_rediscover(self):
        if self.redisc_src is None:
            self.redisc_src = GLib.timeout_add(REDISCOVER_DEBOUNCE, self.guard, self.rediscover, False)

    # --- events -----------------------------------------------------------------------------------------
    def on_x(self, fd, cond):
        if cond & (GLib.IO_HUP | GLib.IO_ERR):
            log("X connection lost"); Gtk.main_quit(); return False
        if self.drain() is None:
            return False
        self.guard(self.schedule, None)
        return True

    def drain(self, where=None):
        """Handle every queued X event. Any reply read (query_pointer, get_geometry, ...) also moves events that
        arrived meanwhile into Xlib's queue, where the fd watch never sees them: timer handlers drain too.
        Number of events handled, None if the connection is gone; `where` (a timer) logs a non-empty drain."""
        n = 0
        try:
            while self.d.pending_events():
                e = self.d.next_event(); n += 1
                self.guard(self.event, e, None)
        except (error.ConnectionClosedError, BrokenPipeError):
            log("X connection closed"); Gtk.main_quit(); return None
        if n and where:
            log(f"{where}: {n} queued X events handled")
        return n

    def event(self, e):
        now = ms()
        if e.type in (X.EnterNotify, X.LeaveNotify, X.MotionNotify):
            b = self.bars.get(e.window.id)
        else:   # structure events: the window they were selected on is `event` (`parent` for CreateNotify)
            on = e.parent if e.type == X.CreateNotify else getattr(e, "event", None)
            if on == self.root:   # a new or remapped i3 frame may hold a bar; our own popup is override-redirect
                if e.type in (X.CreateNotify, X.MapNotify, X.ReparentNotify) and not getattr(e, "override", False):
                    self.later_rediscover()
                return
            b = self.bars.get(on.id) if on is not None else None
        if b is None:
            return
        if e.type == X.EnterNotify:
            b.refresh(); b.hv.enter(e.detail == X.NotifyInferior)
            self.click(b, now)
            self.apply(b, b.hv.over(b.hit(e.root_x), now))
        elif e.type == X.MotionNotify:
            if now - b.stat_at >= MOTION_STAT:
                b.stat_at = now; b.refresh(); self.click(b, now)
            self.apply(b, b.hv.over(b.hit(e.root_x), now))
        elif e.type == X.LeaveNotify:
            if DEBUG:
                log(f"{b.out}: leave detail {e.detail} mode {e.mode} x {e.root_x}")
            self.apply(b, b.hv.leave(now, e.detail == X.NotifyInferior))
        elif e.type in (X.UnmapNotify, X.DestroyNotify) and e.event == e.window:   # bar itself (Win+i off)
            self.apply(b, b.hv.unmapped(now)); self.later_rediscover()
        elif e.type in (X.MapNotify, X.UnmapNotify, X.DestroyNotify, X.ConfigureNotify):  # tray icon or bar geometry
            n = b.tray_n; b.geom(); self.relayout(b, force=True)
            if b.tray_n != n:
                log(f"{b.out}: tray {b.tray_n}")

    def click(self, b, now):
        k = b.check_click()
        if k is not None:
            self.apply(b, b.hv.click(k, now))

    def relayout(self, b, force=False):
        if b.refresh(force) and b.hv.shown is not None:
            x = self.pointer_x(b)
            self.apply(b, b.hv.over(b.hit(x), ms(), relayout=True) if x is not None else b.hv.leave(ms()))

    def pointer_x(self, b):
        p = b.win.query_pointer()
        return p.root_x if p.same_screen and b.x <= p.root_x < b.x + b.w and b.y <= p.root_y < b.y + b.h else None

    def tick(self):
        self.tick_src = None
        now = ms()
        for b in list(self.bars.values()):
            if b.hv.shown is not None or b.hv.armed is not None:
                self.relayout(b); self.click(b, now)
            self.apply(b, b.hv.tick(now))
        self.drain("tick" if DEBUG else None)   # common (a Leave read by relayout's query_pointer)
        self.schedule()
        return False

    def schedule(self):
        """One timer: the nearest state deadline, else the 250 ms tick while a bar is armed/shown, else none."""
        now, nxt = ms(), None
        for b in self.bars.values():
            if b.hv.deadline is not None:
                nxt = min(nxt or b.hv.deadline, b.hv.deadline)
            if b.hv.shown is not None or b.hv.armed is not None:
                nxt = min(nxt or now + TICK, now + TICK)
        if self.tick_src is not None:
            GLib.source_remove(self.tick_src); self.tick_src = None
        if nxt is not None:
            self.tick_src = GLib.timeout_add(max(1, int(nxt - now) + 1), self.guard, self.tick, False)

    # --- popup ------------------------------------------------------------------------------------------
    def text(self, key):
        mt = os.stat(EXPLAIN).st_mtime
        if mt != self.texts_mt:
            self.texts, self.texts_mt = {}, mt
        if key not in self.texts or key.startswith("ddc-"):  # ddc text has live values (state file, ~10 ms)
            r = subprocess.run([EXPLAIN, key], capture_output=True, text=True, timeout=2, env={**os.environ, "EXPLAIN_DRY": "1"})
            self.texts[key] = "\n".join(r.stdout.rstrip("\n").split("\n")[:6]) if r.returncode == 0 else None
        return self.texts[key]

    def apply(self, b, acts):
        for a in acts:
            if DEBUG:
                log(f"{b.out}: {a}")
            if a[0] == "hide":
                if self.popup.shown and self.popup.shown[0] is b:
                    self.popup.hide()
            elif a[0] == "move" and self.popup.shown == (b, a[1]):
                self.popup.place(self.mons.get(b.out, (b.x, b.w)))
            else:   # show (a move of a region whose popup is not up acts as a show)
                key = explain_key(b, a[1])
                t = self.text(key) if key else None
                if t:
                    self.popup.show(t, b, a[1], self.mons.get(b.out, (b.x, b.w)))
                elif self.popup.shown:
                    self.popup.hide()

_keys = {}
def explain_key(b, k):
    """explain.sh key of block k in the config the bar's status file names (cached per config mtime)."""
    if not b.config:
        return None
    mt = os.stat(b.config).st_mtime
    if _keys.get(b.config, (None,))[0] != mt:
        _keys[b.config] = (mt, layout.explain_keys(b.config))
    return _keys[b.config][1].get(k)

def xrdb_dpi():
    try:
        out = subprocess.run(["xrdb", "-query"], capture_output=True, text=True, timeout=2).stdout
        return next(float(l.split(":", 1)[1]) for l in out.splitlines() if l.startswith("Xft.dpi:"))
    except Exception:
        return 96

if __name__ == "__main__":
    if sys.argv[1:] == ["--selftest"]:
        sys.exit(selftest())
    try:
        DPI = xrdb_dpi()
        Daemon()
    except (error.DisplayError, error.ConnectionClosedError) as e:
        log(f"no X: {e}"); sys.exit(0)
    log(f"started pid {os.getpid()} dpi {DPI}")
    Gtk.main()
    log("stopped"); sys.exit(0)
