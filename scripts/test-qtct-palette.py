#!/usr/bin/env python3
"""Check Qt palette files and preserve hand-edited qtct configuration."""

import configparser
import fcntl
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

HELPER = Path(__file__).resolve().parent / "colors/apply-qtct-theme.py"
OPAQUE = r'''[Fonts]
# Keep custom Qt values verbatim.
general="@Variant(\0\0\0@\0\0\0\x1a\0N\0o\0t\0o\0 \0S\0\x61\0n\0s\0 e\xe5g,\x8a\x9e@&\0\0\0\0\0\0\xff\xff\xff\xff\x5\x1\0\x32\x10)"
[Interface]
bytes=@ByteArray(a\0\x62\n\xff)
list=one, "two,three", "#four;five"
text="@@literal, semicolon; #quote\" slash\\ line\nnext\tend"
; Keep this comment too.
'''


def source_text(light=False):
    background, foreground = ("239,240,241", "35,38,41") if light else ("17,17,19", "245,245,247")
    sections = []
    for group in ("Window", "View", "Button", "Selection", "Tooltip"):
        bg = "61,174,233" if group == "Selection" else background
        fg = "255,255,255" if group == "Selection" else foreground
        sections.append(f"""[Colors:{group}]
BackgroundNormal={bg}
BackgroundAlternate=31,32,33
ForegroundNormal={fg}
ForegroundInactive=110,111,112
ForegroundActive=71,174,199
ForegroundLink=41,128,185
ForegroundVisited=155,89,182
""")
    return "\n".join(sections) + "\n[Colors:Window][Inactive]\nForegroundNormal=101,102,103\n"


