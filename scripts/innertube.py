#!/usr/bin/env python3
"""
InnerTube browsing helper for iNiR — wraps `ytmusicapi` (the InnerTube API client).
Replaces the flaky yt-dlp + browser-cookie path for search/browse/radio/lyrics.
Public browsing needs NO cookies; auth (oauth file) only enables personalized results.

Protocol mirrors ytmusic_rate.py: a subcommand prints JSON (or JSONL + a final
{"_done":true,"count":N} for paged streams) to stdout; errors print
{"error":...} and exit 1.

Usage:
  innertube.py ping
  innertube.py search <query> [filter]      # filter: songs|videos|albums|artists|playlists
  innertube.py home [limit]
  innertube.py radio <videoId>              # autoplay watch-playlist
  innertube.py artist <browseId>
  innertube.py album <browseId>
  innertube.py playlist <playlistId>
  innertube.py library <songs|artists|albums|playlists> [limit]
  innertube.py rate <videoId> <LIKE|INDIFFERENT>
  innertube.py lyrics <videoId>
  innertube.py song <videoId>
"""
import sys
import json
import os
import signal
import time
import hashlib
import tempfile

try:
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)
except (AttributeError, ValueError):
    pass

_CFG_DIR = os.path.join(
    os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")), "illogical-impulse")
# iNiR's existing YouTube Data API OAuth (reused if present).
OAUTH_PATH = os.path.join(_CFG_DIR, "ytmusic_oauth.json")
# Native ytmusicapi OAuth token written by our own one-tap device flow.
ITUBE_OAUTH_PATH = os.path.join(_CFG_DIR, "innertube_oauth.json")
# Browser session cookies (Netscape format) exported by scripts/ytmusic_auth.py. This is the
# auth that actually works for personalized browse — the public device-flow OAuth client was
# disabled by YouTube (Nov 2024 ytmusicapi requires your OWN Cloud client), so cookie auth
# (the same session a logged-in browser uses, InnerTune-style) is the primary path.
YTCOOKIE_PATH = os.path.join(_CFG_DIR, "yt-cookies.txt")

# Public "YouTube on TV" OAuth client (limited-input device flow). This is the well-known
# client ytmusicapi shipped by default; it lets users sign in by entering a code at
# youtube.com/activate with no Google Cloud project — InnerTune-style frictionless login.
TV_CLIENT_ID = "861556708454-d6dlm3lh05idd8npek18k6be8ba3oc68.apps.googleusercontent.com"
TV_CLIENT_SECRET = "SboVhoG9s0rNafixCSGGKXAT"


def _fail(msg, detail=""):
    out = {"error": str(msg)}
    if detail:
        out["detail"] = str(detail)[:300]
    print(json.dumps(out))
    sys.exit(1)


def _tv_creds():
    from ytmusicapi.auth.oauth import OAuthCredentials
    return OAuthCredentials(TV_CLIENT_ID, TV_CLIENT_SECRET)


# Only these cookies belong in the YTM API `Cookie:` header. Sending the WHOLE google.com jar
# (every Google service's cookies — often ~190 KB) makes YouTube reject the request with HTTP 413
# (Request Entity Too Large) and return an empty body, which breaks ALL authenticated browse. A
# real music.youtube.com request only carries this auth subset (~1.7 KB).
_YTM_HEADER_COOKIES = {
    "SID", "HSID", "SSID", "APISID", "SAPISID",
    "__Secure-1PSID", "__Secure-3PSID", "__Secure-1PAPISID", "__Secure-3PAPISID",
    "__Secure-1PSIDCC", "__Secure-3PSIDCC", "SIDCC",
    "__Secure-1PSIDTS", "__Secure-3PSIDTS",
    "LOGIN_INFO", "VISITOR_INFO1_LIVE", "VISITOR_PRIVACY_METADATA", "YSC", "PREF",
}


def _read_cookie_header(cookie_path=None):
    """Build a `Cookie:` header string for YTM API requests from the Netscape cookie jar.
    Returns (cookie_str, cookies_dict) or (None, None) if no logged-in session is present. Only the
    auth-relevant cookies go into the header string (see `_YTM_HEADER_COOKIES`) — the full dict is
    still returned so callers can check markers like LOGIN_INFO.

    Browser exports commonly contain duplicate Google auth cookie names for both `.youtube.com`
    and `.google.com`. A real request to music.youtube.com sends the YouTube-domain value. Keep
    Google-domain cookies only as a fallback for names absent from the YouTube jar; allowing their
    later row order to overwrite YouTube values turns a valid session into a signed-out one."""
    path = cookie_path or YTCOOKIE_PATH
    if not os.path.exists(path):
        return None, None
    cookies = {}
    priorities = {}

    def domain_priority(domain):
        host = domain.lstrip(".").lower()
        if host == "music.youtube.com":
            return 3
        if host == "youtube.com" or host.endswith(".youtube.com"):
            return 2
        if host == "google.com" or host.endswith(".google.com"):
            return 1
        return 0

    try:
        with open(path) as f:
            for line in f:
                if line.startswith("#") or not line.strip():
                    continue
                p = line.rstrip("\n").split("\t")
                # The session auth cookies (SAPISID/HSID/SSID/APISID) live on .google.com, while
                # YTM-specific ones live on .youtube.com — we need BOTH for an authenticated request.
                if len(p) >= 7 and ("youtube.com" in p[0] or "google.com" in p[0]):
                    priority = domain_priority(p[0])
                    name = p[5]
                    if priority >= priorities.get(name, -1):
                        cookies[name] = p[6]
                        priorities[name] = priority
    except Exception:
        return None, None
    # SAPISID (or its __Secure variants) is the signal that we have a real logged-in session.
    sapisid = cookies.get("SAPISID") or cookies.get("__Secure-3PAPISID") or cookies.get("__Secure-1PAPISID")
    if not sapisid:
        return None, None
    header = "; ".join(f"{k}={v}" for k, v in cookies.items() if k in _YTM_HEADER_COOKIES)
    return header, cookies


def _sapisid_hash(sapisid, origin="https://music.youtube.com"):
    ts = int(time.time())
    digest = hashlib.sha1(f"{ts} {sapisid} {origin}".encode()).hexdigest()
    return f"SAPISIDHASH {ts}_{digest}"


def _browser_client(cookie_path=None):
    """Authenticate the way InnerTune/a logged-in browser does: reuse the YouTube session
    cookies. This is the path that actually works for personalized browse (library, home,
    account) — the public device-flow OAuth client is dead (HTTP 400)."""
    cookie_str, cookies = _read_cookie_header(cookie_path)
    if not cookie_str:
        return None
    sapisid = cookies.get("SAPISID") or cookies.get("__Secure-3PAPISID") or cookies.get("__Secure-1PAPISID")
    headers = {
        "cookie": cookie_str,
        "authorization": _sapisid_hash(sapisid),
        "x-goog-authuser": "0",
        "origin": "https://music.youtube.com",
        "user-agent": "Mozilla/5.0 (X11; Linux x86_64; rv:120.0) Gecko/20100101 Firefox/120.0",
        "accept": "*/*",
        "accept-language": "en-US,en;q=0.5",
        "content-type": "application/json",
        "x-origin": "https://music.youtube.com",
    }
    try:
        from ytmusicapi import YTMusic
        return YTMusic(json.dumps(headers))
    except Exception:
        return None


def _authenticated_client(cookie_path=None, allow_oauth=True):
    """Build an authenticated YTMusic. Cookie auth (logged-in browser session) is preferred
    because it's the only method YouTube still honours for personalized browse; OAuth tokens
    are kept as a fallback. Any failure returns None so public browsing is never broken."""
    from ytmusicapi import YTMusic
    from ytmusicapi.auth.oauth import OAuthCredentials
    # 1) Browser session cookies — the working path.
    yt = _browser_client(cookie_path)
    if yt is not None:
        return yt
    if not allow_oauth:
        return None
    # 2) Native one-tap token (TV client) — fallback (currently 400s on browse upstream).
    if os.path.exists(ITUBE_OAUTH_PATH):
        try:
            return YTMusic(ITUBE_OAUTH_PATH, oauth_credentials=_tv_creds())
        except Exception:
            pass
    # 3) Reuse iNiR's OAuth (its own TV/limited-input client).
    if os.path.exists(OAUTH_PATH):
        try:
            with open(OAUTH_PATH) as f:
                o = json.load(f)
            if o.get("client_id") and o.get("client_secret") and o.get("refresh_token"):
                token = {
                    "access_token": o.get("access_token", ""),
                    "refresh_token": o["refresh_token"],
                    "scope": "https://www.googleapis.com/auth/youtube",
                    "token_type": "Bearer",
                    "expires_at": int(o.get("expires_at", 0)),
                    "expires_in": 3600,
                }
                return YTMusic(token, oauth_credentials=OAuthCredentials(o["client_id"], o["client_secret"]))
        except Exception:
            pass
    return None


def cmd_oauth_request():
    """Start the device flow: return a user code + verification URL for youtube.com/activate."""
    try:
        code = _tv_creds().get_code()
    except Exception as e:
        _fail("oauth request failed", e)
    print(json.dumps({
        "device_code": code.get("device_code", ""),
        "user_code": code.get("user_code", ""),
        "verification_url": code.get("verification_url", ""),
        "interval": code.get("interval", 5),
        "expires_in": code.get("expires_in", 1800),
    }))


def cmd_oauth_poll(device_code):
    """Poll once for the token. Prints {status: authorized|pending|error}."""
    try:
        token = _tv_creds().token_from_code(device_code)
    except Exception as e:
        msg = str(e).lower()
        if "pending" in msg or "authorization_pending" in msg:
            print(json.dumps({"status": "pending"})); return
        if "slow_down" in msg:
            print(json.dumps({"status": "pending"})); return
        print(json.dumps({"status": "error", "error": str(e)[:200]})); return
    # ytmusicapi's token_from_code returns the raw token endpoint JSON WITHOUT raising on
    # OAuth errors, so a still-pending device returns {"error": "authorization_pending"}.
    # Treat any error payload — or a response missing access_token — as not-yet-authorized,
    # otherwise we'd save that error dict as the token and report a false "authorized".
    err = token.get("error") if isinstance(token, dict) else None
    if err:
        if err in ("authorization_pending", "slow_down"):
            print(json.dumps({"status": "pending"})); return
        print(json.dumps({"status": "error", "error": str(err)[:200]})); return
    if not (isinstance(token, dict) and token.get("access_token")):
        print(json.dumps({"status": "pending"})); return
    try:
        data = dict(token)
        data.setdefault("scope", "https://www.googleapis.com/auth/youtube")
        data.setdefault("token_type", "Bearer")
        os.makedirs(_CFG_DIR, exist_ok=True)
        with open(ITUBE_OAUTH_PATH, "w") as f:
            json.dump(data, f, indent=2)
        os.chmod(ITUBE_OAUTH_PATH, 0o600)
        print(json.dumps({"status": "authorized"}))
    except Exception as e:
        _fail("oauth save failed", e)


def cmd_logout():
    for p in (ITUBE_OAUTH_PATH,):
        try:
            if os.path.exists(p):
                os.remove(p)
        except Exception:
            pass
    print(json.dumps({"status": "ok"}))


class _FallbackClient:
    """Wraps an authenticated YTMusic. A stale/rotated cookie session doesn't just lose
    personalization — it makes EVERY browse call (even public data) return an empty body
    ('Expecting value: line 1 column 1'), which would break all of InnerTune. So if an authed call
    raises or returns nothing, transparently retry the same call on a fresh public client. Personal
    data still comes through when the session is valid; public browse never breaks when it isn't."""
    def __init__(self, authed):
        self._authed = authed
        self._public = None

    def _pub(self):
        from ytmusicapi import YTMusic
        if self._public is None:
            self._public = YTMusic()
        return self._public

    def __getattr__(self, name):
        attr = getattr(self._authed, name)
        if not callable(attr):
            return attr
        def wrapped(*a, **k):
            try:
                res = attr(*a, **k)
                if res:
                    return res
            except Exception:
                pass
            return getattr(self._pub(), name)(*a, **k)
        return wrapped


def _client():
    """Construct a YTMusic client for PUBLIC/mixed browse. When a cookie session exists it's wrapped
    so a stale session can never break public browsing (auth only adds personalization). Auth-only
    commands (library, rate) use `_authenticated_client()` directly instead."""
    try:
        from ytmusicapi import YTMusic
    except ImportError:
        _fail("ytmusicapi not installed")
    authed = _authenticated_client()
    return _FallbackClient(authed) if authed is not None else YTMusic()


def _best_thumb(thumbs):
    if not thumbs:
        return ""
    try:
        return max(thumbs, key=lambda t: t.get("width", 0) * t.get("height", 0)).get("url", "")
    except Exception:
        return thumbs[-1].get("url", "") if thumbs else ""


def _parse_duration(item):
    """Return integer seconds from ytmusicapi's duration_seconds or 'mm:ss' string."""
    secs = item.get("duration_seconds")
    if isinstance(secs, int):
        return secs
    dur = item.get("duration")
    if isinstance(dur, str) and ":" in dur:
        parts = [int(p) for p in dur.split(":") if p.isdigit()]
        out = 0
        for p in parts:
            out = out * 60 + p
        return out
    return 0


def _artists(item):
    arts = item.get("artists") or []
    names = [a.get("name", "") for a in arts if a.get("name")]
    return ", ".join(names)


def _track(item):
    """Normalize a song/video into iNiR's track shape."""
    vid = item.get("videoId") or ""
    album = item.get("album") or {}
    return {
        "type": "song",
        "videoId": vid,
        "title": item.get("title", ""),
        "artist": _artists(item),
        "thumbnail": _best_thumb(item.get("thumbnails")),
        "duration": _parse_duration(item),
        "url": f"https://music.youtube.com/watch?v={vid}" if vid else "",
        "album": album.get("name", "") if isinstance(album, dict) else "",
        "albumId": album.get("id", "") if isinstance(album, dict) else "",
    }


def _card(item):
    """Normalize any home/browse card (song, album, playlist, artist) by what id it carries."""
    if item.get("videoId"):
        return _track(item)
    if item.get("playlistId") or item.get("browseId"):
        bid = item.get("browseId", "") or ""
        # YouTube browseId prefixes are stable: UC…=artist, MPREb…=album, else playlist.
        if item.get("subscribers") is not None or item.get("type") == "artist" or bid.startswith("UC"):
            kind = "artist"
        elif item.get("type") == "album" or bid.startswith("MPREb"):
            kind = "album"
        else:
            kind = "playlist"
        return {
            "type": kind,
            "title": item.get("title") or item.get("artist", ""),
            "subtitle": _artists(item) or item.get("description", ""),
            "thumbnail": _best_thumb(item.get("thumbnails")),
            "browseId": item.get("browseId", ""),
            "playlistId": item.get("playlistId", ""),
        }
    return _track(item)


# ---- subcommands ----

def _auth_helper():
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), "ytmusic_auth.py")


