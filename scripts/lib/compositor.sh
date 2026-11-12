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

# ── Which compositors iNiR sets itself up on ──────────────────────────────────────────────────────────────────────
# The person's pick, the file "compositor" in iNiR's config dir: "niri" (Umbriel is left as it is: no config,
# the shell does not start there), "umbriel" or "both". No file means nobody asked (an update from v2.33, an
# unattended install): Niri, and Umbriel too the moment it is installed or logged into.
compositor_choice_file() {
    local h="${XDG_CONFIG_HOME:-$HOME/.config}" d
    # resolve_inir_config_dir's rule (sdata/lib/environment-variables.sh, inir-cli's Env.configDir)
    if [[ -L "$h/illogical-impulse" && -d "$h/inir" ]]; then d="$h/inir"
    elif [[ -d "$h/illogical-impulse" ]]; then d="$h/illogical-impulse"
    else d="$h/inir"
    fi
    echo "${DOTS_CORE_CONFDIR:-$d}/compositor"
}

compositor_choice() {
    local v; v="$(head -n1 "$(compositor_choice_file)" 2>/dev/null | tr -d '[:space:]')"
    case "$v" in niri|umbriel|both) echo "$v" ;; esac
}

compositor_set_choice() {
    case "$1" in niri|umbriel|both) ;; *) return 2 ;; esac
    local f; f="$(compositor_choice_file)"
    mkdir -p "$(dirname "$f")" && printf '%s\n' "$1" > "$f"
}

# Whether iNiR may set itself up on Umbriel (config, colours, the shell at login).
compositor_umbriel_wanted() { [[ "$(compositor_choice)" != niri ]]; }

# The units inir.service is wired under, one per line: both compositors as soon as either is installed (one added
# later starts the shell too), only Niri's when the person picked Niri alone. Nothing when neither is installed.
compositor_units() {
    local unit
    for unit in niri.service umbriel.service; do
        systemctl --user cat "$unit" &>/dev/null || continue
        echo niri.service
        compositor_umbriel_wanted && echo umbriel.service
        return 0
    done
    return 1
}

# A session start under Umbriel: the first login with no config of their own gets iNiR's (the early port's one is
# moved aside), and every login brings their Niri keys and keyboard along, so nothing has to be typed. Their own
# config is never touched. Quiet; the launcher runs it beside the shell.
compositor_umbriel_session_start() {
    local src="$1" dest="${XDG_CONFIG_HOME:-$HOME/.config}/umbriel"
    [[ "$(compositor_name)" == umbriel ]] && compositor_umbriel_wanted || return 0
    case "$(compositor_umbriel_config_state "$dest")" in
        foreign) return 0 ;;
        none|old)
            compositor_install_umbriel_config "$src" "$dest" || return 1
            compositor_sync_umbriel_from_niri "$dest" || true
            # Umbriel started on its built-in config: it loads and watches iNiR's from now on.
            umbriel config-replace "$dest/config.toml" >/dev/null 2>&1 || true
            # The colours file comes with the next theme change; write it now from the current colours.
            local colors="${src%/defaults/umbriel}/scripts/colors/modules/15-umbriel.sh"
            [[ -f "$colors" ]] && bash "$colors" >/dev/null 2>&1 || true
            ;;
        inir) compositor_sync_umbriel_from_niri "$dest" || true ;;
    esac
}

# ── Umbriel's config ──────────────────────────────────────────────────────────────────────────────────────────────
# Puts iNiR's Umbriel config (defaults/umbriel: config.toml and config.d; effects/ is read from the shell's own
# folder, never installed) in ~/.config/umbriel. A file of ours the person never changed is
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
    done < <(cd "$src" && find config.toml config.d -type f -name '*.toml' ! -name '90-user-extra.toml' | sort)
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
    if command -v dnf >/dev/null 2>&1; then
        # Umbriel's Fedora builds live in Terra (Fyra Labs); added the way Terra's docs say, its key checked
        if ! dnf repolist 2>/dev/null | grep -qi terra; then
            echo "Umbriel comes from Terra, Fyra Labs' repository: adding it" >&2
            sudo dnf install -y --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' \
                --setopt='terra.gpgkey=https://repos.fyralabs.com/terra$releasever/key.asc' terra-release \
                || { echo "Could not add Terra; see $guide" >&2; return 1; }
        fi
        sudo dnf install -y umbriel-nightly && return 0
        return 1
    fi
    echo "Install Umbriel the way its guide says for your distribution: $guide" >&2
    echo "Then run: inir compositor add umbriel" >&2
    return 1
}