def run(home, source, *arguments, success=True):
    env = {"PATH": os.environ.get("PATH", "/usr/bin:/bin"), "HOME": str(home)}
    for name, directory in (("CONFIG", "config"), ("DATA", "data"), ("STATE", "state"), ("CACHE", "cache")):
        env[f"XDG_{name}_HOME"] = str(home / directory)
    with (home / "app-theme.lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        result = subprocess.run([sys.executable, str(HELPER), str(source), *arguments], env=env, capture_output=True, text=True)
    assert (result.returncode == 0) == success, result.stderr or "invalid source was accepted"


def config_path(home, version):
    return home / f"config/qt{version}ct/qt{version}ct.conf"


def read_palette(home):
    text = (home / "data/color-schemes/iNiR-qtct.conf").read_text()
    assert not any(line.lstrip().startswith("#") for line in text.splitlines()), "QSettings comments must use semicolons"
    config = configparser.ConfigParser()
    config.read_string(text)
    groups = {key: [value.strip() for value in config["ColorScheme"][key].split(",")]
              for key in ("active_colors", "inactive_colors", "disabled_colors")}
    for colors in groups.values():
        assert len(colors) == 22, "Qt6 requires an Accent entry after the Qt5 roles"
        assert all(re.fullmatch(r"#[0-9a-fA-F]{8}", color) for color in colors)
    return groups


def snapshot(paths):
    return [(path.read_bytes(), path.stat().st_mtime_ns, path.stat().st_ino) for path in paths]


def check_qsettings_syntax(root):
    home = root / "qsettings-syntax"
    home.mkdir()
    source = home / "source.colors"
    source.write_text(source_text())
    for ending in (b"\n", b"\r\n", b"\r", b"\n\r"):
        opaque = (b'[Interface]\ntext="first\n[Appearance]\nstyle=inside a string\nlast"\n'
                  b'[ %41ppearance ]\n%73tyle=Fusion\n%U0073tyle=Fusion\n'
                  b'%u0073tyle=unrelated\n%UD83D%UDE00=emoji key\n'
                  b'continued=one\\\nicon_theme=two\n'
                  b'quoted="first\ncustom_palette=false\nlast"\n').replace(b"\n", ending)
        for version in (5, 6):
            path = config_path(home, version)
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(opaque + b'color_scheme_path=old\\' + ending + b'path' + ending
                             + b'custom_palette=false ; keep comment' + ending)
        run(home, source, "--icon-theme", "NewIcon")
        for version in (5, 6):
            result = config_path(home, version).read_bytes()
            assert result.startswith(opaque), "logical values and escaped Appearance keys must survive"
            assert b'icon_theme="NewIcon"' + ending in result, "a continuation is not an icon assignment"
            assert b'custom_palette=true; keep comment' + ending in result
            assert b'old\\' not in result and b'path' + ending not in result, "replace the entire continued path"
            assert b'Darkly' not in result, "preserve a style in an escaped or whitespace-padded section"
        paths = [config_path(home, version) for version in (5, 6)]
        before = snapshot(paths)
        run(home, source, "--icon-theme", "NewIcon")
        assert snapshot(paths) == before, "logical-line updates must be idempotent"

    for version in (5, 6):
        config_path(home, version).write_bytes(b'[Appearance]\nstyle="" ; style comment\nicon_theme= ; icon comment\n')
    run(home, source, "--fallback-icon-theme", "fallback")
    for version in (5, 6):
        result = config_path(home, version).read_bytes()
        assert b'style=Darkly; style comment\n' in result
        assert b'icon_theme="fallback"; icon comment\n' in result

    raw_icon = '"@@theme éa😀,semi;hash#quote\\"slash\\\\tail"'.encode("utf-8")
    config_path(home, 5).write_bytes(b'[Appearance]\n')
    config_path(home, 6).write_bytes(b'[Appearance]\nicon_theme=' + raw_icon + b'\n')
    run(home, source)
    expected = raw_icon.replace('éa😀'.encode("utf-8"), br'\x00e9\x0061\xd83d\xde00')
    assert b'icon_theme=' + expected + b'\n' in config_path(home, 5).read_bytes(), "Qt5 needs escaped UTF-16 when inheriting a Qt6 UTF-8 icon"
    assert b'icon_theme=' + raw_icon + b'\n' in config_path(home, 6).read_bytes(), "preserve Qt6's existing icon bytes"


def main():
    with tempfile.TemporaryDirectory(prefix="inir-qtct-test-") as temporary:
        root = Path(temporary)
        for light in (False, True):
            home = root / ("light" if light else "dark")
            home.mkdir()
            source = home / "source.colors"
            source.write_text(source_text(light))
            for version, style in ((5, "Fusion"), (6, "Breeze")):
                path = config_path(home, version)
                path.parent.mkdir(parents=True)
                path.write_text(f"# Personal preferences\n[Appearance]\nstyle={style}\nicon_theme=personal\n\n" + OPAQUE)
            target = home / "linked-qt5ct.conf"
            config_path(home, 5).rename(target)
            target.chmod(0o600)
            config_path(home, 5).symlink_to(target)

            run(home, source, "--icon-theme", "Papirus")
            groups = read_palette(home)
            active, inactive, disabled = (groups[f"{group}_colors"] for group in ("active", "inactive", "disabled"))
            background, foreground = ("#ffeff0f1", "#ff232629") if light else ("#ff111113", "#fff5f5f7")
            assert active[9:11] == [background, background], "Base and Window must follow the source"
            assert active[6] == foreground and active[12:14] == ["#ff3daee9", "#ffffffff"]
            assert active[21] == "#ff47aec7", "Accent must retain the source accent color"
            assert inactive[0] == "#ff656667" and inactive[10] == background, "partial inactive groups must fall back per key"
            assert disabled[6] == "#ff6e6f70" and disabled[12] == "#ff1f2021"
            for version, style in ((5, "Fusion"), (6, "Breeze")):
                text = config_path(home, version).read_text()
                assert OPAQUE in text and text.startswith("# Personal preferences\n")
                assert f"style={style}\n" in text, "existing styles must survive palette changes"
                config = configparser.ConfigParser(interpolation=None)
                config.read_string(text)
                assert config["Appearance"]["icon_theme"].strip('"') == "Papirus"
                assert config["Appearance"]["custom_palette"] == "true"
                assert Path(config["Appearance"]["color_scheme_path"].strip('"')).is_file()
            assert config_path(home, 5).is_symlink() and target.stat().st_mode & 0o777 == 0o600

            outputs = [home / "data/color-schemes/iNiR-qtct.conf", config_path(home, 5), config_path(home, 6)]
            before = snapshot(outputs)
            directories = [config_path(home, version).parent for version in (5, 6)]
            directory_times = [directory.stat().st_mtime_ns for directory in directories]
            run(home, source)
            assert snapshot(outputs) == before, "an unchanged palette must not rewrite files or reset icons"
            assert [directory.stat().st_mtime_ns for directory in directories] == directory_times, "unchanged inputs must not notify Qt applications"
            for invalid in (source_text(light).replace("[Colors:Window]", "[Missing:Window]"),
                            source_text(light).replace("ForegroundActive=71,174,199", "ForegroundActive=999,174,199")):
                source.write_text(invalid)
                run(home, source, success=False)
                assert snapshot(outputs) == before, "invalid sources must not partly update settings"
            source.write_text(source_text(not light))
            run(home, source)
            assert snapshot(outputs[1:]) == before[1:], "a palette-only change must preserve configuration files"
            assert all(directory.stat().st_mtime_ns != timestamp for directory, timestamp in zip(directories, directory_times)), "palette changes must notify both qtct directories, including file symlinks"

        home = root / "new-config"
        home.mkdir()
        source = home / "source.colors"
        source.write_text(source_text())
        path = config_path(home, 5)
        path.parent.mkdir(parents=True)
        path.write_text('[Appearance]\nstyle=""\nicon_theme=personal\n')
        run(home, source, "--fallback-icon-theme", "fallback-theme")
        for version in (5, 6):
            config = configparser.ConfigParser()
            config.read(config_path(home, version))
            assert config["Appearance"]["style"].strip('"') == "Darkly", "unset styles must follow iNiR's Darkly default"
            assert config["Appearance"]["icon_theme"].strip('"') == ("personal" if version == 5 else "fallback-theme")

        for version in (5, 6):
            config_path(home, version).write_text("[Appearance]\n")
        run(home, source, "--fallback-icon-theme", "fallback-theme")
        for version in (5, 6):
            config = configparser.ConfigParser()
            config.read(config_path(home, version))
            assert config["Appearance"]["icon_theme"].strip('"') == "fallback-theme"

        encoded_icon = r'icon_theme="@@personal, \x00e9\x0061"' + "\n"
        config_path(home, 5).write_text("[Appearance]\n")
        config_path(home, 6).write_text("[Appearance]\n" + encoded_icon)
        run(home, source)
        assert all(encoded_icon in config_path(home, version).read_text() for version in (5, 6)), "Qt5 must inherit Qt6's encoded icon without re-encoding it"
        check_qsettings_syntax(root)
    print("qtct palette: dark/light roles, inactive fallback, settings preservation, idempotence and invalid-input safety pass")
    return 0


if __name__ == "__main__":
    sys.exit(main())
