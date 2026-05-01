#!/usr/bin/env bash

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
CACHE_DIR="$XDG_CACHE_HOME/quickshell"
STATE_DIR="$XDG_STATE_HOME/quickshell"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHELL_ROOT="$(cd "$SCRIPT_DIR/../.." 2>/dev/null && pwd)"

# shellcheck source=scripts/lib/config-path.sh
source "$SCRIPT_DIR/../lib/config-path.sh"
SHELL_CONFIG_FILE="$(inir_config_file)"
TEMPLATE_DIR="$XDG_CONFIG_HOME/matugen"
terminalscheme="$SCRIPT_DIR/terminal/scheme-base.json"

# Validate critical runtime dependencies early
if ! command -v jq &>/dev/null; then
    echo "[switchwall.sh] Missing required dependency: jq"
    echo "  Arch: sudo pacman -S jq"
    exit 1
fi

# Serialized config.json write — flock prevents concurrent jq writes from
# clobbering each other. QML's FileView doesn't participate in this lock;
# ThemeService uses a 100ms delay to let FileView flush before invoking us.
_config_locked_write() {
    local lockfile="$SHELL_CONFIG_FILE.lock"
    (
        flock -w 5 200 || { echo "[switchwall.sh] config lock timeout" >&2; return 1; }
        jq "$@" "$SHELL_CONFIG_FILE" > "$SHELL_CONFIG_FILE.tmp" && \
            mv "$SHELL_CONFIG_FILE.tmp" "$SHELL_CONFIG_FILE"
    ) 200>"$lockfile"
}

handle_kde_material_you_colors() {
    # Check if Qt app theming is enabled in config
    if [ -f "$SHELL_CONFIG_FILE" ]; then
        enable_qt_apps=$(jq -r '.appearance.wallpaperTheming.enableQtApps' "$SHELL_CONFIG_FILE")
        if [ "$enable_qt_apps" == "false" ]; then
            return
        fi
    fi

    # Map $type_flag to allowed scheme variants for kde-material-you-colors-wrapper.sh
    local kde_scheme_variant=""
    case "$type_flag" in
        scheme-content|scheme-expressive|scheme-fidelity|scheme-fruit-salad|scheme-monochrome|scheme-neutral|scheme-rainbow|scheme-tonal-spot)
            kde_scheme_variant="$type_flag"
            ;;
        *)
            kde_scheme_variant="scheme-tonal-spot" # default
            ;;
    esac

    # Kill any previous wrapper process to prevent stacking
    local pidfile="$CACHE_DIR/kde-material-you-colors.pid"
    if [[ -f "$pidfile" ]]; then
        local old_pid
        old_pid=$(<"$pidfile")
        if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
            kill "$old_pid" 2>/dev/null
        fi
    fi

    nohup "$XDG_CONFIG_HOME"/matugen/templates/kde/kde-material-you-colors-wrapper.sh --scheme-variant "$kde_scheme_variant" >/dev/null 2>&1 &
    echo $! > "$pidfile"
}

pre_process() {
    local mode_flag="$1"

    # Set GNOME color-scheme if mode_flag is dark or light
    if [[ "$mode_flag" == "dark" ]]; then
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
        gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark'
    elif [[ "$mode_flag" == "light" ]]; then
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-light'
        gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3'
    fi

    if [ ! -d "$CACHE_DIR"/user/generated ]; then
        mkdir -p "$CACHE_DIR"/user/generated
    fi
    if [ ! -d "$STATE_DIR"/user/generated ]; then
        mkdir -p "$STATE_DIR"/user/generated
    fi
}

post_process() {
    local screen_width="$1"
    local screen_height="$2"
    local wallpaper_path="$3"

    handle_kde_material_you_colors &
    "$SCRIPT_DIR/code/material-code-set-color.sh" &
    # Best-effort live refresh is handled by apply-gtk-theme.sh for GTK/KDE apps.
}

hex_to_rgb_triplet() {
    local hex="$1"
    hex="${hex#\#}"
    [[ "$hex" =~ ^[A-Fa-f0-9]{6}$ ]] || return 1
    printf "%d,%d,%d\n" "0x${hex:0:2}" "0x${hex:2:2}" "0x${hex:4:2}"
}

