#!/usr/bin/env python3
"""Sync inir-pixel SDDM theme colors with current Material You palette.

Reads generated colors from matugen's colors.json and updates
the inir-pixel theme.conf with matching colors.
Reads wallpaper path from iNiR state and updates background image.

Note: install-pixel-sddm.sh transfers ownership of the theme directory to
the current user at install time, so no sudo/polkit is required here.
"""

import json
import os
import shutil
import subprocess
import sys

THEME_NAME = "inir-pixel"
THEME_DIR = f"/usr/share/sddm/themes/{THEME_NAME}"
THEME_CONF = os.path.join(THEME_DIR, "theme.conf")
ASSETS_DIR = os.path.join(THEME_DIR, "assets")

# When invoked via `sudo`, resolve paths against the real user's home,
# not root's home — SUDO_USER contains the original username.
_sudo_user = os.environ.get("SUDO_USER", "")
if _sudo_user:
    import pwd
    _real_home = pwd.getpwnam(_sudo_user).pw_dir
else:
    _real_home = os.path.expanduser("~")

STATE_DIR = os.path.join(
    os.environ.get("XDG_STATE_HOME") or os.path.join(_real_home, ".local", "state"),
    "quickshell",
)
COLORS_JSON = os.path.join(STATE_DIR, "user", "generated", "colors.json")

CONFIG_JSON = os.path.join(
    os.environ.get("XDG_CONFIG_HOME") or os.path.join(_real_home, ".config"),
    "inir",
    "config.json",
)


def read_colors():
    """Read Material You colors from matugen's colors.json.

    Handles both output formats:
    - Flat:   { "primary": "#...", "on_primary": "#...", ... }   (modern matugen)
    - Nested: { "colors": { "dark": { "primary": "#...", ... } } }
    """
    if not os.path.isfile(COLORS_JSON):
        print(f"[sddm-pixel] colors.json not found: {COLORS_JSON}")
        return None
    with open(COLORS_JSON) as f:
        data = json.load(f)

    # Try nested format first, then fall back to flat
    dark = data.get("colors", {}).get("dark", {})
    if not dark:
        # Flat format: keys are directly on the root object
        if "primary" in data or "on_surface" in data:
            dark = data
        else:
            print("[sddm-pixel] No dark colors in colors.json")
            return None

    return {
        "primaryColor":          dark.get("primary",                "#cba6f7"),
        "onPrimaryColor":        dark.get("on_primary",             "#1e1e2e"),
        "surfaceColor":          dark.get("surface",                "#1e1e2e"),
        "surfaceContainerColor": dark.get("surface_container",      "#181825"),
        "onSurfaceColor":        dark.get("on_surface",             "#cdd6f4"),
        "onSurfaceVariantColor": dark.get("on_surface_variant",     "#9399b2"),
        "backgroundColor":       dark.get("background",             "#1e1e2e"),
        "errorColor":            dark.get("error",                  "#f38ba8"),
    }


def read_wallpaper():
    """Read current wallpaper path from iNiR config.json."""
    if not os.path.isfile(CONFIG_JSON):
        return None
    try:
        with open(CONFIG_JSON) as f:
            config = json.load(f)
        path = (config.get("background", {}) or {}).get("wallpaperPath", "")
        if path and path.startswith("file://"):
            path = path[7:]
        return path if path and os.path.isfile(path) else None
    except Exception:
        return None


def read_material_shape_chars():
    """Mirror lockscreen password behavior flag into SDDM theme config."""
    if not os.path.isfile(CONFIG_JSON):
        return "false"
    try:
        with open(CONFIG_JSON) as f:
            config = json.load(f)
        val = (config.get("lock", {}) or {}).get("materialShapeChars", False)
        return "true" if bool(val) else "false"
    except Exception:
        return "false"


def update_theme_conf(colors):
    """Update inir-pixel theme.conf [General] section with new colors."""
    if not os.path.isfile(THEME_CONF):
        print(f"[sddm-pixel] theme.conf not found: {THEME_CONF}")
        return False

    with open(THEME_CONF) as f:
        lines = f.read().split("\n")

    remaining = dict(colors)
    remaining["materialShapeChars"] = read_material_shape_chars()
    new_lines = []
    for line in lines:
        stripped = line.strip()
        matched = False
        for key, value in remaining.items():
            if stripped.startswith(f"{key}="):
                new_lines.append(f"{key}={value}")
                remaining.pop(key)
                matched = True
                break
        if not matched:
            new_lines.append(line)
    for key, value in remaining.items():
        new_lines.append(f"{key}={value}")
    content = "\n".join(new_lines)

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