def _account_probe(cookie_path=None, allow_oauth=True):
    """Validate the current yt-cookies.txt against the real YTM API.
    Returns (authenticated, account_name, avatar_url). `LOGIN_INFO` is YouTube's signed-in marker —
    Google-only cookies (SID/SAPISID) without it mean the browser is logged into Google but NOT
    YouTube, so YTM serves anonymous/empty data. We require it AND a successful account call so the
    UI never claims a login that yields an empty library."""
    path = cookie_path or YTCOOKIE_PATH
    cookie_str, cookies = _read_cookie_header(path)
    signed_in = bool(cookies and cookies.get("LOGIN_INFO"))
    if not signed_in and (not allow_oauth or not (os.path.exists(ITUBE_OAUTH_PATH) or os.path.exists(OAUTH_PATH))):
        return False, "", ""
    yt = _authenticated_client(path, allow_oauth=allow_oauth)
    if yt is None:
        return False, "", ""
    # The ONLY reliable signed-in signal is `get_account_info` returning a real account name.
    # A rotated/anonymous session still has cookies and still answers browse calls (200), and
    # `get_library_songs` returns [] without raising — indistinguishable from a real-but-empty
    # library — so we must NOT use it to prove sign-in. On an anonymous session, get_account_info
    # hits the signed-out account menu (no activeAccountHeaderRenderer) and raises → not signed in.
    try:
        info = yt.get_account_info() or {}
    except Exception:
        return False, "", ""
    name = info.get("accountName", "") or ""
    if not name:
        return False, "", ""
    photo = info.get("accountPhotoUrl") or info.get("thumbnails") or ""
    if isinstance(photo, str):
        avatar = photo
    elif isinstance(photo, list):
        avatar = _best_thumb(photo)
    else:
        avatar = ""
    return True, name, avatar


