#!/usr/bin/env python3
"""Apply iNiR's KDE colors in the palette format understood by qt5ct/qt6ct.

Called under apply-gtk-theme.sh's app-theme.lock. A standalone invocation must
hold that same lock. Qt5 ignores the final Qt6 Accent role in the shared palette.
"""

import argparse
import configparser
import os
from pathlib import Path
import re
import stat
import tempfile


def read_ini(path):
    config = configparser.ConfigParser(interpolation=None, strict=False)
    config.optionxform = str
    with path.open() as stream:
        config.read_file(stream)
    return config


def palette(config, disabled=False, inactive=False):
    def color(group, key):
        section = f"Colors:{group}"
        if inactive and config.has_option(f"{section}][Inactive", key):
            section += "][Inactive"
        channels = tuple(int(value.strip()) for value in config[section][key].split(","))
        if len(channels) != 3 or any(value < 0 or value > 255 for value in channels):
            raise ValueError(f"Invalid RGB color: [{section}] {key}")
        return channels

    def foreground(group, key="ForegroundNormal"):
        return color(group, "ForegroundInactive" if disabled else key)

    def shade(rgb, factor):
        return tuple(max(0, min(255, round(value * factor))) for value in rgb)

    button = color("Button", "BackgroundNormal")
    # QPalette::ColorRole order, including NoRole at 17 and Qt6 Accent at 21.
    colors = [
        foreground("Window"),                       # WindowText
        button,                                      # Button
        shade(button, 1.5),                           # Light
        shade(button, 1.25),                          # Midlight
        shade(button, 1 / 1.5),                       # Dark
        shade(button, 1 / 1.25),                      # Mid
        foreground("View"),                         # Text
        foreground("Selection"),                    # BrightText
        foreground("Button"),                       # ButtonText
        color("View", "BackgroundNormal"),          # Base
        color("Window", "BackgroundNormal"),        # Window
        (0, 0, 0),                                   # Shadow
        color("View", "BackgroundAlternate") if disabled else color("Selection", "BackgroundNormal"),
        foreground("View" if disabled else "Selection"),  # HighlightedText
        foreground("View", "ForegroundLink"),       # Link
        foreground("View", "ForegroundVisited"),    # LinkVisited
        color("View", "BackgroundAlternate"),       # AlternateBase
        color("Window", "BackgroundNormal"),        # NoRole
        color("Tooltip", "BackgroundNormal"),       # ToolTipBase
        foreground("Tooltip"),                      # ToolTipText
        color("View", "ForegroundInactive"),        # PlaceholderText
        foreground("Window", "ForegroundActive"),   # Accent
    ]
    return ", ".join("#ff" + "".join(f"{channel:02x}" for channel in rgb) for rgb in colors)


def qsettings_string(value):
    if value.startswith("@"):
        value = "@" + value
    encoded = value.encode("utf-16-be", errors="surrogatepass")
    escaped = []
    after_hex = False
    # Qt5's default INI codec is not UTF-8; both versions read UTF-16 escapes.
    for index in range(0, len(encoded), 2):
        code = int.from_bytes(encoded[index:index + 2], "big")
        character = chr(code)
        if code < 32 or code > 126 or (after_hex and character in "0123456789abcdefABCDEF"):
            escaped.append(f"\\x{code:04x}")
            after_hex = True
        else:
            escaped.append("\\" + character if character in '\\"' else character)
            after_hex = False
    return ('"' + "".join(escaped) + '"').encode("ascii")


def qt5_value(value):
    # Qt6 writes UTF-8; retain existing escapes and typed-value syntax for Qt5.
    def escape(match):
        encoded = match[0].encode("utf-16-be")
        return "".join(f"\\x{int.from_bytes(encoded[index:index + 2], 'big'):04x}"
                       for index in range(0, len(encoded), 2))

    return re.sub(r"[^\x00-\x7f]+[0-9a-fA-F]*", escape,
                  value.decode("utf-8", errors="replace")).encode("ascii")


def ini_records(contents):
    start = index = 0
    equals = comment = None
    quoted = False
    while index < len(contents):
        character = contents[index]
        if comment is None:
            if character == 92:
                index += 1
                if (index + 1 < len(contents)
                        and contents[index:index + 2] in (b"\r\n", b"\n\r")):
                    index += 1
                index += 1
                continue
            if character == 34:
                quoted = not quoted
            elif not quoted:
                if character == 59:
                    comment = index
                elif character == 61 and equals is None:
                    equals = index
        if character in (10, 13) and (comment is not None or not quoted):
            end = index + (2 if contents[index:index + 2] in (b"\r\n", b"\n\r") else 1)
            yield contents[start:end], None if equals is None else equals - start, (comment if comment is not None else index) - start
            start = index = end
            equals = comment = None
            quoted = False
        else:
            index += 1
    if start < len(contents):
        yield contents[start:], None if equals is None else equals - start, (comment if comment is not None else len(contents)) - start


