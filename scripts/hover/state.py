#!/usr/bin/env python3
# T1 hover core, pure state machine (spec 3.1): events in, actions out, injected clock (ms).
# Events take the pointer's hit: a block index, None (gap / workspace buttons) or "tray".
# Actions: ("show", K), ("move", K), ("hide",). `deadline` is the next time tick() must run (or None).
DELAY, GRACE, BROWSE = 500, 150, 300

class Hover:
    def __init__(self):
        self.armed = None      # region waiting for the delay
        self.shown = None      # region whose popup is up
        self.deadline = None   # delay timer (armed) or grace timer (shown, pointer in a gap)
        self.browse_until = 0  # a region entered before this shows at once
        self.suppressed = None # clicked region: no popup until the pointer is elsewhere

    def _hide(self, now, browse):
        acts = [("hide",)] if self.shown is not None else []
        self.armed = self.shown = self.deadline = None
        if browse and acts:
            self.browse_until = now + BROWSE
        return acts

    def over(self, k, now, relayout=False):
        """Pointer (or, with relayout, the layout under it) now on region k, a gap (None) or "tray"."""
        if k is None or k == "tray":
            if self.shown is not None:
                if k == "tray":
                    return self._hide(now, True)
                if self.deadline is None:
                    self.deadline = now + GRACE
                return []
            self.armed = self.deadline = None
            if k == "tray":
                self.suppressed = None
            return []
        if k == self.suppressed:
            return []
        self.suppressed = None
        if self.shown is not None:
            self.deadline = None
            if k == self.shown:
                return [("move", k)] if relayout else []
            self.shown = k
            return [("show", k)]
        if now < self.browse_until:
            self.armed = self.deadline = None
            self.shown = k
            return [("show", k)]
        if self.armed != k:
            self.armed, self.deadline = k, now + DELAY
        return []

    def enter(self, inferior):
        """Pointer enters the bar window; the caller follows with over() for the hit under it."""
        return []

    def leave(self, now, inferior=False):
        """Pointer leaves the bar window; Inferior = onto a tray icon (child window)."""
        if not inferior:
            self.suppressed = None
        return self._hide(now, True) if self.shown is not None else self._reset()

    def _reset(self):
        self.armed = self.deadline = None
        return []

    def unmapped(self, now):
        self.suppressed = None
        return self._hide(now, True) if self.shown is not None else self._reset()

    def click(self, k, now):
        """Click on region k (new click file): hide, stay quiet until the pointer is elsewhere."""
        self.suppressed = k
        return self._hide(now, False) if self.shown is not None else self._reset()

    def tick(self, now):
        if self.deadline is None or now < self.deadline:
            return []
        self.deadline = None
        if self.shown is not None:       # grace over, pointer still in a gap
            return self._hide(now, False)
        k, self.armed = self.armed, None
        self.shown = k
        return [("show", k)]
