#!/usr/bin/env python3
"""App theming must not stop at its own fingerprint.

applycolor.sh runs under `set -euo pipefail` and fingerprints its inputs before applying anything. A
`[[ -e path ]] && stat …` as the last command of that block made the whole block fail whenever the path was
missing: on a machine without Steam the script exited there, silently, and no app was ever themed. This runs
the function the script really contains in an empty HOME, and again with a browser profile in it.
"""

import os
import pathlib
import re
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
COLORS = ROOT / "scripts" / "colors"


def fingerprint(home: pathlib.Path) -> subprocess.CompletedProcess:
    source = (COLORS / "applycolor.sh").read_text(encoding="utf-8")
    match = re.search(r"^inputs_fingerprint\(\) \{.*?^\}", source, re.S | re.M)
    if not match:
        sys.exit("applycolor fingerprint: inputs_fingerprint() not found in applycolor.sh")
    script = "\n".join([
        "set -euo pipefail",
        f'source "{COLORS}/lib/module-runtime.sh"',
        match.group(0),
        'value="$(inputs_fingerprint)"',
        'printf "%s\\n" "$value"',
    ])
    env = {
        "PATH": os.environ.get("PATH", "/usr/bin:/bin"),
        "HOME": str(home),
        "XDG_CONFIG_HOME": str(home / ".config"),
        "XDG_STATE_HOME": str(home / ".local/state"),
        "XDG_CACHE_HOME": str(home / ".cache"),
    }
    return subprocess.run(["bash", "-c", script], capture_output=True, text=True, env=env)


def main() -> int:
    with tempfile.TemporaryDirectory() as tmp:
        home = pathlib.Path(tmp)
        empty = fingerprint(home)
        if empty.returncode != 0 or not re.fullmatch(r"[0-9a-f]{40}\n", empty.stdout):
            print(f"applycolor fingerprint: fails in an empty HOME (exit {empty.returncode}): {empty.stderr.strip()}")
            return 1
        profiles = home / ".config/mozilla/firefox"
        profiles.mkdir(parents=True)
        (profiles / "profiles.ini").write_text("[Profile0]\nPath=p\n", encoding="utf-8")
        with_profile = fingerprint(home)
        if with_profile.returncode != 0 or with_profile.stdout == empty.stdout:
            print("applycolor fingerprint: a new Firefox profile does not change the fingerprint")
            return 1
    print("applycolor fingerprint: runs on a bare machine and sees new browser profiles")
    return 0


if __name__ == "__main__":
    sys.exit(main())
