#!/usr/bin/env python3
"""Key labels for the on-screen keyboard, straight from xkbcommon.

Usage: osk-layout-labels.py "<layout description>"   (as niri/Hyprland report it, e.g. "Arabic")

Prints JSON: {"layout": "ara", "variant": "", "iso": bool, "keys": {"<evdev keycode>": [plain, shift]},
              "letters": [keycodes that type a letter], "combine": {"<keycode>": [plain, shift combining mark]}}
The OSK types evdev keycodes and the compositor's xkb keymap turns them into text, so labelling the
keys with what this same keymap produces is exactly what gets typed, for any layout.
"""

import ctypes
import ctypes.util
import json
import sys
import unicodedata

EVDEV_OFFSET = 8
# Printable keys of a 105-key board (evdev codes); control keys keep their own labels.
KEYCODES = list(range(2, 14)) + list(range(16, 28)) + list(range(30, 42)) + list(range(43, 54)) + [86]
# What a dead key adds to the next letter, for surfaces that type text themselves (the lock keyboard).
DEAD_COMBINING = {
    "grave": "\u0300", "acute": "\u0301", "circumflex": "\u0302", "tilde": "\u0303", "macron": "\u0304",
    "breve": "\u0306", "abovedot": "\u0307", "diaeresis": "\u0308", "abovering": "\u030a",
    "doubleacute": "\u030b", "caron": "\u030c", "cedilla": "\u0327", "ogonek": "\u0328",
    "belowdot": "\u0323", "hook": "\u0309", "horn": "\u031b",
}
DEAD_KEYS = {
    "grave": "`", "acute": "´", "circumflex": "^", "tilde": "~", "macron": "¯", "breve": "˘",
    "abovedot": "˙", "diaeresis": "¨", "abovering": "˚", "doubleacute": "˝", "caron": "ˇ",
    "cedilla": "¸", "ogonek": "˛", "iota": "ͺ", "belowdot": ".", "hook": "̉", "horn": "̛",
    "stroke": "/", "greek": "α", "currency": "¤",
}


class RuleNames(ctypes.Structure):
    _fields_ = [(n, ctypes.c_char_p) for n in ("rules", "model", "layout", "variant", "options")]


def load_xkb():
    path = ctypes.util.find_library("xkbcommon") or "libxkbcommon.so.0"
    xkb = ctypes.CDLL(path)
    xkb.xkb_context_new.restype = ctypes.c_void_p
    xkb.xkb_context_new.argtypes = [ctypes.c_int]
    xkb.xkb_context_include_path_get.restype = ctypes.c_char_p
    xkb.xkb_context_include_path_get.argtypes = [ctypes.c_void_p, ctypes.c_uint]
    xkb.xkb_context_num_include_paths.restype = ctypes.c_uint
    xkb.xkb_context_num_include_paths.argtypes = [ctypes.c_void_p]
    xkb.xkb_keymap_new_from_names.restype = ctypes.c_void_p
    xkb.xkb_keymap_new_from_names.argtypes = [ctypes.c_void_p, ctypes.POINTER(RuleNames), ctypes.c_int]
    xkb.xkb_keymap_mod_get_index.restype = ctypes.c_uint
    xkb.xkb_keymap_mod_get_index.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
    xkb.xkb_state_new.restype = ctypes.c_void_p
    xkb.xkb_state_new.argtypes = [ctypes.c_void_p]
    xkb.xkb_state_update_mask.argtypes = [ctypes.c_void_p] + [ctypes.c_uint] * 6
    xkb.xkb_state_key_get_utf8.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_char_p, ctypes.c_size_t]
    xkb.xkb_state_key_get_one_sym.restype = ctypes.c_uint
    xkb.xkb_state_key_get_one_sym.argtypes = [ctypes.c_void_p, ctypes.c_uint]
    xkb.xkb_keysym_get_name.argtypes = [ctypes.c_uint, ctypes.c_char_p, ctypes.c_size_t]
    return xkb


