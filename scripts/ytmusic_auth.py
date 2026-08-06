#!/usr/bin/env python3
"""
YouTube Music authentication helper.
Extracts cookies from browsers for yt-dlp to use.

Supports Firefox forks (Zen, LibreWolf, Floorp, Waterfox) by using
firefox:/path/to/profile syntax since yt-dlp doesn't natively support them.
"""
import sys
import json
import subprocess
import os
import shutil
import glob
import time

def get_base_dir():
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def get_cookie_output_path():
    """Get path for storing extracted cookies."""
    xdg_config = os.environ.get("XDG_CONFIG_HOME")
    if not xdg_config:
        xdg_config = os.path.expanduser("~/.config")
    # Use illogical-impulse directory as per project convention
    config_dir = os.path.join(xdg_config, "illogical-impulse")
    os.makedirs(config_dir, exist_ok=True)
    return os.path.join(config_dir, "yt-cookies.txt")

# Firefox forks that use the same cookie format
# Values may be a single base path or a list of candidates (different distros/installs put the
# profile in different places — Zen ships as both ~/.zen and ~/.config/zen, plus flatpak).
FIREFOX_FORKS = {
    "zen": ["~/.zen", "~/.config/zen", "~/.var/app/app.zen_browser.zen/.zen"],
    "librewolf": ["~/.librewolf", "~/.var/app/io.gitlab.librewolf-community/.librewolf"],
    "floorp": ["~/.floorp", "~/.var/app/one.ablaze.floorp/.floorp"],
    "waterfox": "~/.waterfox",
    "firefox": ["~/.mozilla/firefox", "~/.var/app/org.mozilla.firefox/.mozilla/firefox"],
}

# Browsers natively supported by yt-dlp
YTDLP_NATIVE_BROWSERS = ["brave", "chrome", "chromium", "edge", "firefox", "opera", "safari", "vivaldi", "whale"]

def _profile_from_ini(base):
    """Resolve the active profile directory by parsing Firefox's `profiles.ini`. This is the
    correct way — globbing for `*.default-release`/`*.default` MISSES forks that name profiles
    differently (e.g. Zen uses `jjajtz77.Default (release)`, capital D + a space). Priority:
    the `[Install*]` section's `Default=` (the profile the browser actually launches), then any
    profile flagged `Default=1`, then any profile whose dir has cookies.sqlite."""
    ini = os.path.join(base, "profiles.ini")
    if not os.path.exists(ini):
        return None
    import configparser
    cfg = configparser.ConfigParser()
    cfg.optionxform = str  # preserve key case; values keep spaces
    try:
        cfg.read(ini)
    except Exception:
        return None

    def resolve(path_value, is_relative):
        p = os.path.join(base, path_value) if is_relative else os.path.expanduser(path_value)
        return p if os.path.exists(os.path.join(p, "cookies.sqlite")) else None

    # 1) [Install*] Default= — the path the browser is actually using right now.
    for section in cfg.sections():
        if section.startswith("Install") and cfg.has_option(section, "Default"):
            cand = os.path.join(base, cfg.get(section, "Default"))
            if os.path.exists(os.path.join(cand, "cookies.sqlite")):
                return cand

    # 2) A [Profile*] flagged Default=1.
    profiles = []
    for section in cfg.sections():
        if not section.startswith("Profile") or not cfg.has_option(section, "Path"):
            continue
        path = cfg.get(section, "Path")
        is_rel = cfg.get(section, "IsRelative", fallback="1") != "0"
        is_default = cfg.get(section, "Default", fallback="0") == "1"
        profiles.append((is_default, path, is_rel))
    for is_default, path, is_rel in profiles:
        if is_default:
            r = resolve(path, is_rel)
            if r:
                return r
    # 3) First profile listed that has a cookie DB.
    for _, path, is_rel in profiles:
        r = resolve(path, is_rel)
        if r:
            return r
    return None


