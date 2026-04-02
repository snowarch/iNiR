#!/usr/bin/env python3
"""
niri-config.py — Niri compositor configuration helper for iNiR settings UI.

SAFETY: All persist/set commands do SURGICAL edits on existing KDL files.
They NEVER rewrite files from scratch. Unknown settings, comments, and
structure are always preserved.

Commands:
  outputs              JSON array of outputs with modes/capabilities
  apply-output NAME    Apply temporary output changes via niri msg
  persist-output NAME  Write output config to KDL config.d/15-outputs.kdl
  get-input            Read current input config from KDL
  get-layout           Read current layout config from KDL
  get-animations       Read current animation config from KDL (with per-type springs)
  get-window-rules     Read window-rule globals from KDL
  list-cursor-themes   List available cursor themes from icon dirs
  validate             Validate current Niri config via niri validate
  detect-customizations Report Niri files that differ from shipped iNiR defaults
  set SECTION KEY VAL  Surgical edit of a single config value
  get-binds            JSON of all keybinds from 70-binds.kdl with categories/metadata
  set-bind KEY ACTION  Add or update a keybind in 70-binds.kdl (surgical edit)
  remove-bind KEY      Comment out a keybind in 70-binds.kdl (surgical edit)
"""

from difflib import unified_diff
import json
import os
import re
import subprocess
import sys
from pathlib import Path


DEFAULT_NIRI_FILES = [
    "config.kdl",
    "config.d/10-input-and-cursor.kdl",
    "config.d/20-layout-and-overview.kdl",
    "config.d/30-window-rules.kdl",
    "config.d/40-environment.kdl",
    "config.d/50-startup.kdl",
    "config.d/60-animations.kdl",
    "config.d/70-binds.kdl",
    "config.d/80-layer-rules.kdl",
    "config.d/90-user-extra.kdl",
]


def get_niri_config_dir():
    """Resolve the Niri config directory."""
    xdg = os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config"))
    return Path(xdg) / "niri"


def get_niri_config_path():
    return get_niri_config_dir() / "config.kdl"


def get_repo_default_niri_dir():
    return Path(__file__).resolve().parent / ".." / "defaults" / "niri"


def _root_includes(relative_path: str) -> bool:
    config_file = get_niri_config_path()
    if not config_file.exists():
        return False

    try:
        content = config_file.read_text()
    except Exception:
        return False

    escaped = re.escape(relative_path)
    return bool(re.search(rf'^\s*include\s+"{escaped}"\s*$', content, re.MULTILINE))


def resolve_niri_section_file(relative_path: str) -> Path:
    config_dir = get_niri_config_dir()
    root_config = get_niri_config_path()
    modular_file = config_dir / relative_path

    if modular_file.exists() and _root_includes(relative_path):
        return modular_file
    if root_config.exists():
        return root_config
    return modular_file


def run_niri(*args):
    """Run niri msg and return output."""
    try:
        r = subprocess.run(
            ["niri", "msg", *args], capture_output=True, text=True, timeout=5
        )
        return r.stdout.strip(), r.returncode
    except Exception as e:
        return str(e), 1


# ─── Outputs ──────────────────────────────────────────────────────────


def cmd_outputs():
    """Get structured output info from Niri."""
    raw, rc = run_niri("-j", "outputs")
    if rc != 0:
        print(json.dumps({"error": f"niri msg failed: {raw}"}))
        return 1

    data = json.loads(raw)
    result = []

    for name, out in data.items():
        modes = out.get("modes", [])
        current_idx = out.get("current_mode", 0)
        logical = out.get("logical") or {}

        res_map = {}
        for i, m in enumerate(modes):
            key = f"{m['width']}x{m['height']}"
            rate = round(m["refresh_rate"] / 1000, 3)
            rate_string = f"{rate:.3f}"
            if key not in res_map:
                res_map[key] = {
                    "width": m["width"],
                    "height": m["height"],
                    "rates": [],
                    "preferred": m.get("is_preferred", False),
                }
            if rate not in [r["rate"] for r in res_map[key]["rates"]]:
                res_map[key]["rates"].append(
                    {
                        "rate": rate,
                        "rate_string": rate_string,
                        "mode_index": i,
                        "preferred": m.get("is_preferred", False),
                    }
                )
            elif m.get("is_preferred", False):
                res_map[key]["preferred"] = True

        current_mode = modes[current_idx] if current_idx < len(modes) else None
        current_res = ""
        current_rate = 0.0
        current_rate_string = ""
        if current_mode:
            current_res = f"{current_mode['width']}x{current_mode['height']}"
            current_rate = round(current_mode["refresh_rate"] / 1000, 3)
            current_rate_string = f"{current_rate:.3f}"

        result.append(
            {
                "name": name,
                "make": out.get("make", ""),
                "model": out.get("model", ""),
                "serial": out.get("serial", ""),
                "physical_size": out.get("physical_size", [0, 0]),
                "current_resolution": current_res,
                "current_rate": current_rate,
                "current_rate_string": current_rate_string,
                "scale": logical.get("scale", 1.0),
                "transform": logical.get("transform", "Normal"),
                "position": {"x": logical.get("x", 0), "y": logical.get("y", 0)},
                "vrr_supported": out.get("vrr_supported", False),
                "vrr_enabled": out.get("vrr_enabled", False),
                "resolutions": list(res_map.values()),
            }
        )

    print(json.dumps(result))
    return 0


def cmd_apply_output(args):
    """Apply temporary output changes via niri msg output."""
    if len(args) < 2:
        print(json.dumps({"error": "Usage: apply-output <name> <key=value>..."}))
        return 1

    output_name = args[0]
    changes = args[1:]
    results = []

    for change in changes:
        key, _, value = change.partition("=")
        if not value:
            results.append({"key": key, "error": "missing value"})
            continue

        if key == "mode":
            out, rc = run_niri("output", output_name, "mode", value)
        elif key == "scale":
            out, rc = run_niri("output", output_name, "scale", value)
        elif key == "transform":
            out, rc = run_niri("output", output_name, "transform", value)
        elif key == "vrr":
            out, rc = run_niri("output", output_name, "vrr", value)
        elif key == "position":
            parts = value.split(",")
            if len(parts) == 2:
                out, rc = run_niri(
                    "output", output_name, "position", "set", parts[0], parts[1]
                )
            else:
                out, rc = run_niri("output", output_name, "position", "auto")
        elif key == "dpms":
            out, rc = run_niri("output", output_name, value)
        else:
            results.append({"key": key, "error": "unknown key"})
            continue

        results.append({"key": key, "value": value, "success": rc == 0, "output": out})

    print(json.dumps({"results": results}))
    # Return non-zero if any individual apply step failed
    any_failed = any(not r.get("success", True) for r in results)
    return 1 if any_failed else 0


def cmd_persist_output(args):
    """Write output config to KDL config.d/15-outputs.kdl using surgical edits."""
    if len(args) < 2:
        print(json.dumps({"error": "Usage: persist-output <name> <key=value>..."}))
        return 1

    output_name = args[0]
    changes = dict(c.split("=", 1) for c in args[1:] if "=" in c)

    outputs_file = resolve_niri_section_file("config.d/15-outputs.kdl")
    outputs_file.parent.mkdir(parents=True, exist_ok=True)

    existing = outputs_file.read_text() if outputs_file.exists() else ""

    # Find existing output block for this name
    pattern = rf'(output\s+"{re.escape(output_name)}"\s*\{{)(.*?)(\}})'
    match = re.search(pattern, existing, re.DOTALL)

    if match:
        # Surgical edit within existing block
        block_content = match.group(2)

        for key, value in changes.items():
            if key == "mode":
                block_content = _set_in_block(block_content, "mode", f'"{value}"')
            elif key == "scale":
                block_content = _set_in_block(block_content, "scale", value)
            elif key == "transform":
                block_content = _set_in_block(block_content, "transform", f'"{value}"')
            elif key == "vrr":
                if value == "off":
                    # Remove variable-refresh-rate line
                    block_content = re.sub(
                        r"\n?\s*variable-refresh-rate[^\n]*", "", block_content
                    )
                elif value == "on-demand":
                    block_content = _set_in_block(
                        block_content, "variable-refresh-rate", "on-demand=true"
                    )
                else:
                    block_content = _set_in_block(
                        block_content, "variable-refresh-rate", ""
                    )
            elif key == "position":
                parts = value.split(",")
                if len(parts) == 2:
                    block_content = _set_in_block(
                        block_content, "position", f"x={parts[0]} y={parts[1]}"
                    )

        result = (
            existing[: match.start()]
            + match.group(1)
            + block_content
            + match.group(3)
            + existing[match.end() :]
        )
    else:
        # Create new output block
        lines = []
        if "mode" in changes:
            lines.append(f'    mode "{changes["mode"]}"')
        if "scale" in changes:
            lines.append(f"    scale {changes['scale']}")
        if "transform" in changes:
            lines.append(f'    transform "{changes["transform"]}"')
        if "position" in changes:
            parts = changes["position"].split(",")
            if len(parts) == 2:
                lines.append(f"    position x={parts[0]} y={parts[1]}")
        if "vrr" in changes:
            vrr_val = changes["vrr"]
            if vrr_val == "on-demand":
                lines.append("    variable-refresh-rate on-demand=true")
            elif vrr_val != "off":
                lines.append("    variable-refresh-rate")

        new_block = f'output "{output_name}" {{\n' + "\n".join(lines) + "\n}"

        if existing.strip():
            result = existing.rstrip() + "\n\n" + new_block + "\n"
        else:
            result = new_block + "\n"

    return _write_validated(outputs_file, result)


def _set_in_block(block_content, key, value):
    """Set a key=value inside a KDL block, preserving other content.
    If key exists, replace the line. If not, append it."""
    # Escape key for regex (handles hyphens)
    escaped = re.escape(key)
    # Try to replace existing line
    pattern = rf"(\n?\s*){escaped}\b[^\n]*"
    if re.search(pattern, block_content):
        if value:
            return re.sub(pattern, rf"\g<1>{key} {value}", block_content, count=1)
        else:
            # Flag-style (no value) like variable-refresh-rate
            return re.sub(pattern, rf"\g<1>{key}", block_content, count=1)
    else:
        # Append
        indent = "    "
        if value:
            return block_content.rstrip() + f"\n{indent}{key} {value}\n"
        else:
            return block_content.rstrip() + f"\n{indent}{key}\n"


