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

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(json.dumps({"error": "Usage: ytmusic_rate.py like|unlike <videoId>"}))
        sys.exit(1)

    action = sys.argv[1]
    video_id = sys.argv[2]

    if action == "like":
        rate_video(video_id, "like")
    elif action == "unlike":
        rate_video(video_id, "none")
    else:
        print(json.dumps({"error": f"Unknown action: {action}"}))
        sys.exit(1)
