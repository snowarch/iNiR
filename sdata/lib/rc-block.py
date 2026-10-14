#!/usr/bin/env python3
"""Owns iNiR's marked blocks in shell profiles (~/.bashrc, ~/.profile, ...).

  rc-block.py set NAME FILE   write block NAME with the body read from stdin
  rc-block.py remove FILE     drop every iNiR block; delete FILE if nothing else is left
  rc-block.py prune FILE      delete FILE only if it holds nothing but iNiR blocks

NAME is `path` or `env`. A block is its start marker, the body and its end
marker, preceded by one blank line. Writing the same block again leaves the
file byte-identical, and blank lines left by older installers are trimmed.
"""

import os
import re
import sys

BLOCKS = {
    "path": ("# iNiR launcher PATH", "# end iNiR launcher PATH"),
    "env": ("# iNiR environment", "# end iNiR"),
}


def strip_blocks(text, names=BLOCKS):
    for start, end in (BLOCKS[n] for n in names):
        pattern = (rf"(?ms)(?:^[ \t]*\n)*^[ \t]*{re.escape(start)}[ \t]*\n"
                   rf".*?^[ \t]*{re.escape(end)}[ \t]*(?:\n|\Z)")
        text = re.sub(pattern, "", text)
    return text


def read(path):
    try:
        with open(path, encoding="utf-8") as f:
            return f.read()
    except FileNotFoundError:
        return None


def write(path, text, old):
    if text == old:
        return
    tmp = f"{path}.inir.{os.getpid()}"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(text)
    if old is not None:
        os.chmod(tmp, os.stat(path).st_mode & 0o7777)
    os.replace(tmp, path)


def cmd_set(name, path):
    start, end = BLOCKS[name]
    body = sys.stdin.read().strip("\n")
    old = read(path)
    rest = strip_blocks(old or "", [name]).rstrip()
    block = f"{start}\n{body}\n{end}\n"
    write(path, f"{rest}\n\n{block}" if rest else block, old)


def cmd_remove(path):
    old = read(path)
    if old is None:
        return
    rest = strip_blocks(old)
    if rest == old:
        return
    if not rest.strip():
        os.remove(path)
        return
    write(path, rest.rstrip() + "\n", old)


def cmd_prune(path):
    old = read(path)
    if old is not None and old.strip() and not strip_blocks(old).strip():
        os.remove(path)


def main(argv):
    if len(argv) == 3 and argv[0] == "set" and argv[1] in BLOCKS:
        cmd_set(argv[1], argv[2])
    elif len(argv) == 2 and argv[0] == "remove":
        cmd_remove(argv[1])
    elif len(argv) == 2 and argv[0] == "prune":
        cmd_prune(argv[1])
    else:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