# ─── Input ────────────────────────────────────────────────────────────


def cmd_get_input():
    """Read current input config from KDL file."""
    input_file = resolve_niri_section_file("config.d/10-input-and-cursor.kdl")

    result = {
        "keyboard": {
            "layout": "us",
            "variant": "",
            "options": "",
            "track_layout": "global",
            "repeat_delay": 250,
            "repeat_rate": 50,
            "numlock": False,
        },
        "touchpad": {
            "tap": True,
            "natural_scroll": False,
            "dwt": False,
            "dwtp": False,
            "drag_lock": False,
            "disabled_on_external_mouse": False,
            "left_handed": False,
            "middle_emulation": False,
            "accel_profile": "adaptive",
            "accel_speed": 0.0,
            "tap_button_map": "left-right-middle",
            "click_method": "button-areas",
            "scroll_method": "two-finger",
            "scroll_button_lock": False,
        },
        "mouse": {
            "natural_scroll": False,
            "left_handed": False,
            "middle_emulation": False,
            "scroll_button_lock": False,
            "accel_profile": "flat",
            "accel_speed": 0.0,
            "scroll_method": "no-scroll",
        },
        "trackpoint": {
            "natural_scroll": False,
            "left_handed": False,
            "middle_emulation": False,
            "scroll_button_lock": False,
            "accel_profile": "flat",
            "accel_speed": 0.0,
            "scroll_method": "on-button-down",
        },
        "cursor": {
            "theme": "capitaine-cursors-light",
            "size": 24,
            "hide_when_typing": True,
        },
        "general": {
            "disable_power_key_handling": False,
            "warp_mouse_to_focus": False,
            "warp_mouse_to_focus_mode": "separate",
            "focus_follows_mouse": False,
            "focus_follows_mouse_max_scroll": 0,
            "workspace_auto_back_and_forth": False,
            "mod_key": "Super",
            "mod_key_nested": "Alt",
        },
    }

    if not input_file.exists():
        print(json.dumps(result))
        return 0

    content = input_file.read_text()

    # Extract subsections — handle nested braces properly
    input_block = _extract_block(content, "input", top_level=True)
    cursor_block = _extract_block(content, "cursor", top_level=True)

    if input_block:
        kb_block = _extract_block(input_block, "keyboard")
        tp_block = _extract_block(input_block, "touchpad")
        mouse_block = _extract_block(input_block, "mouse")
        trackpoint_block = _extract_block(input_block, "trackpoint")

        # Keyboard
        if kb_block:
            xkb_block = _extract_block(kb_block, "xkb")
            if xkb_block:
                m = re.search(r'layout\s+"([^"]*)"', xkb_block)
                if m:
                    result["keyboard"]["layout"] = m.group(1)
                m = re.search(r'variant\s+"([^"]*)"', xkb_block)
                if m:
                    result["keyboard"]["variant"] = m.group(1)
                m = re.search(r'options\s+"([^"]*)"', xkb_block)
                if m:
                    result["keyboard"]["options"] = m.group(1)
            m = re.search(r"repeat-delay\s+(\d+)", kb_block)
            if m:
                result["keyboard"]["repeat_delay"] = int(m.group(1))
            m = re.search(r"repeat-rate\s+(\d+)", kb_block)
            if m:
                result["keyboard"]["repeat_rate"] = int(m.group(1))
            m = re.search(r'track-layout\s+"([^"]*)"', kb_block)
            if m:
                result["keyboard"]["track_layout"] = m.group(1)
            # numlock is a standalone flag
            result["keyboard"]["numlock"] = bool(
                re.search(r"^\s*numlock\s*$", kb_block, re.MULTILINE)
            )

        # Touchpad
        if tp_block:
            result["touchpad"]["tap"] = bool(
                re.search(r"^\s*tap\s*$", tp_block, re.MULTILINE)
            )
            result["touchpad"]["natural_scroll"] = bool(
                re.search(r"^\s*natural-scroll\s*$", tp_block, re.MULTILINE)
            )
            result["touchpad"]["dwt"] = bool(
                re.search(r"^\s*dwt\s*$", tp_block, re.MULTILINE)
            )
            result["touchpad"]["dwtp"] = bool(
                re.search(r"^\s*dwtp\s*$", tp_block, re.MULTILINE)
            )
            result["touchpad"]["drag_lock"] = bool(
                re.search(r"^\s*drag-lock\s*$", tp_block, re.MULTILINE)
            )
            result["touchpad"]["disabled_on_external_mouse"] = bool(
                re.search(
                    r"^\s*disabled-on-external-mouse\s*$",
                    tp_block,
                    re.MULTILINE,
                )
            )
            result["touchpad"]["left_handed"] = bool(
                re.search(r"^\s*left-handed\s*$", tp_block, re.MULTILINE)
            )
            result["touchpad"]["middle_emulation"] = bool(
                re.search(r"^\s*middle-emulation\s*$", tp_block, re.MULTILINE)
            )
            m = re.search(r'accel-profile\s+"([^"]*)"', tp_block)
            if m:
                result["touchpad"]["accel_profile"] = m.group(1)
            m = re.search(r"accel-speed\s+([\d.-]+)", tp_block)
            if m:
                result["touchpad"]["accel_speed"] = float(m.group(1))
            m = re.search(r'tap-button-map\s+"([^"]*)"', tp_block)
            if m:
                result["touchpad"]["tap_button_map"] = m.group(1)
            m = re.search(r'click-method\s+"([^"]*)"', tp_block)
            if m:
                result["touchpad"]["click_method"] = m.group(1)
            m = re.search(r'scroll-method\s+"([^"]*)"', tp_block)
            if m:
                result["touchpad"]["scroll_method"] = m.group(1)
            result["touchpad"]["scroll_button_lock"] = bool(
                re.search(r"^\s*scroll-button-lock\s*$", tp_block, re.MULTILINE)
            )

        # Mouse
        if mouse_block:
            m = re.search(r'accel-profile\s+"([^"]*)"', mouse_block)
            if m:
                result["mouse"]["accel_profile"] = m.group(1)
            result["mouse"]["natural_scroll"] = bool(
                re.search(r"^\s*natural-scroll\s*$", mouse_block, re.MULTILINE)
            )
            m = re.search(r"accel-speed\s+([\d.-]+)", mouse_block)
            if m:
                result["mouse"]["accel_speed"] = float(m.group(1))
            m = re.search(r'scroll-method\s+"([^"]*)"', mouse_block)
            if m:
                result["mouse"]["scroll_method"] = m.group(1)
            result["mouse"]["left_handed"] = bool(
                re.search(r"^\s*left-handed\s*$", mouse_block, re.MULTILINE)
            )
            result["mouse"]["middle_emulation"] = bool(
                re.search(r"^\s*middle-emulation\s*$", mouse_block, re.MULTILINE)
            )
            result["mouse"]["scroll_button_lock"] = bool(
                re.search(r"^\s*scroll-button-lock\s*$", mouse_block, re.MULTILINE)
            )

        # Trackpoint
        if trackpoint_block:
            m = re.search(r'accel-profile\s+"([^"]*)"', trackpoint_block)
            if m:
                result["trackpoint"]["accel_profile"] = m.group(1)
            result["trackpoint"]["natural_scroll"] = bool(
                re.search(r"^\s*natural-scroll\s*$", trackpoint_block, re.MULTILINE)
            )
            m = re.search(r"accel-speed\s+([\d.-]+)", trackpoint_block)
            if m:
                result["trackpoint"]["accel_speed"] = float(m.group(1))
            m = re.search(r'scroll-method\s+"([^"]*)"', trackpoint_block)
            if m:
                result["trackpoint"]["scroll_method"] = m.group(1)
            result["trackpoint"]["left_handed"] = bool(
                re.search(r"^\s*left-handed\s*$", trackpoint_block, re.MULTILINE)
            )
            result["trackpoint"]["middle_emulation"] = bool(
                re.search(r"^\s*middle-emulation\s*$", trackpoint_block, re.MULTILINE)
            )
            result["trackpoint"]["scroll_button_lock"] = bool(
                re.search(r"^\s*scroll-button-lock\s*$", trackpoint_block, re.MULTILINE)
            )

        result["general"]["disable_power_key_handling"] = bool(
            re.search(r"^\s*disable-power-key-handling\s*$", input_block, re.MULTILINE)
        )
        result["general"]["workspace_auto_back_and_forth"] = bool(
            re.search(
                r"^\s*workspace-auto-back-and-forth\s*$",
                input_block,
                re.MULTILINE,
            )
        )

        m = re.search(r'^\s*mod-key\s+"([^"]*)"', input_block, re.MULTILINE)
        if m:
            result["general"]["mod_key"] = m.group(1)

        m = re.search(r'^\s*mod-key-nested\s+"([^"]*)"', input_block, re.MULTILINE)
        if m:
            result["general"]["mod_key_nested"] = m.group(1)

        m = re.search(
            r'^\s*warp-mouse-to-focus(?:\s+mode="([^"]*)")?\s*$',
            input_block,
            re.MULTILINE,
        )
        if m:
            result["general"]["warp_mouse_to_focus"] = True
            result["general"]["warp_mouse_to_focus_mode"] = m.group(1) or "separate"

        m = re.search(
            r'^\s*focus-follows-mouse(?:\s+max-scroll-amount="(\d+)%")?\s*$',
            input_block,
            re.MULTILINE,
        )
        if m:
            result["general"]["focus_follows_mouse"] = True
            if m.group(1):
                result["general"]["focus_follows_mouse_max_scroll"] = int(m.group(1))

    # Cursor (top-level section, not inside input)
    if cursor_block:
        m = re.search(r'xcursor-theme\s+"([^"]*)"', cursor_block)
        if m:
            result["cursor"]["theme"] = m.group(1)
        m = re.search(r"xcursor-size\s+(\d+)", cursor_block)
        if m:
            result["cursor"]["size"] = int(m.group(1))
        result["cursor"]["hide_when_typing"] = bool(
            re.search(r"^\s*hide-when-typing\s*$", cursor_block, re.MULTILINE)
        )

    print(json.dumps(result))
    return 0


