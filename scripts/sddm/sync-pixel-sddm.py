#!/usr/bin/env python3
"""Sync the ii-pixel SDDM theme with iNiR: appearance, colours, picture and avatar.

The theme holds two appearances (Main.qml picks one from theme.conf):
- classic: the Material lock replica, coloured from the generated app palette;
- iris: the iRiS lock screen, from iris.lock (layout, scene, type) and the iRiS palette.
`lock.loginScreen` chooses: auto (iris under the iRiS family, classic otherwise), classic or iris.

Run by the colour pipeline (scripts/colors/modules/60-sddm.sh). Nothing is written when it already
matches. install-pixel-sddm.sh gives the theme directory to the user, so no sudo/polkit is needed.
"""

import json
import os
import shutil
import subprocess
import tempfile

THEME_NAME = "ii-pixel"
THEME_DIR = f"/usr/share/sddm/themes/{THEME_NAME}"
THEME_CONF = os.path.join(THEME_DIR, "theme.conf")
ASSETS_DIR = os.path.join(THEME_DIR, "assets")

# Canonical template structure — restored when theme.conf is corrupted.
# Only the structural/metadata lines; the synced keys are appended by update_theme_conf().
THEME_CONF_TEMPLATE = """\
[SddmTheme]
Name=ii-pixel
Description=iNiR SDDM login screen — Material You dynamic colors
Type=sddm-theme
Author=iNiR project
Version=1.0
Website=https://github.com/snowarch/iNiR
Screenshot=
MainScript=Main.qml
ConfigFile=theme.conf

[General]
background=assets/background.png
defaultBackground=assets/background.png
blurRadius=50

# iNiR: updated automatically by sync-pixel-sddm.py"""

# When invoked via `sudo`, resolve paths against the real user's home,
# not root's home — SUDO_USER contains the original username.
_sudo_user = os.environ.get("SUDO_USER", "")
if _sudo_user:
    import pwd

    _real_home = pwd.getpwnam(_sudo_user).pw_dir
else:
    _real_home = os.path.expanduser("~")

GENERATED_DIR = os.path.join(
    os.environ.get("XDG_STATE_HOME") or os.path.join(_real_home, ".local", "state"),
    "quickshell",
    "user",
    "generated",
)
APP_PALETTE_JSON = os.path.join(GENERATED_DIR, "app-palette.json")
PALETTE_JSON = os.path.join(GENERATED_DIR, "palette.json")
COLORS_JSON = os.path.join(GENERATED_DIR, "colors.json")
IRIS_WASHI_JSON = os.path.join(GENERATED_DIR, "iris-washi.json")

CONFIG_JSON = os.path.join(
    os.environ.get("XDG_CONFIG_HOME") or os.path.join(_real_home, ".config"),
    "inir",
    "config.json",
)


def load_json(path):
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, ValueError):
        return None


def dig(data, *keys, default=None):
    for key in keys:
        if not isinstance(data, dict) or key not in data or data[key] is None:
            return default
        data = data[key]
    return data


def read_colors():
    """Classic colours from iNiR's generated palette (flat contract, or the old nested one)."""
    source = next(
        (
            path
            for path in (APP_PALETTE_JSON, PALETTE_JSON, COLORS_JSON)
            if os.path.isfile(path)
        ),
        None,
    )
    if source is None:
        print(f"[sddm-pixel] generated palette not found: {APP_PALETTE_JSON}")
        return None
    data = load_json(source) or {}

    dark = data.get("colors", {}).get("dark", {})
    if not dark:
        if "primary" in data or "on_surface" in data:
            dark = data
        else:
            print("[sddm-pixel] No dark colors in generated palette")
            return None

    return {
        "primaryColor": dark.get("app_accent") or dark.get("primary", "#cba6f7"),
        "onPrimaryColor": dark.get("app_on_accent") or dark.get("on_primary", "#1e1e2e"),
        "surfaceColor": dark.get("app_background") or dark.get("surface", "#1e1e2e"),
        "surfaceContainerColor": dark.get("app_surface")
        or dark.get("surface_container", "#181825"),
        "onSurfaceColor": dark.get("app_foreground") or dark.get("on_surface", "#cdd6f4"),
        "onSurfaceVariantColor": dark.get("app_subtext")
        or dark.get("on_surface_variant", "#9399b2"),
        "backgroundColor": dark.get("app_background") or dark.get("background", "#1e1e2e"),
        "errorColor": dark.get("error", "#f38ba8"),
    }