def cmd_authstatus():
    """Report whether the stored session works for personalized browse, plus account + avatar."""
    auth, name, avatar = _account_probe()
    print(json.dumps({"authenticated": auth, "account": name, "avatar": avatar}))


def cmd_detect_browsers():
    """Enumerate installed browsers (+ system default) that have a usable cookie store."""
    import subprocess
    try:
        out = subprocess.run([sys.executable, _auth_helper(), "detect"],
                             capture_output=True, text=True, timeout=15)
        sys.stdout.write(out.stdout or '{"browsers": [], "default": null}')
    except Exception as e:
        print(json.dumps({"browsers": [], "default": None, "error": str(e)[:200]}))


def _candidate_cookie_path():
    os.makedirs(_CFG_DIR, exist_ok=True)
    fd, path = tempfile.mkstemp(prefix="yt-cookies.candidate-", dir=_CFG_DIR)
    os.close(fd)
    os.unlink(path)
    return path


def _run_auth_helper(args, output_path):
    import subprocess
    try:
        if os.path.exists(output_path):
            os.remove(output_path)
    except OSError:
        return False
    env = os.environ.copy()
    env["INIR_YTMUSIC_COOKIE_OUTPUT"] = output_path
    try:
        result = subprocess.run(
            [sys.executable, _auth_helper(), *args], capture_output=True,
            text=True, timeout=90, env=env)
        data = json.loads(result.stdout or "{}")
        return result.returncode == 0 and data.get("status") == "success" and os.path.isfile(output_path)
    except Exception:
        return False