def _extract_block(content, section_name, top_level=False):
    """Extract the content of a top-level block { ... } handling nested braces.
    Returns the content BETWEEN the outermost braces, or None."""
    bounds = _find_block_bounds(content, section_name, top_level=top_level)
    if not bounds:
        return None

    _, inner_start, inner_end, _ = bounds
    return content[inner_start:inner_end]


def _find_block_bounds(content, section_name, top_level=False):
    pattern = re.compile(rf"(?:^|\n)\s*{re.escape(section_name)}\s*\{{")
    for match in pattern.finditer(content):
        if top_level and _brace_depth_before(content, match.start()) != 0:
            continue

        inner_start = match.end()
        depth = 1
        i = inner_start
        while i < len(content) and depth > 0:
            if content[i] == "{":
                depth += 1
            elif content[i] == "}":
                depth -= 1
            i += 1

        if depth == 0:
            return match.start(), inner_start, i - 1, i

    return None


def _brace_depth_before(content, pos):
    depth = 0
    for ch in content[:pos]:
        if ch == "{":
            depth += 1
        elif ch == "}" and depth > 0:
            depth -= 1
    return depth


def _has_top_level_flag(block_content, flag_name):
    depth = 0
    for raw_line in block_content.splitlines():
        stripped = raw_line.strip()
        if depth == 0 and stripped == flag_name:
            return True
        depth += raw_line.count("{") - raw_line.count("}")
    return False


# ─── Layout ───────────────────────────────────────────────────────────


def cmd_get_layout():
    """Read current layout config from KDL file."""
    layout_file = resolve_niri_section_file("config.d/20-layout-and-overview.kdl")

    result = {
        "gaps": 25,
        "center_focused": "never",
        "always_center_single_column": True,
        "empty_workspace_above_first": False,
        "default_column_display": "normal",
        "border": {
            "enabled": False,
            "width": 4,
            "active_color": "#707070",
            "inactive_color": "#d0d0d0",
            "urgent_color": "#cc4444",
        },
        "focus_ring": {
            "enabled": False,
            "width": 1,
            "active_color": "#808080",
            "inactive_color": "#505050",
        },
        "shadow": {
            "enabled": True,
            "softness": 30,
            "spread": 5,
            "offset_x": 0,
            "offset_y": 5,
            "color": "#0007",
        },
        "struts": {"left": 0, "right": 0, "top": 0, "bottom": 0},
        "overview_zoom": 0.75,
    }

    if not layout_file.exists():
        print(json.dumps(result))
        return 0

    content = layout_file.read_text()
    layout_block = _extract_block(content, "layout", top_level=True)

    if layout_block:
        m = re.search(r"gaps\s+([\d.]+)", layout_block)
        if m:
            result["gaps"] = int(float(m.group(1)))

        m = re.search(r'center-focused-column\s+"([^"]*)"', layout_block)
        if m:
            result["center_focused"] = m.group(1)

        result["always_center_single_column"] = bool(
            re.search(
                r"^\s*always-center-single-column(?:\s+true)?\s*$",
                layout_block,
                re.MULTILINE,
            )
        )
        result["empty_workspace_above_first"] = bool(
            re.search(
                r"^\s*empty-workspace-above-first(?:\s+true)?\s*$",
                layout_block,
                re.MULTILINE,
            )
        )

        m = re.search(r'default-column-display\s+"([^"]*)"', layout_block)
        if m:
            result["default_column_display"] = m.group(1)

        # Subsections with on/off flags
        for section in ["border", "focus-ring", "shadow"]:
            block = _extract_block(layout_block, section)
            if block is not None:
                py_key = section.replace("-", "_")
                # "off" on its own line means disabled
                has_off = bool(re.search(r"^\s*off\s*$", block, re.MULTILINE))
                result[py_key]["enabled"] = not has_off
                m = re.search(r"width\s+(\d+)", block)
                if m and "width" in result[py_key]:
                    result[py_key]["width"] = int(m.group(1))
                # Parse color properties (border, focus-ring, shadow)
                for color_key in [
                    "active-color",
                    "inactive-color",
                    "urgent-color",
                    "color",
                ]:
                    m = re.search(rf'{re.escape(color_key)}\s+"([^"]*)"', block)
                    if m:
                        py_color_key = color_key.replace("-", "_")
                        if py_color_key in result[py_key]:
                            result[py_key][py_color_key] = m.group(1)

                if py_key == "shadow":
                    for setting in ["softness", "spread"]:
                        m = re.search(rf"{setting}\s+([\d.-]+)", block)
                        if m:
                            result[py_key][setting] = int(float(m.group(1)))
                    m = re.search(r"offset\s+x=([\d.-]+)\s+y=([\d.-]+)", block)
                    if m:
                        result[py_key]["offset_x"] = int(float(m.group(1)))
                        result[py_key]["offset_y"] = int(float(m.group(2)))

        # Struts
        struts_block = _extract_block(layout_block, "struts")
        if struts_block:
            for edge in ["left", "right", "top", "bottom"]:
                m = re.search(rf"{edge}\s+(\d+)", struts_block)
                if m:
                    result["struts"][edge] = int(m.group(1))

    overview_block = _extract_block(content, "overview", top_level=True)
    if overview_block:
        m = re.search(r"zoom\s+([\d.]+)", overview_block)
        if m:
            result["overview_zoom"] = float(m.group(1))

    print(json.dumps(result))
    return 0


# ─── Animations ───────────────────────────────────────────────────────


ANIMATION_TYPES = [
    "workspace-switch",
    "window-open",
    "window-close",
    "horizontal-view-movement",
    "window-movement",
    "window-resize",
    "config-notification-open-close",
    "exit-confirmation-open-close",
    "screenshot-ui-open",
    "overview-open-close",
    "recent-windows-close",
]

ANIMATION_DEFAULTS = {
    "workspace-switch": {
        "mode": "spring",
        "damping_ratio": 0.98,
        "stiffness": 300,
        "epsilon": 0.0001,
    },
    "window-open": {
        "mode": "spring",
        "damping_ratio": 0.98,
        "stiffness": 300,
        "epsilon": 0.0001,
    },
    "window-close": {
        "mode": "spring",
        "damping_ratio": 0.18,
        "stiffness": 300,
        "epsilon": 0.0001,
    },
    "horizontal-view-movement": {
        "mode": "spring",
        "damping_ratio": 0.98,
        "stiffness": 300,
        "epsilon": 0.0001,
    },
    "window-movement": {
        "mode": "spring",
        "damping_ratio": 0.98,
        "stiffness": 900,
        "epsilon": 0.0001,
    },
    "window-resize": {
        "mode": "spring",
        "damping_ratio": 0.98,
        "stiffness": 300,
        "epsilon": 0.0001,
    },
    "config-notification-open-close": {
        "mode": "spring",
        "damping_ratio": 0.98,
        "stiffness": 300,
        "epsilon": 0.0001,
    },
    "exit-confirmation-open-close": {
        "mode": "spring",
        "damping_ratio": 0.6,
        "stiffness": 500,
        "epsilon": 0.01,
    },
    "screenshot-ui-open": {
        "mode": "spring",
        "damping_ratio": 0.98,
        "stiffness": 300,
        "epsilon": 0.0001,
    },
    "overview-open-close": {
        "mode": "spring",
        "damping_ratio": 1.0,
        "stiffness": 800,
        "epsilon": 0.0001,
    },
    "recent-windows-close": {
        "mode": "spring",
        "damping_ratio": 1.0,
        "stiffness": 800,
        "epsilon": 0.001,
    },
}


def cmd_get_animations():
    anim_file = resolve_niri_section_file("config.d/60-animations.kdl")

    result = {"enabled": True, "slowdown": 1.0, "types": {}}

    if not anim_file.exists():
        for t in ANIMATION_TYPES:
            result["types"][t] = dict(ANIMATION_DEFAULTS[t])
        print(json.dumps(result))
        return 0

    content = anim_file.read_text()
    anim_block = _extract_block(content, "animations", top_level=True)

    if anim_block:
        result["enabled"] = not _has_top_level_flag(anim_block, "off")
        m = re.search(r"slowdown\s+([\d.]+)", anim_block)
        if m:
            result["slowdown"] = float(m.group(1))

        for anim_type in ANIMATION_TYPES:
            anim_settings = dict(ANIMATION_DEFAULTS[anim_type])
            type_block = _extract_block(anim_block, anim_type)
            if type_block:
                spring_match = re.search(r"spring\s+(.*)", type_block)
                if spring_match:
                    anim_settings["mode"] = "spring"
                    params = spring_match.group(1)
                    for param, py_key in [
                        ("damping-ratio", "damping_ratio"),
                        ("stiffness", "stiffness"),
                        ("epsilon", "epsilon"),
                    ]:
                        m = re.search(rf"{param}=([\d.]+)", params)
                        if m:
                            anim_settings[py_key] = float(m.group(1))
                else:
                    duration_match = re.search(r"duration-ms\s+(\d+)", type_block)
                    curve_match = re.search(r'curve\s+"([^"]*)"(.*)', type_block)
                    if duration_match or curve_match:
                        anim_settings = {
                            "mode": "easing",
                            "duration_ms": int(duration_match.group(1))
                            if duration_match
                            else 150,
                            "curve": curve_match.group(1)
                            if curve_match
                            else "ease-out-expo",
                            "curve_args": curve_match.group(2).strip()
                            if curve_match
                            else "",
                        }

                has_off = bool(re.search(r"^\s*off\s*$", type_block, re.MULTILINE))
                if has_off:
                    anim_settings["off"] = True
            result["types"][anim_type] = anim_settings
    else:
        for t in ANIMATION_TYPES:
            result["types"][t] = dict(ANIMATION_DEFAULTS[t])

    print(json.dumps(result))
    return 0


# ─── Window Rules ─────────────────────────────────────────────────────