def read_appearance(config):
    chosen = str(dig(config, "lock", "loginScreen", default="auto"))
    if chosen in ("classic", "iris"):
        return chosen
    return "iris" if config.get("panelFamily") == "iris" else "classic"


def read_iris(config, palette):
    """The iRiS lock as theme.conf keys: what modules/iris/lock reads, resolved for SDDM's own Qt."""
    lock = dig(config, "iris", "lock", default={}) or {}
    appearance = dig(config, "iris", "appearance", default={}) or {}
    scene = lock.get("scene") or {}
    kind = lock.get("type") or {}
    clock = dig(lock, "blocks", "clock", default={}) or {}
    session = dig(lock, "blocks", "session", default={}) or {}

    washi = dig(load_json(IRIS_WASHI_JSON) or {}, "schemes", "dark", default={}) or {}
    accent = washi.get("accent") or (palette or {}).get("primaryColor") or "#a8c7fa"
    highlight = washi.get("highlight") or "#ff9f0a"
    material = "theme" if appearance.get("followTheme", True) else str(dig(appearance, "theme", "surface", default="black"))
    surface = dig(washi, "materials", material) or (palette or {}).get("backgroundColor") or "#000000"

    main_font = appearance.get("fontFamily") or "Inter"
    clock_font = {
        "main": main_font,
        "title": appearance.get("titleFontFamily") or "Inter Display",
    }.get(str(kind.get("clockFont", "numbers")), appearance.get("numbersFontFamily") or "Rubik")
    clock_colour = {"accent": accent, "highlight": highlight}.get(str(kind.get("accent", "plain")), "#ffffff")

    def flag(value):
        return "true" if value else "false"

    return {
        "irisSceneSource": scene.get("source", "desktop"),
        "irisBlur": scene.get("blur", 100),
        "irisSaturation": scene.get("saturation", 15),
        "irisDim": scene.get("dim", 0),
        "irisVignette": scene.get("vignette", 0),
        "irisScrim": scene.get("scrim", "gradient"),
        "irisScrimStrength": scene.get("scrimStrength", 100),
        "irisFit": scene.get("fit", "cover"),
        "irisSurface": surface,
        "irisDanger": washi.get("danger") or "#ff6961",
        "irisAccent": accent,
        "irisHighlight": highlight,
        "irisClockColour": clock_colour,
        "irisFontMain": main_font,
        "irisFontClock": clock_font,
        "irisTypeScale": kind.get("scale", 100),
        "irisClockSize": kind.get("clockSize", 112),
        "irisClockWeight": kind.get("clockWeight", 700),
        "irisClockTracking": kind.get("clockTracking", -2),
        "irisClockFormat": kind.get("clockFormat", "auto"),
        "irisClockSeconds": flag(kind.get("seconds", False)),
        "irisDateFormat": kind.get("dateFormat", "long"),
        "irisClock": flag(clock.get("enable", True)),
        "irisClockZone": clock.get("zone", "top"),
        "irisClockStyle": clock.get("style", "stack"),
        "irisClockDate": flag(clock.get("date", True)),
        "irisClockFx": clock.get("fx", 0.5),
        "irisClockFy": clock.get("fy", 0.4),
        "irisSessionZone": session.get("zone", "bottom"),
        "irisSessionFx": session.get("fx", 0.5),
        "irisSessionFy": session.get("fy", 0.6),
        "irisSessionWidth": session.get("width", 248),
        "irisAvatar": flag(session.get("avatar", True)),
        "irisName": flag(session.get("name", True)),
        "irisHint": flag(session.get("hint", True)),
    }


