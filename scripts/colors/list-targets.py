#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import os
import re
from pathlib import Path


GENERATED_DIR = Path.home() / ".local/state/quickshell/user/generated"


def resolve_default_config_path() -> Path:
    xdg_config_home = Path(
        os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))
    )
    new_file = xdg_config_home / "inir" / "config.json"
    old_file = xdg_config_home / "illogical-impulse" / "config.json"

    if old_file.is_symlink() and new_file.exists():
        return new_file
    if old_file.exists():
        return old_file
    if new_file.exists():
        return new_file
    return new_file


def generated_input_path(name: str) -> Path:
    return GENERATED_DIR / name


def slug_to_label(slug: str) -> str:
    return slug.replace("-", " ").replace("_", " ").title()


def scaffold_module_template(target_id: str, label: str, description: str) -> str:
    return f'''#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${{BASH_SOURCE[0]}}")/.." && pwd)/lib/module-runtime.sh"
COLOR_MODULE_ID="{target_id}"

main() {{
  log_module "stub target for {label}"
  # TODO: implement {description}
  # Read generated inputs from ~/.local/state/quickshell/user/generated/
  # and write/apply the app-specific theme here.
}}

main "$@"
'''


def is_valid_target_id(value: str) -> bool:
    return bool(re.fullmatch(r"[a-z0-9][a-z0-9-]*", value))


def load_targets(targets_dir: Path) -> list[dict]:
    targets: list[dict] = []
    if not targets_dir.exists():
        return targets
    for path in sorted(targets_dir.glob("*.json")):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except Exception:
            continue
        if not isinstance(data, dict):
            continue
        data.setdefault("manifest", path.name)
        data.setdefault("manifestPath", str(path))
        targets.append(data)
    return targets


def load_target(targets_dir: Path, target_id: str) -> dict | None:
    for target in load_targets(targets_dir):
        if target.get("id") == target_id:
            return target
    return None


def inspect_target(
    target: dict, colors_dir: Path, modules_dir: Path | None = None
) -> dict:
    module_name = target.get("module", "")
    resolved_modules_dir = modules_dir if modules_dir else colors_dir / "modules"
    module_path = resolved_modules_dir / module_name if module_name else None
    inputs = target.get("inputs", []) or []
    return {
        **target,
        "modulePath": str(module_path) if module_path else "",
        "moduleExists": bool(module_path and module_path.exists()),
        "moduleExecutable": bool(
            module_path and module_path.exists() and module_path.stat().st_mode & 0o111
        ),
        "resolvedInputs": [
            {
                "name": input_name,
                "path": str(generated_input_path(input_name)),
                "exists": generated_input_path(input_name).exists(),
            }
            for input_name in inputs
        ],
    }


def load_config(config_path: Path) -> dict:
    if not config_path.exists():
        return {}
    try:
        return json.loads(config_path.read_text(encoding="utf-8"))
    except Exception:
        return {}


def nested_get(data: dict, dotted_key: str):
    cur = data
    for part in dotted_key.split("."):
        if not isinstance(cur, dict) or part not in cur:
            return None
        cur = cur[part]
    return cur


def doctor_target(
    target: dict, colors_dir: Path, config: dict, modules_dir: Path | None = None
) -> dict:
    info = inspect_target(target, colors_dir, modules_dir)
    config_key = target.get("configKey", "")
    config_value = nested_get(config, config_key) if config_key else None
    problems: list[str] = []
    warnings: list[str] = []

    if not info["moduleExists"]:
        problems.append("module file is missing")
    elif not info["moduleExecutable"]:
        warnings.append("module file is not executable")

    missing_inputs = [
        item["name"] for item in info["resolvedInputs"] if not item["exists"]
    ]
    if missing_inputs:
        warnings.append("missing generated inputs: " + ", ".join(missing_inputs))

    if config_key and config_value is False:
        warnings.append(f"config gate disabled: {config_key}=false")

    status = "ok"
    if problems:
        status = "error"
    elif warnings:
        status = "warn"

    return {
        **info,
        "status": status,
        "problems": problems,
        "warnings": warnings,
        "configValue": config_value,
    }


