#!/usr/bin/env python3
"""
YouTube Music OAuth Setup for iNiR
Interactive setup wizard that guides users through OAuth configuration
for the YouTube like/unlike feature.

Usage: python3 ytmusic_oauth_setup.py
"""
import json
import os
import sys
import time
import urllib.request
import urllib.parse
import urllib.error

OAUTH_PATH = os.path.join(
    os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")),
    "illogical-impulse", "ytmusic_oauth.json"
)

SCOPES = "https://www.googleapis.com/auth/youtube"

# ── Colors ──────────────────────────────────────────────────────────────────
R = "\033[0m"
B = "\033[1m"
DIM = "\033[2m"
CYAN = "\033[36m"
GREEN = "\033[32m"
YELLOW = "\033[33m"
RED = "\033[31m"

def banner():
    print(f"""
{CYAN}{B}╔══════════════════════════════════════════════════════╗
║         iNiR — YouTube Music OAuth Setup             ║
╚══════════════════════════════════════════════════════╝{R}
""")

def step(n, total, text):
    print(f"\n{CYAN}{B}[{n}/{total}]{R} {B}{text}{R}")

def info(text):
    print(f"  {DIM}→{R} {text}")

def success(text):
    print(f"  {GREEN}✓{R} {text}")

def warn(text):
    print(f"  {YELLOW}⚠{R} {text}")

def error(text):
    print(f"  {RED}✗{R} {text}")

def ask(prompt, default=None):
    suffix = f" [{default}]" if default else ""
    val = input(f"  {B}>{R} {prompt}{suffix}: ").strip()
    return val if val else default

def check_existing():
    """Check if OAuth is already configured."""
    if os.path.exists(OAUTH_PATH):
        try:
            with open(OAUTH_PATH) as f:
                data = json.load(f)
            if data.get("access_token") and data.get("refresh_token"):
                print(f"{GREEN}OAuth is already configured.{R}")
                print(f"  Token file: {OAUTH_PATH}")
                choice = ask("Reconfigure? (y/N)", "n")
                if choice.lower() != "y":
                    sys.exit(0)
        except (json.JSONDecodeError, KeyError):
            pass

def device_flow_auth(client_id, client_secret):
    """Run OAuth 2.0 device flow."""
    # Step 1: Request device code
    data = urllib.parse.urlencode({
        "client_id": client_id,
        "scope": SCOPES,
    }).encode()

    req = urllib.request.Request(
        "https://oauth2.googleapis.com/device/code",
        data=data, method="POST"
    )
    req.add_header("Content-Type", "application/x-www-form-urlencoded")

    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            result = json.loads(resp.read())
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        error(f"Device code request failed: {e.code}")
        error(body[:300])
        return None
    except Exception as e:
        error(f"Network error: {e}")
        return None

    user_code = result["user_code"]
    verification_url = result["verification_url"]
    device_code = result["device_code"]
    interval = result.get("interval", 5)
    expires_in = result.get("expires_in", 1800)

    print(f"""
  ┌─────────────────────────────────────────────┐
  │                                             │
  │   {B}1.{R} Open: {CYAN}{verification_url}{R}
  │   {B}2.{R} Enter code: {GREEN}{B}{user_code}{R}
  │   {B}3.{R} Sign in with your Google account      │
  │   {B}4.{R} Allow access to YouTube                │
  │                                             │
  └─────────────────────────────────────────────┘
""")
    info("Waiting for authorization...")

    # Step 2: Poll for token
    deadline = time.time() + expires_in
    while time.time() < deadline:
        time.sleep(interval)
        poll_data = urllib.parse.urlencode({
            "client_id": client_id,
            "client_secret": client_secret,
            "device_code": device_code,
            "grant_type": "urn:ietf:params:oauth:grant_type:device_code",
        }).encode()

        poll_req = urllib.request.Request(
            "https://oauth2.googleapis.com/token",
            data=poll_data, method="POST"
        )
        poll_req.add_header("Content-Type", "application/x-www-form-urlencoded")

        try:
            with urllib.request.urlopen(poll_req, timeout=10) as resp:
                token_data = json.loads(resp.read())
                return token_data  # Success!
        except urllib.error.HTTPError as e:
            body = json.loads(e.read().decode())
            err = body.get("error", "")
            if err == "authorization_pending":
                print(".", end="", flush=True)
                continue
            elif err == "slow_down":
                interval += 2
                continue
            elif err == "access_denied":
                print()
                error("Access denied. User rejected the authorization.")
                return None
            elif err == "expired_token":
                print()
                error("Code expired. Please run setup again.")
                return None
            else:
                print()
                error(f"Unexpected error: {err}")
                return None

    error("Timed out waiting for authorization.")
    return None