write_chromium_theme_contract() {
    local source_json="$1"
    local output_path="$2"
    local hex_color=""
    local rgb_color=""

    [[ -f "$source_json" ]] || return 1
    hex_color=$(jq -r '.surface_container_low // .surface // .background // empty' "$source_json" 2>/dev/null)
    [[ "$hex_color" =~ ^#[A-Fa-f0-9]{6}$ ]] || return 1
    rgb_color=$(hex_to_rgb_triplet "$hex_color") || return 1
    printf '%s\n' "$rgb_color" > "$output_path"
}

write_generated_wallpaper_path() {
    local wallpaper_path="$1"
    local wallpaper_state_path="$STATE_DIR/user/generated/wallpaper/path.txt"

    mkdir -p "$(dirname "$wallpaper_state_path")"
    printf '%s\n' "$wallpaper_path" > "$wallpaper_state_path"
}

get_max_monitor_resolution() {
    local width=1920
    local height=1080
    # Try Niri first
    if command -v niri >/dev/null 2>&1 && niri msg outputs >/dev/null 2>&1; then
        # Parse niri msg outputs for resolution (e.g., "  Current mode: 1920x1080@60.000")
        local res=$(niri msg outputs 2>/dev/null | grep -oP 'Current mode: \K\d+x\d+' | sort -t'x' -k1 -nr | head -1)
        if [[ -n "$res" ]]; then
            width=$(echo "$res" | cut -d'x' -f1)
            height=$(echo "$res" | cut -d'x' -f2)
        fi
    # Fallback to Hyprland
    elif command -v hyprctl >/dev/null 2>&1; then
        width="$(hyprctl monitors -j 2>/dev/null | jq '([.[].width] | max)' | xargs)"
        height="$(hyprctl monitors -j 2>/dev/null | jq '([.[].height] | max)' | xargs)"
    fi
    echo "$width $height"
}

check_and_prompt_upscale() {
    local img="$1"

    # Check if upscale notifications are disabled in config
    local config_file
    config_file="$(inir_config_file)"
    if [[ -f "$config_file" ]] && command -v jq &>/dev/null; then
        local hide_upscale
        hide_upscale=$(jq -r '.background.hideUpscaleNotification // false' "$config_file" 2>/dev/null)
        if [[ "$hide_upscale" == "true" ]]; then
            return
        fi
    fi

    read min_width_desired min_height_desired <<< "$(get_max_monitor_resolution)"

    if command -v identify &>/dev/null && [ -f "$img" ]; then
        local img_width img_height
        if is_video "$img"; then # Not check resolution for videos, just let em pass
            img_width=$min_width_desired
            img_height=$min_height_desired
        else
            img_width=$(identify -format "%w" "$img" 2>/dev/null)
            img_height=$(identify -format "%h" "$img" 2>/dev/null)
        fi
        if [[ "$img_width" -lt "$min_width_desired" || "$img_height" -lt "$min_height_desired" ]]; then
            action=$(notify-send "Upscale?" \
                "Image resolution (${img_width}x${img_height}) is lower than screen resolution (${min_width_desired}x${min_height_desired})" \
                -A "open_upscayl=Open Upscayl"\
                -a "Wallpaper switcher")
            if [[ "$action" == "open_upscayl" ]]; then
                if command -v upscayl &>/dev/null; then
                    nohup upscayl > /dev/null 2>&1 &
                else
                    action2=$(notify-send \
                        -a "Wallpaper switcher" \
                        -c "im.error" \
                        -A "install_upscayl=Install Upscayl (Arch)" \
                        "Install Upscayl?" \
                        "yay -S upscayl-bin")
                    if [[ "$action2" == "install_upscayl" ]]; then
                        kitty -1 yay -S upscayl-bin
                        if command -v upscayl &>/dev/null; then
                            nohup upscayl > /dev/null 2>&1 &
                        fi
                    fi
                fi
            fi
        fi
    fi
}

CUSTOM_DIR="$XDG_CACHE_HOME/quickshell"
RESTORE_SCRIPT_DIR="$CUSTOM_DIR/scripts"
RESTORE_SCRIPT="$RESTORE_SCRIPT_DIR/__restore_video_wallpaper.sh"
THUMBNAIL_DIR="$CUSTOM_DIR/video_thumbnails"
VIDEO_OPTS="no-audio loop hwdec=auto scale=bilinear interpolation=no video-sync=display-resample panscan=1.0 video-scale-x=1.0 video-scale-y=1.0 video-align-x=0.5 video-align-y=0.5 load-scripts=no"

is_video() {
    local extension="${1##*.}"
    [[ "$extension" == "mp4" || "$extension" == "webm" || "$extension" == "mkv" || "$extension" == "avi" || "$extension" == "mov" ]] && return 0 || return 1
}

is_gif() {
    local extension="${1##*.}"
    [[ "${extension,,}" == "gif" ]] && return 0 || return 1
}

has_valid_file() {
    local path="$1"
    [[ -n "$path" && -f "$path" && -s "$path" ]]
}

kill_existing_mpvpaper() {
    pkill -f -9 mpvpaper || true
}

start_mpvpaper_for_all_outputs() {
    local video_path="$1"
    local outputs=""

    # Niri: obtener conectores (HDMI-A-2, eDP-1, etc.) desde `niri msg outputs`
    if command -v niri >/dev/null 2>&1 && niri msg outputs >/dev/null 2>&1; then
        outputs=$(niri msg outputs | awk -F'[()]' '/^Output / {gsub(/^ +| +$/, "", $2); print $2}')
    fi

    # Hyprland (comportamiento original): nombres desde `hyprctl monitors -j`
    if [[ -z "$outputs" ]] && command -v hyprctl >/dev/null 2>&1; then
        outputs=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | .name')
    fi

    if [[ -z "$outputs" ]]; then
        echo "[switchwall.sh] Warning: could not detect outputs for mpvpaper" >&2
        return 1
    fi

    # Create a detached launcher script to ensure mpvpaper survives parent termination
    local launcher_script="$RESTORE_SCRIPT_DIR/.mpvpaper_launcher_$$.sh"
    cat > "$launcher_script" << 'LAUNCHER_EOF'
#!/bin/bash
video_path="$1"
shift
outputs="$@"
VIDEO_OPTS="no-audio loop hwdec=auto scale=bilinear interpolation=no video-sync=display-resample panscan=1.0 video-scale-x=1.0 video-scale-y=1.0 video-align-x=0.5 video-align-y=0.5 load-scripts=no"
for output in $outputs; do
    nohup mpvpaper -o "$VIDEO_OPTS" "$output" "$video_path" > /dev/null 2>&1 &
    disown
    sleep 0.2
done
LAUNCHER_EOF
    chmod +x "$launcher_script"
    
    # Execute launcher in a completely detached way using at if available, otherwise nohup
    if command -v at >/dev/null 2>&1; then
        echo "$launcher_script '$video_path' $outputs" | at now 2>/dev/null
    else
        (nohup "$launcher_script" "$video_path" $outputs > /dev/null 2>&1 &)
    fi
    
    # Small delay to let the launcher start
    sleep 0.3
    
    # Clean up launcher script after a delay
    (sleep 5 && rm -f "$launcher_script") &
}

create_restore_script() {
    local video_path=$1
    mkdir -p "$RESTORE_SCRIPT_DIR" 2>/dev/null || true
    cat > "$RESTORE_SCRIPT.tmp" << EOF
#!/bin/bash
# Generated by switchwall.sh - Don't modify it by yourself.
# Time: $(date)

pkill -f -9 mpvpaper

# Get monitors - try Niri first, then Hyprland
monitors=""
if command -v niri >/dev/null 2>&1 && niri msg outputs >/dev/null 2>&1; then
    monitors=\$(niri msg outputs | awk -F'[()]' '/^Output / {gsub(/^ +| +\$/, "", \$2); print \$2}')
elif command -v hyprctl >/dev/null 2>&1; then
    monitors=\$(hyprctl monitors -j | jq -r '.[] | .name')
fi

for monitor in \$monitors; do
    mpvpaper -o "$VIDEO_OPTS" "\$monitor" "$video_path" &
    sleep 0.1
done
EOF
    mv "$RESTORE_SCRIPT.tmp" "$RESTORE_SCRIPT"
    chmod +x "$RESTORE_SCRIPT"
}

remove_restore() {
    mkdir -p "$RESTORE_SCRIPT_DIR" 2>/dev/null || true
    cat > "$RESTORE_SCRIPT.tmp" << EOF
#!/bin/bash
# The content of this script will be generated by switchwall.sh - Don't modify it by yourself.
EOF
    mv "$RESTORE_SCRIPT.tmp" "$RESTORE_SCRIPT"
}

set_wallpaper_path() {
    local path="$1"
    if [ -f "$SHELL_CONFIG_FILE" ]; then
        _config_locked_write --arg path "$path" '.background.wallpaperPath = $path'
    fi
}

set_wallpaper_path_per_monitor() {
    local path="$1"
    local monitor="$2"
    local startWs="${3:-1}"
    local endWs="${4:-10}"

    if [ -f "$SHELL_CONFIG_FILE" ]; then
        # Use jq to update wallpapersByMonitor array
        # Remove existing entry for this monitor, then add new entry
        _config_locked_write --arg monitor "$monitor" \
           --arg path "$path" \
           --argjson startWs "${startWs:-1}" \
           --argjson endWs "${endWs:-10}" \
           '.background.wallpapersByMonitor = (
               (.background.wallpapersByMonitor // []) |
               map(select(.monitor != $monitor)) +
               [{
                   "monitor": $monitor,
                   "path": $path,
                   "workspaceFirst": $startWs,
                   "workspaceLast": $endWs
               }]
           )'
    fi
}

set_thumbnail_path() {
    local path="$1"
    if [ -f "$SHELL_CONFIG_FILE" ]; then
        _config_locked_write --arg path "$path" '.background.thumbnailPath = $path'
    fi
}

set_backdrop_thumbnail_path() {
    local path="$1"
    if [ -f "$SHELL_CONFIG_FILE" ]; then
        _config_locked_write --arg path "$path" '.background.backdrop.thumbnailPath = $path'
    fi
}

get_focused_monitor_name() {
    if command -v niri >/dev/null 2>&1 && niri msg -j focused-output >/dev/null 2>&1; then
        niri msg -j focused-output 2>/dev/null | jq -r '.name // ""'
        return
    fi
    if command -v hyprctl >/dev/null 2>&1; then
        hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused == true) | .name' | head -1
        return
    fi
    echo ""
 }

 resolve_effective_theming_wallpaper() {
    jq -r --arg focused_monitor "$(get_focused_monitor_name)" '
        def monitor_entry: if ((.background.multiMonitor.enable // false) and ($focused_monitor != ""))
            then ((.background.wallpapersByMonitor // []) | map(select(.monitor == $focused_monitor)) | .[0])
            else null end;
        def main_path: (monitor_entry.path // .background.wallpaperPath // "");
        def monitor_backdrop: (monitor_entry.backdropPath // "");
        def waffle_main: (if (.waffles.background.useMainWallpaper // "true") == true then main_path else (.waffles.background.wallpaperPath // main_path) end);
        if (.appearance.wallpaperTheming.useBackdropForColors // false) then
            if (.panelFamily // "ii") == "waffle" then
                (if (.waffles.background.backdrop.useMainWallpaper // "true") == true then waffle_main else (.waffles.background.backdrop.wallpaperPath // waffle_main) end)
            else
                (if monitor_backdrop != "" then monitor_backdrop else (if (.background.backdrop.useMainWallpaper // "true") == true then main_path else (.background.backdrop.wallpaperPath // main_path) end) end)
            end
        else
            if (.panelFamily // "ii") == "waffle" then waffle_main else main_path end
        end // ""
    ' "$SHELL_CONFIG_FILE" 2>/dev/null || echo ""
 }

 ensure_color_preview_for_media() {
    local media_path="$1"
    local out_path="$2"
    mkdir -p "$(dirname "$out_path")"

    if is_video "$media_path"; then
        if ! command -v ffmpeg >/dev/null 2>&1; then
            echo "[switchwall.sh] Missing ffmpeg for video color preview generation" >&2
            return 1
        fi
        ffmpeg -y -i "$media_path" -vframes 1 "$out_path" >/dev/null 2>&1
        return $?
    fi

    if is_gif "$media_path"; then
        if command -v magick >/dev/null 2>&1; then
            magick "$media_path[0]" "$out_path" >/dev/null 2>&1
            return $?
        fi
        if command -v ffmpeg >/dev/null 2>&1; then
            ffmpeg -y -i "$media_path" -vframes 1 "$out_path" >/dev/null 2>&1
            return $?
        fi
        echo "[switchwall.sh] Missing magick/ffmpeg for gif color preview generation" >&2
        return 1
    fi

    return 1
 }

switch() {
    imgpath="$1"
    mode_flag="$2"
    type_flag="$3"
    color_flag="$4"
    color="$5"
    skip_config_write="$6"
    noswitch_flag="${7:-}"

    # Per-monitor wallpaper changes: only update config, skip color generation
    # Global theme colors should only change from global wallpaper changes
    if [[ -n "$monitor_name" && -n "$imgpath" ]]; then
        set_wallpaper_path_per_monitor "$imgpath" "$monitor_name" "$start_workspace" "$end_workspace"
        echo "[switchwall.sh] Per-monitor wallpaper set for $monitor_name, skipping global color generation"
        return
    fi

    # Start Gemini auto-categorization if enabled
    aiStylingEnabled=$(jq -r '.background.clock.cookie.aiStyling' "$SHELL_CONFIG_FILE")
    if [[ "$aiStylingEnabled" == "true" ]]; then
        "$SCRIPT_DIR/../ai/gemini-categorize-wallpaper.sh" "$imgpath" > "$STATE_DIR/user/generated/wallpaper/category.txt" &
    fi

    # Hyprland-specific cursor/monitor math: only run if hyprctl is available.
    # On Niri or other compositors we fall back to centered defaults to avoid
    # spamming errors while still producing valid colors.
    if command -v hyprctl >/dev/null 2>&1; then
        focused_monitor_info=$(hyprctl monitors -j 2>/dev/null | jq -r '[.[] | select(.focused == true)] | first | if . == null then "" else "\(.scale) \(.x) \(.y) \(.height)" end' 2>/dev/null)
        if [[ -n "$focused_monitor_info" ]]; then
            read scale screenx screeny screensizey <<< "$focused_monitor_info"
            cursor_json=$(hyprctl cursorpos -j 2>/dev/null)
            cursorposx=$(printf '%s' "$cursor_json" | jq -r '.x // empty' 2>/dev/null)
            cursorposy=$(printf '%s' "$cursor_json" | jq -r '.y // empty' 2>/dev/null)
            if [[ -n "$cursorposx" && -n "$cursorposy" ]]; then
                cursorposx=$(bc <<< "scale=0; ($cursorposx - $screenx) * $scale / 1")
                cursorposy=$(bc <<< "scale=0; ($cursorposy - $screeny) * $scale / 1")
            else
                cursorposx=960
                cursorposy=540
            fi
            cursorposy_inverted=$((screensizey - cursorposy))
        else
            scale=1
            screenx=0
            screeny=0
            screensizey=1080
            cursorposx=960
            cursorposy=540
            cursorposy_inverted=$((screensizey - cursorposy))
        fi
    else
        scale=1
        screenx=0
        screeny=0
        screensizey=1080
        cursorposx=960
        cursorposy=540
        cursorposy_inverted=$((screensizey - cursorposy))
    fi

    if [[ "$color_flag" == "1" ]]; then
        generate_colors_material_args=(--color "$color")
    else
        if [[ -z "$imgpath" ]]; then
            if [[ -n "$noswitch_flag" ]]; then
                # --noswitch without --image: read current wallpaper from config for color regeneration
                imgpath=$(resolve_effective_theming_wallpaper)
                if [[ -z "$imgpath" || ! -f "$imgpath" ]]; then
                    echo "[switchwall.sh] --noswitch: No valid wallpaper path in config"
                    exit 0
                fi
                echo "[switchwall.sh] --noswitch: Using current wallpaper for color regeneration: $imgpath"
            else
                echo 'Aborted'
                exit 0
            fi
        fi

        check_and_prompt_upscale "$imgpath" &
        kill_existing_mpvpaper

        if is_video "$imgpath"; then
            mkdir -p "$THUMBNAIL_DIR"

            # Only check for ffmpeg (needed for thumbnail generation)
            # mpvpaper is no longer needed - Qt Multimedia handles video playback natively
            if ! command -v ffmpeg &> /dev/null; then
                echo "Missing dependency: ffmpeg"
                echo "Arch: sudo pacman -S ffmpeg"
                action=$(notify-send \
                    -a "Wallpaper switcher" \
                    -c "im.error" \
                    -A "install_arch=Install (Arch)" \
                    "Can't switch to video wallpaper" \
                    "Missing dependency: ffmpeg (needed for thumbnail generation)")
                if [[ "$action" == "install_arch" ]]; then
                    kitty -1 sudo pacman -S ffmpeg
                    if command -v ffmpeg &>/dev/null; then
                        notify-send 'Wallpaper switcher' 'Alright, try again!' -a "Wallpaper switcher"
                    fi
                fi
                exit 0
            fi

            # Extract first frame for thumbnail (used for color generation)
            # Use md5sum hash of full path to avoid collisions between videos with same basename
            thumbnail="$THUMBNAIL_DIR/$(echo -n "$imgpath" | md5sum | cut -d' ' -f1).jpg"
            config_thumbnail="$(jq -r '.background.thumbnailPath // ""' "$SHELL_CONFIG_FILE" 2>/dev/null)"
            config_thumbnail="${config_thumbnail#file://}"

            if has_valid_file "$config_thumbnail"; then
                thumbnail="$config_thumbnail"
            elif ! has_valid_file "$thumbnail"; then
                ffmpeg -y -i "$imgpath" -vframes 1 "$thumbnail" 2>/dev/null
            fi

            if ! has_valid_file "$thumbnail"; then
                echo "Cannot create thumbnail for color generation"
                remove_restore
                exit 1
            fi

            # Set wallpaper path (Qt Multimedia Video component will handle playback)
            if [[ "$skip_config_write" != "1" ]]; then
                set_wallpaper_path "$imgpath"
            fi

            # Set thumbnail path (used for color generation and as fallback)
            if [[ "$skip_config_write" != "1" ]]; then
                set_thumbnail_path "$thumbnail"
            fi

            # Use thumbnail for color generation
            generate_colors_material_args=(--path "$thumbnail")
            create_restore_script "$imgpath"
        else
            color_source="$imgpath"
            if is_gif "$imgpath"; then
                color_preview="$THUMBNAIL_DIR/$(echo -n "$imgpath" | md5sum | cut -d' ' -f1).jpg"
                if ensure_color_preview_for_media "$imgpath" "$color_preview"; then
                    color_source="$color_preview"
                fi
            fi
            generate_colors_material_args=(--path "$color_source")
            # Update wallpaper path in config
            if [[ "$skip_config_write" != "1" ]]; then
                set_wallpaper_path "$imgpath"
            fi
            # Clear video thumbnail path (prevents stale video colors)
            if [[ "$skip_config_write" != "1" ]]; then
                set_thumbnail_path ""
            fi
            remove_restore
        fi
    fi

    # Determine mode if not set
    if [[ -z "$mode_flag" ]]; then
        current_mode=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null | tr -d "'")
        if [[ "$current_mode" == "prefer-dark" ]]; then
            mode_flag="dark"
        else
            mode_flag="light"
        fi
    fi

    # Shell/UI colors follow the requested real mode.
    # Terminal colors may optionally force dark mode, but that must not darken the shell palette.
    if [[ -n "$mode_flag" ]]; then
        generate_colors_material_args+=(--mode "$mode_flag")
    fi
    # If useBackdropForColors is enabled, override color source to use backdrop wallpaper
    # Respects active panel family: ii reads from background.backdrop, waffle from waffles.background.backdrop
    if [[ "$color_flag" != "1" ]]; then
        use_backdrop_colors=$(jq -r '.appearance.wallpaperTheming.useBackdropForColors // false' "$SHELL_CONFIG_FILE" 2>/dev/null)
        if [[ "$use_backdrop_colors" == "true" ]]; then
            local panel_family=$(jq -r '.panelFamily // "ii"' "$SHELL_CONFIG_FILE" 2>/dev/null)
            local backdrop_use_main=""
            local backdrop_path=""

            if [[ "$panel_family" == "waffle" ]]; then
                backdrop_use_main=$(jq -r '.waffles.background.backdrop.useMainWallpaper // true' "$SHELL_CONFIG_FILE" 2>/dev/null)
                backdrop_path=$(jq -r '.waffles.background.backdrop.wallpaperPath // ""' "$SHELL_CONFIG_FILE" 2>/dev/null)
            else
                backdrop_use_main=$(jq -r '.background.backdrop.useMainWallpaper // true' "$SHELL_CONFIG_FILE" 2>/dev/null)
                backdrop_path=$(jq -r '.background.backdrop.wallpaperPath // ""' "$SHELL_CONFIG_FILE" 2>/dev/null)
            fi

            if [[ "$backdrop_use_main" != "true" && -n "$backdrop_path" && -f "$backdrop_path" ]]; then
                echo "[switchwall.sh] Using backdrop wallpaper for color generation ($panel_family): $backdrop_path"
                # Check if backdrop is a video - use its thumbnail instead
                if is_video "$backdrop_path"; then
                    local backdrop_thumb="$THUMBNAIL_DIR/$(echo -n "$backdrop_path" | md5sum | cut -d' ' -f1).jpg"
                    if [[ -f "$backdrop_thumb" ]]; then
                        generate_colors_material_args=(--path "$backdrop_thumb")
                    fi
                else
                    generate_colors_material_args=(--path "$backdrop_path")
                fi
            fi
        fi
    fi

    [[ -n "$type_flag" ]] && generate_colors_material_args+=(--scheme "$type_flag")
    generate_colors_material_args+=(--termscheme "$terminalscheme" --blend_bg_fg)
    generate_colors_material_args+=(--cache "$STATE_DIR/user/generated/color.txt")

    pre_process "$mode_flag"
    write_generated_wallpaper_path "$imgpath"

    # Check if app and shell theming is enabled in config
    local enable_apps_shell="true"
    local enable_terminal="true"
    if [ -f "$SHELL_CONFIG_FILE" ]; then
        enable_apps_shell=$(jq -r '.appearance.wallpaperTheming.enableAppsAndShell // true' "$SHELL_CONFIG_FILE")
        enable_terminal=$(jq -r '.appearance.wallpaperTheming.enableTerminal // true' "$SHELL_CONFIG_FILE")
    fi

    # Skip entirely only if BOTH app theming AND terminal theming are disabled
    if [ "$enable_apps_shell" == "false" ] && [ "$enable_terminal" == "false" ]; then
        echo "Both app/shell and terminal theming disabled, skipping color generation"
        return
    fi

    # Set terminal generation properties from config
    if [ -f "$SHELL_CONFIG_FILE" ]; then
        # Read from terminalColorAdjustments (the unified config)
        term_saturation=$(jq -r '.appearance.wallpaperTheming.terminalColorAdjustments.saturation // 0.65' "$SHELL_CONFIG_FILE")
        term_brightness=$(jq -r '.appearance.wallpaperTheming.terminalColorAdjustments.brightness // 0.60' "$SHELL_CONFIG_FILE")
        term_harmony=$(jq -r '.appearance.wallpaperTheming.terminalColorAdjustments.harmony // .appearance.wallpaperTheming.terminalGenerationProps.harmony // 0.40' "$SHELL_CONFIG_FILE")
        term_bg_brightness=$(jq -r '.appearance.wallpaperTheming.terminalColorAdjustments.backgroundBrightness // 0.50' "$SHELL_CONFIG_FILE")
        color_strength=$(jq -r '.appearance.wallpaperTheming.colorStrength // 1.0' "$SHELL_CONFIG_FILE")

        # Legacy props for backwards compatibility
        harmonize_threshold=$(jq -r '.appearance.wallpaperTheming.terminalGenerationProps.harmonizeThreshold // 100' "$SHELL_CONFIG_FILE")
        term_fg_boost=$(jq -r '.appearance.wallpaperTheming.terminalGenerationProps.termFgBoost // 0.35' "$SHELL_CONFIG_FILE")
        soften_colors=$(jq -r '.appearance.softenColors' "$SHELL_CONFIG_FILE")
        
        # Pass new parameters to Python script
        [[ "$term_saturation" != "null" && -n "$term_saturation" ]] && generate_colors_material_args+=(--term_saturation "$term_saturation")
        [[ "$term_brightness" != "null" && -n "$term_brightness" ]] && generate_colors_material_args+=(--term_brightness "$term_brightness")
        [[ "$term_harmony" != "null" && -n "$term_harmony" ]] && generate_colors_material_args+=(--harmony "$term_harmony")
        [[ "$term_bg_brightness" != "null" && -n "$term_bg_brightness" ]] && generate_colors_material_args+=(--term_bg_brightness "$term_bg_brightness")
        [[ "$color_strength" != "null" && -n "$color_strength" ]] && generate_colors_material_args+=(--color-strength "$color_strength")
        [[ "$harmonize_threshold" != "null" && -n "$harmonize_threshold" ]] && generate_colors_material_args+=(--harmonize_threshold "$harmonize_threshold")
        [[ "$term_fg_boost" != "null" && -n "$term_fg_boost" ]] && generate_colors_material_args+=(--term_fg_boost "$term_fg_boost")
        [[ "$soften_colors" == "true" ]] && generate_colors_material_args+=(--soften)
    fi

    # Generate colors and render templates in one unified Python pass
    if [[ -n "${INIR_VENV:-}" ]]; then
        _ii_venv="$(eval echo "$INIR_VENV")"
    elif [[ -n "${ILLOGICAL_IMPULSE_VIRTUAL_ENV:-}" ]]; then
        _ii_venv="$(eval echo "$ILLOGICAL_IMPULSE_VIRTUAL_ENV")"
    else
        _ii_venv="$HOME/.local/state/quickshell/.venv"
    fi
    source "$_ii_venv/bin/activate" 2>/dev/null || true
    _ii_python="$_ii_venv/bin/python3"
    [[ ! -x "$_ii_python" ]] && _ii_python="python3"

    _scss_tmp="$STATE_DIR/user/generated/material_colors.scss.tmp"
    _json_tmp="$STATE_DIR/user/generated/colors.json.tmp"
    _json_out="$STATE_DIR/user/generated/colors.json"
    _palette_tmp="$STATE_DIR/user/generated/palette.json.tmp"
    _palette_out="$STATE_DIR/user/generated/palette.json"
    _terminal_tmp="$STATE_DIR/user/generated/terminal.json.tmp"
    _terminal_out="$STATE_DIR/user/generated/terminal.json"
    _meta_tmp="$STATE_DIR/user/generated/theme-meta.json.tmp"
    _meta_out="$STATE_DIR/user/generated/theme-meta.json"
    _chromium_tmp="$STATE_DIR/user/generated/chromium.theme.tmp"
    _chromium_out="$STATE_DIR/user/generated/chromium.theme"

    # 1) Generate authoritative shell/UI colors.json + render app templates.
    if "$_ii_python" "$SCRIPT_DIR/generate_colors_material.py" "${generate_colors_material_args[@]}" \
        --json-output "$_json_tmp" \
        --palette-output "$_palette_tmp" \
        --terminal-output "$_terminal_tmp" \
        --meta-output "$_meta_tmp" \
        --render-templates "$TEMPLATE_DIR" \
        > /dev/null 2>/dev/null && [[ -s "$_json_tmp" ]]; then
        mv "$_json_tmp" "$_json_out"
        [[ -s "$_palette_tmp" ]] && mv "$_palette_tmp" "$_palette_out" || rm -f "$_palette_tmp"
        [[ -s "$_terminal_tmp" ]] && mv "$_terminal_tmp" "$_terminal_out" || rm -f "$_terminal_tmp"
        [[ -s "$_meta_tmp" ]] && mv "$_meta_tmp" "$_meta_out" || rm -f "$_meta_tmp"
        if write_chromium_theme_contract "$_palette_out" "$_chromium_tmp" && [[ -s "$_chromium_tmp" ]]; then
            mv "$_chromium_tmp" "$_chromium_out"
        else
            rm -f "$_chromium_tmp"
        fi
    else
        echo "[switchwall] Warning: colors.json generation failed, keeping previous JSON" >&2
        rm -f "$_json_tmp"
        rm -f "$_palette_tmp"
        rm -f "$_terminal_tmp"
        rm -f "$_meta_tmp"
        rm -f "$_chromium_tmp"
    fi

    # 2) Generate material_colors.scss for terminals/editors. This path may optionally
    #    force dark mode without affecting the shell/UI palette above.
    scss_generate_args=("${generate_colors_material_args[@]}")
    force_dark_terminal=$(jq -r '.appearance.wallpaperTheming.terminalGenerationProps.forceDarkMode // false' "$SHELL_CONFIG_FILE" 2>/dev/null || echo "false")
    if [[ "$force_dark_terminal" == "true" ]]; then
        for i in "${!scss_generate_args[@]}"; do
            if [[ "${scss_generate_args[$i]}" == "--mode" && $((i + 1)) -lt ${#scss_generate_args[@]} ]]; then
                scss_generate_args[$((i + 1))]="dark"
                break
            fi
        done
    fi

    _terminal_force_tmp="$STATE_DIR/user/generated/terminal.json.force.tmp"

    scss_cmd=("$_ii_python" "$SCRIPT_DIR/generate_colors_material.py" "${scss_generate_args[@]}")
    if [[ "$force_dark_terminal" == "true" ]]; then
        scss_cmd+=(--terminal-output "$_terminal_force_tmp")
    fi

    if "${scss_cmd[@]}" > "$_scss_tmp" 2>/dev/null && [[ -s "$_scss_tmp" ]]; then
        mv "$_scss_tmp" "$STATE_DIR/user/generated/material_colors.scss"
        # Keep terminal outputs aligned with forced-dark generation path when enabled.
        if [[ "$force_dark_terminal" == "true" && -s "$_terminal_force_tmp" ]]; then
            mv "$_terminal_force_tmp" "$_terminal_out"
        else
            rm -f "$_terminal_force_tmp"
        fi
    else
        echo "[switchwall] Warning: material_colors.scss generation failed, keeping previous SCSS" >&2
        rm -f "$_scss_tmp"
        rm -f "$_terminal_force_tmp"
    fi

    # Generate Vesktop theme if enabled (only when app theming is on)
    if [ "$enable_apps_shell" != "false" ]; then
        enable_vesktop=$(jq -r '.appearance.wallpaperTheming.enableVesktop // true' "$SHELL_CONFIG_FILE" 2>/dev/null || echo "true")
        if [[ "$enable_vesktop" != "false" ]]; then
            "$SCRIPT_DIR/system24_palette.sh"
        fi
    fi

    # Note: applycolor.sh is NOT invoked here.  The shell's MaterialThemeLoader
    # watches colors.json and runs applycolor.sh exactly once when the file
    # changes (see services/MaterialThemeLoader.qml — delayedExternalApply).
    # Running it here on top caused 2x app theming per regen and races between
    # the parallel module workers.  CLI standalone use (shell not running) can
    # invoke applycolor.sh manually if app theming is desired.
    deactivate 2>/dev/null || true

    # Pass screen width, height, and wallpaper path to post_process (only when app theming is on)
    if [ "$enable_apps_shell" != "false" ]; then
        read max_width_desired max_height_desired <<< "$(get_max_monitor_resolution)"
        post_process "$max_width_desired" "$max_height_desired" "$imgpath"
    fi
}

main() {
    imgpath=""
    mode_flag=""
    type_flag=""
    color_flag=""
    color=""
    noswitch_flag=""
    skip_config_write=""
    skip_accent_write=""

    get_type_from_config() {
        jq -r '.appearance.palette.type' "$SHELL_CONFIG_FILE" 2>/dev/null || echo "auto"
    }

    get_accent_color_from_config() {
        jq -r '.appearance.palette.accentColor' "$SHELL_CONFIG_FILE" 2>/dev/null || echo ""
    }

    set_accent_color() {
        local color="$1"
        _config_locked_write --arg color "$color" '.appearance.palette.accentColor = $color'
    }

    detect_scheme_type_from_image() {
        local img="$1"
        local _det_venv
        if [[ -n "${INIR_VENV:-}" ]]; then
            _det_venv="$(eval echo "$INIR_VENV")"
        elif [[ -n "${ILLOGICAL_IMPULSE_VIRTUAL_ENV:-}" ]]; then
            _det_venv="$(eval echo "$ILLOGICAL_IMPULSE_VIRTUAL_ENV")"
        else
            _det_venv="$HOME/.local/state/quickshell/.venv"
        fi
        source "$_det_venv/bin/activate" 2>/dev/null || true
        "$SCRIPT_DIR"/scheme_for_image.py "$img" 2>/dev/null | tr -d '\n'
        deactivate 2>/dev/null || true
    }

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --mode)
                mode_flag="$2"
                shift 2
                ;;
            --type)
                type_flag="$2"
                shift 2
                ;;
            --color)
                if [[ "$2" =~ ^#?[A-Fa-f0-9]{6}$ ]]; then
                    [[ "$skip_accent_write" != "1" ]] && set_accent_color "$2"
                    color_flag="1"
                    color="$2"
                    shift 2
                elif [[ "$2" == "clear" ]]; then
                    [[ "$skip_accent_write" != "1" ]] && set_accent_color ""
                    shift 2
                else
                    set_accent_color $(hyprpicker --no-fancy)
                    shift
                fi
                ;;
            --image)
                imgpath="$2"
                shift 2
                ;;
            --noswitch)
                noswitch_flag="1"
                skip_config_write="1"
                shift
                ;;
            --skip-config-write)
                skip_config_write="1"
                shift
                ;;
            --skip-accent-write)
                skip_accent_write="1"
                shift
                ;;
            --monitor)
                monitor_name="$2"
                shift 2
                ;;
            --start-workspace)
                start_workspace="$2"
                shift 2
                ;;
            --end-workspace)
                end_workspace="$2"
                shift 2
                ;;
            *)
                if [[ -z "$imgpath" ]]; then
                    imgpath="$1"
                fi
                shift
                ;;
        esac
    done

    # If type_flag is not set, get it from config
    if [[ -z "$type_flag" ]]; then
        type_flag="$(get_type_from_config)"
    fi

    # If accentColor is set in config, use it for static themes only.
    # For auto themes, colors must come from the wallpaper — a stale accentColor
    # from a previous static-theme variant would override wallpaper extraction.
    if [[ -z "$color_flag" ]]; then
        current_theme=$(jq -r '.appearance.theme // "auto"' "$SHELL_CONFIG_FILE" 2>/dev/null)
        if [[ "$current_theme" != "auto" ]]; then
            config_color="$(get_accent_color_from_config)"
            if [[ "$config_color" =~ ^#?[A-Fa-f0-9]{6}$ ]]; then
                color_flag="1"
                color="$config_color"
            fi
        fi
    fi

    # Validate type_flag (allow 'auto' as well)
    allowed_types=(scheme-content scheme-expressive scheme-fidelity scheme-fruit-salad scheme-monochrome scheme-neutral scheme-rainbow scheme-tonal-spot scheme-vibrant auto)
    valid_type=0
    for t in "${allowed_types[@]}"; do
        if [[ "$type_flag" == "$t" ]]; then
            valid_type=1
            break
        fi
    done
    if [[ $valid_type -eq 0 ]]; then
        echo "[switchwall.sh] Warning: Invalid type '$type_flag', defaulting to 'auto'" >&2
        type_flag="auto"
    fi

    # Only prompt for wallpaper if not using --color and not using --noswitch and no imgpath set
    if [[ -z "$imgpath" && -z "$color_flag" && -z "$noswitch_flag" ]]; then
        cd "$(xdg-user-dir PICTURES)/Wallpapers/showcase" 2>/dev/null || cd "$(xdg-user-dir PICTURES)/Wallpapers" 2>/dev/null || cd "$(xdg-user-dir PICTURES)" || return 1
        imgpath="$(kdialog --getopenfilename . --title 'Choose wallpaper')"
    fi

    # --noswitch should regenerate from the current effective theming source.
    # If no explicit image was passed, force resolution now so family-specific
    # wallpapers (e.g. waffle.background.wallpaperPath) are honored.
    if [[ -z "$imgpath" && -n "$noswitch_flag" && -z "$color_flag" ]]; then
        imgpath="$(resolve_effective_theming_wallpaper)"
    fi

    # If type_flag is 'auto', detect scheme type from image (after imgpath is set)
    if [[ "$type_flag" == "auto" ]]; then
        auto_detect_path="$imgpath"
        if [[ -z "$auto_detect_path" && -n "$noswitch_flag" && -z "$color_flag" ]]; then
            auto_detect_path="$(resolve_effective_theming_wallpaper)"
        fi

        if [[ -n "$auto_detect_path" && -f "$auto_detect_path" ]]; then
            detected_type="$(detect_scheme_type_from_image "$auto_detect_path")"
            # Only use detected_type if it's valid
            valid_detected=0
            for t in "${allowed_types[@]}"; do
                if [[ "$detected_type" == "$t" && "$detected_type" != "auto" ]]; then
                    valid_detected=1
                    break
                fi
            done
            if [[ $valid_detected -eq 1 ]]; then
                type_flag="$detected_type"
            else
                echo "[switchwall] Warning: Could not auto-detect a valid scheme, defaulting to 'scheme-tonal-spot'" >&2
                type_flag="scheme-tonal-spot"
            fi
        else
            echo "[switchwall] Warning: No image to auto-detect scheme from, defaulting to 'scheme-tonal-spot'" >&2
            type_flag="scheme-tonal-spot"
        fi
    fi

    switch "$imgpath" "$mode_flag" "$type_flag" "$color_flag" "$color" "$skip_config_write" "$noswitch_flag"
}

main "$@"