def cmd_get_window_rules():
    rules_file = resolve_niri_section_file("config.d/30-window-rules.kdl")

    result = {
        "corner_radius": 16,
        "clip_to_geometry": True,
        "inactive_opacity": 0.9,
    }

    if not rules_file.exists():
        print(json.dumps(result))
        return 0

    content = rules_file.read_text()

    # Find all window-rule blocks
    pos = 0
    while True:
        match = re.search(r"window-rule\s*\{", content[pos:])
        if not match:
            break
        block_start = pos + match.end()
        depth = 1
        i = block_start
        while i < len(content) and depth > 0:
            if content[i] == "{":
                depth += 1
            elif content[i] == "}":
                depth -= 1
            i += 1
        block = content[block_start : i - 1] if depth == 0 else ""
        pos = i

        # Check if this is the inactive-opacity rule (has match is-active=false)
        if re.search(r"match\s+is-active\s*=\s*false", block):
            m = re.search(r"opacity\s+([\d.]+)", block)
            if m:
                result["inactive_opacity"] = float(m.group(1))
        else:
            # General rule — corner radius / clip
            m = re.search(r"geometry-corner-radius\s+(\d+)", block)
            if m:
                result["corner_radius"] = int(m.group(1))
            m = re.search(r"clip-to-geometry\s+(true|false)", block)
            if m:
                result["clip_to_geometry"] = m.group(1) == "true"

    print(json.dumps(result))
    return 0


# ─── Cursor Themes ────────────────────────────────────────────────────


def cmd_list_cursor_themes():
    themes = set()
    search_dirs = []

    xdg_data = os.environ.get("XDG_DATA_HOME", os.path.expanduser("~/.local/share"))
    search_dirs.append(Path(xdg_data) / "icons")
    search_dirs.append(Path("/usr/share/icons"))
    search_dirs.append(Path(os.path.expanduser("~/.icons")))

    for icons_dir in search_dirs:
        if not icons_dir.is_dir():
            continue
        for entry in icons_dir.iterdir():
            if entry.is_dir() and (entry / "cursors").is_dir():
                themes.add(entry.name)

    print(json.dumps(sorted(themes)))
    return 0


# ─── Validate ─────────────────────────────────────────────────────────


def cmd_validate():
    config_file = get_niri_config_path()
    if not config_file.exists():
        print(
            json.dumps(
                {
                    "valid": False,
                    "config_path": str(config_file),
                    "output": "config.kdl not found",
                }
            )
        )
        return 0

    try:
        r = subprocess.run(
            ["niri", "validate", "-c", str(config_file)],
            capture_output=True,
            text=True,
            timeout=5,
        )
        print(
            json.dumps(
                {
                    "valid": r.returncode == 0,
                    "config_path": str(config_file),
                    "output": (r.stdout + r.stderr).strip(),
                }
            )
        )
    except Exception as e:
        print(
            json.dumps(
                {"valid": False, "config_path": str(config_file), "output": str(e)}
            )
        )
    return 0


def _meaningful_lines(text: str):
    return [
        line.rstrip()
        for line in text.splitlines()
        if line.strip() and not line.lstrip().startswith("//")
    ]


def _normalized_meaningful_text(text: str) -> str:
    return "\n".join(_meaningful_lines(text))


def _preview_diff(default_text: str, user_text: str, max_lines: int = 8):
    preview = []
    for line in unified_diff(
        _meaningful_lines(default_text),
        _meaningful_lines(user_text),
        fromfile="default",
        tofile="user",
        lineterm="",
    ):
        if line.startswith(("@@", "---", "+++")):
            continue
        if line.startswith(("+", "-")):
            preview.append(line)
        if len(preview) >= max_lines:
            break
    return preview


def _preview_lines(text: str, max_lines: int = 8):
    return _meaningful_lines(text)[:max_lines]


def cmd_detect_customizations():
    config_dir = get_niri_config_dir()
    defaults_dir = get_repo_default_niri_dir()
    files = []
    summary = {
        "managed_override": 0,
        "extra_file": 0,
        "expected_generated": 0,
        "user_extra": 0,
    }

    def add_file(entry):
        kind = entry.get("kind", "")
        if kind == "managed-override":
            summary["managed_override"] += 1
        elif kind == "extra-file":
            summary["extra_file"] += 1
        elif kind == "expected-generated":
            summary["expected_generated"] += 1
        elif kind == "user-extra":
            summary["user_extra"] += 1
        files.append(entry)

    for relative_path in DEFAULT_NIRI_FILES:
        user_path = config_dir / relative_path
        default_path = defaults_dir / relative_path

        if not user_path.exists() or not default_path.exists():
            continue

        user_text = user_path.read_text()
        default_text = default_path.read_text()

        if relative_path == "config.d/90-user-extra.kdl":
            preview = _preview_lines(user_text)
            if preview:
                add_file(
                    {
                        "path": relative_path,
                        "kind": "user-extra",
                        "reason": "User-owned extension file for personal Niri rules.",
                        "preview": preview,
                        "line_count": len(_meaningful_lines(user_text)),
                    }
                )
            continue

        if _normalized_meaningful_text(user_text) == _normalized_meaningful_text(
            default_text
        ):
            continue

        preview = _preview_diff(default_text, user_text)
        add_file(
            {
                "path": relative_path,
                "kind": "managed-override",
                "reason": "This managed Niri file differs from the shipped iNiR default.",
                "preview": preview if preview else _preview_lines(user_text),
                "line_count": len(_meaningful_lines(user_text)),
            }
        )

    config_d_dir = config_dir / "config.d"
    if config_d_dir.exists():
        default_set = set(DEFAULT_NIRI_FILES)
        for extra_file in sorted(config_d_dir.glob("*.kdl")):
            relative_path = str(extra_file.relative_to(config_dir))
            if relative_path in default_set:
                continue

            extra_text = extra_file.read_text()
            preview = _preview_lines(extra_text)
            if not preview:
                continue

            add_file(
                {
                    "path": relative_path,
                    "kind": "expected-generated"
                    if relative_path == "config.d/15-outputs.kdl"
                    else "extra-file",
                    "reason": "Generated by Niri output settings and expected in customized setups."
                    if relative_path == "config.d/15-outputs.kdl"
                    else "Additional user config file not shipped by iNiR defaults.",
                    "preview": preview,
                    "line_count": len(_meaningful_lines(extra_text)),
                }
            )

    actionable_count = summary["managed_override"] + summary["extra_file"]

    print(
        json.dumps(
            {
                "customized": actionable_count > 0,
                "config_dir": str(config_dir),
                "summary": {
                    **summary,
                    "actionable": actionable_count,
                    "total": len(files),
                },
                "files": files,
            }
        )
    )
    return 0


def _validate_config():
    """Run niri validate silently. Returns (valid, error_msg)."""
    config_file = get_niri_config_path()
    if not config_file.exists():
        return True, ""  # no config to validate
    try:
        r = subprocess.run(
            ["niri", "validate", "-c", str(config_file)],
            capture_output=True,
            text=True,
            timeout=5,
        )
        return r.returncode == 0, (r.stdout + r.stderr).strip()
    except Exception:
        return True, ""  # can't validate, proceed anyway


# ─── Surgical Set ─────────────────────────────────────────────────────


def cmd_set(args):
    """Surgical edit of a single config value.

    Usage: set <section> <key> <value>

    Sections and keys:
      input  keyboard.layout "es"
      input  keyboard.repeat-delay 250
      input  keyboard.repeat-rate 50
      input  keyboard.numlock on|off
      input  touchpad.tap on|off
      input  touchpad.natural-scroll on|off
      input  touchpad.dwt on|off
      input  touchpad.accel-profile "flat"|"adaptive"
      input  touchpad.accel-speed -1.0..1.0
      input  mouse.accel-profile "flat"|"adaptive"
      input  mouse.natural-scroll on|off
      input  mouse.accel-speed -1.0..1.0
      input  cursor.xcursor-theme "name"
      input  cursor.xcursor-size 24
      input  cursor.hide-when-typing on|off
      layout gaps 25
      layout center-focused-column "never"|"always"|"on-overflow"
      layout border.enabled on|off
      layout border.width 4
      layout focus-ring.enabled on|off
      layout focus-ring.width 4
      layout shadow.enabled on|off
      layout overview.zoom 0.7
      animations enabled on|off
      animations slowdown 1.0
      output <name>.<key> <value>
    """
    if len(args) < 3:
        print(json.dumps({"error": "Usage: set <section> <key> <value>"}))
        return 1

    section = args[0]
    key = args[1]
    value = args[2]

    config_dir = get_niri_config_dir()

    if section == "input":
        return _set_input(config_dir, key, value)
    elif section == "layout":
        return _set_layout(config_dir, key, value)
    elif section == "animations":
        return _set_animations(config_dir, key, value)
    elif section == "window-rules":
        return _set_window_rules(config_dir, key, value)
    elif section == "output":
        # output HDMI-A-2.mode 1920x1080@74.973
        parts = key.split(".", 1)
        if len(parts) != 2:
            print(json.dumps({"error": "output key must be <name>.<prop>"}))
            return 1
        return cmd_persist_output([parts[0], f"{parts[1]}={value}"])
    else:
        print(json.dumps({"error": f"Unknown section: {section}"}))
        return 1