def find_firefox_profile(base_path):
    """Find the active profile in a Firefox-based browser. base_path may be a single path or a
    list of candidate base dirs (the first one that yields a profile with cookies.sqlite wins).
    Parses profiles.ini first (handles Zen/forks), then falls back to glob heuristics."""
    if isinstance(base_path, (list, tuple)):
        for candidate in base_path:
            found = find_firefox_profile(candidate)
            if found:
                return found
        return None
    base = os.path.expanduser(base_path)
    if not os.path.exists(base):
        return None

    # Authoritative: profiles.ini.
    via_ini = _profile_from_ini(base)
    if via_ini:
        return via_ini

    # Legacy fallback: *.default-release, *.default, any with cookies.sqlite. Skip backups.
    patterns = ["*.default-release", "*.default"]
    for pattern in patterns:
        matches = glob.glob(os.path.join(base, pattern))
        for match in matches:
            if os.path.isdir(match) and not match.endswith("-backup"):
                cookies_path = os.path.join(match, "cookies.sqlite")
                if os.path.exists(cookies_path):
                    return match

    for item in os.listdir(base):
        item_path = os.path.join(base, item)
        if os.path.isdir(item_path) and not item.endswith("-backup") and not item == "Crash Reports":
            cookies_path = os.path.join(item_path, "cookies.sqlite")
            if os.path.exists(cookies_path):
                return item_path
    return None

def find_chrome_profile(browser_name="google-chrome"):
    """Find profile for Chromium-based browsers."""
    config_map = {
        "chrome": "google-chrome",
        "google-chrome": "google-chrome",
        "chromium": "chromium",
        "brave": "BraveSoftware/Brave-Browser",
        "vivaldi": "vivaldi",
        "opera": "opera",
        "edge": "microsoft-edge",
        "thorium": "thorium"
    }

    config_dir = config_map.get(browser_name.lower(), browser_name)
    base = os.path.expanduser(f"~/.config/{config_dir}")

    if not os.path.exists(base):
        return None

    # Check Default or Profile 1
    for profile in ["Default", "Profile 1"]:
        profile_path = os.path.join(base, profile)
        if os.path.exists(os.path.join(profile_path, "Cookies")):
            return profile_path
    return None

def is_firefox_fork(browser):
    """Check if browser is a Firefox fork."""
    return browser.lower() in FIREFOX_FORKS

def get_ytdlp_browser_arg(browser, profile_path=None):
    """
    Get the correct --cookies-from-browser argument for yt-dlp.
    For Firefox forks, use firefox:/path/to/profile syntax.
    """
    browser = browser.lower()

    if browser in FIREFOX_FORKS and browser != "firefox":
        # Firefox fork - need to use firefox:path syntax
        if profile_path:
            return f"firefox:{profile_path}"
        # Find profile automatically
        profile = find_firefox_profile(FIREFOX_FORKS[browser])
        if profile:
            return f"firefox:{profile}"
        return None

    # Native yt-dlp browser
    if profile_path:
        return f"{browser}:{profile_path}"
    return browser

def extract_firefox_direct(profile_dir, output_path):
    """Read cookies straight from Firefox's `cookies.sqlite` (values are plaintext on Linux).
    This is the RELIABLE path for Firefox-family browsers: it never makes a network request, so it
    can't trigger YouTube's server-side cookie rotation. yt-dlp's `--cookies-from-browser` completes
    a request to YouTube which responds with Set-Cookie that ROTATES the session, and yt-dlp then
    saves the rotated jar — frequently dropping `LOGIN_INFO` and breaking auth. Reading the DB
    avoids that entirely. Skips partitioned cookies (non-empty originAttributes)."""
    import sqlite3
    db = os.path.join(profile_dir, "cookies.sqlite")
    if not os.path.exists(db):
        return False, f"No cookies.sqlite in {profile_dir}"
    # Copy the DB plus its -wal/-shm to a temp dir and read the COPY. A running Firefox keeps the
    # freshest cookies (incl. ones YouTube just rotated in) in the write-ahead log; an immutable
    # read of the bare .sqlite would miss them. Opening a normal copy merges the WAL → latest state,
    # and also sidesteps the live-DB lock.
    tmp = f"/tmp/inir-ytcookies-{int(time.time())}-{os.getpid()}"
    os.makedirs(tmp, exist_ok=True)
    try:
        for ext in ("", "-wal", "-shm"):
            src = db + ext
            if os.path.exists(src):
                shutil.copy2(src, os.path.join(tmp, "cookies.sqlite" + ext))
        copy = os.path.join(tmp, "cookies.sqlite")
        con = sqlite3.connect(copy)
        rows = con.execute(
            "SELECT host, path, isSecure, expiry, name, value, originAttributes "
            "FROM moz_cookies WHERE host LIKE '%youtube.com' OR host LIKE '%google.com'"
        ).fetchall()
        con.close()
    except Exception as e:
        return False, f"Could not read cookie DB: {e}"
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    lines = ["# Netscape HTTP Cookie File", "# Extracted by iNiR (direct, rotation-safe)"]
    names = set()
    for host, path, secure, expiry, name, value, oa in rows:
        if oa:  # partitioned cookie — not the main session
            continue
        flag = "TRUE" if str(host).startswith(".") else "FALSE"
        sec = "TRUE" if secure else "FALSE"
        lines.append(f"{host}\t{flag}\t{path}\t{sec}\t{int(expiry or 0)}\t{name}\t{value}")
        names.add(name)
    if not (names & {"SAPISID", "__Secure-3PAPISID", "__Secure-1PAPISID"}):
        return False, "No Google session cookies in profile (not logged in)."
    try:
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        with open(output_path, "w") as f:
            f.write("\n".join(lines) + "\n")
    except Exception as e:
        return False, str(e)
    _trim_cookie_file(output_path)
    return True, None


