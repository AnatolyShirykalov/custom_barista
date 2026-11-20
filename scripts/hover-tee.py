#!/usr/bin/env python3
# status_command pass-through: hover-tee.py --output DP-0 -- i3status-rs CONF
# Forwards i3status-rs <-> i3bar unchanged (written and flushed first) and taps the latest status line
# and click to $HOVER_DIR/<output>.{status,click}.json for the hover daemon (removed at start: an earlier
# session's files are never read as ours). Tap errors never affect the bar.
import os, signal, subprocess, sys, threading, time
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "hover"))
import rundir

def main():
    a = sys.argv[1:]
    if len(a) < 4 or a[0] != "--output" or a[2] != "--":
        sys.exit("usage: hover-tee.py --output OUT -- CMD...")
    out, cmd = a[1], a[3:]
    conf = cmd[-1]
    d = [None]
    off = [0.0]  # tapping paused until this time

    def pdeath():
        try:
            import ctypes
            ctypes.CDLL(None).prctl(1, 15)
        except Exception:
            pass

    def jstr(s):  # JSON string literal without parsing the payload
        return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'

    def tap(name, body):
        if time.time() < off[0]:
            return
        try:
            if d[0] is None:
                d[0] = rundir.hover_dir()
            os.makedirs(d[0], mode=0o700, exist_ok=True)
            p = os.path.join(d[0], name)
            tmp = "%s.%d.tmp" % (p, threading.get_ident())
            with open(tmp, "w") as f:
                f.write(body)
            os.replace(tmp, p)
        except Exception as e:
            off[0] = time.time() + 60
            print("hover-tee: tap disabled for 60 s: %s" % e, file=sys.stderr, flush=True)

    try:
        d[0] = rundir.hover_dir()
        for n in ("status", "click"):
            try:
                os.unlink(os.path.join(d[0], "%s.%s.json" % (out, n)))
            except FileNotFoundError:
                pass
    except Exception as e:
        print("hover-tee: %s" % e, file=sys.stderr, flush=True)
    p = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, bufsize=0, preexec_fn=pdeath)

    def pump_in():
        try:
            for line in sys.stdin.buffer:
                try:
                    p.stdin.write(line)
                    p.stdin.flush()
                except Exception:
                    break
                s = line.decode(errors="replace").strip()
                if s and s != "[":
                    tap(out + ".click.json", '{"v":1,"ts":%f,"click":%s}' % (time.time(), s.lstrip(",")))
        finally:
            try:
                p.stdin.close()
            except Exception:
                pass

    def fwd(sig, _):
        try:
            p.send_signal(sig)
        except Exception:
            pass

    signal.signal(signal.SIGTERM, fwd)
    signal.signal(signal.SIGINT, fwd)
    threading.Thread(target=pump_in, daemon=True).start()
    fd = sys.stdout.fileno()
    for line in iter(p.stdout.readline, b""):
        mv = memoryview(line)
        while mv:  # a signal (i3bar's SIGSTOP) can cut a blocking pipe write short: write the rest
            mv = mv[os.write(fd, mv):]
        s = line.decode(errors="replace").strip().rstrip(",").removeprefix(",")
        if len(s) > 1 and s[0] == "[" and s[-1] == "]":  # a status line (not the protocol's opening "[")
            tap(out + ".status.json", '{"v":1,"ts":%f,"output":%s,"config":%s,"status":%s}' % (time.time(), jstr(out), jstr(conf), s))
    sys.exit(p.wait())

main()
