#!/usr/bin/env bash

QUICKSHELL_CONFIG_NAME="ii"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
CONFIG_DIR="$XDG_CONFIG_HOME/quickshell/$QUICKSHELL_CONFIG_NAME"
CACHE_DIR="$XDG_CACHE_HOME/quickshell"
STATE_DIR="$XDG_STATE_HOME/quickshell"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHELL_CONFIG_FILE="$XDG_CONFIG_HOME/illogical-impulse/config.json"
MATUGEN_DIR="$XDG_CONFIG_HOME/matugen"
terminalscheme="$SCRIPT_DIR/terminal/scheme-base.json"

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
    "$XDG_CONFIG_HOME"/matugen/templates/kde/kde-material-you-colors-wrapper.sh --scheme-variant "$kde_scheme_variant"
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
}

post_process() {
    local screen_width="$1"
    local screen_height="$2"
    local wallpaper_path="$3"

    handle_kde_material_you_colors &
    "$SCRIPT_DIR/code/material-code-set-color.sh" &
    # Note: GTK4/libadwaita apps don't reload ~/.config/gtk-4.0/gtk.css in real-time
    # Apps need to be restarted to pick up new colors from matugen
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

CUSTOM_DIR="$XDG_CONFIG_HOME/hypr/custom"
RESTORE_SCRIPT_DIR="$CUSTOM_DIR/scripts"
RESTORE_SCRIPT="$RESTORE_SCRIPT_DIR/__restore_video_wallpaper.sh"
THUMBNAIL_DIR="$RESTORE_SCRIPT_DIR/mpvpaper_thumbnails"
VIDEO_OPTS="no-audio loop hwdec=auto scale=bilinear interpolation=no video-sync=display-resample panscan=1.0 video-scale-x=1.0 video-scale-y=1.0 video-align-x=0.5 video-align-y=0.5 load-scripts=no"

is_video() {
    local extension="${1##*.}"
    [[ "$extension" == "mp4" || "$extension" == "webm" || "$extension" == "mkv" || "$extension" == "avi" || "$extension" == "mov" ]] && return 0 || return 1
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
    cat > "$RESTORE_SCRIPT.tmp" << EOF
#!/bin/bash
# Generated by switchwall.sh - Don't modify it by yourself.
# Time: $(date)

pkill -f -9 mpvpaper

for monitor in \$(hyprctl monitors -j | jq -r '.[] | .name'); do
    mpvpaper -o "$VIDEO_OPTS" "\$monitor" "$video_path" &
    sleep 0.1
done
EOF
    mv "$RESTORE_SCRIPT.tmp" "$RESTORE_SCRIPT"
    chmod +x "$RESTORE_SCRIPT"
}

remove_restore() {
    cat > "$RESTORE_SCRIPT.tmp" << EOF
#!/bin/bash
# The content of this script will be generated by switchwall.sh - Don't modify it by yourself.
EOF
    mv "$RESTORE_SCRIPT.tmp" "$RESTORE_SCRIPT"
}

set_wallpaper_path() {
    local path="$1"
    if [ -f "$SHELL_CONFIG_FILE" ]; then
        jq --arg path "$path" '.background.wallpaperPath = $path' "$SHELL_CONFIG_FILE" > "$SHELL_CONFIG_FILE.tmp" && mv "$SHELL_CONFIG_FILE.tmp" "$SHELL_CONFIG_FILE"
    fi
}

set_thumbnail_path() {
    local path="$1"
    if [ -f "$SHELL_CONFIG_FILE" ]; then
        jq --arg path "$path" '.background.thumbnailPath = $path' "$SHELL_CONFIG_FILE" > "$SHELL_CONFIG_FILE.tmp" && mv "$SHELL_CONFIG_FILE.tmp" "$SHELL_CONFIG_FILE"
    fi
}

set_backdrop_thumbnail_path() {
    local path="$1"
    if [ -f "$SHELL_CONFIG_FILE" ]; then
        jq --arg path "$path" '.background.backdrop.thumbnailPath = $path' "$SHELL_CONFIG_FILE" > "$SHELL_CONFIG_FILE.tmp" && mv "$SHELL_CONFIG_FILE.tmp" "$SHELL_CONFIG_FILE"
    fi
}

switch() {
    imgpath="$1"
    mode_flag="$2"
    type_flag="$3"
    color_flag="$4"
    color="$5"

    # Start Gemini auto-categorization if enabled
    aiStylingEnabled=$(jq -r '.background.clock.cookie.aiStyling' "$SHELL_CONFIG_FILE")
    if [[ "$aiStylingEnabled" == "true" ]]; then
        "$SCRIPT_DIR/../ai/gemini-categorize-wallpaper.sh" "$imgpath" > "$STATE_DIR/user/generated/wallpaper/category.txt" &
    fi

    # Hyprland-specific cursor/monitor math: only run if hyprctl is available.
    # On Niri or other compositors we fall back to centered defaults to avoid
    # spamming errors while still producing valid colors.
    if command -v hyprctl >/dev/null 2>&1; then
        read scale screenx screeny screensizey < <(hyprctl monitors -j | jq '.[] | select(.focused) | .scale, .x, .y, .height' | xargs)
        cursorposx=$(hyprctl cursorpos -j | jq '.x' 2>/dev/null) || cursorposx=960
        cursorposx=$(bc <<< "scale=0; ($cursorposx - $screenx) * $scale / 1")
        cursorposy=$(hyprctl cursorpos -j | jq '.y' 2>/dev/null) || cursorposy=540
        cursorposy=$(bc <<< "scale=0; ($cursorposy - $screeny) * $scale / 1")
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

    if [[ "$color_flag" == "1" ]]; then
        matugen_args=(color hex "$color")
        generate_colors_material_args=(--color "$color")
    else
        if [[ -z "$imgpath" ]]; then
            echo 'Aborted'
            exit 0
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
            thumbnail="$THUMBNAIL_DIR/$(basename "$imgpath").jpg"
            ffmpeg -y -i "$imgpath" -vframes 1 "$thumbnail" 2>/dev/null

            if [ ! -f "$thumbnail" ]; then
                echo "Cannot create thumbnail for color generation"
                remove_restore
                exit 1
            fi

            # Set wallpaper path (Qt Multimedia Video component will handle playback)
            set_wallpaper_path "$imgpath"
            
            # Set thumbnail path (used for color generation and as fallback)
            set_thumbnail_path "$thumbnail"

            # Use thumbnail for color generation
            matugen_args=(image "$thumbnail")
            generate_colors_material_args=(--path "$thumbnail")
            create_restore_script "$imgpath"
        else
            matugen_args=(image "$imgpath")
            generate_colors_material_args=(--path "$imgpath")
            # Update wallpaper path in config
            set_wallpaper_path "$imgpath"
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

    # enforce dark mode for terminal
    if [[ -n "$mode_flag" ]]; then
        matugen_args+=(--mode "$mode_flag")
        if [[ $(jq -r '.appearance.wallpaperTheming.terminalGenerationProps.forceDarkMode' "$SHELL_CONFIG_FILE") == "true" ]]; then
            generate_colors_material_args+=(--mode "dark")
        else
            generate_colors_material_args+=(--mode "$mode_flag")
        fi
    fi
    [[ -n "$type_flag" ]] && matugen_args+=(--type "$type_flag") && generate_colors_material_args+=(--scheme "$type_flag")
    generate_colors_material_args+=(--termscheme "$terminalscheme" --blend_bg_fg)
    generate_colors_material_args+=(--cache "$STATE_DIR/user/generated/color.txt")

    pre_process "$mode_flag"

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

    # Set harmony and related properties from terminalColorAdjustments
    if [ -f "$SHELL_CONFIG_FILE" ]; then
        # Read from terminalColorAdjustments (the unified config)
        term_saturation=$(jq -r '.appearance.wallpaperTheming.terminalColorAdjustments.saturation // 0.40' "$SHELL_CONFIG_FILE")
        term_brightness=$(jq -r '.appearance.wallpaperTheming.terminalColorAdjustments.brightness // 0.55' "$SHELL_CONFIG_FILE")
        term_harmony=$(jq -r '.appearance.wallpaperTheming.terminalColorAdjustments.harmony // 0.15' "$SHELL_CONFIG_FILE")
        
        # Legacy props for backwards compatibility
        harmonize_threshold=$(jq -r '.appearance.wallpaperTheming.terminalGenerationProps.harmonizeThreshold // 100' "$SHELL_CONFIG_FILE")
        soften_colors=$(jq -r '.appearance.softenColors' "$SHELL_CONFIG_FILE")
        
        # Pass new parameters to Python script
        [[ "$term_saturation" != "null" && -n "$term_saturation" ]] && generate_colors_material_args+=(--term_saturation "$term_saturation")
        [[ "$term_brightness" != "null" && -n "$term_brightness" ]] && generate_colors_material_args+=(--term_brightness "$term_brightness")
        [[ "$term_harmony" != "null" && -n "$term_harmony" ]] && generate_colors_material_args+=(--harmony "$term_harmony")
        [[ "$harmonize_threshold" != "null" && -n "$harmonize_threshold" ]] && generate_colors_material_args+=(--harmonize_threshold "$harmonize_threshold")
        [[ "$soften_colors" == "true" ]] && generate_colors_material_args+=(--soften)
    fi

    matugen "${matugen_args[@]}"
    source "$(eval echo $ILLOGICAL_IMPULSE_VIRTUAL_ENV)/bin/activate" 2>/dev/null || true
    
    # Generate colors with soften applied (overwrites matugen's colors.json if soften is enabled)
    generate_colors_material_args+=(--json-output "$STATE_DIR/user/generated/colors.json")
    
    python3 "$SCRIPT_DIR/generate_colors_material.py" "${generate_colors_material_args[@]}" \
        > "$STATE_DIR"/user/generated/material_colors.scss
    
    # Generate Vesktop theme if enabled (only when app theming is on)
    if [ "$enable_apps_shell" != "false" ]; then
        enable_vesktop=$(jq -r '.appearance.wallpaperTheming.enableVesktop // true' "$SHELL_CONFIG_FILE" 2>/dev/null || echo "true")
        if [[ "$enable_vesktop" != "false" ]]; then
            python3 "$SCRIPT_DIR/system24_palette.py"
        fi
    fi
    
    # Always run applycolor.sh - it has its own checks for enableTerminal and enableAppsAndShell
    "$SCRIPT_DIR"/applycolor.sh
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

    get_type_from_config() {
        jq -r '.appearance.palette.type' "$SHELL_CONFIG_FILE" 2>/dev/null || echo "auto"
    }

    get_accent_color_from_config() {
        jq -r '.appearance.palette.accentColor' "$SHELL_CONFIG_FILE" 2>/dev/null || echo ""
    }

    set_accent_color() {
        local color="$1"
        jq --arg color "$color" '.appearance.palette.accentColor = $color' "$SHELL_CONFIG_FILE" > "$SHELL_CONFIG_FILE.tmp" && mv "$SHELL_CONFIG_FILE.tmp" "$SHELL_CONFIG_FILE"
    }

    detect_scheme_type_from_image() {
        local img="$1"
        source "$(eval echo $ILLOGICAL_IMPULSE_VIRTUAL_ENV)/bin/activate" 2>/dev/null || true
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
                    set_accent_color "$2"
                    shift 2
                elif [[ "$2" == "clear" ]]; then
                    set_accent_color ""
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
                imgpath=$(jq -r '.background.wallpaperPath' "$SHELL_CONFIG_FILE" 2>/dev/null || echo "")
                shift
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

    # If accentColor is set in config, use it
    config_color="$(get_accent_color_from_config)"
    if [[ "$config_color" =~ ^#?[A-Fa-f0-9]{6}$ ]]; then
        color_flag="1"
        color="$config_color"
    fi

    # Validate type_flag (allow 'auto' as well)
    allowed_types=(scheme-content scheme-expressive scheme-fidelity scheme-fruit-salad scheme-monochrome scheme-neutral scheme-rainbow scheme-tonal-spot auto)
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

    # If type_flag is 'auto', detect scheme type from image (after imgpath is set)
    if [[ "$type_flag" == "auto" ]]; then
        if [[ -n "$imgpath" && -f "$imgpath" ]]; then
            detected_type="$(detect_scheme_type_from_image "$imgpath")"
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

    switch "$imgpath" "$mode_flag" "$type_flag" "$color_flag" "$color"
}

main "$@"