# The cookie jar MUST be trimmed before use. The full browser jar (every google.com subdomain,
# ~190 KB) makes BOTH ytmusicapi AND yt-dlp/mpv hit HTTP 413 (Request Entity Too Large) → browse
# fails and songs won't play. Keeping only the YouTube/Google auth cookies on the ROOT domains
# drops it to ~4 KB, which authenticates and plays. (yt-dlp matches by domain, so subdomain copies
# like accounts.google.com bloat the request without helping.)
_KEEP_COOKIE_NAMES = {
    "SID", "HSID", "SSID", "APISID", "SAPISID",
    "__Secure-1PSID", "__Secure-3PSID", "__Secure-1PAPISID", "__Secure-3PAPISID",
    "__Secure-1PSIDCC", "__Secure-3PSIDCC", "SIDCC", "__Secure-1PSIDTS", "__Secure-3PSIDTS",
    "LOGIN_INFO", "VISITOR_INFO1_LIVE", "VISITOR_PRIVACY_METADATA", "YSC", "PREF", "CONSENT", "SOCS",
}
_KEEP_COOKIE_DOMAINS = {
    ".youtube.com", "youtube.com", "www.youtube.com", "music.youtube.com",
    ".google.com", "google.com",
}


def _trim_cookie_file(path):
    """Rewrite a Netscape cookie file in place, keeping only the YouTube/Google auth cookies on
    root domains. Prevents the HTTP 413 that breaks browse and playback."""
    try:
        with open(path) as f:
            lines = f.readlines()
    except Exception:
        return
    out = ["# Netscape HTTP Cookie File"]
    for line in lines:
        if line.startswith("#") or not line.strip():
            continue
        p = line.rstrip("\n").split("\t")
        if len(p) >= 7 and p[5] in _KEEP_COOKIE_NAMES and p[0] in _KEEP_COOKIE_DOMAINS:
            out.append(line.rstrip("\n"))
    try:
        with open(path, "w") as f:
            f.write("\n".join(out) + "\n")
    except Exception:
        pass


# Extraction URL. CRITICAL: must NOT be a watchable video. yt-dlp dumps the browser cookie jar
# regardless of URL, but if the URL is a real video yt-dlp completes an authenticated request whose
# Set-Cookie ROTATES the session and yt-dlp then saves the rotated jar — dropping LOGIN_INFO and
# leaving a set YouTube treats as anonymous. A plain music.youtube.com GET extracts fresh, valid,
# still-authenticating cookies without that rotation (verified).
_EXTRACT_URL = "https://music.youtube.com"


def extract_cookies(browser, output_path):
    """
    Extract cookies. For Firefox-family browsers, read `cookies.sqlite` DIRECTLY (rotation-safe):
    it makes NO network request, so YouTube can't rotate the session mid-extract. yt-dlp's
    `--cookies-from-browser` completes a request to YouTube whose Set-Cookie ROTATES the session and
    intermittently saves a jar missing `LOGIN_INFO` → an anonymous, non-authenticating set (verified:
    direct read = 3/3 snow.f; yt-dlp = flaky). Chromium has an encrypted store, so it must use yt-dlp.
    Returns (success, error_message).
    """
    browser = browser.lower()

    # Firefox-family → direct, rotation-safe sqlite read (primary).
    if browser in FIREFOX_FORKS:
        profile = find_firefox_profile(FIREFOX_FORKS[browser])
        if profile:
            ok, err = extract_firefox_direct(profile, output_path)
            if ok:
                return True, None
            if err and "logged in" in err:
                return False, err  # profile genuinely has no session; don't mask with yt-dlp

    # Chromium-family (encrypted DB) or Firefox without a resolvable profile → yt-dlp.
    browser_arg = get_ytdlp_browser_arg(browser)
    if browser_arg:
        cmd = [
            "yt-dlp",
            "--cookies-from-browser", browser_arg,
            "--cookies", output_path,
            "--no-warnings", "--skip-download", "--no-playlist",
            _EXTRACT_URL,
        ]
        try:
            # yt-dlp exits non-zero on this non-media URL but writes the cookie jar BEFORE failing,
            # so success is judged by the file, not the return code.
            subprocess.run(cmd, capture_output=True, text=True, timeout=60)
            if os.path.exists(output_path):
                with open(output_path) as f:
                    content = f.read()
                if any(t in content for t in ("SAPISID", "__Secure-3PAPISID", "__Secure-1PAPISID")):
                    _trim_cookie_file(output_path)
                    return True, None
        except subprocess.TimeoutExpired:
            pass
        except Exception:
            pass

    return False, f"Could not extract cookies from {browser}. Make sure you're signed into YouTube Music there."