def update_theme_conf(values):
    """Set `values` in theme.conf's [General] section; the file is rewritten only when it changes.

    Self-heals corrupted files: if the [General] section or ``background=`` key are missing, the
    canonical template structure is restored before applying values.
    """
    if not os.path.isfile(THEME_CONF):
        print(f"[sddm-pixel] theme.conf not found: {THEME_CONF}")
        return False

    with open(THEME_CONF) as f:
        before = f.read()
    lines = before.split("\n")

    has_general = any("[General]" in l for l in lines)
    has_background = any(l.strip().startswith("background=") for l in lines)
    if not has_general or not has_background:
        print("[sddm-pixel] theme.conf missing structural elements — restoring template")
        lines = THEME_CONF_TEMPLATE.split("\n")

    remaining = {key: str(value) for key, value in values.items()}
    new_lines = []
    for line in lines:
        key = line.split("=", 1)[0].strip() if "=" in line else None
        if key in remaining:
            new_lines.append(f"{key}={remaining.pop(key)}")
        else:
            new_lines.append(line)
    while new_lines and new_lines[-1] == "":
        new_lines.pop()
    new_lines.extend(f"{key}={value}" for key, value in remaining.items())
    content = "\n".join(new_lines) + "\n"
    if content == before:
        return True

    try:
        with open(THEME_CONF, "w") as f:
            f.write(content)
        return True
    except PermissionError:
        print(f"[sddm-pixel] Permission denied writing {THEME_CONF}.")
        print(f"[sddm-pixel] Re-run install-pixel-sddm.sh to fix ownership.")
        return False
    except OSError as e:
        print(f"[sddm-pixel] Error writing theme.conf: {e}")
        return False


def same_file(src, dst):
    """Copies keep the source's size and mtime (copy2), so a match means nothing to copy."""
    try:
        a, b = os.stat(src), os.stat(dst)
    except OSError:
        return False
    return a.st_size == b.st_size and int(a.st_mtime) == int(b.st_mtime)


def copy_asset(src, name):
    if not os.path.isdir(ASSETS_DIR):
        try:
            os.makedirs(ASSETS_DIR, exist_ok=True)
        except OSError as e:
            print(f"[sddm-pixel] Cannot create {ASSETS_DIR}: {e}")
            return False
    dst = os.path.join(ASSETS_DIR, name)
    if same_file(src, dst):
        return True
    try:
        shutil.copy2(src, dst)
        os.chmod(dst, 0o644)
        return True
    except OSError as e:
        print(f"[sddm-pixel] Copy to {dst} failed: {e}")
        return False


def update_avatar():
    """Copy the user's avatar to a world-readable theme asset (the sddm user cannot read ~/.face)."""
    username = _sudo_user or os.environ.get("USER", "")
    candidates = [
        os.path.join(_real_home, ".face"),
        os.path.join(_real_home, ".face.icon"),
    ]
    if username:
        candidates.append(f"/var/lib/AccountsService/icons/{username}")

    src = next((p for p in candidates if p and os.path.isfile(p)), None)
    return bool(src) and copy_asset(src, "user-face.png")


VIDEO_EXTENSIONS = {".mp4", ".mkv", ".webm", ".avi", ".mov", ".gif", ".webp"}


def video_frame(video_path):
    """First frame of a video as a PNG next to it in a temp dir; None without ffmpeg."""
    if not shutil.which("ffmpeg"):
        print("[sddm-pixel] ffmpeg not found — cannot extract video frame")
        return None
    out = os.path.join(tempfile.mkdtemp(prefix="sddm-pixel-"), "frame.png")
    try:
        proc = subprocess.run(
            ["ffmpeg", "-y", "-i", video_path, "-vframes", "1", "-update", "1", "-f", "image2", out],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=15,
        )
        if proc.returncode == 0 and os.path.isfile(out):
            # The frame takes the video's mtime so an unchanged video is not extracted into a new copy.
            st = os.stat(video_path)
            os.utime(out, (st.st_atime, st.st_mtime))
            return out
    except (OSError, subprocess.SubprocessError) as e:
        print(f"[sddm-pixel] ffmpeg error: {e}")
    return None


