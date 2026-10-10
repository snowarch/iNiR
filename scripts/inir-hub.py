#!/usr/bin/env python3
"""iNiR Hub client: browse, install, update and remove community items.

The catalogue is an index.json published by github.com/snowarch/inir-hub (or any source built with its
tools/hub.py). Every package is checked against the sha256 the index lists before anything is written,
unpacked into a staging folder, and swapped into place in one rename.

    inir-hub.py status [--max-age SECONDS|--cached] [--json]   catalogue merged with what is installed
    inir-hub.py sync [--json]                         fetch every source now
    inir-hub.py list [--installed|--updates] [--kind K] [--json]
    inir-hub.py search TEXT [--json]
    inir-hub.py info ID [--json]
    inir-hub.py install ID... [--json]
    inir-hub.py update [ID...] [--json]               all updates when no id is given
    inir-hub.py remove ID... [--json]

Machine-readable output goes to stdout with --json; diagnostics go to stderr. Exit codes: 0 ok, 1 error,
2 usage, 3 a local item of that name exists that the hub did not install, 4 needs a newer iNiR,
5 network, 6 package failed its checksum, 7 unknown id.
"""

from __future__ import annotations

import argparse
import contextlib
import datetime as dt
import fcntl
import hashlib
import io
import json
import os
import shutil
import sys
import tarfile
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path, PurePosixPath

OFFICIAL = "https://snowarch.github.io/inir-hub/index.json"
TIMEOUT = 15
MAX_PACKAGE = 4 * 1024 * 1024
MAX_UNPACKED = 12 * 1024 * 1024
DEFAULT_MAX_AGE = 6 * 3600
KINDS = ("widget", "theme", "iris-theme", "webapp")

EXIT_ERROR, EXIT_USAGE, EXIT_CONFLICT, EXIT_INCOMPATIBLE, EXIT_NETWORK, EXIT_INTEGRITY, EXIT_UNKNOWN = 1, 2, 3, 4, 5, 6, 7


class HubError(Exception):
    def __init__(self, message: str, code: int = EXIT_ERROR) -> None:
        super().__init__(message)
        self.code = code


def xdg(var: str, fallback: str) -> Path:
    value = os.environ.get(var, "")
    return Path(value) if value.startswith("/") else Path.home() / fallback


CONFIG_HOME = xdg("XDG_CONFIG_HOME", ".config")
STATE_DIR = xdg("XDG_STATE_HOME", ".local/state") / "inir" / "hub"
CACHE_DIR = xdg("XDG_CACHE_HOME", ".cache") / "inir" / "hub"
RECORDS = STATE_DIR / "installed.json"


def shell_config_dir() -> Path:
    """Directories.shellConfig as the shell resolves it: inir, or a real legacy illogical-impulse folder."""
    new, legacy = CONFIG_HOME / "inir", CONFIG_HOME / "illogical-impulse"
    if legacy.is_symlink() and new.is_dir():
        return new
    if legacy.is_dir():
        return legacy
    return new


def target_of(kind: str, item_id: str) -> Path:
    """Where iNiR loads each kind from; never a path the index chooses."""
    if kind == "widget":
        return CONFIG_HOME / "inir" / "widgets" / item_id  # services/CustomWidgets.qml
    if kind == "webapp":
        return shell_config_dir() / "plugins" / item_id  # scripts/scan-plugins.py
    if kind == "theme":
        return shell_config_dir() / "themes" / f"{item_id}.json"  # modules/settings/ThemesConfig.qml
    if kind == "iris-theme":
        return shell_config_dir() / "iris" / "themes" / f"{item_id}.json"  # modules/iris/settings/IrisThemes.qml
    raise HubError(f"unknown kind {kind}")


def inir_version() -> str:
    try:
        return (Path(__file__).resolve().parent.parent / "VERSION").read_text().strip()
    except OSError:
        return "0.0.0"