def _promote_cookie_candidate(candidate):
    try:
        os.makedirs(os.path.dirname(YTCOOKIE_PATH), exist_ok=True)
        os.chmod(candidate, 0o600)
        os.replace(candidate, YTCOOKIE_PATH)
        return True
    except Exception:
        return False


def _extract_and_probe(browser, attempts=3):
    """Extract this browser's cookies and validate against YTM, retrying a few times. Live browser
    cookies rotate constantly; a single extraction can momentarily catch a mid-rotation/anonymous
    state even though the browser IS logged in. Retrying a couple of times with a short pause lands
    on the settled, authenticating set. Candidate extraction is transactional: a failed reconnect
    must not replace the last canonical jar with anonymous/stale browser cookies.
    Returns (authenticated, name, avatar)."""
    candidate = _candidate_cookie_path()
    try:
        for i in range(attempts):
            if _run_auth_helper([browser], candidate):
                # Never allow an unrelated OAuth token or the previous canonical
                # jar to validate this browser candidate.
                auth, name, avatar = _account_probe(candidate, allow_oauth=False)
                if auth and _promote_cookie_candidate(candidate):
                    return True, name, avatar
            if i < attempts - 1:
                time.sleep(1.5)
        return False, "", ""
    finally:
        try:
            if os.path.exists(candidate):
                os.remove(candidate)
        except OSError:
            pass


