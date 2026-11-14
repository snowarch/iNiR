# shellcheck shell=bash
# The base carries no family: every plugin comes from inir-hub through the inir binary (`inir hub`). Install and
# update bring the ones this person has, fetched before anything is synced (a miss stops with the old runtime
# untouched) and installed right after the sync, before the shell restarts.

_hub() {
    local cli="${INIR_CLI:-${XDG_DATA_HOME:-$HOME/.local/share}/inir/cli/inir}"
    [[ -x "$cli" ]] || return 127
    # the running shell is the old one until the restart: nothing to tell it yet
    INIR_HUB_FROM_SHELL=1 "$cli" hub "$@"
}

# Why a hub call failed, in the inir command's own words, on stderr: "tries again once online" alone left a tester
# with a working connection and nothing to go on (11-03).
_hub_why() {
    local errors="$1" json="${2:-}" why
    why="$(jq -r '[.sources[]? | .error // empty | select(. != "")] | join("; ")' <<<"$json" 2>/dev/null)"
    [[ -n "$why" ]] || why="$(head -c 600 "$errors" 2>/dev/null)"
    [[ -n "$why" ]] || why="the hub catalogue came back empty"
    printf '  %s\n' "$why" >&2
}

# _hub_worn RUNTIME: the plugin ids the person's config wears. A family names in its plugin.json `wears` the config
# keys whose value is a plugin of the hub (iRiS: the Design it wears); the base reads them and never names one.
_hub_worn() {
    local runtime="$1" config="" candidate key
    for candidate in "${XDG_CONFIG_HOME:-$HOME/.config}/illogical-impulse/config.json" "${XDG_CONFIG_HOME:-$HOME/.config}/inir/config.json"; do
        [[ -f "$candidate" ]] && { config="$candidate"; break; }
    done
    [[ -n "$config" ]] || return 0
    jq -r '.wears[]? | strings' "$runtime"/modules/*/plugin.json 2>/dev/null | sort -u | while read -r key; do
        jq -r --arg key "$key" 'getpath($key | split(".")) // empty | strings' "$config" 2>/dev/null
    done
}

# hub_plugins_needed RUNTIME TREE: one id per line, fails when the catalogue can't be read.
# Needed: every family the hub lists (each machine carries all three), what the hub installed, what the old runtime
# still holds as a real folder at a plugin's path (a v2.33 install carried its families in its own tree) and what the
# config wears (a Design picked before it came from the hub). Nothing else: a component or Design comes only when the
# person installs it.
hub_plugins_needed() {
    local catalogue runtime="$1" tree="$2" id provides installed kind errors worn unasked rc=0
    if [[ ! -x "${INIR_CLI:-${XDG_DATA_HOME:-$HOME/.local/share}/inir/cli/inir}" ]]; then
        printf '  %s\n' "the inir command is not installed, and the hub lives in it" >&2
        return 1
    fi
    errors="$(mktemp)" || return 1
    catalogue="$(_hub status --max-age 0 --json 2>"$errors")" || rc=$?
    if ((rc != 0)) || ! jq -e '(.items // []) | length > 0' >/dev/null 2>&1 <<<"$catalogue"; then
        _hub_why "$errors" "$catalogue"
        rm -f "$errors"
        return 1
    fi
    rm -f "$errors"
    worn=" $(_hub_worn "$runtime" | tr '\n' ' ') "
    unasked=" $(hub_unasked "$runtime" | tr '\n' ' ') "
    # a unit separator, not a tab: bash folds empty tab-separated fields away
    while IFS=$'\x1f' read -r id provides installed kind; do
        [[ -n "$provides" && ! -e "$tree/$provides" && "$unasked" != *" $id "* ]] || continue
        if [[ "$installed" == yes || ( -d "$runtime/$provides" && ! -L "$runtime/$provides" ) \
            || "$worn" == *" $id "* || "$kind" == family ]]; then
            printf '%s\n' "$id"
        fi
    # `installed` is the installed version, "" when it is not: jq takes "" as true, so test it for a value (a bare
    # `if .installed` put every component and Design of the hub on every machine that updated).
    done < <(jq -r '.items[] | [.id, (.provides // ""), (if (.installed // "") != "" then "yes" else "" end), (.kind // "")] | map(tostring) | join("\u001f")' <<<"$catalogue")
}

# hub_unasked RUNTIME: the components and Designs an update put here without the person asking (v3.0.0 to 3.1.1 brought
# every one the hub listed), one id per line, until hub_drop_unasked has run once on this machine. Nothing tells them
# apart from one the person picked, so only what the config wears stays; the Hub brings any other back, and its
# options file under ~/.config/inir/plugins stays for it.
hub_unasked() {
    local state="${XDG_STATE_HOME:-$HOME/.local/state}/inir/hub" worn id
    [[ -f "$state/installed.json" && ! -e "$state/unasked-dropped" ]] || return 0
    worn=" $(_hub_worn "$1" | tr '\n' ' ') "
    jq -r '(.items // {}) | to_entries[] | select(.value.kind == "component" or .value.kind == "design") | .key' \
        "$state/installed.json" 2>/dev/null | while read -r id; do
        [[ "$worn" == *" $id "* ]] || printf '%s\n' "$id"
    done
}

# hub_drop_unasked RUNTIME: removes them one by one (one another item needs stays) and prints the name of each
# removed, then marks the machine: what the person installs afterwards is theirs.
hub_drop_unasked() {
    local state="${XDG_STATE_HOME:-$HOME/.local/state}/inir/hub" id name
    for id in $(hub_unasked "$1"); do
        name="$(jq -r --arg id "$id" '.items[$id].name // $id' "$state/installed.json" 2>/dev/null)"
        _hub remove "$id" >/dev/null 2>&1 && printf '%s\n' "${name:-$id}"
    done
    [[ -d "$state" ]] && : >"$state/unasked-dropped"
    return 0
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