def version_key(text: str) -> tuple[int, ...]:
    parts = []
    for piece in str(text or "0").split("-")[0].split("."):
        parts.append(int(piece) if piece.isdigit() else 0)
    return tuple(parts + [0] * (3 - len(parts)))


def sources() -> list[str]:
    env = os.environ.get("INIR_HUB_SOURCES", "").replace(",", " ").split()
    if env:
        return env
    out = [OFFICIAL]
    try:
        config = json.loads((shell_config_dir() / "config.json").read_text())
        extra = (config.get("hub") or {}).get("sources") or []
        out += [str(s).strip() for s in extra if str(s).strip() and str(s).strip() not in out]
    except (OSError, json.JSONDecodeError, AttributeError):
        pass
    return out


def to_url(source: str) -> str:
    if "://" in source:
        return source
    path = Path(source).expanduser().resolve()
    if path.is_dir():
        path = path / "index.json"
    return path.as_uri()


def fetch(url: str, limit: int = MAX_PACKAGE) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": f"inir-hub/{inir_version()}"})
    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
            data = response.read(limit + 1)
    except urllib.error.HTTPError as exc:
        raise HubError(f"{url}: HTTP {exc.code}", EXIT_NETWORK) from exc
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        reason = getattr(exc, "reason", exc)
        raise HubError(f"{url}: {reason}", EXIT_NETWORK) from exc
    if len(data) > limit:
        raise HubError(f"{url}: larger than {limit // 1024} KB", EXIT_INTEGRITY)
    return data


def cache_file(source: str) -> Path:
    return CACHE_DIR / f"index-{hashlib.sha1(to_url(source).encode()).hexdigest()[:12]}.json"


def sync_source(source: str) -> dict:
    url = to_url(source)
    meta = {"source": source, "url": url, "fetched": 0, "error": "", "count": 0, "name": ""}
    try:
        index = json.loads(fetch(url, 2 * 1024 * 1024))
        if not isinstance(index, dict) or index.get("schema") != 1 or not isinstance(index.get("items"), list):
            raise HubError(f"{url}: not an iNiR Hub index (schema 1)")
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        payload = {"fetched": int(time.time()), "url": url, "index": index}
        tmp = cache_file(source).with_suffix(".tmp")
        tmp.write_text(json.dumps(payload))
        os.replace(tmp, cache_file(source))
        meta.update(fetched=payload["fetched"], count=len(index["items"]), name=str(index.get("name", "")))
    except (HubError, json.JSONDecodeError) as exc:
        meta["error"] = str(exc)
        cached = read_cache(source)
        if cached:
            meta.update(fetched=cached["fetched"], count=len(cached["index"]["items"]), name=cached["index"].get("name", ""))
    return meta


def read_cache(source: str) -> dict | None:
    try:
        data = json.loads(cache_file(source).read_text())
        return data if isinstance(data.get("index"), dict) else None
    except (OSError, json.JSONDecodeError, AttributeError):
        return None


def load_records() -> dict:
    try:
        data = json.loads(RECORDS.read_text())
        return data.get("items", {}) if isinstance(data, dict) else {}
    except (OSError, json.JSONDecodeError):
        return {}


def save_records(records: dict) -> None:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    tmp = RECORDS.with_suffix(".tmp")
    tmp.write_text(json.dumps({"schema": 1, "items": records}, indent=1, sort_keys=True) + "\n")
    os.replace(tmp, RECORDS)


@contextlib.contextmanager
def locked():
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    with open(STATE_DIR / ".lock", "w") as handle:
        fcntl.flock(handle, fcntl.LOCK_EX)
        try:
            yield
        finally:
            fcntl.flock(handle, fcntl.LOCK_UN)