def cmd_connect(browser="auto"):
    """Connect by reusing the logged-in browser's YouTube session cookies (InnerTune-style).
    `auto` (default) detects installed browsers and tries each — system default first — until one
    yields a session that actually works for personalized browse. An explicit browser id extracts
    only from that browser. Reports {authenticated, account, avatar, browser}."""
    import subprocess
    if not browser or browser == "auto":
        try:
            det = json.loads(subprocess.run([sys.executable, _auth_helper(), "detect"],
                                            capture_output=True, text=True, timeout=15).stdout or "{}")
        except Exception:
            det = {}
        detected = [b.get("id") for b in det.get("browsers", []) if b.get("id")]
        order = []
        default = det.get("default")
        # XDG defaults routinely outlive removed/replaced browsers. Only prioritize
        # the default when this detector found an actual cookie store for it.
        if default in detected:
            order.append(default)
        for browser_id in detected:
            if browser_id not in order:
                order.append(browser_id)
        if not order:
            print(json.dumps({"authenticated": False, "error": "no_browser"})); return
        # Give the preferred candidate more retries. If the real XDG default was
        # detected it is first; otherwise this is simply the first usable profile.
        for idx, b in enumerate(order):
            auth, name, avatar = _extract_and_probe(b, attempts=3 if idx == 0 else 1)
            if auth:
                print(json.dumps({"authenticated": True, "account": name, "avatar": avatar, "browser": b})); return
        print(json.dumps({"authenticated": False, "error": "not_logged_in"})); return
    auth, name, avatar = _extract_and_probe(browser, attempts=3)
    if not auth:
        print(json.dumps({"authenticated": False, "error": "not_logged_in"})); return
    print(json.dumps({"authenticated": True, "account": name, "avatar": avatar, "browser": browser}))


