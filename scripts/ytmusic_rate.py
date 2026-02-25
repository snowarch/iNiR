#!/usr/bin/env python3
"""
YouTube Music like/unlike helper using YouTube Data API v3 + OAuth.
Usage: ytmusic_rate.py like <videoId>
       ytmusic_rate.py unlike <videoId>
"""
import sys
import json
import os
import time
import urllib.request
import urllib.parse
import urllib.error

OAUTH_PATH = os.path.join(
    os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")),
    "illogical-impulse", "ytmusic_oauth.json"
)

def load_oauth():
    if not os.path.exists(OAUTH_PATH):
        print(json.dumps({"error": "OAuth not configured"}))
        sys.exit(1)
    with open(OAUTH_PATH) as f:
        return json.load(f)

def save_oauth(data):
    with open(OAUTH_PATH, 'w') as f:
        json.dump(data, f, indent=2)

def refresh_token(oauth):
    """Refresh the access token using the refresh token."""
    data = urllib.parse.urlencode({
        "client_id": oauth["client_id"],
        "client_secret": oauth["client_secret"],
        "refresh_token": oauth["refresh_token"],
        "grant_type": "refresh_token"
    }).encode()
    req = urllib.request.Request("https://oauth2.googleapis.com/token", data=data, method="POST")
    req.add_header("Content-Type", "application/x-www-form-urlencoded")
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            result = json.loads(resp.read())
            oauth["access_token"] = result["access_token"]
            oauth["expires_at"] = int(time.time()) + result.get("expires_in", 3600)
            save_oauth(oauth)
            return oauth
    except Exception as e:
        print(json.dumps({"error": f"Token refresh failed: {e}"}))
        sys.exit(1)

def ensure_valid_token(oauth):
    """Refresh token if expired or about to expire."""
    expires_at = oauth.get("expires_at", 0)
    if time.time() > expires_at - 60:
        return refresh_token(oauth)
    return oauth

def rate_video(video_id, rating):
    """Rate a video using YouTube Data API v3. rating: 'like' or 'none'."""
    oauth = load_oauth()
    oauth = ensure_valid_token(oauth)

    url = f"https://www.googleapis.com/youtube/v3/videos/rate?id={video_id}&rating={rating}"
    req = urllib.request.Request(url, data=b'', method="POST")
    req.add_header("Authorization", f"Bearer {oauth['access_token']}")
    req.add_header("Content-Length", "0")
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            print(json.dumps({"status": "ok", "rating": rating, "videoId": video_id}))
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        print(json.dumps({"error": f"HTTP {e.code}", "detail": body[:200]}))
        sys.exit(1)

def setup_check():
    """Check if OAuth is configured and token is valid."""
    if not os.path.exists(OAUTH_PATH):
        print(json.dumps({"configured": False}))
        return
    try:
        oauth = load_oauth()
        has_token = bool(oauth.get("access_token") and oauth.get("refresh_token"))
        expired = time.time() > oauth.get("expires_at", 0) - 60
        # Try to get channel name
        channel = ""
        if has_token:
            try:
                if expired:
                    oauth = refresh_token(oauth)
                url = "https://www.googleapis.com/youtube/v3/channels?part=snippet&mine=true"
                req = urllib.request.Request(url)
                req.add_header("Authorization", f"Bearer {oauth['access_token']}")
                with urllib.request.urlopen(req, timeout=10) as resp:
                    data = json.loads(resp.read())
                    items = data.get("items", [])
                    if items:
                        channel = items[0].get("snippet", {}).get("title", "")
            except Exception:
                pass
        print(json.dumps({"configured": has_token, "channel": channel}))
    except Exception:
        print(json.dumps({"configured": False}))

def setup_request(client_id, client_secret):
    """Request device code for OAuth device flow."""
    data = urllib.parse.urlencode({
        "client_id": client_id,
        "scope": "https://www.googleapis.com/auth/youtube",
    }).encode()
    req = urllib.request.Request("https://oauth2.googleapis.com/device/code", data=data, method="POST")
    req.add_header("Content-Type", "application/x-www-form-urlencoded")
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            result = json.loads(resp.read())
            # Save client credentials for later
            os.makedirs(os.path.dirname(OAUTH_PATH), exist_ok=True)
            save_oauth({"client_id": client_id, "client_secret": client_secret})
            print(json.dumps({
                "status": "ok",
                "user_code": result["user_code"],
                "verification_url": result["verification_url"],
                "device_code": result["device_code"],
                "interval": result.get("interval", 5),
                "expires_in": result.get("expires_in", 1800),
            }))
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        print(json.dumps({"error": f"HTTP {e.code}", "detail": body[:300]}))
        sys.exit(1)
    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)

