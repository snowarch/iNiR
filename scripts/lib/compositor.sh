# Which compositor runs this session, and the few facts scripts ask it for, on Niri and on Umbriel alike.
# Source it; nothing runs on load.

# niri, umbriel, hyprland or nothing. Umbriel first: a nested one inherits the outer NIRI_SOCKET.
compositor_name() {
    if [ -n "${UMBRIEL_SOCKET:-}" ] && [ -S "$UMBRIEL_SOCKET" ] && command -v umbriel >/dev/null 2>&1; then
        echo umbriel
    elif [ -n "${NIRI_SOCKET:-}" ] && command -v niri >/dev/null 2>&1; then
        echo niri
    elif [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && command -v hyprctl >/dev/null 2>&1; then
        echo hyprland
    fi
}

# The output the pointer and keyboard are on, by its connector name (DP-1).
compositor_focused_output() {
    case "$(compositor_name)" in
        umbriel) umbriel outputs --json 2>/dev/null | jq -r 'map(select(.focused))[0].name // ""' ;;
        niri) niri msg -j focused-output 2>/dev/null | jq -r '.name // ""' ;;
        hyprland) hyprctl monitors -j 2>/dev/null | jq -r 'map(select(.focused))[0].name // ""' ;;
    esac
}

# First and last workspace index of an output, as "FIRST LAST".
compositor_workspace_range() {
    local output="$1"
    case "$(compositor_name)" in
        umbriel) umbriel workspaces --json 2>/dev/null | jq -r --arg o "$output" '[.[] | select(.output == $o) | .index] | sort | "\(first // "") \(last // "")"' ;;
        niri) niri msg -j workspaces 2>/dev/null | jq -r --arg o "$output" '[.[] | select(.output == $o) | .idx] | sort | "\(first // "") \(last // "")"' ;;
    esac
}

# The widest current mode across outputs, as WIDTHxHEIGHT.
compositor_max_resolution() {
    case "$(compositor_name)" in
        umbriel) umbriel outputs --json 2>/dev/null | jq -r '[.[] | .modes[]? | select(.current)] | max_by(.width * .height) // empty | "\(.width)x\(.height)"' ;;
        niri) niri msg -j outputs 2>/dev/null | jq -r '[.[] | .current_mode as $c | .modes[$c]? // empty] | max_by(.width * .height) // empty | "\(.width)x\(.height)"' ;;
    esac
}

# ── Umbriel's config ──────────────────────────────────────────────────────────────────────────────────────────────
# Puts iNiR's Umbriel config (defaults/umbriel) in ~/.config/umbriel. A file of ours the person never changed is
# refreshed; one they changed is kept (`.inir-sums` remembers what we wrote); config.d/90-user-extra.toml is theirs
# and only created. A config.toml that is not iNiR's is their own setup: nothing is touched. The one the early
# iNiR-Umbriel port wrote ("# iNiR defaults for Umbriel") no longer loads in today's Umbriel: it is moved aside
# whole to umbriel.inir-old-<time> and replaced.
# Sets COMPOSITOR_CONFIG_RESULT (installed | replaced | updated | current | foreign), COMPOSITOR_CONFIG_KEPT (files
# kept) and COMPOSITOR_CONFIG_BACKUP (where a replaced config went).
compositor_umbriel_config_state() {
    local conf="${1:-${XDG_CONFIG_HOME:-$HOME/.config}/umbriel}/config.toml"
    if [[ ! -f "$conf" ]]; then echo none
    elif grep -q '^# iNiR — Umbriel configuration' "$conf"; then echo inir
    elif grep -q '^# iNiR defaults for Umbriel' "$conf"; then echo old
    else echo foreign
    fi
}

