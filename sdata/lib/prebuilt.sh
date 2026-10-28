# shellcheck shell=bash
# What iNiR runs prebuilt: qs-rs with its own Qt (runtime/) and inir-accel (accel/), under
# ${XDG_DATA_HOME:-~/.local/share}/inir. sdata/prebuilt.json pins each part (version, file, sha256); where the file
# lives comes from inir.space/releases/manifest.json, so hosting can move without touching installs, and the sha256
# only ever from the pin. Fetched before anything is synced (a miss stops with nothing changed), switched on after.
# A pin without a sha256 is not released yet and is skipped. INIR_PREBUILT_FROM=<dir or URL> serves the files
# instead (VMs, a mirror); INIR_PREBUILT=0 skips it all. x86_64 only: elsewhere the shell keeps Quickshell.

# the base's pins; a local INIR_PREBUILT_FROM (VMs, before the releases) may carry its own beside the files
_prebuilt_pins() {
    local from="${INIR_PREBUILT_FROM#file://}"
    if [[ -n "${INIR_PREBUILT_FROM:-}" && -f "$from/prebuilt.json" ]]; then
        printf '%s' "$from/prebuilt.json"
    else
        printf '%s' "${REPO_ROOT}/sdata/prebuilt.json"
    fi
}
_prebuilt_home() { printf '%s' "${XDG_DATA_HOME:-$HOME/.local/share}/inir"; }

# prebuilt_parts: one "part dest version file sha256 repo" line (tab separated) per part this machine takes
prebuilt_parts() {
    [[ "$(uname -m)" == x86_64 && "${INIR_PREBUILT:-1}" == 1 && -f "$(_prebuilt_pins)" ]] || return 0
    jq -r '.parts | to_entries[] | select(.value.sha256 != "")
        | [.key, .value.dest, .value.version, .value.file, .value.sha256, .value.repo] | @tsv' "$(_prebuilt_pins)"
}