def cmd_connect_manual(path):
    """Connect from a manually-exported cookies.txt (the reliable incognito-export method). YouTube
    rotates cookies on open tabs, so a file exported from a closed incognito session stays valid
    far longer than live extraction from the user's active profile."""
    candidate = _candidate_cookie_path()
    try:
        if not _run_auth_helper(["import", path], candidate):
            print(json.dumps({"authenticated": False, "error": "import_failed"})); return
        auth, name, avatar = _account_probe(candidate, allow_oauth=False)
        if not auth or not _promote_cookie_candidate(candidate):
            print(json.dumps({"authenticated": False, "error": "not_logged_in"})); return
        print(json.dumps({"authenticated": True, "account": name, "avatar": avatar, "browser": "manual"}))
    finally:
        try:
            if os.path.exists(candidate):
                os.remove(candidate)
        except OSError:
            pass


def cmd_disconnect():
    for p in (YTCOOKIE_PATH, ITUBE_OAUTH_PATH):
        try:
            if os.path.exists(p):
                os.remove(p)
        except Exception:
            pass
    print(json.dumps({"connected": False}))


def cmd_ping():
    try:
        import ytmusicapi
        _client()  # touch construction so a broken network surfaces here
        print(json.dumps({"available": True, "version": ytmusicapi.__version__}))
    except SystemExit:
        raise
    except Exception as e:
        print(json.dumps({"available": False, "error": str(e)[:200]}))


def cmd_search(query, filter_=None):
    yt = _client()
    valid = {"songs", "videos", "albums", "artists", "playlists", "community_playlists", "featured_playlists"}
    f = filter_ if filter_ in valid else "songs"
    try:
        results = yt.search(query, filter=f, limit=25)
    except Exception as e:
        _fail("search failed", e)
    count = 0
    for item in results:
        card = _card(item)
        if card.get("type") == "song" and not card.get("videoId"):
            continue
        print(json.dumps(card), flush=True)
        count += 1
    print(json.dumps({"_done": True, "count": count}), flush=True)


def cmd_home(limit=None):
    yt = _client()
    try:
        shelves = yt.get_home(limit=int(limit) if limit else 3)
    except Exception as e:
        _fail("home failed", e)
    out = []
    for shelf in shelves:
        items = [_card(c) for c in shelf.get("contents", []) if c]
        out.append({"title": shelf.get("title", ""), "items": items})
    print(json.dumps({"shelves": out}))