def setup_poll(client_id, client_secret, device_code):
    """Poll for OAuth token (single attempt)."""
    data = urllib.parse.urlencode({
        "client_id": client_id,
        "client_secret": client_secret,
        "device_code": device_code,
        "grant_type": "urn:ietf:params:oauth:grant_type:device_code",
    }).encode()
    req = urllib.request.Request("https://oauth2.googleapis.com/token", data=data, method="POST")
    req.add_header("Content-Type", "application/x-www-form-urlencoded")
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            token_data = json.loads(resp.read())
            # Save full OAuth data
            oauth = {
                "client_id": client_id,
                "client_secret": client_secret,
                "access_token": token_data["access_token"],
                "refresh_token": token_data.get("refresh_token", ""),
                "expires_at": int(time.time()) + token_data.get("expires_in", 3600),
            }
            os.makedirs(os.path.dirname(OAUTH_PATH), exist_ok=True)
            save_oauth(oauth)
            os.chmod(OAUTH_PATH, 0o600)
            print(json.dumps({"status": "authorized"}))
    except urllib.error.HTTPError as e:
        body = json.loads(e.read().decode())
        err = body.get("error", "unknown")
        if err == "authorization_pending":
            print(json.dumps({"status": "pending"}))
        elif err == "slow_down":
            print(json.dumps({"status": "slow_down"}))
        elif err == "access_denied":
            print(json.dumps({"status": "denied", "error": "User denied access"}))
        elif err == "expired_token":
            print(json.dumps({"status": "expired", "error": "Code expired, try again"}))
        else:
            print(json.dumps({"status": "error", "error": err}))
    except Exception as e:
        print(json.dumps({"status": "error", "error": str(e)}))

def fetch_liked():
    """Fetch liked videos via YouTube Data API v3. Outputs one JSON per line (JSONL)."""
    oauth = load_oauth()
    oauth = ensure_valid_token(oauth)

    page_token = ""
    count = 0
    max_results = 200  # safety cap

    while count < max_results:
        url = "https://www.googleapis.com/youtube/v3/videos?part=snippet,contentDetails&myRating=like&maxResults=50"
        if page_token:
            url += f"&pageToken={page_token}"

        req = urllib.request.Request(url)
        req.add_header("Authorization", f"Bearer {oauth['access_token']}")

        try:
            with urllib.request.urlopen(req, timeout=15) as resp:
                data = json.loads(resp.read())
        except urllib.error.HTTPError as e:
            body = e.read().decode()
            print(json.dumps({"_error": f"HTTP {e.code}", "detail": body[:200]}), flush=True)
            break
        except Exception as e:
            print(json.dumps({"_error": str(e)}), flush=True)
            break

        for item in data.get("items", []):
            snippet = item.get("snippet", {})
            content = item.get("contentDetails", {})
            video_id = item.get("id", "")

            # Parse ISO 8601 duration (PT3M45S -> seconds)
            duration_str = content.get("duration", "PT0S")
            duration = 0
            import re
            m = re.match(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?', duration_str)
            if m:
                duration = int(m.group(1) or 0) * 3600 + int(m.group(2) or 0) * 60 + int(m.group(3) or 0)

            # Filter: 30s-900s (same as existing yt-dlp filter)
            if duration < 30 or duration > 900:
                continue

            # Get best thumbnail
            thumbs = snippet.get("thumbnails", {})
            thumb = (thumbs.get("medium") or thumbs.get("default") or {}).get("url", "")

            print(json.dumps({
                "videoId": video_id,
                "title": snippet.get("title", "Unknown"),
                "artist": snippet.get("channelTitle", ""),
                "thumbnail": thumb,
                "duration": duration,
                "url": f"https://music.youtube.com/watch?v={video_id}",
            }), flush=True)
            count += 1

        page_token = data.get("nextPageToken", "")
        if not page_token:
            break

    # Signal done
    print(json.dumps({"_done": True, "count": count}), flush=True)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(json.dumps({"error": "Usage: ytmusic_rate.py <command> [args]"}))
        sys.exit(1)

    action = sys.argv[1]

    if action == "like" and len(sys.argv) == 3:
        rate_video(sys.argv[2], "like")
    elif action == "unlike" and len(sys.argv) == 3:
        rate_video(sys.argv[2], "none")
    elif action == "check":
        setup_check()
    elif action == "setup-request" and len(sys.argv) == 4:
        setup_request(sys.argv[2], sys.argv[3])
    elif action == "setup-poll" and len(sys.argv) == 5:
        setup_poll(sys.argv[2], sys.argv[3], sys.argv[4])
    elif action == "fetch-liked":
        fetch_liked()
    else:
        print(json.dumps({"error": f"Unknown command: {' '.join(sys.argv[1:])}"}))
        sys.exit(1)