compositor_install_umbriel_config() {
    local src="$1" dest="${2:-${XDG_CONFIG_HOME:-$HOME/.config}/umbriel}"
    local sums="$dest/.inir-sums" rel want have recorded new_sums="" changed=false fresh=false replaced=false
    COMPOSITOR_CONFIG_RESULT="" COMPOSITOR_CONFIG_KEPT="" COMPOSITOR_CONFIG_BACKUP=""
    [[ -f "$src/config.toml" ]] || return 1
    case "$(compositor_umbriel_config_state "$dest")" in
        foreign) COMPOSITOR_CONFIG_RESULT=foreign; return 0 ;;
        old)
            COMPOSITOR_CONFIG_BACKUP="$dest.inir-old-$(date +%Y%m%d-%H%M%S)"
            mv "$dest" "$COMPOSITOR_CONFIG_BACKUP" || return 1
            replaced=true ;;
    esac
    [[ -f "$dest/config.toml" ]] || fresh=true
    mkdir -p "$dest/config.d" || return 1
    while IFS= read -r rel; do
        want=$(sha256sum < "$src/$rel" | cut -d' ' -f1)
        if [[ -f "$dest/$rel" ]]; then
            have=$(sha256sum < "$dest/$rel" | cut -d' ' -f1)
            if [[ "$have" == "$want" ]]; then
                new_sums+="$want $rel"$'\n'
                continue
            fi
            recorded=$(awk -v f="$rel" '$2 == f { print $1 }' "$sums" 2>/dev/null)
            if [[ "$have" != "$recorded" ]]; then
                COMPOSITOR_CONFIG_KEPT+="${COMPOSITOR_CONFIG_KEPT:+ }$rel"
                [[ -n "$recorded" ]] && new_sums+="$recorded $rel"$'\n'
                continue
            fi
        fi
        cp -f "$src/$rel" "$dest/$rel" || return 1
        new_sums+="$want $rel"$'\n'
        changed=true
    done < <(cd "$src" && find . -type f -name '*.toml' ! -name '90-user-extra.toml' | sed 's|^\./||' | sort)
    if [[ ! -f "$dest/config.d/90-user-extra.toml" && -f "$src/config.d/90-user-extra.toml" ]]; then
        cp "$src/config.d/90-user-extra.toml" "$dest/config.d/90-user-extra.toml" || return 1
    fi
    printf '%s' "$new_sums" > "$sums"
    if $replaced; then COMPOSITOR_CONFIG_RESULT=replaced
    elif $fresh; then COMPOSITOR_CONFIG_RESULT=installed
    elif $changed; then COMPOSITOR_CONFIG_RESULT=updated
    else COMPOSITOR_CONFIG_RESULT=current
    fi
}

# Installs the Umbriel package where iNiR knows how: a distribution repository first (CachyOS ships it), then the
# AUR. Elsewhere it prints where Umbriel's own guide is and fails.
compositor_install_umbriel_package() {
    command -v umbriel >/dev/null 2>&1 && umbriel --version >/dev/null 2>&1 && return 0
    local guide="https://docs.noctalia.dev/umbriel/installation/"
    if command -v pacman >/dev/null 2>&1; then
        local pkgs=(umbriel)
        if pacman -Si umbriel >/dev/null 2>&1; then
            pacman -Si xdg-desktop-portal-umbriel >/dev/null 2>&1 && pkgs+=(xdg-desktop-portal-umbriel)
            # A broken umbriel-git (a library it was built against is gone) is replaced, not kept beside it.
            sudo pacman -S --needed "${pkgs[@]}" && return 0
            return 1
        fi
        local helper
        for helper in paru yay; do
            if command -v "$helper" >/dev/null 2>&1; then
                "$helper" -S --needed umbriel-git && return 0
                return 1
            fi
        done
        echo "Umbriel is in the AUR (umbriel-git); install paru or yay, or see $guide" >&2
        return 1
    fi
    if command -v dnf >/dev/null 2>&1 && dnf repolist 2>/dev/null | grep -qi terra; then
        sudo dnf install -y umbriel-nightly && return 0
        return 1
    fi
    echo "Install Umbriel the way its guide says for your distribution: $guide" >&2
    echo "Then run: inir compositor add umbriel" >&2
    return 1
}