def extract_cookies_with_copy(browser, output_path):
    """
    Fallback: Copy cookies file to temp location and extract.
    Useful when browser has the DB locked.
    """
    browser = browser.lower()

    # Find profile path
    if is_firefox_fork(browser):
        profile_path = find_firefox_profile(FIREFOX_FORKS.get(browser, "~/.mozilla/firefox"))
    else:
        profile_path = find_chrome_profile(browser)

    if not profile_path:
        return False, f"Could not locate profile for {browser}"

    # Create temp dir
    temp_dir = f"/tmp/yt-music-auth-{int(time.time())}"
    os.makedirs(temp_dir, exist_ok=True)

    try:
        # Copy cookie files
        if is_firefox_fork(browser) or browser == "firefox":
            src_cookie = os.path.join(profile_path, "cookies.sqlite")
            if os.path.exists(src_cookie):
                shutil.copy2(src_cookie, temp_dir)
                # Copy WAL file if exists (important for locked DBs)
                for ext in ["-wal", "-shm"]:
                    wal = src_cookie + ext
                    if os.path.exists(wal):
                        shutil.copy2(wal, temp_dir)
            browser_arg = f"firefox:{temp_dir}"
        else:
            # Chromium based
            src_cookie = os.path.join(profile_path, "Cookies")
            if os.path.exists(src_cookie):
                shutil.copy2(src_cookie, temp_dir)
            browser_arg = f"{browser}:{temp_dir}"

        cmd = [
            "yt-dlp",
            "--cookies-from-browser", browser_arg,
            "--cookies", output_path,
            "--no-warnings",
            "--quiet",
            "--skip-download",
            "https://music.youtube.com"
        ]

        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)

        if result.returncode == 0 and os.path.exists(output_path):
            return True, None
        return False, result.stderr or "Failed to extract cookies"

    finally:
        shutil.rmtree(temp_dir, ignore_errors=True)

def verify_connection(output_path):
    """Confirm the exported cookie file carries a Google/YouTube session. This is a fast,
    NETWORK-FREE presence check (look for the auth markers). We deliberately do NOT make a yt-dlp
    request here: any completed request to YouTube triggers server-side cookie rotation that can
    invalidate the freshly-exported set. The authoritative validation (a real YTM API call) is
    done by innertube.py:_account_probe()."""
    try:
        with open(output_path, "r") as f:
            content = f.read()
    except Exception:
        return False
    auth_tokens = ["__Secure-3PSID", "SAPISID", "LOGIN_INFO"]
    return any(token in content for token in auth_tokens)

# Human-readable names for the browsers we can extract from.
BROWSER_DISPLAY = {
    "zen": "Zen", "librewolf": "LibreWolf", "floorp": "Floorp", "waterfox": "Waterfox",
    "firefox": "Firefox", "brave": "Brave", "chrome": "Chrome", "google-chrome": "Chrome",
    "chromium": "Chromium", "vivaldi": "Vivaldi", "edge": "Edge", "opera": "Opera",
    "thorium": "Thorium",
}

# Map a .desktop id (from xdg-settings) to our browser id.
_DESKTOP_TO_BROWSER = {
    "zen": "zen", "zen-browser": "zen", "app.zen_browser.zen": "zen",
    "librewolf": "librewolf", "io.gitlab.librewolf-community": "librewolf",
    "floorp": "floorp", "one.ablaze.floorp": "floorp", "waterfox": "waterfox",
    "firefox": "firefox", "org.mozilla.firefox": "firefox", "firefox-esr": "firefox",
    "brave-browser": "brave", "brave": "brave", "com.brave.browser": "brave",
    "google-chrome": "chrome", "chromium": "chromium", "chromium-browser": "chromium",
    "vivaldi-stable": "vivaldi", "vivaldi": "vivaldi", "microsoft-edge": "edge",
}

