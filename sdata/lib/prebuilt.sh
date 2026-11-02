# shellcheck shell=bash
# What iNiR runs prebuilt: qs-rs with its own Qt (runtime/) and inir-accel (accel/), under
# ${XDG_DATA_HOME:-~/.local/share}/inir. sdata/prebuilt.json pins each part (version, file, sha256); where the file
# lives comes from inir.space/releases/manifest.json, so hosting can move without touching installs, and the sha256
# only ever from the pin. Fetched before anything is synced (a miss stops with nothing changed), switched on after.
# A pin without a sha256 is not released yet: update and install refuse it (prebuilt_unpinned). INIR_PREBUILT_FROM=<dir or URL> serves the files
# instead (VMs, a mirror); INIR_PREBUILT=0 skips it all. A part is built for its "arch" (x86_64 when it names none):
# aarch64 takes only inir-accel, so the shell keeps Quickshell there.
# An add-on ("with": the part it unpacks over, e.g. Qt WebEngine over qs-rs) has that part's version, so it lands in
# the folder it was built for; it comes only while its "when" config key is true or INIR_PREBUILT_WANT names it.

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
# the inir-accel the shell runs (scripts/lib/accel.sh: the same path, INIR_ACCEL first)
prebuilt_accel_bin() { printf '%s' "${INIR_ACCEL:-$(_prebuilt_home)/accel/current/inir-accel}"; }

