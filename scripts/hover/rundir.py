# Tap/daemon dir shared by hover-tee.py and hover-daemon.py (hover-run.sh has the same rule in shell):
# $HOVER_DIR, else $XDG_RUNTIME_DIR/custom_barista/hover, else a private /tmp/custom_barista-$UID/hover
# (0700; refused if it is not our own directory, so another user cannot pre-create it and feed tap files).
import os, stat

def hover_dir():
    if os.environ.get("HOVER_DIR"):
        return os.environ["HOVER_DIR"]
    if os.environ.get("XDG_RUNTIME_DIR"):
        return os.path.join(os.environ["XDG_RUNTIME_DIR"], "custom_barista", "hover")
    base = "/tmp/custom_barista-%d" % os.getuid()
    try:
        os.mkdir(base, 0o700)
    except FileExistsError:
        pass
    st = os.lstat(base)
    if not stat.S_ISDIR(st.st_mode) or st.st_uid != os.getuid() or st.st_mode & 0o077:
        raise PermissionError("%s is not a private directory of uid %d" % (base, os.getuid()))
    return os.path.join(base, "hover")
