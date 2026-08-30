#!/usr/bin/env python3
"""Validate, extract and fingerprint optional Kira art packs.

This helper is intentionally independent from QML. The art release owns only
flat inir-mascot-*.png|gif files; iNiR owns manifest.json and behavior.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import sys
import tarfile
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ASSET_RE = re.compile(r"^inir-mascot-[a-z0-9]+(?:-[a-z0-9]+)*\.(png|gif)$")
REQUIRED_ASSETS = {"inir-mascot-presence-idle-loop.gif"}


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def asset_paths(directory: Path) -> list[Path]:
    if not directory.is_dir():
        return []
    return sorted(
        path
        for path in directory.iterdir()
        if path.is_file() and ASSET_RE.fullmatch(path.name)
    )


def tree_info(directory: Path) -> dict[str, Any]:
    assets = asset_paths(directory)
    digest = hashlib.sha256()
    for path in assets:
        digest.update(f"{file_sha256(path)}  {path.name}\n".encode())
    return {
        "asset_count": len(assets),
        "asset_tree_sha256": digest.hexdigest(),
    }


def read_metadata(path: Path | None) -> dict[str, Any] | None:
    if path is None or not path.is_file() or path.stat().st_size == 0:
        return None
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ValueError(f"invalid metadata: {exc}") from exc
    if not isinstance(value, dict) or value.get("schema") != 1:
        raise ValueError("metadata schema must be 1")
    return value


def inspect_archive(archive: Path) -> tuple[list[tarfile.TarInfo], list[str]]:
    try:
        with tarfile.open(archive, "r:gz") as handle:
            members = handle.getmembers()
    except (OSError, tarfile.TarError) as exc:
        raise ValueError(f"cannot read archive: {exc}") from exc

    names = [member.name for member in members]
    invalid = [
        name
        for name in names
        if not ASSET_RE.fullmatch(name)
        or Path(name).is_absolute()
        or ".." in Path(name).parts
    ]
    non_files = [member.name for member in members if not member.isfile()]
    duplicates = sorted({name for name in names if names.count(name) > 1})
    if invalid:
        raise ValueError("invalid archive members: " + ", ".join(invalid))
    if non_files:
        raise ValueError("archive contains non-files: " + ", ".join(non_files))
    if duplicates:
        raise ValueError("archive contains duplicate members: " + ", ".join(duplicates))
    if len(names) <= 10:
        raise ValueError(f"archive contains too few assets: {len(names)}")
    missing_required = sorted(REQUIRED_ASSETS - set(names))
    if missing_required:
        raise ValueError("archive misses required assets: " + ", ".join(missing_required))
    return members, names


def extract_verified(
    archive: Path, destination: Path, metadata_path: Path | None
) -> dict[str, Any]:
    members, names = inspect_archive(archive)
    metadata = read_metadata(metadata_path)
    archive_hash = file_sha256(archive)

    if metadata is not None:
        if metadata.get("archive") != archive.name:
            raise ValueError("metadata archive name does not match")
        if metadata.get("archive_sha256") != archive_hash:
            raise ValueError("archive checksum does not match metadata")
        if int(metadata.get("asset_count", -1)) != len(names):
            raise ValueError("archive asset count does not match metadata")
        required = set(metadata.get("required_assets", []))
        if required and not required.issubset(set(names)):
            raise ValueError("metadata required assets are absent from archive")

    destination.mkdir(parents=True, exist_ok=True)
    for old in asset_paths(destination):
        old.unlink()
    with tarfile.open(archive, "r:gz") as handle:
        for member in members:
            source = handle.extractfile(member)
            if source is None:
                raise ValueError(f"cannot extract {member.name}")
            target = destination / member.name
            temporary = destination / f".{member.name}.part"
            with temporary.open("wb") as output:
                shutil.copyfileobj(source, output)
            os.replace(temporary, target)

    info = tree_info(destination)
    info["archive_sha256"] = archive_hash
    if info["asset_count"] != len(names):
        raise ValueError("extracted asset count does not match archive")
    if metadata is not None and metadata.get("asset_tree_sha256") != info["asset_tree_sha256"]:
        raise ValueError("installed asset tree does not match metadata")
    return info


def read_state(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ValueError(f"invalid state: {exc}") from exc
    if not isinstance(value, dict) or value.get("schema") != 1:
        raise ValueError("state schema must be 1")
    for key in ("tag", "asset_count", "asset_tree_sha256", "archive_sha256"):
        if key not in value:
            raise ValueError(f"state is missing {key}")
    return value


def write_state(
    path: Path, tag: str, count: int, tree_hash: str, archive_hash: str
) -> None:
    value = {
        "schema": 1,
        "tag": tag,
        "asset_count": count,
        "asset_tree_sha256": tree_hash,
        "archive_sha256": archive_hash,
        "installed_at": datetime.now(timezone.utc).isoformat(),
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(value, handle, indent=2)
            handle.write("\n")
        os.replace(temporary_name, path)
    finally:
        try:
            os.unlink(temporary_name)
        except FileNotFoundError:
            pass


def main() -> int:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)

    tree_parser = subparsers.add_parser("tree")
    tree_parser.add_argument("directory", type=Path)

    verify_parser = subparsers.add_parser("verify")
    verify_parser.add_argument("archive", type=Path)
    verify_parser.add_argument("destination", type=Path)
    verify_parser.add_argument("--metadata", type=Path)

    state_parser = subparsers.add_parser("state")
    state_parser.add_argument("path", type=Path)

    write_parser = subparsers.add_parser("write-state")
    write_parser.add_argument("path", type=Path)
    write_parser.add_argument("tag")
    write_parser.add_argument("asset_count", type=int)
    write_parser.add_argument("asset_tree_sha256")
    write_parser.add_argument("archive_sha256")

    args = parser.parse_args()
    try:
        if args.command == "tree":
            print(json.dumps(tree_info(args.directory), separators=(",", ":")))
        elif args.command == "verify":
            info = extract_verified(args.archive, args.destination, args.metadata)
            print(json.dumps(info, separators=(",", ":")))
        elif args.command == "state":
            print(json.dumps(read_state(args.path), separators=(",", ":")))
        elif args.command == "write-state":
            write_state(
                args.path,
                args.tag,
                args.asset_count,
                args.asset_tree_sha256,
                args.archive_sha256,
            )
        return 0
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