def _set_input(config_dir, key, value):
    """Surgical edit in 10-input-and-cursor.kdl."""
    input_file = resolve_niri_section_file("config.d/10-input-and-cursor.kdl")
    if not input_file.exists():
        print(json.dumps({"error": "input config file not found"}))
        return 1

    content = input_file.read_text()
    parts = key.split(".", 1)

    if len(parts) == 1:
        if key == "disable-power-key-handling":
            content = _toggle_flag(content, "input", key, value == "on", top_level=True)
        elif key == "workspace-auto-back-and-forth":
            content = _toggle_flag(content, "input", key, value == "on", top_level=True)
        elif key == "warp-mouse-to-focus":
            if value == "off":
                content = _remove_key_from_section(
                    content, "input", key, top_level=True
                )
            else:
                content = _set_value_in_block(
                    content,
                    "input",
                    key,
                    'mode="center-xy"'
                    if value == "center-xy"
                    else 'mode="center-xy-always"'
                    if value == "center-xy-always"
                    else "",
                    top_level=True,
                )
        elif key == "focus-follows-mouse":
            if value == "off":
                content = _remove_key_from_section(
                    content, "input", key, top_level=True
                )
            else:
                content = _set_value_in_block(
                    content, "input", key, value if value else "", top_level=True
                )
        elif key in ("mod-key", "mod-key-nested"):
            content = _set_value_in_block(
                content, "input", key, f'"{value}"', top_level=True
            )
        else:
            print(json.dumps({"error": f"Unknown input key: {key}"}))
            return 1

        return _write_validated(input_file, content)

    subsection, prop = parts

    if subsection == "keyboard":
        if prop in ("layout", "variant", "options"):
            content = _set_xkb_value(content, prop, value)
        elif prop in ("repeat-delay", "repeat-rate"):
            content = _set_value_in_block(content, "keyboard", prop, str(value))
        elif prop == "track-layout":
            content = _set_value_in_block(content, "keyboard", prop, f'"{value}"')
        elif prop == "numlock":
            content = _toggle_flag(content, "keyboard", "numlock", value == "on")
        else:
            print(json.dumps({"error": f"Unknown keyboard prop: {prop}"}))
            return 1

    elif subsection == "touchpad":
        if prop in ("tap", "natural-scroll", "dwt", "dwtp"):
            content = _toggle_flag(content, "touchpad", prop, value == "on")
        elif prop in (
            "drag-lock",
            "disabled-on-external-mouse",
            "left-handed",
            "middle-emulation",
            "scroll-button-lock",
        ):
            content = _toggle_flag(content, "touchpad", prop, value == "on")
        elif prop == "accel-profile":
            content = _set_value_in_subsection(
                content, "touchpad", "accel-profile", f'"{value}"'
            )
        elif prop == "accel-speed":
            content = _set_value_in_subsection(
                content, "touchpad", "accel-speed", value
            )
        elif prop in ("tap-button-map", "click-method", "scroll-method"):
            content = _set_value_in_subsection(content, "touchpad", prop, f'"{value}"')
        else:
            print(json.dumps({"error": f"Unknown touchpad prop: {prop}"}))
            return 1

    elif subsection == "mouse":
        if prop == "natural-scroll":
            content = _toggle_flag(content, "mouse", prop, value == "on")
        elif prop in ("left-handed", "middle-emulation", "scroll-button-lock"):
            content = _toggle_flag(content, "mouse", prop, value == "on")
        elif prop == "accel-profile":
            content = _set_value_in_subsection(
                content, "mouse", "accel-profile", f'"{value}"'
            )
        elif prop == "accel-speed":
            content = _set_value_in_subsection(content, "mouse", "accel-speed", value)
        elif prop == "scroll-method":
            content = _set_value_in_subsection(content, "mouse", prop, f'"{value}"')
        else:
            print(json.dumps({"error": f"Unknown mouse prop: {prop}"}))
            return 1

    elif subsection == "trackpoint":
        content = _ensure_subsection(content, "input", "trackpoint")
        if prop == "natural-scroll":
            content = _toggle_flag(content, "trackpoint", prop, value == "on")
        elif prop in ("left-handed", "middle-emulation", "scroll-button-lock"):
            content = _toggle_flag(content, "trackpoint", prop, value == "on")
        elif prop == "accel-profile":
            content = _set_value_in_subsection(
                content, "trackpoint", "accel-profile", f'"{value}"'
            )
        elif prop == "accel-speed":
            content = _set_value_in_subsection(
                content, "trackpoint", "accel-speed", value
            )
        elif prop == "scroll-method":
            content = _set_value_in_subsection(
                content, "trackpoint", prop, f'"{value}"'
            )
        else:
            print(json.dumps({"error": f"Unknown trackpoint prop: {prop}"}))
            return 1

    elif subsection == "cursor":
        if prop == "xcursor-theme":
            content = _set_value_in_block(
                content, "cursor", prop, f'"{value}"', top_level=True
            )
        elif prop == "xcursor-size":
            content = _set_value_in_block(
                content, "cursor", prop, str(value), top_level=True
            )
        elif prop == "hide-when-typing":
            content = _toggle_flag(
                content, "cursor", "hide-when-typing", value == "on", top_level=True
            )
        else:
            print(json.dumps({"error": f"Unknown cursor prop: {prop}"}))
            return 1
    else:
        print(json.dumps({"error": f"Unknown input subsection: {subsection}"}))
        return 1

    return _write_validated(input_file, content)


def _set_layout(config_dir, key, value):
    layout_file = resolve_niri_section_file("config.d/20-layout-and-overview.kdl")
    if not layout_file.exists():
        print(json.dumps({"error": "layout config file not found"}))
        return 1

    content = layout_file.read_text()

    if key == "gaps":
        content = _set_value_in_block(
            content, "layout", "gaps", str(value), top_level=True
        )

    elif key == "center-focused-column":
        content = _set_value_in_block(
            content, "layout", "center-focused-column", f'"{value}"', top_level=True
        )

    elif key == "always-center-single-column":
        content = _toggle_flag(content, "layout", key, value == "on", top_level=True)

    elif key == "empty-workspace-above-first":
        content = _toggle_flag(content, "layout", key, value == "on", top_level=True)

    elif key == "default-column-display":
        content = _set_value_in_block(
            content, "layout", key, f'"{value}"', top_level=True
        )

    elif key == "overview.zoom" or key == "overview-zoom":
        content = _set_value_in_block(
            content, "overview", "zoom", str(value), top_level=True
        )

    elif "." in key:
        subsection, prop = key.split(".", 1)

        if prop == "enabled":
            # Toggle off/on flag inside a subsection block
            content = _toggle_subsection_enabled(content, subsection, value == "on")
        elif prop == "width":
            content = _set_value_in_subsection(content, subsection, "width", value)
        elif prop in ("active-color", "inactive-color", "urgent-color", "color"):
            # Color properties for border, focus-ring, shadow
            content = _set_value_in_subsection(content, subsection, prop, f'"{value}"')
        elif subsection == "shadow" and prop in ("softness", "spread"):
            content = _set_value_in_subsection(content, subsection, prop, value)
        elif subsection == "shadow" and prop == "offset":
            content = _set_shadow_offset(content, value)
        elif subsection == "struts" and prop in ("left", "right", "top", "bottom"):
            content = _ensure_subsection(content, "layout", "struts")
            content = _set_value_in_subsection(content, "struts", prop, value)
        else:
            print(json.dumps({"error": f"Unknown layout sub-prop: {key}"}))
            return 1

    else:
        print(json.dumps({"error": f"Unknown layout key: {key}"}))
        return 1

    return _write_validated(layout_file, content)


def _set_animations(config_dir, key, value):
    anim_file = resolve_niri_section_file("config.d/60-animations.kdl")
    if not anim_file.exists():
        print(json.dumps({"error": "animations config file not found"}))
        return 1

    content = anim_file.read_text()

    if key == "enabled":
        anim_block = _extract_block(content, "animations", top_level=True)
        if anim_block is None:
            print(json.dumps({"error": "animations block not found"}))
            return 1

        has_off = _has_top_level_flag(anim_block, "off")

        if value == "on" and has_off:
            content = re.sub(
                r"(animations\s*\{)\s*\n\s*off\s*\n",
                r"\g<1>\n",
                content,
                count=1,
            )
        elif value == "off" and not has_off:
            content = re.sub(
                r"(animations\s*\{)\s*\n",
                r"\g<1>\n    off\n",
                content,
                count=1,
            )

    elif key == "slowdown":
        anim_block = _extract_block(content, "animations", top_level=True)
        if anim_block and "slowdown" in anim_block:
            content = re.sub(r"(slowdown\s+)[\d.]+", rf"\g<1>{value}", content, count=1)
        else:
            content = re.sub(
                r"(animations\s*\{)\s*\n",
                rf"\g<1>\n    slowdown {value}\n",
                content,
                count=1,
            )

    elif "." in key:
        # Per-type spring param: e.g. "window-open.damping-ratio" "0.98"
        anim_type, param = key.split(".", 1)
        if anim_type not in ANIMATION_TYPES:
            print(json.dumps({"error": f"Unknown animation type: {anim_type}"}))
            return 1
        if param not in ("enabled", "damping-ratio", "stiffness", "epsilon"):
            print(json.dumps({"error": f"Unknown spring param: {param}"}))
            return 1

        anim_block = _extract_block(content, "animations", top_level=True)
        if anim_block is None:
            print(json.dumps({"error": "animations block not found"}))
            return 1

        type_block = _extract_block(anim_block, anim_type)

        if param == "enabled":
            if type_block:
                content = _toggle_flag(content, anim_type, "off", value != "on")
            elif value != "on":
                content = re.sub(
                    r"(animations\s*\{)\s*\n",
                    rf"\g<1>\n    {anim_type} {{\n        off\n    }}\n",
                    content,
                    count=1,
                )
            return _write_validated(anim_file, content)

        if type_block:
            spring_match = re.search(r"spring\s+(.*)", type_block)
            if spring_match:
                old_spring_line = spring_match.group(0)
                # Replace the specific param in the spring line
                if re.search(rf"{re.escape(param)}=[\d.]+", old_spring_line):
                    new_spring_line = re.sub(
                        rf"{re.escape(param)}=[\d.]+",
                        f"{param}={value}",
                        old_spring_line,
                    )
                else:
                    new_spring_line = old_spring_line + f" {param}={value}"
                content = content.replace(old_spring_line, new_spring_line, 1)
            else:
                # No spring line yet — add one
                type_pattern = rf"({re.escape(anim_type)}\s*\{{)"
                content = re.sub(
                    type_pattern,
                    rf"\g<1>\n        spring {param}={value}",
                    content,
                    count=1,
                )
        else:
            # Animation type block doesn't exist — create it
            content = re.sub(
                r"(animations\s*\{)\s*\n",
                rf"\g<1>\n    {anim_type} {{\n        spring {param}={value}\n    }}\n",
                content,
                count=1,
            )

    else:
        print(json.dumps({"error": f"Unknown animations key: {key}"}))
        return 1

    return _write_validated(anim_file, content)