def catalogue(max_age: int | None) -> tuple[list[dict], list[dict]]:
    """Every source's items (first source wins an id) and each source's state; refreshes stale caches."""
    items: dict[str, dict] = {}
    states = []
    now = time.time()
    for source in sources():
        cached = read_cache(source)
        if max_age is not None and (cached is None or now - cached["fetched"] > max_age):
            state = sync_source(source)
            cached = read_cache(source)
        else:
            state = {"source": source, "url": to_url(source), "fetched": cached["fetched"] if cached else 0,
                     "error": "" if cached else "not fetched yet", "name": cached["index"].get("name", "") if cached else "",
                     "count": len(cached["index"]["items"]) if cached else 0}
        states.append(state)
        if not cached:
            continue
        base = cached["url"]
        for raw in cached["index"]["items"]:
            if not isinstance(raw, dict) or raw.get("kind") not in KINDS or not raw.get("id") or raw["id"] in items:
                continue
            item = dict(raw)
            item["source"] = source
            item["sourceName"] = state["name"]
            item["packageUrl"] = urllib.parse.urljoin(base, str(raw.get("package", "")))
            item["previewUrl"] = urllib.parse.urljoin(base, str(raw["preview"])) if raw.get("preview") else ""
            home = str(cached["index"].get("home", ""))
            item["page"] = f"{home}/tree/main/{raw['path']}" if home.startswith("https://github.com/") and raw.get("path") else home
            items[item["id"]] = item
    return list(items.values()), states


def present(kind: str, item_id: str) -> bool:
    path = target_of(kind, item_id)
    return path.exists() or path.is_symlink()


def annotate(items: list[dict], records: dict) -> list[dict]:
    current = version_key(inir_version())
    out = []
    for item in items:
        record = records.get(item["id"])
        if record and not present(record["kind"], item["id"]):
            record = None  # deleted by hand
        item["installed"] = record["version"] if record else ""
        item["update"] = bool(record) and version_key(item["version"]) > version_key(record["version"])
        item["compatible"] = not item.get("minInir") or version_key(item["minInir"]) <= current
        item["conflict"] = not record and present(item["kind"], item["id"])
        out.append(item)
    known = {item["id"] for item in out}
    for item_id, record in records.items():
        if item_id not in known and present(record["kind"], item_id):
            out.append({"id": item_id, "kind": record["kind"], "name": record.get("name", item_id), "summary": "",
                        "description": "", "version": record["version"], "installed": record["version"], "update": False,
                        "compatible": True, "conflict": False, "orphan": True, "authors": [], "tags": [],
                        "permissions": [], "families": [], "surfaces": [], "previewUrl": "", "source": record.get("source", "")})
    return out


def find(item_id: str, items: list[dict]) -> dict:
    for item in items:
        if item["id"] == item_id:
            return item
    raise HubError(f'no item "{item_id}" in the hub; try: inir hub search', EXIT_UNKNOWN)


def safe_unpack(data: bytes, dest: Path) -> None:
    total = 0
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as tar:
        members = tar.getmembers()
        if len(members) > 400:
            raise HubError("package holds too many files", EXIT_INTEGRITY)
        for member in members:
            path = PurePosixPath(member.name)
            if path.is_absolute() or ".." in path.parts or not (member.isfile() or member.isdir()):
                raise HubError(f"package entry {member.name!r} is not allowed", EXIT_INTEGRITY)
            total += member.size
        if total > MAX_UNPACKED:
            raise HubError("package unpacks too large", EXIT_INTEGRITY)
        if hasattr(tarfile, "data_filter"):
            tar.extractall(dest, filter="data")
        else:
            tar.extractall(dest)


def download(item: dict) -> bytes:
    expected = str(item.get("sha256", ""))
    cached = CACHE_DIR / "packages" / f"{item['id']}-{item['version']}.tar.gz"
    if cached.is_file():
        data = cached.read_bytes()
        if hashlib.sha256(data).hexdigest() == expected:
            return data
    data = fetch(item["packageUrl"])
    if hashlib.sha256(data).hexdigest() != expected:
        raise HubError(f"{item['id']}: package does not match the checksum the hub lists; nothing was installed",
                       EXIT_INTEGRITY)
    cached.parent.mkdir(parents=True, exist_ok=True)
    cached.write_bytes(data)
    return data


