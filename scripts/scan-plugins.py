#!/usr/bin/env python3
"""Scan plugin directory for valid manifest.json files and output JSON array.

On first run (empty plugins dir), copies built-in plugins from defaults/plugins/
so existing users get Discord + YouTube Music out of the box after updating.
"""

import json
import os
import shutil
import sys


def resolve_shell_config_dir() -> str:
    xdg_config = os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config"))
    new_dir = os.path.join(xdg_config, "inir")
    legacy_dir = os.path.join(xdg_config, "illogical-impulse")

    if os.path.islink(legacy_dir) and os.path.isdir(new_dir):
        return new_dir
    if os.path.isdir(legacy_dir):
        return legacy_dir
    if os.path.isdir(new_dir):
        return new_dir
    return new_dir


plugins_dir = os.path.join(resolve_shell_config_dir(), "plugins")

# Find defaults/plugins/ relative to this script's location in the iNiR repo
# scripts/scan-plugins.py → ../defaults/plugins/
script_dir = os.path.dirname(os.path.abspath(__file__))
defaults_dir = os.path.join(script_dir, "..", "defaults", "plugins")


def bootstrap_defaults():
    """Copy built-in plugins from defaults/ if user has no plugins yet."""
    if not os.path.isdir(defaults_dir):
        return
    os.makedirs(plugins_dir, exist_ok=True)
    for entry in os.listdir(defaults_dir):
        src = os.path.join(defaults_dir, entry)
        dest = os.path.join(plugins_dir, entry)
        if not os.path.isdir(src):
            continue
        if not os.path.isdir(dest):
            # New plugin — copy entirely
            shutil.copytree(src, dest)
            print(f"[Plugins] Installed default plugin: {entry}", file=sys.stderr)
        else:
            # Existing plugin — update userscripts only (don't overwrite user manifest/icon)
            src_scripts = os.path.join(src, "scripts")
            if os.path.isdir(src_scripts):
                dest_scripts = os.path.join(dest, "scripts")
                os.makedirs(dest_scripts, exist_ok=True)
                for sf in os.listdir(src_scripts):
                    shutil.copy2(
                        os.path.join(src_scripts, sf), os.path.join(dest_scripts, sf)
                    )


if not os.path.isdir(plugins_dir) or not os.listdir(plugins_dir):
    bootstrap_defaults()

if not os.path.isdir(plugins_dir):
    print("[]")
    sys.exit(0)

plugins = []
for entry in sorted(os.listdir(plugins_dir)):
    manifest_path = os.path.join(plugins_dir, entry, "manifest.json")
    if not os.path.isfile(manifest_path):
        continue
    try:
        with open(manifest_path, "r") as f:
            data = json.load(f)
        if "id" in data and "url" in data:
            # Ensure required fields have defaults
            data.setdefault("name", data["id"])
            data.setdefault("icon", "language")
            data.setdefault("display", "tab")
            data.setdefault("version", "1.0")
            plugin_dir = os.path.join(plugins_dir, entry)
            # Resolve iconPath to an absolute faviconPath
            icon_path = data.get("iconPath")
            if icon_path:
                full_path = os.path.join(plugin_dir, icon_path)
                if os.path.isfile(full_path):
                    data["faviconPath"] = full_path
            # Resolve userscripts to absolute paths and read their source code
            scripts = data.get("userscripts", [])
            if scripts:
                resolved = []
                sources = []
                for s in scripts:
                    full = os.path.join(plugin_dir, s)
                    if os.path.isfile(full):
                        resolved.append(full)
                        try:
                            with open(full, "r") as sf:
                                sources.append(sf.read())
                        except OSError:
                            sources.append("")
                data["userscriptPaths"] = resolved
                data["userscriptSources"] = sources
            plugins.append(data)
    except (json.JSONDecodeError, OSError):
        continue

print(json.dumps(plugins))