def _set_window_rules(config_dir, key, value):
    rules_file = resolve_niri_section_file("config.d/30-window-rules.kdl")
    if not rules_file.exists():
        print(json.dumps({"error": "window rules config file not found"}))
        return 1

    content = rules_file.read_text()

    if key == "corner-radius":
        if re.search(r"geometry-corner-radius\s+\d+", content):
            content = re.sub(
                r"(geometry-corner-radius\s+)\d+",
                rf"\g<1>{value}",
                content,
                count=1,
            )
        else:
            # Insert in first window-rule block
            content = re.sub(
                r"(window-rule\s*\{)\s*\n",
                rf"\g<1>\n    geometry-corner-radius {value}\n",
                content,
                count=1,
            )

    elif key == "inactive-opacity":
        # Find the inactive rule block (has match is-active=false)
        inactive_pattern = r"(window-rule\s*\{[^}]*match\s+is-active\s*=\s*false[^}]*)(opacity\s+[\d.]+)"
        if re.search(inactive_pattern, content, re.DOTALL):
            content = re.sub(
                r"(match\s+is-active\s*=\s*false\s*\n\s*)(opacity\s+)[\d.]+",
                rf"\g<1>\g<2>{value}",
                content,
                count=1,
            )
        else:
            # No inactive rule exists — append one
            content = (
                content.rstrip()
                + f"\n\nwindow-rule {{\n    match is-active=false\n    opacity {value}\n}}\n"
            )

    elif key == "clip-to-geometry":
        if re.search(r"clip-to-geometry\s+(true|false)", content):
            content = re.sub(
                r"(clip-to-geometry\s+)(true|false)",
                rf"\g<1>{value}",
                content,
                count=1,
            )
        else:
            content = re.sub(
                r"(window-rule\s*\{)\s*\n",
                rf"\g<1>\n    clip-to-geometry {value}\n",
                content,
                count=1,
            )

    else:
        print(json.dumps({"error": f"Unknown window-rules key: {key}"}))
        return 1

    return _write_validated(rules_file, content)


# ─── Surgical helpers ─────────────────────────────────────────────────


def _write_validated(filepath, content):
    """Write content to file, then validate. If invalid, restore original and report error."""
    backup = filepath.read_text() if filepath.exists() else None
    filepath.write_text(content)

    valid, err = _validate_config()
    if not valid:
        if backup is not None:
            filepath.write_text(backup)
        else:
            filepath.unlink(missing_ok=True)
        print(json.dumps({"success": False, "error": f"Validation failed: {err}"}))
        return 1

    print(json.dumps({"success": True, "file": str(filepath)}))
    return 0


def _toggle_flag(content, parent_section, flag_name, enable, top_level=False):
    """Toggle a standalone flag (like `tap`, `natural-scroll`, `numlock`)
    inside a KDL subsection. Enable=True adds/uncomments, Enable=False
    removes/comments the flag line."""
    escaped_flag = re.escape(flag_name)

    bounds = _find_block_bounds(content, parent_section, top_level=top_level)
    if bounds is None:
        return content

    _, inner_start, inner_end, _ = bounds
    block_content = content[inner_start:inner_end]

    # Check if flag exists (uncommented)
    has_flag = bool(re.search(rf"^\s*{escaped_flag}\s*$", block_content, re.MULTILINE))
    # Check if flag exists commented out
    has_commented = bool(
        re.search(rf"^\s*//\s*{escaped_flag}\s*$", block_content, re.MULTILINE)
    )

    if enable and has_flag:
        return content  # Already enabled
    elif enable and has_commented:
        # Uncomment
        new_block = re.sub(
            rf"^(\s*)//\s*{escaped_flag}\s*$",
            rf"\g<1>{flag_name}",
            block_content,
            flags=re.MULTILINE,
            count=1,
        )
    elif enable:
        # Add flag — find good insertion point (before closing brace)
        new_block = block_content.rstrip() + f"\n        {flag_name}\n    "
    elif not enable and has_flag:
        new_block = re.sub(
            rf"^[ \t]*{escaped_flag}[ \t]*\n",
            "",
            block_content,
            flags=re.MULTILINE,
            count=1,
        )
    elif not enable and has_commented:
        return content  # Already disabled
    else:
        return content  # Flag doesn't exist and we want it off — nothing to do

    return content[:inner_start] + new_block + content[inner_end:]


def _set_value_in_subsection(content, section, prop, value):
    """Replace a key-value pair inside a section block."""
    return _set_value_in_block(content, section, prop, value)


def _remove_key_from_section(content, section, prop, top_level=False):
    bounds = _find_block_bounds(content, section, top_level=top_level)
    if not bounds:
        return content

    _, inner_start, inner_end, _ = bounds
    block_content = content[inner_start:inner_end]
    new_block = _remove_key_from_block_content(block_content, prop)
    return content[:inner_start] + new_block + content[inner_end:]


def _ensure_subsection(content, parent_section, subsection):
    parent_bounds = _find_block_bounds(content, parent_section, top_level=True)
    if not parent_bounds:
        return content

    if _find_block_bounds(content, subsection):
        return content

    _, inner_start, inner_end, _ = parent_bounds
    parent_content = content[inner_start:inner_end]
    new_parent_content = parent_content.rstrip() + f"\n    {subsection} {{\n    }}\n"
    return content[:inner_start] + new_parent_content + content[inner_end:]


def _set_value_in_block(content, section, prop, value, top_level=False):
    bounds = _find_block_bounds(content, section, top_level=top_level)
    if not bounds:
        return content

    _, inner_start, inner_end, _ = bounds
    block_content = content[inner_start:inner_end]
    new_block = _set_in_block(block_content, prop, value)
    return content[:inner_start] + new_block + content[inner_end:]


def _toggle_subsection_enabled(content, section, enable):
    """Toggle the `off` flag inside a subsection block (border, focus-ring, shadow)."""
    bounds = _find_block_bounds(content, section)
    if not bounds:
        return content

    _, inner_start, inner_end, _ = bounds
    block_content = content[inner_start:inner_end]
    has_off = bool(re.search(r"^\s*off\s*$", block_content, re.MULTILINE))

    if enable and has_off:
        new_block = re.sub(
            r"^[ \t]*off\s*\n", "", block_content, flags=re.MULTILINE, count=1
        )
    elif not enable and not has_off:
        new_block = "\n        off\n" + block_content.lstrip("\n")
    else:
        return content  # Already in desired state

    return content[:inner_start] + new_block + content[inner_end:]


def _remove_key_from_block_content(block_content, key):
    return re.sub(
        rf"\n?\s*{re.escape(key)}\b[^\n]*",
        "",
        block_content,
        count=1,
    )


def _set_xkb_value(content, prop, value):
    kb_bounds = _find_block_bounds(content, "keyboard")
    if not kb_bounds:
        return content

    kb_start, kb_inner_start, kb_inner_end, kb_end = kb_bounds
    kb_content = content[kb_inner_start:kb_inner_end]
    xkb_bounds = _find_block_bounds(kb_content, "xkb")
    if not xkb_bounds:
        return content

    _, xkb_inner_start, xkb_inner_end, _ = xkb_bounds
    xkb_content = kb_content[xkb_inner_start:xkb_inner_end]
    if value:
        new_xkb_content = _set_in_block(xkb_content, prop, f'"{value}"')
    else:
        new_xkb_content = _remove_key_from_block_content(xkb_content, prop)

    new_kb_content = (
        kb_content[:xkb_inner_start] + new_xkb_content + kb_content[xkb_inner_end:]
    )
    return content[:kb_inner_start] + new_kb_content + content[kb_inner_end:]


def _set_shadow_offset(content, value):
    parts = [part.strip() for part in str(value).split(",", 1)]
    if len(parts) != 2:
        return content
    return _set_value_in_block(
        content, "shadow", "offset", f"x={parts[0]} y={parts[1]}"
    )


# ─── Keybinds ──────────────────────────────────────────────────────────
#
# Inlined from parse_niri_keybinds.py to avoid import-path fragility when
# niri-config.py is called with a full path from the inir launcher.

_KB_ACTION_MAP = {
    "toggle-overview": "Niri Overview",
    "quit": "Quit Niri",
    "toggle-keyboard-shortcuts-inhibit": "Toggle shortcuts inhibit",
    "power-off-monitors": "Power off monitors",
    "show-hotkey-overlay": "Niri hotkey overlay",
    "close-window": "Close window",
    "maximize-column": "Maximize column",
    "maximize-window-to-edges": "Maximize to edges",
    "fullscreen-window": "Fullscreen",
    "toggle-window-floating": "Toggle floating",
    "switch-focus-between-floating-and-tiling": "Switch float/tile focus",
    "center-column": "Center column",
    "center-visible-columns": "Center visible columns",
    "expand-column-to-available-width": "Expand to available width",
    "consume-or-expel-window-left": "Consume/expel left",
    "consume-or-expel-window-right": "Consume/expel right",
    "expel-window-from-column": "Expel from column",
    "consume-window-into-column": "Consume into column",
    "switch-preset-column-width": "Cycle column width",
    "switch-preset-window-height": "Cycle window height",
    "reset-window-height": "Reset window height",
    "toggle-column-tabbed-display": "Toggle tabbed display",
    "focus-column-left": "Focus left",
    "focus-column-right": "Focus right",
    "focus-window-up": "Focus up",
    "focus-window-down": "Focus down",
    "focus-column-first": "Focus first column",
    "focus-column-last": "Focus last column",
    "focus-monitor-left": "Focus monitor left",
    "focus-monitor-right": "Focus monitor right",
    "focus-monitor-up": "Focus monitor up",
    "focus-monitor-down": "Focus monitor down",
    "move-column-left": "Move left",
    "move-column-right": "Move right",
    "move-window-up": "Move up",
    "move-window-down": "Move down",
    "move-column-to-first": "Move to first",
    "move-column-to-last": "Move to last",
    "move-column-to-monitor-left": "Move to monitor left",
    "move-column-to-monitor-right": "Move to monitor right",
    "move-column-to-monitor-up": "Move to monitor up",
    "move-column-to-monitor-down": "Move to monitor down",
    "focus-workspace-up": "Previous workspace",
    "focus-workspace-down": "Next workspace",
    "move-column-to-workspace-up": "Move to prev workspace",
    "move-column-to-workspace-down": "Move to next workspace",
    "move-workspace-up": "Move workspace up",
    "move-workspace-down": "Move workspace down",
    "screenshot": "Screenshot",
    "screenshot-screen": "Screenshot screen",
    "screenshot-window": "Screenshot window",
}