def cmd_radio(video_id):
    yt = _client()
    try:
        wp = yt.get_watch_playlist(videoId=video_id, limit=50)
    except Exception as e:
        _fail("radio failed", e)
    print(json.dumps({"lyricsId": wp.get("lyrics") or "", "_meta": True}), flush=True)
    count = 0
    for t in wp.get("tracks", []):
        card = _track(t)
        if not card.get("videoId"):
            continue
        print(json.dumps(card), flush=True)
        count += 1
    print(json.dumps({"_done": True, "count": count}), flush=True)


def cmd_artist(browse_id):
    yt = _client()
    try:
        a = yt.get_artist(browse_id)
    except Exception as e:
        _fail("artist failed", e)
    songs = [_track(s) for s in (a.get("songs", {}) or {}).get("results", [])]
    albums = [_card(s) for s in (a.get("albums", {}) or {}).get("results", [])]
    singles = [_card(s) for s in (a.get("singles", {}) or {}).get("results", [])]
    print(json.dumps({
        "name": a.get("name", ""),
        "description": a.get("description", ""),
        "thumbnail": _best_thumb(a.get("thumbnails")),
        "songs": songs,
        "albums": albums,
        "singles": singles,
    }))


def cmd_album(browse_id):
    yt = _client()
    try:
        al = yt.get_album(browse_id)
    except Exception as e:
        _fail("album failed", e)
    tracks = [_track(t) for t in al.get("tracks", [])]
    print(json.dumps({
        "title": al.get("title", ""),
        "artist": _artists(al),
        "year": al.get("year", ""),
        "thumbnail": _best_thumb(al.get("thumbnails")),
        "trackCount": al.get("trackCount", len(tracks)),
        "tracks": tracks,
    }))


def cmd_playlist(playlist_id):
    yt = _client()
    try:
        pl = yt.get_playlist(playlist_id, limit=200)
    except Exception as e:
        _fail("playlist failed", e)
    print(json.dumps({
        "title": pl.get("title", ""),
        "thumbnail": _best_thumb(pl.get("thumbnails")),
        "trackCount": pl.get("trackCount", 0),
        "_meta": True,
    }), flush=True)
    count = 0
    for t in pl.get("tracks", []):
        card = _track(t)
        if not card.get("videoId"):
            continue
        print(json.dumps(card), flush=True)
        count += 1
    print(json.dumps({"_done": True, "count": count}), flush=True)


def cmd_library(kind, limit="50"):
    yt = _authenticated_client()
    if yt is None:
        _fail("auth required")
    try:
        n = int(limit or 50)
    except ValueError:
        n = 50
    try:
        if kind == "songs":
            items = [_track(t) for t in yt.get_library_songs(limit=n)]
        elif kind == "artists":
            items = [_card(t) for t in yt.get_library_artists(limit=n)]
        elif kind == "albums":
            items = [_card(t) for t in yt.get_library_albums(limit=n)]
        elif kind == "playlists":
            items = [_card(t) for t in yt.get_library_playlists(limit=n)]
        else:
            _fail("unknown library kind")
    except Exception as e:
        _fail("library failed", e)
    print(json.dumps({"kind": kind, "items": items}))


def cmd_rate(video_id, rating):
    yt = _authenticated_client()
    if yt is None:
        _fail("auth required")
    try:
        from ytmusicapi.models.content.enums import LikeStatus
        status = LikeStatus[rating] if rating in LikeStatus.__members__ else LikeStatus.INDIFFERENT
        yt.rate_song(video_id, status)
    except Exception as e:
        _fail("rate failed", e)
    print(json.dumps({"status": "ok", "videoId": video_id, "rating": status.value}))


def _parse_lrc(lrc):
    """Parse LRC text into [{t: seconds, line: str}] sorted by time."""
    import re
    out = []
    tag = re.compile(r"\[(\d+):(\d+)(?:[.:](\d+))?\]")
    for raw in lrc.splitlines():
        stamps = list(tag.finditer(raw))
        if not stamps:
            continue
        text = raw[stamps[-1].end():].strip()
        for m in stamps:
            mins = int(m.group(1)); secs = int(m.group(2))
            frac = m.group(3)
            t = mins * 60 + secs + (int(frac) / (1000.0 if len(frac) == 3 else 100.0) if frac else 0)
            out.append({"t": round(t, 2), "line": text})
    out.sort(key=lambda x: x["t"])
    return out