def place(item: dict, data: bytes) -> Path:
    kind, item_id = item["kind"], item["id"]
    target = target_of(kind, item_id)
    target.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=f".hub-{item_id}-", dir=target.parent) as tmp:
        staging = Path(tmp) / "item"
        staging.mkdir()
        safe_unpack(data, staging)
        if kind in ("theme", "iris-theme"):
            source = staging / "theme.json"
            if not source.is_file():
                raise HubError(f"{item_id}: package has no theme.json", EXIT_INTEGRITY)
            json.loads(source.read_text())  # refuse to install a file iNiR could not read
            os.replace(source, target)
            return target
        old = Path(tmp) / "old"
        if target.exists():
            os.replace(target, old)
        try:
            os.replace(staging, target)
        except OSError:
            if old.exists():
                os.replace(old, target)
            raise
    return target


def install(item_ids: list[str]) -> list[dict]:
    with locked():
        records = load_records()
        items = annotate(catalogue(DEFAULT_MAX_AGE)[0], records)
        results = []
        for item_id in item_ids:
            item = find(item_id, items)
            if item.get("orphan"):
                raise HubError(f"{item_id} is no longer listed in any hub source", EXIT_UNKNOWN)
            if item["conflict"]:
                raise HubError(f"{target_of(item['kind'], item_id)} already exists and was not installed from the hub; "
                               "rename or remove it first", EXIT_CONFLICT)
            if not item["compatible"]:
                raise HubError(f"{item['name']} needs iNiR {item['minInir']} (this is {inir_version()}); "
                               "run: inir update", EXIT_INCOMPATIBLE)
            if item["installed"] and not item["update"]:
                results.append({"id": item_id, "kind": item["kind"], "version": item["installed"], "changed": False})
                continue
            path = place(item, download(item))
            records[item_id] = {"kind": item["kind"], "version": item["version"], "sha256": item["sha256"],
                                "source": item["source"], "name": item["name"], "path": str(path),
                                "installed": dt.datetime.now().replace(microsecond=0).isoformat()}
            save_records(records)
            results.append({"id": item_id, "kind": item["kind"], "version": item["version"], "changed": True,
                            "from": item["installed"], "path": str(path)})
        return results


def update(item_ids: list[str]) -> list[dict]:
    records = load_records()
    items = annotate(catalogue(0)[0], records)
    wanted = item_ids or [item["id"] for item in items if item["update"] and item["compatible"]]
    return install(wanted) if wanted else []


def remove(item_ids: list[str]) -> list[dict]:
    with locked():
        records = load_records()
        results = []
        for item_id in item_ids:
            record = records.get(item_id)
            if not record:
                raise HubError(f"{item_id} was not installed from the hub; iNiR leaves your own items alone",
                               EXIT_UNKNOWN)
            path = target_of(record["kind"], item_id)
            if path.is_dir() and not path.is_symlink():
                shutil.rmtree(path)
            elif path.exists() or path.is_symlink():
                path.unlink()
            del records[item_id]
            save_records(records)
            results.append({"id": item_id, "kind": record["kind"], "removed": True})
        return results


def emit(args, payload: dict, human) -> None:
    if args.json:
        print(json.dumps(payload, ensure_ascii=False))
    else:
        human(payload)


def print_items(items: list[dict]) -> None:
    if not items:
        print("nothing here")
        return
    width = max(len(item["id"]) for item in items)
    for item in sorted(items, key=lambda i: (i["kind"], i["id"])):
        mark = "↑" if item.get("update") else "●" if item.get("installed") else " "
        print(f"{mark} {item['id']:<{width}}  {item['kind']:<10}  {item.get('version', ''):<8}  {item.get('summary', '')}")