_KB_IPC_MAP = {
    ("altSwitcher", "next"): "Next window",
    ("altSwitcher", "previous"): "Previous window",
    ("overlay", "toggle"): "iNiR Overlay",
    ("overview", "toggle"): "iNiR Overview",
    ("clipboard", "toggle"): "Clipboard",
    ("lock", "activate"): "Lock screen",
    ("region", "screenshot"): "Screenshot region",
    ("region", "ocr"): "OCR region",
    ("region", "search"): "Reverse image search",
    ("wallpaperSelector", "toggle"): "Wallpaper selector",
    ("settings", "open"): "Settings",
    ("cheatsheet", "toggle"): "Cheatsheet",
    ("panelFamily", "cycle"): "Cycle panel style",
    ("session", "toggle"): "Session dialog",
    ("browser", "open"): "Browser",
    ("audio", "volumeUp"): "Volume up",
    ("audio", "volumeDown"): "Volume down",
    ("audio", "mute"): "Mute audio",
    ("audio", "micMute"): "Mute microphone",
    ("brightness", "increment"): "Brightness up",
    ("brightness", "decrement"): "Brightness down",
    ("mpris", "playPause"): "Play/Pause",
    ("mpris", "next"): "Next track",
    ("mpris", "previous"): "Previous track",
    ("notifications", "clearAll"): "Clear notifications",
    ("gamemode", "toggle"): "Toggle game mode",
    ("launcher", "terminal"): "Terminal",
    ("launcher", "close-window"): "Close window",
}

_KB_TERMINALS = [
    "foot",
    "kitty",
    "alacritty",
    "wezterm",
    "ghostty",
    "konsole",
    "gnome-terminal",
]
_KB_FILE_MANAGERS = ["dolphin", "nautilus", "thunar", "nemo", "pcmanfm", "ranger"]
_KB_BROWSERS = ["firefox", "zen-browser", "chromium", "brave", "vivaldi"]


def _kb_parse_inir_action(action: str):
    """Detect inir IPC calls and return (target, function) or None."""
    m = re.search(
        r'spawn\s+"(?:[^"]*/)?inir"\s+"ipc"\s+"call"\s+"([\w-]+)"\s+"([\w-]+)"', action
    )
    if m:
        return m.group(1), m.group(2)
    if re.search(r'spawn\s+"(?:[^"]*/)?inir"\s+"settings"(?:\s|;|$)', action):
        return "settings", "open"
    if re.search(r'spawn\s+"(?:[^"]*/)?inir"\s+"terminal"(?:\s|;|$)', action):
        return "launcher", "terminal"
    if re.search(r'spawn\s+"(?:[^"]*/)?inir"\s+"close-window"(?:\s|;|$)', action):
        return "launcher", "close-window"
    if re.search(r'spawn\s+"(?:[^"]*/)?inir"\s+"browser"(?:\s|;|$)', action):
        return "browser", "open"
    m = re.search(r'spawn\s+"(?:[^"]*/)?inir"\s+"([\w-]+)"\s+"([\w-]+)"', action)
    if m:
        return m.group(1), m.group(2)
    return None


def _kb_generate_comment(action: str) -> str:
    """Return a human-readable description for a niri action string."""
    action = action.strip()
    if action in _KB_ACTION_MAP:
        return _KB_ACTION_MAP[action]
    m = re.match(r"(focus-workspace|move-column-to-workspace)\s+(\d+)", action)
    if m:
        verb = "Focus" if "focus" in m.group(1) else "Move to"
        return f"{verb} workspace {m.group(2)}"
    m = re.match(r'set-(column-width|window-height)\s+"([+-]\d+%?)"', action)
    if m:
        target = "column" if "column" in m.group(1) else "window"
        val = m.group(2)
        direction = "Shrink" if val.startswith("-") else "Grow"
        return f"{direction} {target} {val.lstrip('+-')}"
    if action.startswith("spawn"):
        inir = _kb_parse_inir_action(action)
        if inir:
            return _KB_IPC_MAP.get(inir, f"{inir[0]} {inir[1]}")
        m = re.search(r'ipc.*call.*"(\w+)".*"(\w+)"', action)
        if m:
            return _KB_IPC_MAP.get(
                (m.group(1), m.group(2)), f"{m.group(1)} {m.group(2)}"
            )
        if "launch-terminal.sh" in action or any(t in action for t in _KB_TERMINALS):
            return "Terminal"
        if any(fm in action for fm in _KB_FILE_MANAGERS):
            return "File manager"
        if any(br in action for br in _KB_BROWSERS):
            return "Browser"
        if "wpctl" in action:
            return (
                ("Volume up" if "+" in action else "Volume down")
                if "set-volume" in action
                else "Mute toggle"
            )
        if "brightnessctl" in action or "light" in action:
            return (
                "Brightness up"
                if ("+" in action or "inc" in action)
                else "Brightness down"
            )
        if "close-window" in action:
            return "Close window"
        m = re.search(r'spawn\s+"([^"]+)"', action)
        if m:
            app = m.group(1)
            return app.split("/")[-1] if "/" in app else app
    return action[:30] + "..." if len(action) > 30 else action


def _kb_categorize(description: str, action: str) -> str:
    """Return the category name for a keybind given its description and action."""
    desc = description.lower()
    act = action.lower()

    if any(
        x in desc
        for x in [
            "niri overview",
            "quit niri",
            "inhibit",
            "power off",
            "hotkey overlay",
        ]
    ):
        return "System"
    if any(
        x in desc
        for x in [
            "inir ",
            "clipboard",
            "lock screen",
            "wallpaper",
            "settings",
            "cheatsheet",
            "panel style",
        ]
    ):
        return "iNiR Shell"
    inir = _kb_parse_inir_action(action)
    if inir:
        target, _fn = inir
        if target in (
            "overlay",
            "overview",
            "clipboard",
            "lock",
            "wallpaperSelector",
            "settings",
            "cheatsheet",
            "panelFamily",
            "session",
        ):
            return "iNiR Shell"
        if target == "altSwitcher":
            return "Window Switcher"
        if target in ("audio", "mpris"):
            return "Media"
        if target == "brightness":
            return "Brightness"
    if re.search(
        r"ipc.*call.*(overlay|overview|clipboard|lock|wallpaper|settings|cheatsheet|panelfamily)",
        act,
    ):
        return "iNiR Shell"
    if "window" in desc and ("next" in desc or "previous" in desc):
        return "Window Switcher"
    if "altswitcher" in act:
        return "Window Switcher"
    if any(x in desc for x in ["screenshot", "ocr", "image search"]):
        return "Screenshots"
    if any(x in desc for x in ["terminal", "file manager", "browser"]):
        return "Applications"
    if any(x in act for x in _KB_TERMINALS + _KB_FILE_MANAGERS + _KB_BROWSERS):
        return "Applications"
    if any(
        x in desc
        for x in [
            "close",
            "maximize",
            "fullscreen",
            "floating",
            "consume",
            "expel",
            "float/tile",
        ]
    ):
        return "Window Management"
    if "close-window" in act:
        return "Window Management"
    if any(
        x in desc
        for x in [
            "cycle column",
            "cycle window",
            "reset window",
            "center column",
            "center visible",
            "expand to available",
            "tabbed",
        ]
    ):
        return "Layout"
    if any(
        x in act
        for x in [
            "switch-preset-column",
            "switch-preset-window",
            "reset-window-height",
            "center-column",
            "center-visible",
            "expand-column",
            "toggle-column-tabbed",
        ]
    ):
        return "Layout"
    if any(
        x in desc
        for x in ["shrink column", "grow column", "shrink window", "grow window"]
    ):
        return "Resize"
    if any(x in act for x in ["set-column-width", "set-window-height"]):
        return "Resize"
    if "monitor" in desc:
        return "Monitors"
    if any(
        x in act
        for x in [
            "focus-monitor",
            "move-column-to-monitor",
            "move-window-to-monitor",
            "move-workspace-to-monitor",
        ]
    ):
        return "Monitors"
    if "focus" in desc and "workspace" not in desc:
        return "Focus"
    if "move" in desc and "workspace" not in desc and "track" not in desc:
        return "Move Windows"
    if "workspace" in desc:
        return "Workspaces"
    if any(
        x in desc
        for x in ["volume", "mute", "play", "pause", "track", "audio", "microphone"]
    ):
        return "Media"
    if "mpris" in act or "audio" in act:
        return "Media"
    if "brightness" in desc:
        return "Brightness"
    return "Other"


def _kb_find_in_block(block_lines: list, key_combo: str, check_commented: bool = False):
    """Locate a keybind in block_lines.

    Returns (start_idx, end_idx_exclusive) covering all lines of the bind
    (including any multi-line body), or None if not found.
    """
    escaped = re.escape(key_combo)
    for i, raw_line in enumerate(block_lines):
        stripped = raw_line.strip()
        if check_commented:
            if not stripped.startswith("//"):
                continue
            candidate = stripped[2:].lstrip()
        else:
            if stripped.startswith("//"):
                continue
            candidate = stripped

        if not re.match(rf"^{escaped}(?:\s|$|\{{)", candidate):
            continue

        # Single-line: { action; } on the same line
        if re.search(r"\{[^}]*\}", candidate):
            return (i, i + 1)
        # Multi-line block: opening { without matching } on same line
        if "{" in candidate:
            depth = candidate.count("{") - candidate.count("}")
            j = i + 1
            while j < len(block_lines) and depth > 0:
                inner = block_lines[j].strip()
                depth += inner.count("{") - inner.count("}")
                j += 1
            return (i, j)
        # Line with no brace at all — treat as single line
        return (i, i + 1)

    return None


# ─── Keybind commands ──────────────────────────────────────────────────


