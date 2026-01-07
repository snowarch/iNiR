#!/usr/bin/env python3
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
    return os.path.join(get_base_dir(), "yt-cookies.txt")

def find_firefox_profile():
    # Look for default release profile
    base = os.path.expanduser("~/.mozilla/firefox")
    if not os.path.exists(base):
        return None
    
    # Try to find in profiles.ini (too complex for quick script), fallback to glob
    # Priority: *.default-release, *.default, *
    patterns = ["*.default-release", "*.default", "*"]
    for pattern in patterns:
        matches = glob.glob(os.path.join(base, pattern))
        for match in matches:
            if os.path.isdir(match) and os.path.exists(os.path.join(match, "cookies.sqlite")):
                return match
    return None

def find_chrome_profile(browser_name="google-chrome"):
    # Map browser name to config dir
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
    default = os.path.join(base, "Default")
    if os.path.exists(os.path.join(default, "Cookies")):
        return default
    
    # Check Profile 1
    p1 = os.path.join(base, "Profile 1")
    if os.path.exists(os.path.join(p1, "Cookies")):
        return p1
        
    return None

def copy_cookies_and_extract(browser, profile_path, output_path):
    # Create temp dir
    temp_dir = f"/tmp/yt-music-auth-{int(time.time())}"
    os.makedirs(temp_dir, exist_ok=True)
    
    try:
        # Determine source cookie file
        if "firefox" in browser.lower():
            src_cookie = os.path.join(profile_path, "cookies.sqlite")
            if os.path.exists(src_cookie):
                shutil.copy2(src_cookie, temp_dir)
                # Copy WAL file if exists (important for locked DBs)
                if os.path.exists(src_cookie + "-wal"):
                    shutil.copy2(src_cookie + "-wal", temp_dir)
            
            # For Firefox, yt-dlp expects a profile directory
            browser_arg = f"firefox:{temp_dir}"
            
        else:
            # Chromium based
            src_cookie = os.path.join(profile_path, "Cookies")
            if os.path.exists(src_cookie):
                shutil.copy2(src_cookie, temp_dir)
            
            # For Chrome, we point to the temp dir which contains the Cookies file
            # yt-dlp expects the directory containing 'Default/Cookies' or just the profile dir
            # We mimic the structure: temp_dir/Default/Cookies ?
            # No, if we pass chrome:PATH, PATH is the profile dir.
            # So we need Cookies file inside temp_dir/Cookies ? No, Chrome keeps it in Profile/Cookies.
            # Let's try pointing to temp_dir directly.
            browser_arg = f"{browser}:{temp_dir}"
            
        # Run yt-dlp to extract cookies
        # We assume yt-dlp can decrypt Chrome cookies even if moved, as long as keyring is available.
        
        cmd = [
            "yt-dlp",
            "--cookies-from-browser", browser_arg,
            "--cookies", output_path,
            "--no-warnings",
            "--quiet",
            "--skip-download",
            "--check-formats", # minimal check
            "https://music.youtube.com" # Dummy URL to trigger cookie extraction
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        
        if result.returncode == 0 and os.path.exists(output_path):
            return True, None
        else:
            return False, result.stderr
            
    finally:
        shutil.rmtree(temp_dir, ignore_errors=True)

def main():
    if len(sys.argv) < 2:
        print(json.dumps({"status": "error", "message": "Browser argument required"}))
        return 1
        
    browser = sys.argv[1].lower()
    output_path = get_cookie_output_path()
    
    # 1. Try direct access (fastest, works if browser closed)
    cmd = [
        "yt-dlp",
        "--cookies-from-browser", browser,
        "--cookies", output_path,
        "--no-warnings",
        "--quiet",
        "--skip-download",
        "https://music.youtube.com"
    ]
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=15)
        if result.returncode == 0 and os.path.exists(output_path):
            print(json.dumps({
                "status": "success",
                "cookies_path": output_path,
                "message": "Connected successfully"
            }))
            return 0
    except Exception:
        pass
        
    # 2. If failed, try copy workaround
    profile_path = None
    if "firefox" in browser:
        profile_path = find_firefox_profile()
    else:
        profile_path = find_chrome_profile(browser)
        
    if not profile_path:
        print(json.dumps({
            "status": "error",
            "message": f"Could not locate profile for {browser}. Close browser and try again."
        }))
        return 1
        
    success, error = copy_cookies_and_extract(browser, profile_path, output_path)
    
    if success:
        print(json.dumps({
            "status": "success",
            "cookies_path": output_path,
            "message": "Connected using copy workaround"
        }))
        return 0
    else:
        print(json.dumps({
            "status": "error",
            "message": "Failed to extract cookies. Make sure you are logged in.",
            "debug": error
        }))
        return 1

if __name__ == "__main__":
    sys.exit(main())