def scaffold_target(args, colors_dir: Path, targets_dir: Path) -> int:
    target_id = args.target
    if not target_id:
        print("scaffold requires a target id")
        return 1
    if not is_valid_target_id(target_id):
        print("target id must match [a-z0-9][a-z0-9-]*")
        return 1

    modules_dir = Path(args.modules_dir) if args.modules_dir else colors_dir / "modules"
    targets_dir.mkdir(parents=True, exist_ok=True)
    modules_dir.mkdir(parents=True, exist_ok=True)

    module_name = args.module or f"{args.index:02d}-{target_id}.sh"
    manifest_path = targets_dir / f"{target_id}.json"
    module_path = modules_dir / module_name

    if manifest_path.exists() or module_path.exists():
        print("Refusing to overwrite existing scaffold target files")
        print(f"manifest={manifest_path}")
        print(f"module={module_path}")
        return 1

    label = args.label or slug_to_label(target_id)
    description = args.description or f"Apply generated iNiR palette to {label}."
    inputs = args.inputs or ["palette.json"]

    manifest = {
        "id": target_id,
        "label": label,
        "module": module_name,
        "category": args.category,
        "inputs": inputs,
        "description": description,
        "configKey": args.config_key,
    }

    manifest_path.write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    module_path.write_text(
        scaffold_module_template(target_id, label, description), encoding="utf-8"
    )
    module_path.chmod(0o755)

    print(f"created manifest: {manifest_path}")
    print(f"created module:   {module_path}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="iNiR theming target tools")
    parser.add_argument(
        "command",
        nargs="?",
        default="list",
        choices=["list", "inspect", "doctor", "scaffold"],
    )
    parser.add_argument(
        "target", nargs="?", default=None, help="Target id for inspect/doctor"
    )
    parser.add_argument("--json", action="store_true", help="Output raw JSON")
    parser.add_argument(
        "--targets-dir", default=None, help="Override targets directory"
    )
    parser.add_argument(
        "--config",
        default=str(resolve_default_config_path()),
        help="Path to config.json",
    )
    parser.add_argument(
        "--modules-dir", default=None, help="Override modules directory"
    )
    parser.add_argument("--module", default=None, help="Module filename for scaffold")
    parser.add_argument("--label", default=None, help="Display label for scaffold")
    parser.add_argument("--description", default=None, help="Description for scaffold")
    parser.add_argument("--category", default="custom", help="Category for scaffold")
    parser.add_argument(
        "--config-key",
        default="appearance.wallpaperTheming.enableAppsAndShell",
        help="Config key for scaffold",
    )
    parser.add_argument(
        "--index",
        type=int,
        default=70,
        help="Numeric prefix for scaffolded module file",
    )
    parser.add_argument(
        "--inputs",
        nargs="*",
        default=None,
        help="Declared generated inputs for scaffold",
    )
    args = parser.parse_args()

    colors_dir = Path(__file__).resolve().parent
    targets_dir = Path(args.targets_dir) if args.targets_dir else colors_dir / "targets"
    modules_dir = Path(args.modules_dir) if args.modules_dir else colors_dir / "modules"
    config = load_config(Path(args.config))

    if args.command == "scaffold":
        return scaffold_target(args, colors_dir, targets_dir)

    if args.command == "inspect":
        if not args.target:
            print("inspect requires a target id")
            return 1
        target = load_target(targets_dir, args.target)
        if not target:
            print(f"Unknown target: {args.target}")
            return 1
        info = inspect_target(target, colors_dir, modules_dir)
        if args.json:
            print(json.dumps(info, indent=2, ensure_ascii=False))
            return 0
        print(json.dumps(info, indent=2, ensure_ascii=False))
        return 0

    if args.command == "doctor":
        if args.target:
            target = load_target(targets_dir, args.target)
            if not target:
                print(f"Unknown target: {args.target}")
                return 1
            result = doctor_target(target, colors_dir, config, modules_dir)
            if args.json:
                print(json.dumps(result, indent=2, ensure_ascii=False))
                return 0 if result["status"] != "error" else 1
            print(json.dumps(result, indent=2, ensure_ascii=False))
            return 0 if result["status"] != "error" else 1

        results = [
            doctor_target(target, colors_dir, config, modules_dir)
            for target in load_targets(targets_dir)
        ]
        if args.json:
            print(json.dumps(results, indent=2, ensure_ascii=False))
        else:
            for result in results:
                print(f"{result['status']}\t{result['id']}\t{result.get('label', '')}")
                for problem in result["problems"]:
                    print(f"  problem: {problem}")
                for warning in result["warnings"]:
                    print(f"  warning: {warning}")
        return 0 if all(r["status"] != "error" for r in results) else 1

    targets = load_targets(targets_dir)

    if args.json:
        print(json.dumps(targets, indent=2, ensure_ascii=False))
        return 0

    if not targets:
        print("No theming targets found")
        return 0

    for target in targets:
        target_id = target.get("id", "<missing>")
        label = target.get("label", "")
        module = target.get("module", "")
        category = target.get("category", "")
        inputs = ", ".join(target.get("inputs", []))
        print(f"{target_id}\t{label}\t{category}\t{module}\t{inputs}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
