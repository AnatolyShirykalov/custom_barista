#!/usr/bin/env python3
# T1 spike (throwaway, not installed): status_command wrapper that runs i3status-rs and logs
# its JSON output and i3bar's click events. Usage: tee-wrap.py LOGPREFIX i3status-rs CONFIG
import json, subprocess, sys, threading, time

pre, cmd = sys.argv[1], sys.argv[2:]
p = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, bufsize=0)
last = {"line": ""}
lock = threading.Lock()

def pump_in():
    with open(pre + ".in", "a") as log:
        for line in sys.stdin.buffer:
            with lock:
                log.write(json.dumps({"t": time.time(), "click": line.decode(errors="replace"),
                                      "status": last["line"]}) + "\n")
                log.flush()
            p.stdin.write(line); p.stdin.flush()
    p.stdin.close()

threading.Thread(target=pump_in, daemon=True).start()
with open(pre + ".out", "w") as log:
    for line in p.stdout:
        sys.stdout.buffer.write(line); sys.stdout.flush()
        s = line.decode(errors="replace")
        if s.lstrip(",").startswith("["):
            with lock:
                last["line"] = s
            log.seek(0); log.truncate(); log.write(s); log.flush()  # keep only the latest line
sys.exit(p.wait())