def resolve(xkb, ctx, description):
    """Layout description → (layout, variant), read from the rules xkbcommon itself uses."""
    for i in range(xkb.xkb_context_num_include_paths(ctx)):
        root = xkb.xkb_context_include_path_get(ctx, i).decode()
        try:
            text = open(f"{root}/rules/evdev.lst", encoding="utf-8").read()
        except OSError:
            continue
        section = ""
        for line in text.splitlines():
            if line.startswith("! "):
                section = line[2:].strip()
                continue
            parts = line.split(None, 1)
            if len(parts) < 2:
                continue
            name, desc = parts[0], parts[1].strip()
            if section == "layout" and desc == description:
                return name, ""
            if section == "variant" and ":" in desc:
                layout, vdesc = desc.split(":", 1)
                if vdesc.strip() == description:
                    return layout.strip(), name
    return None, None


def dead_name(xkb, state, keycode):
    name = ctypes.create_string_buffer(64)
    xkb.xkb_keysym_get_name(xkb.xkb_state_key_get_one_sym(state, keycode), name, 64)
    sym = name.value.decode()
    return sym[5:] if sym.startswith("dead_") else ""


def label(xkb, state, keycode):
    buf = ctypes.create_string_buffer(64)
    xkb.xkb_state_key_get_utf8(state, keycode, buf, 64)
    text = buf.value.decode("utf-8", "replace")
    if not text:
        name = ctypes.create_string_buffer(64)
        xkb.xkb_keysym_get_name(xkb.xkb_state_key_get_one_sym(state, keycode), name, 64)
        sym = name.value.decode()
        return DEAD_KEYS.get(sym[5:], "") if sym.startswith("dead_") else ""
    if not text.isprintable() or text.isspace():
        return ""
    # A lone combining mark (Arabic harakat, Hebrew points) is drawn on a dotted circle.
    if all(unicodedata.combining(c) for c in text):
        return "◌" + text
    return text


def main():
    if len(sys.argv) != 2:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    xkb = load_xkb()
    ctx = xkb.xkb_context_new(0)
    layout, variant = resolve(xkb, ctx, sys.argv[1])
    if not layout:
        print(json.dumps({"error": f"unknown layout: {sys.argv[1]}"}))
        return 1
    names = RuleNames(b"evdev", b"pc105", layout.encode(), variant.encode(), b"")
    keymap = xkb.xkb_keymap_new_from_names(ctx, ctypes.byref(names), 0)
    if not keymap:
        print(json.dumps({"error": f"xkbcommon could not compile {layout}({variant})"}))
        return 1
    plain = xkb.xkb_state_new(keymap)
    shifted = xkb.xkb_state_new(keymap)
    shift_mask = 1 << xkb.xkb_keymap_mod_get_index(keymap, b"Shift")
    xkb.xkb_state_update_mask(shifted, shift_mask, 0, 0, 0, 0, 0)

    keys = {}
    combine = {}
    letters = []
    for code in KEYCODES:
        # Every printable key is listed, empty when this layout types nothing there.
        keys[str(code)] = [label(xkb, plain, code + EVDEV_OFFSET), label(xkb, shifted, code + EVDEV_OFFSET)]
        dead = [DEAD_COMBINING.get(dead_name(xkb, st, code + EVDEV_OFFSET), "") for st in (plain, shifted)]
        if any(dead):
            combine[str(code)] = dead
        if unicodedata.category(keys[str(code)][0].replace("◌", "")[:1] or " ")[0] in "LM":
            letters.append(code)
    # The ISO key (between left Shift and Z) only matters when it types something no other key does.
    elsewhere = {c for code, pair in keys.items() if code != "86" for c in pair}
    iso = any(c and c not in elsewhere for c in keys.get("86", []))
    print(json.dumps({"layout": layout, "variant": variant, "iso": iso, "keys": keys,
                      "letters": letters, "combine": combine}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
