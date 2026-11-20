#!/usr/bin/env python3
# status_command pass-through: hover-tee.py --output DP-0 -- i3status-rs CONF
# Forwards i3status-rs <-> i3bar unchanged (written and flushed first) and taps the latest status line
# and click to $HOVER_DIR/<output>.{status,click}.json for the hover daemon. Tap errors never affect the bar.
import os, signal, subprocess, sys, threading, time

def main():
    a = sys.argv[1:]
    if len(a) < 4 or a[0] != "--output" or a[2] != "--":
        sys.exit("usage: hover-tee.py --output OUT -- CMD...")
    out, cmd = a[1], a[3:]
    conf = cmd[-1]
    d = os.environ.get("HOVER_DIR") or os.path.join(os.environ.get("XDG_RUNTIME_DIR") or "/tmp", "custom_barista", "hover")
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
            os.makedirs(d, mode=0o700, exist_ok=True)
            p = os.path.join(d, name)
            tmp = "%s.%d.tmp" % (p, threading.get_ident())
            with open(tmp, "w") as f:
                f.write(body)
            os.replace(tmp, p)
        except Exception as e:
            off[0] = time.time() + 60
            print("hover-tee: tap disabled for 60 s: %s" % e, file=sys.stderr, flush=True)

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
        os.write(fd, line)
        if line.startswith((b"[", b",[")):
            s = line.decode(errors="replace").strip().rstrip(",")
            if s.startswith(","):
                s = s[1:]
            tap(out + ".status.json", '{"v":1,"ts":%f,"output":%s,"config":%s,"status":%s}' % (time.time(), jstr(out), jstr(conf), s))
    sys.exit(p.wait())

main()