# ── Niri → Umbriel ────────────────────────────────────────────────────────────────────────────────────────────────
# Brings the person's Niri habits to Umbriel: every keybind (a spawn as is, a Niri action through the pair iNiR's
# own defaults give for the same key), the keys they removed from iNiR's defaults, keyboard layout and repeat.
# Writes config.d/60-from-niri.toml (iNiR's config includes it, 90-user-extra still wins). Needs inir-accel and jq.
compositor_sync_umbriel_from_niri() {
    local dest="${1:-${XDG_CONFIG_HOME:-$HOME/.config}/umbriel}"
    local lib; lib="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local repo="${lib%/scripts/lib}" niri_dir="${XDG_CONFIG_HOME:-$HOME/.config}/niri"
    local binds out="$dest/config.d/60-from-niri.toml" input_file
    [[ -d "$dest/config.d" ]] || return 1
    command -v jq >/dev/null 2>&1 || return 1
    binds="$("$lib/accel-run" niri-config get-binds 2>/dev/null)" || return 1
    input_file="$niri_dir/config.d/10-input-and-cursor.kdl"; [[ -f "$input_file" ]] || input_file="$niri_dir/config.kdl"
    jq -nr --argjson user "$binds" \
        --rawfile niriDef "$repo/defaults/niri/config.d/70-binds.kdl" \
        --rawfile umbDef "$repo/defaults/umbriel/config.d/70-binds.toml" \
        --rawfile input "$(readlink -f "$input_file" 2>/dev/null || echo /dev/null)" '
      def words: [scan("\"((?:[^\"\\\\]|\\\\.)*)\"") | .[0]];
      def combo: gsub("WheelScroll"; "Wheel");
      def norm: gsub("\\s+"; " ") | sub("^ "; "") | sub(" ?;?$"; "");
      def shq: if test("^[A-Za-z0-9_./:@%+=,-]+$") then . else "\u0027" + gsub("\u0027"; "\u0027\\\\\u0027\u0027") + "\u0027" end;
      def tq: "\"" + (gsub("\\\\"; "\\\\\\\\") | gsub("\""; "\\\"")) + "\"";
      ($niriDef | split("\n") | map(select(test("^\\s*//") | not)
        | capture("^\\s*(?<k>[A-Za-z0-9_+]+)[^{]*\\{\\s*(?<a>[^}]*?)\\s*\\}") // empty
        | {key: (.k | combo), value: (.a | norm)}) | from_entries) as $nd
      | ($umbDef | split("\n") | map(capture("^\"(?<k>[^\"]+)\"\\s*=\\s*(?<v>.+)$") // empty
        | .v as $v | {key: .k, value: (($v | capture("^\"(?<a>(?:[^\"\\\\]|\\\\.)*)\"")) // ($v | capture("action\\s*=\\s*\"(?<a>(?:[^\"\\\\]|\\\\.)*)\"")) // {a: null}).a})
        | from_entries) as $ud
      | ([$nd | to_entries[] | select($ud[.key] != null) | {key: .value, value: $ud[.key]}] | from_entries) as $map
      | ($user.binds | map(select(.commented | not) | .key_combo |= combo)) as $ub
      | ($ub | map(.key_combo) ) as $have
      | [ $ub[] | (.action | norm) as $a
          | (if ($a | startswith("spawn-sh ")) then "spawn " + ($a | words | .[0])
             elif ($a | startswith("spawn ")) then "spawn " + ($a | words | map(shq) | join(" "))
             else $map[$a] end) as $u
          | select($u != null and $u != $ud[.key_combo])
          | [(.options | test("repeat=false")), (.options | test("allow-when-locked=true"))] as $o
          | "\(.key_combo | tq) = " + (if ($o | any) then "{ action = \($u | tq)" + (if $o[0] then ", repeat = false" else "" end)
              + (if $o[1] then ", allow_when_locked = true" else "" end) + " }" else ($u | tq) end)
          | if test("Wheel") then sub("\"(?<a>[^\"]+)\"$"; "{ action = \"\(.a)\", cooldown_ms = 150 }") else . end ] as $lines
      | [ $nd | keys[] | select(($have | index(.)) == null and $ud[.] != null) | "\(tq) = \"\"" ] as $gone
      | ($input | [scan("(?m)^\\s*(layout|variant|options)\\s+\"([^\"]*)\"")] | map({key: .[0], value: .[1]}) | from_entries) as $xkb
      | ($input | [scan("(?m)^\\s*(repeat-delay|repeat-rate)\\s+([0-9]+)")] | map({key: (.[0] | gsub("-"; "_")), value: .[1]}) | from_entries) as $rep
      | ["# Written by iNiR from your Niri config (inir compositor sync): the same keys and keyboard on Umbriel.",
         "# Edits here are lost on the next sync; your own changes go in 90-user-extra.toml.", "", "[keybinds]"]
        + $lines + (if ($gone | length) > 0 then ["", "# Keys you removed from iNiR'"'"'s Niri defaults."] + $gone else [] end)
        + ["", "[input.keyboard]"] + ($xkb | to_entries | map("\(.key) = \(.value | tq)"))
        + ($rep | to_entries | map("\(.key) = \(.value)"))
      | .[]' > "$out.tmp" || { rm -f "$out.tmp"; return 1; }
    mv -f "$out.tmp" "$out"
}