def _lrclib_synced(title, artist, duration):
    """Fetch synced lyrics from LrcLib (public, no auth). Returns LRC text or None."""
    import urllib.request, urllib.parse
    q = urllib.parse.urlencode({"track_name": title, "artist_name": artist})
    req = urllib.request.Request("https://lrclib.net/api/search?" + q,
                                 headers={"User-Agent": "iNiR (https://github.com/snowarch/inir)"})
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            tracks = json.loads(resp.read())
    except Exception:
        return None
    candidates = [t for t in tracks if t.get("syncedLyrics")]
    if not candidates:
        return None
    if duration > 0:
        candidates.sort(key=lambda t: abs((t.get("duration") or 0) - duration))
    return candidates[0].get("syncedLyrics")


def cmd_lyrics(video_id, title="", artist="", duration="0"):
    try:
        dur = int(float(duration or 0))
    except ValueError:
        dur = 0
    # Prefer LrcLib synced lyrics (what InnerTune shows), like InnerTune's lrclib module.
    synced = None
    if title and artist:
        lrc = _lrclib_synced(title, artist, dur)
        if lrc:
            synced = _parse_lrc(lrc)
    # Fall back to ytmusicapi plain lyrics.
    plain = ""
    source = "LrcLib" if synced else ""
    try:
        yt = _client()
        wp = yt.get_watch_playlist(videoId=video_id, limit=1)
        lid = wp.get("lyrics")
        if lid:
            ly = yt.get_lyrics(lid)
            plain = ly.get("lyrics") or ""
            if not source:
                source = ly.get("source") or ""
    except Exception:
        pass
    print(json.dumps({"plain": plain, "synced": synced, "source": source}))


def cmd_song(video_id):
    yt = _client()
    try:
        s = yt.get_song(video_id)
    except Exception as e:
        _fail("song failed", e)
    vd = (s.get("videoDetails") or {})
    print(json.dumps({
        "videoId": vd.get("videoId", video_id),
        "title": vd.get("title", ""),
        "artist": vd.get("author", ""),
        "thumbnail": _best_thumb((vd.get("thumbnail") or {}).get("thumbnails")),
        "duration": int(vd.get("lengthSeconds", 0) or 0),
        "url": f"https://music.youtube.com/watch?v={video_id}",
    }))


_COMMANDS = {
    "ping": (cmd_ping, 0),
    "auth-status": (cmd_authstatus, 0),
    "oauth-request": (cmd_oauth_request, 0),
    "oauth-poll": (cmd_oauth_poll, 1),
    "connect": (cmd_connect, 0),       # +optional browser id ("auto" default)
    "connect-manual": (cmd_connect_manual, 1),
    "detect-browsers": (cmd_detect_browsers, 0),
    "disconnect": (cmd_disconnect, 0),
    "logout": (cmd_logout, 0),
    "search": (cmd_search, 1),       # +optional filter
    "home": (cmd_home, 0),           # +optional limit
    "radio": (cmd_radio, 1),
    "artist": (cmd_artist, 1),
    "album": (cmd_album, 1),
    "playlist": (cmd_playlist, 1),
    "library": (cmd_library, 1),
    "rate": (cmd_rate, 2),
    "lyrics": (cmd_lyrics, 1),
    "song": (cmd_song, 1),
}


def main():
    if len(sys.argv) < 2:
        _fail("Usage: innertube.py <command> [args]")
    action = sys.argv[1]
    entry = _COMMANDS.get(action)
    if not entry:
        _fail(f"Unknown command: {action}")
    fn, _min = entry
    args = sys.argv[2:]
    if len(args) < _min:
        _fail(f"'{action}' needs {_min} argument(s)")
    fn(*args[: fn.__code__.co_argcount])


if __name__ == "__main__":
    main()