def get_default_browser():
    """Return our browser id for the system default web browser, or None."""
    try:
        out = subprocess.run(["xdg-settings", "get", "default-web-browser"],
                             capture_output=True, text=True, timeout=5)
        desktop = out.stdout.strip().lower()
    except Exception:
        return None
    if not desktop:
        return None
    key = desktop[:-len(".desktop")] if desktop.endswith(".desktop") else desktop
    return _DESKTOP_TO_BROWSER.get(key)

def detect_browsers():
    """List installed browsers that have a usable cookie store, with the resolved profile path
    (firefox forks) where relevant. Marks the system default. The InnerTube connect flow iterates
    this list to find one with a real YouTube session."""
    found = []
    for browser in FIREFOX_FORKS:
        profile = find_firefox_profile(FIREFOX_FORKS[browser])
        if profile:
            found.append({"id": browser, "name": BROWSER_DISPLAY.get(browser, browser),
                          "kind": "firefox", "profile": profile})
    for browser in ("brave", "chrome", "chromium", "vivaldi", "edge", "opera", "thorium"):
        if find_chrome_profile(browser):
            found.append({"id": browser, "name": BROWSER_DISPLAY.get(browser, browser),
                          "kind": "chromium", "profile": ""})
    default = get_default_browser()
    return {"browsers": found, "default": default}

def import_cookies(src_path, output_path):
    """Manual fallback: copy a user-provided Netscape cookies.txt (e.g. exported via the incognito
    method) into our cookie store after a light sanity check for Google auth markers."""
    src = os.path.expanduser(src_path)
    if not os.path.exists(src):
        return False, f"File not found: {src}"
    try:
        with open(src, "r", errors="ignore") as f:
            content = f.read()
    except Exception as e:
        return False, str(e)
    if not any(t in content for t in ("SAPISID", "__Secure-3PAPISID", "LOGIN_INFO")):
        return False, "No YouTube/Google session cookies found in that file."
    try:
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        shutil.copy2(src, output_path)
    except Exception as e:
        return False, str(e)
    _trim_cookie_file(output_path)
    return True, None

def main():
    if len(sys.argv) < 2:
        print(json.dumps({"status": "error", "message": "Browser argument required"}))
        return 1

    output_path = get_cookie_output_path()

    # Subcommand: enumerate installed browsers (+ system default).
    if sys.argv[1].lower() == "detect":
        print(json.dumps(detect_browsers()))
        return 0

    # Subcommand: import a manually-exported cookies.txt.
    if sys.argv[1].lower() == "import":
        if len(sys.argv) < 3:
            print(json.dumps({"status": "error", "message": "cookies file path required"}))
            return 1
        ok, err = import_cookies(sys.argv[2], output_path)
        if ok:
            print(json.dumps({"status": "success", "cookies_path": output_path}))
            return 0
        print(json.dumps({"status": "error", "message": err}))
        return 1

    browser = sys.argv[1].lower()

    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    # 1. Try direct extraction
    success, error = extract_cookies(browser, output_path)

    if success:
        # Verify the cookies actually work
        if verify_connection(output_path):
            print(json.dumps({
                "status": "success",
                "cookies_path": output_path,
                "message": "Connected successfully"
            }))
            return 0
        else:
            # Cookies extracted but don't work - user probably not logged in
            print(json.dumps({
                "status": "error",
                "message": f"Not logged in to YouTube in {browser}. Please sign in first."
            }))
            return 1

    # 2. Try copy workaround (for locked DBs)
    success, error = extract_cookies_with_copy(browser, output_path)

    if success:
        if verify_connection(output_path):
            print(json.dumps({
                "status": "success",
                "cookies_path": output_path,
                "message": "Connected successfully"
            }))
            return 0
        else:
            print(json.dumps({
                "status": "error",
                "message": f"Not logged in to YouTube in {browser}. Please sign in first."
            }))
            return 1

    # Both methods failed
    print(json.dumps({
        "status": "error",
        "message": f"Failed to extract cookies from {browser}. Try closing the browser.",
        "debug": error
    }))
    return 1

if __name__ == "__main__":
    sys.exit(main())
