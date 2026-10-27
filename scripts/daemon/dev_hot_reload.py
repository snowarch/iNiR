#!/usr/bin/env python3
"""Hot reload for the QML Quickshell's own watcher never sees or misses (development checkouts only).

Quickshell watches only the files its scanner reaches through `import qs.…` lines from shell.qml
(quickshell 0.3.1, src/core/scan.cpp). Everything loaded by `source:` path (each family's panels,
Background, the dock, sidebars, OSDs: 104 of 181 QML directories on 2026-10-01) was never watched,
so edits there did not reload and tests ran stale code. Making the scanner reach them costs ~1.2 s on
every cold start; this watcher costs nothing at start. On a real content change to one of those files
it asks the shell for the same soft reload (`dev reload` → Quickshell.reload(false)).

A file Quickshell does watch can still be missed: a save that replaces the file (rename over it)
reloads only when Quickshell sees the file's removal before the directory's change
(src/core/generation.cpp, onFileChanged / onDirectoryChanged), and the order varies. For those files
this watcher waits, reads the shell's log, and reloads only if Quickshell did not: one reload per
change, never two (two back to back crash Quickshell 0.3.1).

usage: dev_hot_reload.py <shell root> <shell pid>     exits with the shell
"""
import ctypes
import ctypes.util
import hashlib
import os
import re
import select
import struct
import subprocess
import sys
import time

ROOT = os.path.abspath(sys.argv[1])
SHELL_PID = int(sys.argv[2])
WATCHED_TREES = ("modules", "services")
SKIP = re.compile(r"/(\.git|node_modules|prebuilt|native)(/|$)")
DEBOUNCE = 0.35

IN_CLOSE_WRITE, IN_MOVED_TO, IN_CREATE, IN_ISDIR = 0x08, 0x80, 0x100, 0x40000000
libc = ctypes.CDLL(ctypes.util.find_library("c"), use_errno=True)


def scanner_reach() -> set:
    """Files Quickshell's scanner reaches, by its own rules: every capitalised .qml in a directory
    it scans, and the directories named by `import qs.…` (or quoted) lines before the first `{`."""
    files, dirs = set(), set()

    def scan_file(path):
        if path in files:
            return
        files.add(path)
        imports = []
        try:
            for line in open(path, errors="replace"):
                line = line.strip()
                if line.startswith("import"):
                    at = line.find(" qs.")
                    if at != -1:
                        name = re.match(r"[\w.]+", line[at + 4:])
                        if name:
                            imports.append(os.path.join(ROOT, name.group(0).replace(".", "/")))
                    elif (quoted := re.search(r'"([^"]+)"', line)):
                        ref = quoted.group(1)
                        imports.append(os.path.join(ROOT, ref[5:].lstrip("/")) if ref.startswith("root:")
                                       else os.path.join(os.path.dirname(path), ref))
                elif "{" in line:
                    break
        except OSError:
            return
        scan_dir(os.path.dirname(path))
        for target in imports:
            if os.path.isdir(target):
                scan_dir(os.path.abspath(target))

    def scan_dir(directory):
        if directory in dirs:
            return
        dirs.add(directory)
        for name in sorted(os.listdir(directory)):
            full = os.path.join(directory, name)
            if name[:1].isupper() and name.endswith(".qml") and os.path.isfile(full):
                scan_file(full)

    scan_file(os.path.join(ROOT, "shell.qml"))
    return files | {os.path.join(d, f) for d in dirs for f in os.listdir(d) if f.endswith(".js")}


RELOAD_LINE = re.compile(r"^(\d{4}-\d\d-\d\d \d\d:\d\d:\d\d)(\.\d+)\s+INFO:\s+Reloading configuration")
QS_GRACE = 1.2  # Quickshell's own reload starts ~0.1 s after a save it sees
# Old engines leave leftovers in the process: a nest past ~20 reloads drew stale frames and spent 40 % more per
# Settings turn (10-25), and his shell took 28-40 between restarts. Past this, the next change restarts instead.
RELOAD_LIMIT = 15


def reloaded_since(since: float) -> bool:
    """Whether the shell's log shows a reload starting at or after `since` (wall clock)."""
    log = f"/run/user/{os.getuid()}/quickshell/by-pid/{SHELL_PID}/log.log"
    try:
        with open(log, errors="replace") as handle:
            lines = handle.readlines()[-400:]
    except OSError:
        return False
    for line in reversed(lines):
        m = RELOAD_LINE.match(line)
        if m:
            return time.mktime(time.strptime(m.group(1), "%Y-%m-%d %H:%M:%S")) + float(m.group(2)) >= since - 0.05
    return False