def update_avatar():
    """Copy user avatar to a world-readable theme asset for SDDM.

    This avoids permission issues when reading ~/.face from the sddm user.
    Source order matches lockscreen intent:
      1) ~/.face
      2) ~/.face.icon
      3) /var/lib/AccountsService/icons/<user>
    """
    if not os.path.isdir(ASSETS_DIR):
        try:
            os.makedirs(ASSETS_DIR, exist_ok=True)
        except Exception:
            return False

    username = _sudo_user or os.environ.get("USER", "")
    candidates = [
        os.path.join(_real_home, ".face"),
        os.path.join(_real_home, ".face.icon"),
    ]
    if username:
        candidates.append(f"/var/lib/AccountsService/icons/{username}")

    src = next((p for p in candidates if p and os.path.isfile(p)), None)
    if not src:
        return False

    dst = os.path.join(ASSETS_DIR, "user-face.png")
    try:
        shutil.copy2(src, dst)
        os.chmod(dst, 0o644)
        print(f"[sddm-pixel] Avatar updated: {os.path.basename(src)}")
        return True
    except Exception as e:
        print(f"[sddm-pixel] Avatar sync failed: {e}")
        return False


VIDEO_EXTENSIONS = {".mp4", ".mkv", ".webm", ".avi", ".mov", ".gif", ".webp"}


def extract_video_frame(video_path, dest_png):
    """Use ffmpeg to extract the first frame of a video as PNG. Returns tmp path on success, None on failure."""
    if not shutil.which("ffmpeg"):
        print("[sddm-pixel] ffmpeg not found — cannot extract video frame")
        return None
    tmp = os.path.join("/tmp", "sddm-pixel-frame.tmp.png")
    try:
        proc = subprocess.run(
            ["ffmpeg", "-y", "-i", video_path, "-vframes", "1", "-update", "1", "-f", "image2", tmp],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=15,
        )
        if proc.returncode == 0 and os.path.isfile(tmp):
            return tmp
        print(f"[sddm-pixel] ffmpeg frame extraction failed for {os.path.basename(video_path)}")
        return None
    except Exception as e:
        print(f"[sddm-pixel] ffmpeg error: {e}")
        return None


def update_background(wallpaper_path):
    """Copy current wallpaper (or its first video frame) to theme assets/background.png."""
    if not wallpaper_path:
        return False
    if not os.path.isdir(ASSETS_DIR):
        try:
            os.makedirs(ASSETS_DIR, exist_ok=True)
        except PermissionError:
            print(f"[sddm-pixel] Permission denied creating {ASSETS_DIR}.")
            print(f"[sddm-pixel] Re-run install-pixel-sddm.sh to fix ownership.")
            return False

    bg_dest = os.path.join(ASSETS_DIR, "background.png")
    ext = os.path.splitext(wallpaper_path)[1].lower()
    src = wallpaper_path

    if ext in VIDEO_EXTENSIONS:
        tmp_frame = extract_video_frame(wallpaper_path, bg_dest)
        if tmp_frame is None:
            print("[sddm-pixel] Keeping existing background (video, no ffmpeg)")
            return False
        src = tmp_frame

    try:
        shutil.copy2(src, bg_dest)
        if ext in VIDEO_EXTENSIONS and os.path.isfile(src):
            os.unlink(src)
        print(f"[sddm-pixel] Background updated: {os.path.basename(wallpaper_path)}")
        return True
    except PermissionError:
        print(f"[sddm-pixel] Permission denied writing to {ASSETS_DIR}.")
        print(f"[sddm-pixel] Re-run install-pixel-sddm.sh to fix ownership.")
        if ext in VIDEO_EXTENSIONS and os.path.isfile(src):
            os.unlink(src)
        return False
    except Exception as e:
        print(f"[sddm-pixel] Error updating background: {e}")
        if ext in VIDEO_EXTENSIONS and os.path.isfile(src):
            os.unlink(src)
        return False


def main():
    if not os.path.isdir(THEME_DIR):
        print(f"[sddm-pixel] Theme not installed at {THEME_DIR}. Run install-pixel-sddm.sh first.")
        return

    colors = read_colors()
    if colors:
        if update_theme_conf(colors):
            print(f"[sddm-pixel] Colors synced (primary: {colors['primaryColor']})")
        else:
            print("[sddm-pixel] Color sync failed")
    else:
        print("[sddm-pixel] No colors available, skipping color sync")

    wallpaper = read_wallpaper()
    if wallpaper:
        update_background(wallpaper)
    else:
        print("[sddm-pixel] No wallpaper path found, keeping existing background")

    update_avatar()


if __name__ == "__main__":
    main()