def update_picture(path, name):
    """Copy a wallpaper (or its first video frame) into the theme as `name`."""
    if not path or not os.path.isfile(path):
        return False
    if os.path.splitext(path)[1].lower() in VIDEO_EXTENSIONS:
        dst = os.path.join(ASSETS_DIR, name)
        try:
            if os.path.isfile(dst) and int(os.stat(dst).st_mtime) == int(os.stat(path).st_mtime):
                return True
        except OSError:
            pass
        frame = video_frame(path)
        if frame is None:
            print("[sddm-pixel] Keeping the existing picture (video, no frame)")
            return False
        try:
            return copy_asset(frame, name)
        finally:
            shutil.rmtree(os.path.dirname(frame), ignore_errors=True)
    return copy_asset(path, name)


def picture_lift(path):
    """Veil for a light picture: white text needs ~4.5:1 over the blurred mean, so dim by what it lacks."""
    try:
        from PIL import Image, ImageStat

        with Image.open(path) as im:
            lum = ImageStat.Stat(im.convert("L").resize((48, 27))).mean[0] / 255
    except Exception:
        return 0
    return round(max(0.0, min(0.45, (lum - 0.42) * 0.9)), 2)


def read_wallpaper(config):
    """The desktop wallpaper the active family shows."""
    background = config.get("background", {}) or {}
    waffle_background = dig(config, "waffles", "background", default={}) or {}
    main_path = background.get("wallpaperPath", "")
    if config.get("panelFamily", "ii") == "waffle" and not waffle_background.get("useMainWallpaper", True):
        path = waffle_background.get("wallpaperPath", "") or main_path
    else:
        path = main_path
    if path and path.startswith("file://"):
        path = path[7:]
    return path if path and os.path.isfile(path) else None


def main():
    if not os.path.isdir(THEME_DIR):
        print(f"[sddm-pixel] Theme not installed at {THEME_DIR}. Run install-pixel-sddm.sh first.")
        return

    config = load_json(CONFIG_JSON) or {}
    colors = read_colors()
    appearance = read_appearance(config)
    values = {"appearance": appearance}
    if colors:
        values.update(colors)
    values["materialShapeChars"] = "true" if dig(config, "lock", "materialShapeChars", default=False) else "false"
    iris = read_iris(config, colors)
    values.update(iris)

    # The iRiS lock may show a picture of its own instead of the desktop's.
    own = str(dig(config, "iris", "lock", "scene", "path", default="") or "")
    if own.startswith("file://"):
        own = own[7:]
    values["irisPicture"] = ""
    if iris["irisSceneSource"] == "custom" and update_picture(own, "lock-picture.png"):
        values["irisPicture"] = "assets/lock-picture.png"

    # The veil is measured on the picture the chosen look shows: Classic always shows the desktop's.
    own_shown = appearance == "iris" and values["irisPicture"]
    shown = os.path.join(THEME_DIR, values["irisPicture"]) if own_shown else os.path.join(ASSETS_DIR, "background.png")
    wallpaper = read_wallpaper(config)
    if not wallpaper or not update_picture(wallpaper, "background.png"):
        print("[sddm-pixel] No wallpaper path found, keeping existing background")
    values["irisLift"] = picture_lift(shown) if os.path.isfile(shown) else 0

    if update_theme_conf(values):
        print(f"[sddm-pixel] Synced ({appearance})")
    else:
        print("[sddm-pixel] Sync failed")

    update_avatar()


if __name__ == "__main__":
    main()