def verify_token(access_token):
    """Quick check that the token works with YouTube API."""
    url = "https://www.googleapis.com/youtube/v3/channels?part=snippet&mine=true"
    req = urllib.request.Request(url)
    req.add_header("Authorization", f"Bearer {access_token}")
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read())
            items = data.get("items", [])
            if items:
                name = items[0].get("snippet", {}).get("title", "Unknown")
                return name
    except Exception:
        pass
    return None

def main():
    banner()
    check_existing()

    print(f"""{B}This wizard will set up OAuth so iNiR can like/unlike songs
on YouTube Music from the sidebar player.{R}

{DIM}You need a Google Cloud project with YouTube Data API v3 enabled.
This is free and takes ~2 minutes.{R}
""")

    # ── Step 1: Google Cloud Project ────────────────────────────────────
    step(1, 4, "Create a Google Cloud Project")
    print(f"""
  {DIM}If you already have a project with YouTube Data API, skip to step 2.{R}

  1. Go to {CYAN}https://console.cloud.google.com/projectcreate{R}
  2. Name it anything (e.g. "inir-ytmusic")
  3. Click {B}Create{R}
  4. Go to {CYAN}https://console.cloud.google.com/apis/library/youtube.googleapis.com{R}
  5. Click {B}Enable{R}
""")
    input(f"  {DIM}Press Enter when done...{R}")

    # ── Step 2: OAuth Consent Screen ────────────────────────────────────
    step(2, 4, "Configure OAuth Consent Screen")
    print(f"""
  1. Go to {CYAN}https://console.cloud.google.com/apis/credentials/consent{R}
  2. User Type: {B}External{R} → Create
  3. App name: anything (e.g. "iNiR")
  4. User support email: your email
  5. Developer contact: your email
  6. Click {B}Save and Continue{R} through Scopes and Test Users
  7. On {B}Test Users{R} page, add your Google/YouTube account email
     {YELLOW}⚠ This is important! The account you use for YT Music must be a test user.{R}
  8. Save and Continue → Back to Dashboard
""")
    input(f"  {DIM}Press Enter when done...{R}")

    # ── Step 3: Create OAuth Client ─────────────────────────────────────
    step(3, 4, "Create OAuth Client Credentials")
    print(f"""
  1. Go to {CYAN}https://console.cloud.google.com/apis/credentials{R}
  2. Click {B}+ CREATE CREDENTIALS{R} → {B}OAuth client ID{R}
  3. Application type: {B}TVs and Limited Input devices{R}
  4. Name: anything (e.g. "inir-cli")
  5. Click {B}Create{R}
  6. Copy the {B}Client ID{R} and {B}Client Secret{R} below
""")

    client_id = ask("Client ID")
    if not client_id:
        error("Client ID is required.")
        sys.exit(1)

    client_secret = ask("Client Secret")
    if not client_secret:
        error("Client Secret is required.")
        sys.exit(1)

    # ── Step 4: Authorize ───────────────────────────────────────────────
    step(4, 4, "Authorize with your Google Account")

    token_data = device_flow_auth(client_id, client_secret)
    if not token_data:
        error("Authorization failed.")
        sys.exit(1)

    print()
    success("Authorization successful!")

    # Verify
    channel_name = verify_token(token_data["access_token"])
    if channel_name:
        success(f"Connected as: {B}{channel_name}{R}")
    else:
        warn("Token works but couldn't fetch channel name (this is fine)")

    # Save
    os.makedirs(os.path.dirname(OAUTH_PATH), exist_ok=True)
    oauth_data = {
        "client_id": client_id,
        "client_secret": client_secret,
        "access_token": token_data["access_token"],
        "refresh_token": token_data.get("refresh_token", ""),
        "expires_at": int(time.time()) + token_data.get("expires_in", 3600),
    }
    with open(OAUTH_PATH, "w") as f:
        json.dump(oauth_data, f, indent=2)
    os.chmod(OAUTH_PATH, 0o600)

    success(f"Saved to: {OAUTH_PATH}")

    print(f"""
{GREEN}{B}╔══════════════════════════════════════════════════════╗
║                    Setup Complete!                    ║
╚══════════════════════════════════════════════════════╝{R}

  Like/unlike buttons in the YT Music sidebar player
  will now send real likes to your YouTube account.

  Token refreshes automatically. If it ever breaks,
  just run this script again.
""")

if __name__ == "__main__":
    main()