def cmd_get_binds():
    """Return structured JSON of all keybinds from 70-binds.kdl.

    Output: { binds: [...], categories: [...], config_file: "..." }
    Each bind entry includes key_combo, options, action, action_raw,
    category, description, line_number (1-based, in the file), commented.
    """
    binds_file = resolve_niri_section_file("config.d/70-binds.kdl")
    if not binds_file.exists():
        print(json.dumps({"error": f"Binds file not found: {binds_file}"}))
        return 1

    content = binds_file.read_text()
    bounds = _find_block_bounds(content, "binds", top_level=True)
    if not bounds:
        print(json.dumps({"error": "No binds { } block found in file"}))
        return 1

    _, inner_start, inner_end, _ = bounds
    block_content = content[inner_start:inner_end]

    # Line number of the first character inside the block (1-based in the full file)
    base_line = content[:inner_start].count("\n") + 1

    all_binds = []
    block_lines = block_content.split("\n")
    i = 0
    while i < len(block_lines):
        raw_line = block_lines[i]
        stripped = raw_line.strip()

        # Determine whether this is a commented-out bind
        commented = False
        candidate = stripped
        if stripped.startswith("//"):
            inner = stripped[2:].lstrip()
            # Only promote to "commented bind" if it matches the keybind pattern
            if re.match(r"^[A-Za-z0-9_][A-Za-z0-9+_]*\s*(?:[^{]*?)\{", inner):
                commented = True
                candidate = inner

        if not candidate or (stripped.startswith("//") and not commented):
            i += 1
            continue

        match = re.match(r"^([A-Za-z0-9_][A-Za-z0-9+_]*)\s*(.*?)(\{.*)$", candidate)
        if not match:
            i += 1
            continue

        key_combo = match.group(1)
        # Strip hotkey-overlay-title from the options string — it's KDL metadata, not a bind option
        options_raw = match.group(2).strip()
        options_clean = re.sub(
            r'\s*hotkey-overlay-title="[^"]*"', "", options_raw
        ).strip()
        rest = match.group(3)

        line_number = base_line + i

        action_raw = ""
        action = ""
        if re.search(r"\{[^}]*\}", rest):
            # Single-line: extract the content between { and }
            m = re.search(r"\{\s*(.*?)\s*\}", rest)
            if m:
                action_raw = m.group(1).strip()
                action = action_raw.rstrip(";")
        elif "{" in rest:
            # Multi-line: collect lines until the closing }
            action_lines = []
            i += 1
            while i < len(block_lines):
                inner_line = block_lines[i].strip()
                if inner_line == "}":
                    break
                if inner_line and not inner_line.startswith("//"):
                    action_lines.append(inner_line)
                i += 1
            action_raw = " ".join(action_lines)
            action = " ".join(ln.rstrip(";") for ln in action_lines)

        description = _kb_generate_comment(action)
        category = _kb_categorize(description, action)

        all_binds.append(
            {
                "key_combo": key_combo,
                "options": options_clean,
                "action": action,
                "action_raw": action_raw,
                "category": category,
                "description": description,
                "line_number": line_number,
                "commented": commented,
            }
        )
        i += 1

    _KB_CATEGORY_ORDER = [
        "System",
        "iNiR Shell",
        "Window Switcher",
        "Screenshots",
        "Applications",
        "Window Management",
        "Layout",
        "Resize",
        "Focus",
        "Move Windows",
        "Monitors",
        "Workspaces",
        "Media",
        "Brightness",
        "Other",
    ]
    cat_map: dict = {}
    for idx, bind in enumerate(all_binds):
        cat_map.setdefault(bind["category"], []).append(idx)

    categories = []
    seen: set = set()
    for cat in _KB_CATEGORY_ORDER:
        if cat in cat_map:
            categories.append({"name": cat, "binds": cat_map[cat]})
            seen.add(cat)
    for cat, indices in cat_map.items():
        if cat not in seen:
            categories.append({"name": cat, "binds": indices})

    print(
        json.dumps(
            {
                "binds": all_binds,
                "categories": categories,
                "config_file": str(binds_file),
            }
        )
    )
    return 0


def cmd_set_bind(args):
    """Add or update a keybind in 70-binds.kdl (surgical edit).

    Usage: set-bind KEY_COMBO ACTION [--options OPTIONS_STRING]

    If an active bind with KEY_COMBO exists it is replaced in-place.
    If a commented bind with KEY_COMBO exists it is uncommented and updated.
    Otherwise the new bind is appended before the closing } of the binds block.
    The replacement is always written as single-line: KEY [options] { action; }
    """
    if len(args) < 2:
        print(
            json.dumps(
                {"error": "Usage: set-bind KEY_COMBO ACTION [--options OPTIONS]"}
            )
        )
        return 1

    key_combo = args[0]
    action = args[1]
    options = ""
    idx = 2
    while idx < len(args):
        if args[idx] == "--options" and idx + 1 < len(args):
            options = args[idx + 1]
            idx += 2
        else:
            idx += 1

    binds_file = resolve_niri_section_file("config.d/70-binds.kdl")
    binds_file.parent.mkdir(parents=True, exist_ok=True)
    if not binds_file.exists():
        print(json.dumps({"error": f"Binds file not found: {binds_file}"}))
        return 1

    content = binds_file.read_text()
    bounds = _find_block_bounds(content, "binds", top_level=True)
    if not bounds:
        print(json.dumps({"error": "No binds { } block found in file"}))
        return 1

    _, inner_start, inner_end, _ = bounds
    block_content = content[inner_start:inner_end]
    block_lines = block_content.split("\n")

    # Prefer active bind match; fall back to commented
    span = _kb_find_in_block(block_lines, key_combo, check_commented=False)
    if span is None:
        span = _kb_find_in_block(block_lines, key_combo, check_commented=True)

    if span is not None:
        start_idx, end_idx = span
        # Preserve the indentation of the original first line
        original_indent = re.match(r"^([ \t]*)", block_lines[start_idx]).group(1)
        if options:
            replacement = f"{original_indent}{key_combo} {options} {{ {action}; }}"
        else:
            replacement = f"{original_indent}{key_combo} {{ {action}; }}"
        new_block_lines = (
            block_lines[:start_idx] + [replacement] + block_lines[end_idx:]
        )
    else:
        # Append before trailing blank lines (which sit just before the closing })
        if options:
            new_entry = f"    {key_combo} {options} {{ {action}; }}"
        else:
            new_entry = f"    {key_combo} {{ {action}; }}"
        insert_at = len(block_lines)
        while insert_at > 0 and not block_lines[insert_at - 1].strip():
            insert_at -= 1
        new_block_lines = (
            block_lines[:insert_at] + [new_entry, ""] + block_lines[insert_at:]
        )

    new_block_content = "\n".join(new_block_lines)
    new_content = content[:inner_start] + new_block_content + content[inner_end:]
    return _write_validated(binds_file, new_content)


def cmd_remove_bind(args):
    """Comment out a keybind in 70-binds.kdl (surgical edit).

    Usage: remove-bind KEY_COMBO

    Each line of the bind is commented out by prepending // (preserving
    indentation).  Returns {"success": true} on success or an error object.
    """
    if len(args) < 1:
        print(json.dumps({"error": "Usage: remove-bind KEY_COMBO"}))
        return 1

    key_combo = args[0]

    binds_file = resolve_niri_section_file("config.d/70-binds.kdl")
    if not binds_file.exists():
        print(json.dumps({"error": f"Binds file not found: {binds_file}"}))
        return 1

    content = binds_file.read_text()
    bounds = _find_block_bounds(content, "binds", top_level=True)
    if not bounds:
        print(json.dumps({"error": "No binds { } block found in file"}))
        return 1

    _, inner_start, inner_end, _ = bounds
    block_content = content[inner_start:inner_end]
    block_lines = block_content.split("\n")

    span = _kb_find_in_block(block_lines, key_combo, check_commented=False)
    if span is None:
        print(json.dumps({"error": f"Active bind not found: {key_combo}"}))
        return 1

    start_idx, end_idx = span

    # Comment out every line in the bind span
    commented_lines = []
    for line in block_lines[start_idx:end_idx]:
        if line.strip():
            lead = re.match(r"^([ \t]*)", line).group(1)
            commented_lines.append(f"{lead}// {line[len(lead) :]}")
        else:
            commented_lines.append(line)

    # If the immediately preceding non-empty line is a plain description comment
    # (not a section-header divider containing ═), comment it out too so the whole
    # block looks like a commented-out entry.
    prev_idx = start_idx - 1
    while prev_idx >= 0 and not block_lines[prev_idx].strip():
        prev_idx -= 1

    extra_prefix = []
    if prev_idx >= 0:
        prev_stripped = block_lines[prev_idx].strip()
        is_desc_comment = (
            prev_stripped.startswith("//")
            and "\u2550" not in prev_stripped  # ═ character used in section headers
            and "═" not in prev_stripped
        )
        if is_desc_comment:
            prev_line = block_lines[prev_idx]
            lead = re.match(r"^([ \t]*)", prev_line).group(1)
            extra_prefix = [f"{lead}// {prev_line[len(lead) :]}"]
            # Replace the original description line with the double-commented version
            new_block_lines = (
                block_lines[:prev_idx]
                + extra_prefix
                + commented_lines
                + block_lines[end_idx:]
            )
        else:
            new_block_lines = (
                block_lines[:start_idx] + commented_lines + block_lines[end_idx:]
            )
    else:
        new_block_lines = (
            block_lines[:start_idx] + commented_lines + block_lines[end_idx:]
        )

    new_block_content = "\n".join(new_block_lines)
    new_content = content[:inner_start] + new_block_content + content[inner_end:]
    return _write_validated(binds_file, new_content)


# ─── Main ─────────────────────────────────────────────────────────────


def main():
    if len(sys.argv) < 2:
        print(
            json.dumps(
                {
                    "error": "No command. Use: outputs, apply-output, persist-output, get-input, get-layout, get-animations, get-window-rules, list-cursor-themes, validate, detect-customizations, set, get-binds, set-bind, remove-bind"
                }
            )
        )
        return 1

    cmd = sys.argv[1]
    args = sys.argv[2:]

    commands = {
        "outputs": lambda: cmd_outputs(),
        "apply-output": lambda: cmd_apply_output(args),
        "persist-output": lambda: cmd_persist_output(args),
        "get-input": lambda: cmd_get_input(),
        "get-layout": lambda: cmd_get_layout(),
        "get-animations": lambda: cmd_get_animations(),
        "get-window-rules": lambda: cmd_get_window_rules(),
        "list-cursor-themes": lambda: cmd_list_cursor_themes(),
        "validate": lambda: cmd_validate(),
        "detect-customizations": lambda: cmd_detect_customizations(),
        "set": lambda: cmd_set(args),
        "get-binds": lambda: cmd_get_binds(),
        "set-bind": lambda: cmd_set_bind(args),
        "remove-bind": lambda: cmd_remove_bind(args),
    }

    fn = commands.get(cmd)
    if not fn:
        print(json.dumps({"error": f"Unknown command: {cmd}"}))
        return 1

    return fn()


if __name__ == "__main__":
    sys.exit(main() or 0)