# prebuilt_parts: one "part dest version file sha256 repo with" line (tab separated) per part this machine takes
prebuilt_parts() {
    [[ "${INIR_PREBUILT:-1}" == 1 && -f "$(_prebuilt_pins)" ]] || return 0
    local config="${DOTS_CORE_CONFDIR:-${XDG_CONFIG_HOME:-$HOME/.config}/inir}/config.json"
    jq -r --arg arch "$(uname -m)" --arg want " ${INIR_PREBUILT_WANT:-} " \
        --argjson cfg "$(jq -c . "$config" 2>/dev/null || echo '{}')" '
        .parts as $all | .parts | to_entries[] | select(.value.sha256 != "" and (.value.arch // "x86_64") == $arch)
        | . as $p
        | select(($p.value.with // "") == "" or ($want | contains(" " + $p.key + " "))
            or (try ($cfg | getpath($p.value.when | split("."))) catch false) == true)
        | [.key, .value.dest, (if (.value.with // "") == "" then .value.version else $all[.value.with].version end),
            .value.file, .value.sha256, .value.repo, .value.with // ""] | @tsv' \
        "$(_prebuilt_pins)"
}

# prebuilt_unpinned: what this machine needs that has no sha256 yet. The base has no helpers of its own any more, so a
# base published like that stops the update before it touches anything; it never goes on without them.
prebuilt_unpinned() {
    [[ "${INIR_PREBUILT:-1}" == 1 && -f "$(_prebuilt_pins)" ]] || return 0
    jq -r --arg arch "$(uname -m)" '.parts | to_entries[] | .key as $k | .value
        | select(.sha256 == "" and (.with // "") == "" and (.arch // "x86_64") == $arch) | $k' "$(_prebuilt_pins)"
}

# prebuilt_pending_addons: the titles of the add-ons this machine takes whose part is there and they are not
prebuilt_pending_addons() {
    local home part dest ver file sha repo with
    home="$(_prebuilt_home)"
    while IFS=$'\t' read -r part dest ver file sha repo with; do
        [[ -n "$with" && -f "$home/$dest/$ver/.sha256" ]] || continue
        [[ "$(cat "$home/$dest/$ver/.$part.sha256" 2>/dev/null)" != "$sha" ]] || continue
        jq -r --arg p "$part" '.parts[$p].title // $p' "$(_prebuilt_pins)"
    done < <(prebuilt_parts)
}

# _prebuilt_unpack TARBALL DIR SHA PART WITH: a part into DIR whole, beside the old one until it is complete; an add-on
# over its part's DIR. The sha256 is written last, so a half-done unpack is fetched again.
_prebuilt_unpack() {
    local tarball=$1 dir=$2 sha=$3 part=$4 with=$5 x
    if [[ -n "$with" ]]; then
        x="${tarball%/*}/x"
        mkdir -p "$x" && tar -xzf "$tarball" -C "$x" --strip-components=1 --no-same-owner \
            && cp -a "$x/." "$dir/" && printf '%s\n' "$sha" >"$dir/.$part.sha256"
        return
    fi
    rm -rf "$dir.new" && mkdir -p "$dir.new" \
        && tar -xzf "$tarball" -C "$dir.new" --strip-components=1 --no-same-owner \
        && printf '%s\n' "$sha" >"$dir.new/.sha256" \
        && rm -rf "$dir" && mv "$dir.new" "$dir"
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
    local home part dest ver file sha repo with dir mark tmp url
    home="$(_prebuilt_home)"
    while IFS=$'\t' read -r part dest ver file sha repo with; do
        dir="$home/$dest/$ver"
        mark="$dir/.sha256"
        if [[ -n "$with" ]]; then
            # over its part's folder, so that part comes first (the pins list it first)
            [[ -f "$dir/.sha256" ]] || continue
            mark="$dir/.$part.sha256"
        fi
        [[ "$(cat "$mark" 2>/dev/null)" == "$sha" ]] && continue
        url="$(_prebuilt_url "$part" "$ver" "$file" "$repo")"
        tmp="$(mktemp -d)" || return 1
        if curl -fsSL --retry 2 --max-time 900 -o "$tmp/$file" "$url" \
            && [[ "$(sha256sum "$tmp/$file" | cut -d' ' -f1)" == "$sha" ]] \
            && _prebuilt_unpack "$tmp/$file" "$dir" "$sha" "$part" "$with"; then
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
    local home part dest ver file sha repo with prev old
    home="$(_prebuilt_home)"
    while IFS=$'\t' read -r part dest ver file sha repo with; do
        [[ -z "$with" && -f "$home/$dest/$ver/.sha256" ]] || continue
        prev="$(readlink "$home/$dest/current" 2>/dev/null)"
        ln -sfn "$ver" "$home/$dest/current"
        for old in "$home/$dest"/*/; do
            old="${old%/}"
            old="${old##*/}"
            [[ "$old" == "$ver" || "$old" == "$prev" || "$old" == current ]] || rm -rf "${home:?}/$dest/$old"
        done
        [[ "$dest" == accel ]] && prebuilt_accel_hooks
    done < <(prebuilt_parts)
    return 0
}

_PREBUILT_GO=(inir-washi inir-opencode-themegen inir-vscode-themegen inir-zed-themegen)

# prebuilt_accel_hooks: the helpers v2.33 compiled from Go in user/generated/bin run on inir-accel, which proved them
# byte for byte (a compiled one kept as *.go.bak). Without accel/current it puts the originals back.
prebuilt_accel_hooks() {
    local bin gen go
    bin="$(_prebuilt_home)/accel/current/inir-accel"
    gen="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/user/generated/bin"
    if [[ ! -x "$bin" ]]; then
        for go in "${_PREBUILT_GO[@]}"; do
            [[ -L "$gen/$go" && "$(readlink "$gen/$go")" == */accel/current/inir-accel ]] || continue
            rm -f "$gen/$go"
            [[ -f "$gen/$go.go.bak" ]] && mv -f "$gen/$go.go.bak" "$gen/$go"
        done
        return 0
    fi
    mkdir -p "$gen"
    for go in "${_PREBUILT_GO[@]}"; do
        [[ -f "$gen/$go" && ! -L "$gen/$go" ]] && mv -f "$gen/$go" "$gen/$go.go.bak"
        ln -sfn "$bin" "$gen/$go"
    done
    return 0
}

# prebuilt_accel_hooks_ok: the hooks match what is installed (doctor step 13): pointed at accel/current while it is
# there, none left pointing at it once it went
prebuilt_accel_hooks_ok() {
    local bin state go
    bin="$(_prebuilt_home)/accel/current/inir-accel"
    state="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell"
    if [[ -x "$bin" ]]; then
        for go in "${_PREBUILT_GO[@]}"; do
            [[ "$(readlink "$state/user/generated/bin/$go")" == "$bin" ]] || return 1
        done
        return 0
    fi
    for go in "${_PREBUILT_GO[@]/#/user/generated/bin/}"; do
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
