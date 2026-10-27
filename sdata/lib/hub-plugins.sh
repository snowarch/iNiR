# shellcheck shell=bash
# The base carries no family: every plugin comes from inir-hub through the inir binary (`inir hub`). Install and
# update bring the ones this person has, fetched before anything is synced (a miss stops with the old runtime
# untouched) and installed right after the sync, before the shell restarts.

_hub() {
    local cli="${XDG_DATA_HOME:-$HOME/.local/share}/inir/cli/inir"
    [[ -x "$cli" ]] || return 127
    # the running shell is the old one until the restart: nothing to tell it yet
    INIR_HUB_FROM_SHELL=1 "$cli" hub "$@"
}

# hub_plugins_needed RUNTIME TREE [all-families]: one id per line, fails when the catalogue can't be read.
# Needed: what the hub installed, what the old runtime still holds as a real folder at a plugin's path (a v2.33
# install carried its families in its own tree), and with all-families every family listed (a fresh install).
hub_plugins_needed() {
    local catalogue
    catalogue="$(_hub status --max-age 0 --json 2>/dev/null)" || return 1
    RUNTIME="$1" TREE="$2" ALL="${3:-}" python3 -c '
import json, os, sys
items = json.loads(sys.stdin.read() or "{}").get("items") or []
if not items:
    sys.exit(1)
runtime, tree, every = os.environ["RUNTIME"], os.environ["TREE"], os.environ["ALL"] == "all-families"
for item in items:
    provides = item.get("provides") or ""
    if not provides or os.path.exists(os.path.join(tree, provides)):
        continue
    at = os.path.join(runtime, provides)
    carried = os.path.isdir(at) and not os.path.islink(at)
    if item.get("installed") or carried or (every and item.get("kind") == "family"):
        print(item["id"])
' <<<"$catalogue"
}

# hub_fetch_plugins VERSION ID...: into the hub cache, checked against the iNiR version being installed
hub_fetch_plugins() {
    local version="$1"; shift
    (($#)) || return 0
    _hub fetch "$@" --for "$version" >/dev/null
}

# hub_install_plugins ID...: from the cache once the runtime is synced; relinks what a rollback unlinked
hub_install_plugins() {
    (($#)) || return 0
    _hub install "$@" >/dev/null
}