_prebuilt_manifest=""
# _prebuilt_url PART VERSION FILE REPO
_prebuilt_url() {
    local from="${INIR_PREBUILT_FROM:-}" template
    if [[ -n "$from" ]]; then
        [[ "$from" == /* ]] && from="file://$from"
        printf '%s/%s' "${from%/}" "$3"
        return
    fi
    [[ -n "$_prebuilt_manifest" ]] \
        || _prebuilt_manifest="$(curl -fsSL --retry 2 --max-time 20 "$(jq -r .manifest "$(_prebuilt_pins)")" 2>/dev/null)" \
        || _prebuilt_manifest="{}"
    template="$(jq -r --arg p "$1" '.parts[$p] // empty' <<<"$_prebuilt_manifest" 2>/dev/null)"
    [[ -n "$template" ]] || template="$(jq -r .fallback "$(_prebuilt_pins)")"
    template="${template//\{repo\}/$4}"
    template="${template//\{version\}/$2}"
    printf '%s' "${template//\{file\}/$3}"
}

# prebuilt_fetch: every pinned part unpacked at <dest>/<version>, its sha256 checked; fails on the first miss
prebuilt_fetch() {
    local home part dest ver file sha repo dir tmp url
    home="$(_prebuilt_home)"
    while IFS=$'\t' read -r part dest ver file sha repo; do
        dir="$home/$dest/$ver"
        [[ "$(cat "$dir/.sha256" 2>/dev/null)" == "$sha" ]] && continue
        url="$(_prebuilt_url "$part" "$ver" "$file" "$repo")"
        tmp="$(mktemp -d)" || return 1
        if curl -fsSL --retry 2 --max-time 900 -o "$tmp/$file" "$url" \
            && [[ "$(sha256sum "$tmp/$file" | cut -d' ' -f1)" == "$sha" ]] \
            && rm -rf "$dir.new" && mkdir -p "$dir.new" \
            && tar -xzf "$tmp/$file" -C "$dir.new" --strip-components=1 --no-same-owner \
            && printf '%s\n' "$sha" >"$dir.new/.sha256" \
            && rm -rf "$dir" && mv "$dir.new" "$dir"; then
            rm -rf "$tmp"
        else
            rm -rf "$tmp" "$dir.new"
            printf '%s %s: could not get or verify %s\n' "$part" "$ver" "$url" >&2
            return 1
        fi
    done < <(prebuilt_parts)
}

# prebuilt_activate: each part's `current` link on its pinned version, accel's hooks, and of the older versions
# only the one current pointed at before (what a rollback goes back to)
prebuilt_activate() {
    local home part dest ver file sha repo prev old
    home="$(_prebuilt_home)"
    while IFS=$'\t' read -r part dest ver file sha repo; do
        [[ -f "$home/$dest/$ver/.sha256" ]] || continue
        prev="$(readlink "$home/$dest/current" 2>/dev/null)"
        ln -sfn "$ver" "$home/$dest/current"
        for old in "$home/$dest"/*/; do
            old="${old%/}"
            old="${old##*/}"
            [[ "$old" == "$ver" || "$old" == "$prev" || "$old" == current ]] || rm -rf "${home:?}/$dest/$old"
        done
        [[ "$part" == inir-accel ]] && prebuilt_accel_hooks
    done < <(prebuilt_parts)
    return 0
}

_PREBUILT_GO=(inir-washi inir-opencode-themegen inir-vscode-themegen)

# prebuilt_accel_hooks: what inir-accel proved byte for byte runs on it: those Go helpers in user/generated/bin
# and the venv's python3, which hands every script it doesn't own to python3.real (as activate-accelerators.sh
# install does on a dev machine). Without accel/current it puts the originals back.
prebuilt_accel_hooks() {
    local bin state gen venv go real
    bin="$(_prebuilt_home)/accel/current/inir-accel"
    state="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell"
    gen="$state/user/generated/bin"
    venv="$state/.venv/bin"
    if [[ ! -x "$bin" ]]; then
        for go in "${_PREBUILT_GO[@]}"; do
            [[ -L "$gen/$go" && "$(readlink "$gen/$go")" == */accel/current/inir-accel ]] || continue
            rm -f "$gen/$go"
            [[ -f "$gen/$go.go.bak" ]] && mv -f "$gen/$go.go.bak" "$gen/$go"
        done
        if [[ -L "$venv/python3" && "$(readlink "$venv/python3")" == */accel/current/inir-accel && -e "$venv/python3.real" ]]; then
            ln -sfn "$(readlink -f "$venv/python3.real")" "$venv/python3" && rm -f "$venv/python3.real"
        fi
        return 0
    fi
    mkdir -p "$gen"
    for go in "${_PREBUILT_GO[@]}"; do
        [[ -f "$gen/$go" && ! -L "$gen/$go" ]] && mv -f "$gen/$go" "$gen/$go.go.bak"
        ln -sfn "$bin" "$gen/$go"
    done
    if [[ -d "$venv" ]]; then
        # a venv made again since the last hook has its own python3 again: that one is the real one now
        if [[ "$(readlink "$venv/python3" 2>/dev/null)" != "$bin" ]]; then
            real="$(readlink -f "$venv/python3" 2>/dev/null)" && [[ -x "$real" ]] && ln -sfn "$real" "$venv/python3.real"
        fi
        [[ -e "$venv/python3.real" ]] && ln -sfn "$bin" "$venv/python3"
    fi
    return 0
}

# prebuilt_accel_hooks_ok: the hooks match what is installed (doctor step 13): pointed at accel/current while it is
# there, none left pointing at it once it went
prebuilt_accel_hooks_ok() {
    local bin state go
    bin="$(_prebuilt_home)/accel/current/inir-accel"
    state="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell"
    if [[ -x "$bin" ]]; then
        [[ ! -d "$state/.venv/bin" || "$(readlink "$state/.venv/bin/python3")" == "$bin" ]] || return 1
        for go in "${_PREBUILT_GO[@]}"; do
            [[ "$(readlink "$state/user/generated/bin/$go")" == "$bin" ]] || return 1
        done
        return 0
    fi
    for go in .venv/bin/python3 "${_PREBUILT_GO[@]/#/user/generated/bin/}"; do
        [[ "$(readlink "$state/$go")" != */accel/current/inir-accel ]] || return 1
    done
}

# prebuilt_runtime_off: the shell back on Quickshell when qs-rs did not load (the launcher takes runtime/current
# first); the next update tries again
prebuilt_runtime_off() { rm -f "$(_prebuilt_home)/runtime/current"; }

# prebuilt_links / prebuilt_restore_links FILE: the current links, saved with a snapshot and put back with it
prebuilt_links() {
    local dest
    for dest in runtime accel; do
        printf '%s %s\n' "$dest" "$(readlink "$(_prebuilt_home)/$dest/current" 2>/dev/null)"
    done
}
prebuilt_restore_links() {
    local dest target home
    home="$(_prebuilt_home)"
    [[ -f "$1" ]] || return 0
    while read -r dest target; do
        if [[ -n "$target" && -d "$home/$dest/$target" ]]; then
            ln -sfn "$target" "$home/$dest/current"
        else
            rm -f "$home/$dest/current"
        fi
    done <"$1"
    prebuilt_accel_hooks
}
