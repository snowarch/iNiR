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
    local catalogue runtime="$1" tree="$2" all="${3:-}" id provides installed kind
    catalogue="$(_hub status --max-age 0 --json 2>/dev/null)" || return 1
    jq -e '(.items // []) | length > 0' >/dev/null 2>&1 <<<"$catalogue" || return 1
    # a unit separator, not a tab: bash folds empty tab-separated fields away
    while IFS=$'\x1f' read -r id provides installed kind; do
        [[ -n "$provides" && ! -e "$tree/$provides" ]] || continue
        if [[ "$installed" == yes || ( -d "$runtime/$provides" && ! -L "$runtime/$provides" ) \
            || ( "$all" == all-families && "$kind" == family ) ]]; then
            printf '%s\n' "$id"
        fi
    done < <(jq -r '.items[] | [.id, (.provides // ""), (if .installed then "yes" else "" end), (.kind // "")] | map(tostring) | join("\u001f")' <<<"$catalogue")
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