def worn() -> bool:
    """This shell took RELOAD_LIMIT reloads and is the inir service itself (a nest's shell never restarts it)."""
    log = f"/run/user/{os.getuid()}/quickshell/by-pid/{SHELL_PID}/log.log"
    try:
        with open(log, errors="replace") as handle:
            if sum(1 for line in handle if RELOAD_LINE.match(line)) < RELOAD_LIMIT:
                return False
        main = subprocess.run(["systemctl", "--user", "show", "inir", "-p", "MainPID", "--value"],
                              capture_output=True, text=True, timeout=5).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return False
    return main == str(SHELL_PID)


def restart_shell():
    subprocess.run(["systemctl", "--user", "--no-block", "restart", "inir"],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10)


def reload_shell():
    subprocess.run(["qs", "-p", ROOT, "ipc", "call", "dev", "reload"],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10)
    time.sleep(2.5)  # the reload itself; a fresh scan picks up new imports


def digest(path):
    try:
        with open(path, "rb") as handle:
            return hashlib.md5(handle.read()).hexdigest()
    except OSError:
        return None


def main():
    fd = libc.inotify_init1(os.O_NONBLOCK | os.O_CLOEXEC)
    if fd < 0:
        sys.exit("inotify unavailable")
    wd_dirs = {}

    def add_tree(top):
        # the families are linked into modules/ from inir-hub
        for current, subdirs, _ in os.walk(top, followlinks=True):
            subdirs[:] = [d for d in subdirs if not SKIP.search(os.path.join(current, d))]
            wd = libc.inotify_add_watch(fd, current.encode(), IN_CLOSE_WRITE | IN_MOVED_TO | IN_CREATE)
            if wd >= 0:
                wd_dirs[wd] = current

    for tree in WATCHED_TREES:
        add_tree(os.path.join(ROOT, tree))

    reach = scanner_reach()
    hashes = {p: digest(p) for p in reach}
    try:
        shell = os.pidfd_open(SHELL_PID)  # readable once the shell exits
    except (AttributeError, OSError):
        shell = None
    pending_since = 0.0
    watched_since = 0.0  # wall clock of the first change to a file Quickshell watches itself
    while True:
        # Sleep until a file changes, the shell exits or a pending reload falls due: no wakeups while idle.
        if pending_since:
            timeout = max(0.0, DEBOUNCE - (time.monotonic() - pending_since))
        elif watched_since:
            timeout = max(0.0, QS_GRACE - (time.time() - watched_since))
        else:
            timeout = None if shell is not None else 5.0
        ready, _, _ = select.select([fd] if shell is None else [fd, shell], [], [], timeout)
        if shell is not None and shell in ready:
            return
        if shell is None:
            try:
                os.kill(SHELL_PID, 0)
            except ProcessLookupError:
                return
        try:
            data = os.read(fd, 65536) if fd in ready else b""
        except BlockingIOError:
            data = b""
        offset = 0
        while offset < len(data):
            wd, mask, _cookie, length = struct.unpack_from("iIII", data, offset)
            name = data[offset + 16: offset + 16 + length].rstrip(b"\0").decode(errors="replace")
            offset += 16 + length
            path = os.path.join(wd_dirs.get(wd, ""), name)
            if mask & IN_ISDIR:
                if mask & IN_CREATE:
                    add_tree(path)
                continue
            if not (name.endswith(".qml") or name.endswith(".js") or name == "qmldir"):
                continue
            new = digest(path)
            if new is None or os.path.getsize(path) == 0:
                continue  # a truncate before the write (editors save in two steps)
            if hashes.get(path) == new:
                continue  # rewritten with the same bytes
            hashes[path] = new
            if path in reach:
                watched_since = watched_since or time.time()  # Quickshell should reload it; checked below
            else:
                pending_since = time.monotonic()
        due = pending_since and time.monotonic() - pending_since >= DEBOUNCE
        if (due or watched_since and time.time() - watched_since >= QS_GRACE) and worn():
            restart_shell()
            return
        if due:
            pending_since = watched_since = 0.0
            reload_shell()
            reach = scanner_reach()
        elif watched_since and time.time() - watched_since >= QS_GRACE:
            if not reloaded_since(watched_since):
                reload_shell()
            else:
                time.sleep(2.5)  # Quickshell's reload; a fresh scan picks up new imports
            watched_since = 0.0
            reach = scanner_reach()


if __name__ == "__main__":
    main()