def ini_key(value):
    return re.sub(rb"%(?:U([0-9a-fA-F]{4})|([0-9a-fA-F]{2}))",
                  lambda match: chr(int(match[1] or match[2], 16)).encode("utf-8", errors="surrogatepass"), value.strip())


def appearance_entries(contents):
    # Qt's typed values and escapes are not ConfigParser's INI dialect.
    # Only the owned Appearance assignments may be rewritten.
    lines = []
    appearance = False
    insertion = None
    assignments = {}
    for index, (line, equals, end) in enumerate(ini_records(contents)):
        lines.append(line)
        stripped = line[:end].strip()
        if index == 0:
            stripped = stripped.removeprefix(b"\xef\xbb\xbf")
        if stripped.startswith(b"[") and b"]" in stripped:
            if appearance:
                insertion = index
            appearance = ini_key(stripped[1:].partition(b"]")[0]) == b"Appearance"
            if appearance:
                insertion = index + 1
        elif appearance and equals is not None:
            key = ini_key(line[:equals])
            assignments.setdefault(key, []).append((index, equals + 1, end))
    if appearance:
        insertion = len(lines)
    return lines, assignments, insertion


def appearance_value(contents, key):
    lines, assignments, _ = appearance_entries(contents)
    if key not in assignments:
        return b""
    index, start, end = assignments[key][-1]
    return lines[index][start:end].strip()


def is_empty(value):
    return value in (b"", b'""')


def update_appearance(contents, values):
    lines, assignments, insertion = appearance_entries(contents)
    ending = re.search(rb"\r\n|\n\r|\r|\n", contents)
    newline = ending[0] if ending else b"\n"

    values = dict(values)
    if is_empty(appearance_value(contents, b"style")):
        values[b"style"] = b"Darkly"

    missing = []
    for key, value in values.items():
        if key not in assignments:
            missing.append(key + b"=" + value + newline)
        for index, start, end in assignments.get(key, []):
            line = lines[index]
            lines[index] = line[:start] + value + line[end:]

    if missing:
        if insertion is None:
            insertion = len(lines)
            missing.insert(0, b"[Appearance]" + newline)
        if insertion and not lines[insertion - 1].endswith((b"\n", b"\r")):
            missing.insert(0, newline)
        lines[insertion:insertion] = missing
    return b"".join(lines)


def write_if_changed(path, contents):
    # Preserve an existing configuration-file symlink and its target's mode.
    path = path.resolve()
    if path.is_file() and path.read_bytes() == contents:
        return False
    path.parent.mkdir(parents=True, exist_ok=True)
    mode = stat.S_IMODE(path.stat().st_mode) if path.exists() else 0o644
    fd, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(contents)
            stream.flush()
            os.fchmod(stream.fileno(), mode)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
    return True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="iNiR-generated KDE .colors file")
    parser.add_argument("--icon-theme", default="", help="Resolved icon family; preserve current choice when empty")
    parser.add_argument("--fallback-icon-theme", default="Adwaita", help="Icon theme for configurations without a selection")
    args = parser.parse_args()
    config_home = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
    data_home = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local/share")
    output = data_home / "color-schemes/iNiR-qtct.conf"
    source = read_ini(args.source)
    contents = "; Generated by iNiR; shared Qt5/Qt6 QPalette roles.\n[ColorScheme]\n"
    contents += f"active_colors={palette(source)}\n"
    contents += f"inactive_colors={palette(source, inactive=True)}\n"
    contents += f"disabled_colors={palette(source, disabled=True)}\n"

    configs = {}
    for toolkit in ("qt5ct", "qt6ct"):
        target = config_home / toolkit / f"{toolkit}.conf"
        configs[toolkit] = (target, target.read_bytes() if target.exists() else b"")
    qt6_icon = appearance_value(configs["qt6ct"][1], b"icon_theme")
    updates = []
    for toolkit, (target, config) in configs.items():
        appearance = {
            b"color_scheme_path": qsettings_string(str(output)),
            b"custom_palette": b"true",
        }
        if args.icon_theme:
            appearance[b"icon_theme"] = qsettings_string(args.icon_theme)
        elif is_empty(appearance_value(config, b"icon_theme")):
            appearance[b"icon_theme"] = qt5_value(qt6_icon) if not is_empty(qt6_icon) else qsettings_string(args.fallback_icon_theme)
        updates.append((target, update_appearance(config, appearance)))

    palette_changed = write_if_changed(output, contents.encode("utf-8"))
    notifications = set()
    for target, contents in updates:
        config_changed = write_if_changed(target, contents)
        if palette_changed or config_changed:
            notifications.add(target.parent)
    # qtct watches its config directory, including when the file is a symlink.
    for directory in notifications:
        os.utime(directory, None)


if __name__ == "__main__":
    main()