def main() -> int:
    parser = argparse.ArgumentParser(prog="inir hub", description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--json", action="store_true", help="machine-readable output")
    sub = parser.add_subparsers(dest="cmd")
    for name in ("status", "sync", "list", "search", "info", "install", "update", "remove"):
        p = sub.add_parser(name)
        p.add_argument("--json", action="store_true", default=argparse.SUPPRESS)
        if name == "status":
            p.add_argument("--max-age", type=int, default=DEFAULT_MAX_AGE)
            p.add_argument("--cached", action="store_true", help="never fetch; read what was fetched last")
        if name == "list":
            p.add_argument("--installed", action="store_true")
            p.add_argument("--updates", action="store_true")
            p.add_argument("--kind", choices=KINDS)
        if name == "search":
            p.add_argument("text", nargs="+")
        if name == "info":
            p.add_argument("id")
        if name in ("install", "remove"):
            p.add_argument("ids", nargs="+")
        if name == "update":
            p.add_argument("ids", nargs="*")
    args = parser.parse_args()
    if not args.cmd:
        parser.print_help()
        return EXIT_USAGE

    try:
        if args.cmd in ("status", "sync"):
            max_age = 0 if args.cmd == "sync" else None if args.cached else args.max_age
            items, states = catalogue(max_age)
            items = annotate(items, load_records())
            payload = {"ok": True, "inir": inir_version(), "sources": states, "items": items,
                       "updates": sum(1 for i in items if i["update"] and i["compatible"])}

            def human(p: dict) -> None:
                for s in p["sources"]:
                    when = dt.datetime.fromtimestamp(s["fetched"]).strftime("%Y-%m-%d %H:%M") if s["fetched"] else "never"
                    print(f"{s['name'] or s['source']}: {s['count']} items, fetched {when}" + (f" ({s['error']})" if s["error"] else ""))
                if p["updates"]:
                    print(f"{p['updates']} update(s): inir hub update")
            emit(args, payload, human)
            return EXIT_NETWORK if all(s["error"] and not s["count"] for s in states) else 0
        if args.cmd in ("list", "search", "info"):
            items = annotate(catalogue(DEFAULT_MAX_AGE)[0], load_records())
            if args.cmd == "info":
                item = find(args.id, items)
                emit(args, {"ok": True, "item": item}, lambda p: print(json.dumps(p["item"], indent=2, ensure_ascii=False)))
                return 0
            if args.cmd == "search":
                terms = [t.lower() for t in args.text]
                items = [i for i in items if all(t in " ".join([i["id"], i.get("name", ""), i.get("summary", ""),
                         i.get("description", ""), " ".join(i.get("tags", [])), " ".join(i.get("authors", []))]).lower()
                         for t in terms)]
            else:
                if args.installed:
                    items = [i for i in items if i["installed"]]
                if args.updates:
                    items = [i for i in items if i["update"]]
                if args.kind:
                    items = [i for i in items if i["kind"] == args.kind]
            emit(args, {"ok": True, "items": items}, lambda p: print_items(p["items"]))
            return 0
        if args.cmd == "install":
            results = install(args.ids)
        elif args.cmd == "update":
            results = update(args.ids)
        else:
            results = remove(args.ids)

        def human(p: dict) -> None:
            if not p["results"]:
                print("everything is up to date")
            for r in p["results"]:
                if r.get("removed"):
                    print(f"removed {r['id']}")
                elif r.get("changed"):
                    print(f"{'updated' if r.get('from') else 'installed'} {r['id']} {r['version']}")
                else:
                    print(f"{r['id']} {r['version']} is already installed")
        emit(args, {"ok": True, "results": results}, human)
        return 0
    except HubError as exc:
        if getattr(args, "json", False):
            print(json.dumps({"ok": False, "error": str(exc), "code": exc.code}, ensure_ascii=False))
        print(f"inir hub: {exc}", file=sys.stderr)
        return exc.code


if __name__ == "__main__":
    sys.exit(main())
