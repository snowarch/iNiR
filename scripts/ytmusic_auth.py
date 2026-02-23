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
    # Use inir directory as per project convention
    config_dir = os.path.join(xdg_config, "inir")
    os.makedirs(config_dir, exist_ok=True)
    return os.path.join(config_dir, "yt-cookies.txt")

# Firefox forks that use the same cookie format
FIREFOX_FORKS = {
    "zen": "~/.zen",
    "librewolf": "~/.librewolf",
    "floorp": "~/.floorp",
    "waterfox": "~/.waterfox",
    "firefox": "~/.mozilla/firefox",
}

# Browsers natively supported by yt-dlp
YTDLP_NATIVE_BROWSERS = ["brave", "chrome", "chromium", "edge", "firefox", "opera", "safari", "vivaldi", "whale"]

def find_firefox_profile(base_path):
    """Find the default profile in a Firefox-based browser."""
    base = os.path.expanduser(base_path)
    if not os.path.exists(base):
        return None

    # Priority: *.default-release, *.default, any with cookies.sqlite
    # Skip backup directories
    patterns = ["*.default-release", "*.default"]
    for pattern in patterns:
        matches = glob.glob(os.path.join(base, pattern))
        for match in matches:
            if os.path.isdir(match) and not match.endswith("-backup"):
                cookies_path = os.path.join(match, "cookies.sqlite")
                if os.path.exists(cookies_path):
                    return match

    # Fallback: any directory with cookies.sqlite (not backup)
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

def extract_cookies(browser, output_path):
    """
    Extract cookies from browser using yt-dlp.
    Returns (success, error_message)
    """
    browser = browser.lower()

    # Get the correct browser argument for yt-dlp
    browser_arg = get_ytdlp_browser_arg(browser)

    if not browser_arg:
        return False, f"Could not find profile for {browser}"

    cmd = [
        "yt-dlp",
        "--cookies-from-browser", browser_arg,
        "--cookies", output_path,
        "--no-warnings",
        "--quiet",
        "--skip-download",
        "https://www.youtube.com/watch?v=dQw4w9WgXcQ"  # Any valid video URL to trigger cookie extraction
    ]

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        if result.returncode == 0 and os.path.exists(output_path):
            return True, None
        return False, result.stderr or "Unknown error"
    except subprocess.TimeoutExpired:
        return False, "Timeout while extracting cookies"
    except Exception as e:
        return False, str(e)

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
    """Verify that the cookies work by checking for auth tokens in the cookie file,
    then confirming with a lightweight yt-dlp call to the user's feed."""
    # Fast check: look for Google auth cookies in the file
    try:
        with open(output_path, "r") as f:
            content = f.read()
        auth_tokens = ["__Secure-3PSID", "SAPISID", "LOGIN_INFO"]
        has_auth = any(token in content for token in auth_tokens)
        if not has_auth:
            return False
    except:
        return False

    # Network check: verify cookies actually work (feed/history requires login)
    cmd = [
        "yt-dlp",
        "--cookies", output_path,
        "--flat-playlist",
        "-I", "1",
        "--print", "id",
        "--no-warnings",
        "https://www.youtube.com/feed/history"
    ]

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=15)
        return result.returncode == 0 and result.stdout.strip()
    except:
        return False

def main():
    if len(sys.argv) < 2:
        print(json.dumps({"status": "error", "message": "Browser argument required"}))
        return 1

    browser = sys.argv[1].lower()
    output_path = get_cookie_output_path()

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
