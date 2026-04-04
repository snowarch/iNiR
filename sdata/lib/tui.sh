#!/bin/bash
# TUI functions for iNiR setup
# Ink design: whitespace over borders, color over chrome.
# This script is meant to be sourced.

# shellcheck shell=bash

###############################################################################
# Theme Configuration
###############################################################################
TUI_ACCENT="212"
TUI_ACCENT_DIM="99"
TUI_SUCCESS="82"
TUI_WARNING="214"
TUI_ERROR="196"
TUI_INFO="39"
TUI_MUTED="245"
TUI_DIM="240"

TUI_GUM_ACCENT="$TUI_ACCENT"
TUI_GUM_ACCENT_DIM="$TUI_ACCENT_DIM"
TUI_GUM_SUCCESS="$TUI_SUCCESS"
TUI_GUM_WARNING="$TUI_WARNING"
TUI_GUM_ERROR="$TUI_ERROR"
TUI_GUM_INFO="$TUI_INFO"
TUI_GUM_MUTED="$TUI_MUTED"
TUI_GUM_DIM="$TUI_DIM"
TUI_GUM_SURFACE="236"
TUI_GUM_SURFACE_ALT="238"
TUI_GUM_TEXT="252"

# Icons
ICON_CHECK="✓"
ICON_CROSS="✗"
ICON_WARN="⚠"
ICON_INFO="→"
ICON_ARROW="❯"
ICON_DOT="●"
ICON_CIRCLE="○"
ICON_STAR="★"

###############################################################################
# Gum Detection & Palette Sourcing
###############################################################################
HAS_GUM=false
command -v gum &>/dev/null && HAS_GUM=true

_tui_json_value() {
    local file="$1" key="$2"
    [[ -f "$file" ]] || return 1
    sed -n "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$file" | head -1
}

_tui_use_palette_candidate() {
    local current="$1" candidate="$2"
    if [[ -n "$candidate" ]]; then
        printf '%s' "$candidate"
    else
        printf '%s' "$current"
    fi
}

_tui_load_palette() {
    local state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
    local generated_dir="${state_home}/quickshell/user/generated"
    local terminal_file="${generated_dir}/terminal.json"
    local colors_file="${generated_dir}/colors.json"

    TUI_GUM_ACCENT=$(_tui_use_palette_candidate "$TUI_GUM_ACCENT" "$(_tui_json_value "$terminal_file" "term13")")
    TUI_GUM_ACCENT_DIM=$(_tui_use_palette_candidate "$TUI_GUM_ACCENT_DIM" "$(_tui_json_value "$terminal_file" "term12")")
    TUI_GUM_SUCCESS=$(_tui_use_palette_candidate "$TUI_GUM_SUCCESS" "$(_tui_json_value "$terminal_file" "term10")")
    TUI_GUM_WARNING=$(_tui_use_palette_candidate "$TUI_GUM_WARNING" "$(_tui_json_value "$terminal_file" "term11")")
    TUI_GUM_ERROR=$(_tui_use_palette_candidate "$TUI_GUM_ERROR" "$(_tui_json_value "$terminal_file" "term9")")
    TUI_GUM_INFO=$(_tui_use_palette_candidate "$TUI_GUM_INFO" "$(_tui_json_value "$terminal_file" "term12")")
    TUI_GUM_MUTED=$(_tui_use_palette_candidate "$TUI_GUM_MUTED" "$(_tui_json_value "$terminal_file" "term8")")
    TUI_GUM_TEXT=$(_tui_use_palette_candidate "$TUI_GUM_TEXT" "$(_tui_json_value "$terminal_file" "term15")")

    TUI_GUM_ACCENT=$(_tui_use_palette_candidate "$TUI_GUM_ACCENT" "$(_tui_json_value "$colors_file" "primary")")
    TUI_GUM_ACCENT_DIM=$(_tui_use_palette_candidate "$TUI_GUM_ACCENT_DIM" "$(_tui_json_value "$colors_file" "secondary")")
    TUI_GUM_SUCCESS=$(_tui_use_palette_candidate "$TUI_GUM_SUCCESS" "$(_tui_json_value "$colors_file" "success")")
    TUI_GUM_WARNING=$(_tui_use_palette_candidate "$TUI_GUM_WARNING" "$(_tui_json_value "$colors_file" "term11")")
    TUI_GUM_ERROR=$(_tui_use_palette_candidate "$TUI_GUM_ERROR" "$(_tui_json_value "$colors_file" "error")")
    TUI_GUM_INFO=$(_tui_use_palette_candidate "$TUI_GUM_INFO" "$(_tui_json_value "$colors_file" "secondary_fixed")")
    TUI_GUM_MUTED=$(_tui_use_palette_candidate "$TUI_GUM_MUTED" "$(_tui_json_value "$colors_file" "outline")")
    TUI_GUM_DIM=$(_tui_use_palette_candidate "$TUI_GUM_DIM" "$(_tui_json_value "$colors_file" "outline_variant")")
    TUI_GUM_SURFACE=$(_tui_use_palette_candidate "$TUI_GUM_SURFACE" "$(_tui_json_value "$colors_file" "surface_container")")
    TUI_GUM_SURFACE_ALT=$(_tui_use_palette_candidate "$TUI_GUM_SURFACE_ALT" "$(_tui_json_value "$colors_file" "surface_container_high")")
    TUI_GUM_TEXT=$(_tui_use_palette_candidate "$TUI_GUM_TEXT" "$(_tui_json_value "$colors_file" "on_surface")")
}

_tui_color_value() {
    local tone="$1"
    case "$tone" in
        accent)      printf '%s' "$TUI_GUM_ACCENT" ;;
        accent-dim)  printf '%s' "$TUI_GUM_ACCENT_DIM" ;;
        success)     printf '%s' "$TUI_GUM_SUCCESS" ;;
        warning)     printf '%s' "$TUI_GUM_WARNING" ;;
        error)       printf '%s' "$TUI_GUM_ERROR" ;;
        info)        printf '%s' "$TUI_GUM_INFO" ;;
        muted)       printf '%s' "$TUI_GUM_MUTED" ;;
        dim)         printf '%s' "$TUI_GUM_DIM" ;;
        surface)     printf '%s' "$TUI_GUM_SURFACE" ;;
        surface-alt) printf '%s' "$TUI_GUM_SURFACE_ALT" ;;
        text)        printf '%s' "$TUI_GUM_TEXT" ;;
        *)           printf '%s' "$tone" ;;
    esac
}

_tui_load_palette

###############################################################################
# Core Styling Helpers
###############################################################################
_color() {
    local fg="$1" text="$2"
    if $HAS_GUM; then
        echo "$text" | gum style --foreground "$(_tui_color_value "$fg")"
    else
        case "$fg" in
            212|99|accent|accent-dim)  echo -e "${STY_PURPLE}${text}${STY_RST}" ;;
            82|success)                echo -e "${STY_GREEN}${text}${STY_RST}" ;;
            214|208|warning)           echo -e "${STY_YELLOW}${text}${STY_RST}" ;;
            196|error)                 echo -e "${STY_RED}${text}${STY_RST}" ;;
            39|info)                   echo -e "${STY_BLUE}${text}${STY_RST}" ;;
            245|240|muted|dim)         echo -e "${STY_FAINT}${text}${STY_RST}" ;;
            *)                         echo -e "${text}" ;;
        esac
    fi
}

_bold() {
    local text="$1"
    if $HAS_GUM; then
        echo "$text" | gum style --bold
    else
        echo -e "${STY_BOLD}${text}${STY_RST}"
    fi
}

_repeat_char() {
    local char="$1" count="$2" result="" i
    for ((i=0; i<count; i++)); do result+="$char"; done
    echo "$result"
}

_draw_line() {
    local color="${1:-dim}" width="${2:-40}" char="${3:-─}"
    local line=$(_repeat_char "$char" "$width")
    if $HAS_GUM; then
        echo "$line" | gum style --foreground "$(_tui_color_value "$color")"
    else
        echo -e "${STY_FAINT}  ${line}${STY_RST}"
    fi
}

###############################################################################
# Spinner
###############################################################################
tui_spin() {
    local title="$1"; shift
    if $HAS_GUM; then
        gum spin --spinner dot --title "$title" --spinner.foreground "$(_tui_color_value accent)" -- "$@"
    else
        echo -n "$title... "
        "$@" >/dev/null 2>&1
        echo "done"
    fi
}

###############################################################################
# Styled Output
###############################################################################
tui_title() {
    local text="$1"
    echo ""
    if $HAS_GUM; then
        echo "$text" | gum style --foreground "$(_tui_color_value accent)" --bold --padding "0 1"
    else
        echo -e "  ${STY_PURPLE}${STY_BOLD}$text${STY_RST}"
    fi
    echo ""
}

tui_subtitle() {
    local text="$1"
    if $HAS_GUM; then
        echo "$text" | gum style --foreground "$(_tui_color_value muted)" --italic
    else
        echo -e "  ${STY_FAINT}$text${STY_RST}"
    fi
}

tui_success() {
    local text="$1"
    if $HAS_GUM; then
        echo "$ICON_CHECK $text" | gum style --foreground "$(_tui_color_value success)"
    else
        echo -e "  ${STY_GREEN}${ICON_CHECK}${STY_RST} $text"
    fi
}

tui_error() {
    local text="$1"
    if $HAS_GUM; then
        echo "$ICON_CROSS $text" | gum style --foreground "$(_tui_color_value error)"
    else
        echo -e "  ${STY_RED}${ICON_CROSS}${STY_RST} $text"
    fi
}

tui_warn() {
    local text="$1"
    if $HAS_GUM; then
        echo "$ICON_WARN $text" | gum style --foreground "$(_tui_color_value warning)"
    else
        echo -e "  ${STY_YELLOW}${ICON_WARN}${STY_RST} $text"
    fi
}

tui_info() {
    local text="$1"
    if $HAS_GUM; then
        echo "$ICON_INFO $text" | gum style --foreground "$(_tui_color_value info)"
    else
        echo -e "  ${STY_BLUE}${ICON_INFO}${STY_RST} $text"
    fi
}

tui_dim() {
    local text="$1"
    if $HAS_GUM; then
        echo "$text" | gum style --foreground "$(_tui_color_value dim)"
    else
        echo -e "${STY_FAINT}$text${STY_RST}"
    fi
}

###############################################################################
# Prompts
###############################################################################
tui_confirm() {
    local prompt="${1:-Continue?}" default="${2:-yes}"
    if $HAS_GUM; then
        if [[ "$default" == "yes" ]]; then
            gum confirm --default=yes --prompt.foreground "$(_tui_color_value accent)" "$prompt"
        else
            gum confirm --default=no --prompt.foreground "$(_tui_color_value accent)" "$prompt"
        fi
    else
        local yn_hint="[Y/n]"
        [[ "$default" != "yes" ]] && yn_hint="[y/N]"
        echo -ne "  ${STY_PURPLE}?${STY_RST} $prompt $yn_hint "
        read -n 1 -r; echo
        if [[ "$default" == "yes" ]]; then
            [[ ! $REPLY =~ ^[Nn]$ ]]
        else
            [[ $REPLY =~ ^[Yy]$ ]]
        fi
    fi
}

tui_input() {
    local prompt="$1" default="$2"
    if $HAS_GUM; then
        gum input --placeholder "$default" --prompt "$prompt " \
            --prompt.foreground "$(_tui_color_value accent)" \
            --cursor.foreground "$(_tui_color_value accent)"
    else
        echo -ne "  ${STY_PURPLE}?${STY_RST} $prompt "
        [[ -n "$default" ]] && echo -ne "${STY_FAINT}($default)${STY_RST} "
        read -r value
        echo "${value:-$default}"
    fi
}

tui_choose() {
    local header="$1"; shift
    local options=("$@")
    if $HAS_GUM; then
        gum choose --header "$header" \
            --header.foreground "$(_tui_color_value accent)" \
            --cursor.foreground "$(_tui_color_value accent)" \
            --selected.foreground "$(_tui_color_value accent)" \
            "${options[@]}"
    else
        echo -e "\n  ${STY_PURPLE}${STY_BOLD}$header${STY_RST}\n"
        local i=1
        for opt in "${options[@]}"; do
            echo -e "    ${STY_FAINT}$i)${STY_RST} $opt"
            ((i++))
        done
        echo ""
        echo -ne "  ${STY_PURPLE}${ICON_ARROW}${STY_RST} "
        read -r selection
        if [[ "$selection" =~ ^[0-9]+$ ]] && [[ "$selection" -ge 1 ]] && [[ "$selection" -le "${#options[@]}" ]]; then
            echo "${options[$((selection-1))]}"
        else
            echo "${options[0]}"
        fi
    fi
}

tui_choose_multi() {
    local header="$1"; shift
    local options=("$@")
    if $HAS_GUM; then
        gum choose --no-limit --header "$header" \
            --header.foreground "$(_tui_color_value accent)" \
            --cursor.foreground "$(_tui_color_value accent)" \
            --selected.foreground "$(_tui_color_value accent)" \
            "${options[@]}"
    else
        echo -e "\n  ${STY_PURPLE}${STY_BOLD}$header${STY_RST}"
        echo -e "  ${STY_FAINT}(enter numbers separated by space, or 'all')${STY_RST}\n"
        local i=1
        for opt in "${options[@]}"; do
            echo -e "    ${STY_FAINT}$i)${STY_RST} $opt"
            ((i++))
        done
        echo ""
        echo -ne "  ${STY_PURPLE}${ICON_ARROW}${STY_RST} "
        read -r selection
        if [[ "$selection" == "all" ]]; then
            printf '%s\n' "${options[@]}"
        else
            for num in $selection; do
                [[ "$num" =~ ^[0-9]+$ ]] && echo "${options[$((num-1))]}"
            done
        fi
    fi
}

###############################################################################
# Content Blocks — no borders, just space and indent
###############################################################################
tui_box() {
    local content="$1" title="${2:-}" color="${3:-}" width="${4:-}"

    echo ""
    if $HAS_GUM; then
        [[ -n "$title" ]] && echo "$title" | gum style --foreground "$(_tui_color_value accent)" --bold --padding "0 1"
        echo "$content" | gum style --padding "0 3"
    else
        [[ -n "$title" ]] && echo -e "  ${STY_PURPLE}${STY_BOLD}${title}${STY_RST}"
        while IFS= read -r line || [[ -n "$line" ]]; do
            echo "    $line"
        done <<< "$content"
    fi
    echo ""
}

tui_badge() {
    local label="$1" value="$2" tone="${3:-accent}"
    if $HAS_GUM; then
        local styled_label styled_value
        styled_label=$(echo "$label" | gum style --foreground "$(_tui_color_value muted)")
        styled_value=$(echo "$value" | gum style --foreground "$(_tui_color_value "$tone")" --bold)
        printf '%s %s' "$styled_label" "$styled_value"
    else
        printf '  %b%s%b %b%s%b' "$STY_FAINT" "$label" "$STY_RST" "$STY_BOLD" "$value" "$STY_RST"
    fi
}

tui_badge_row() {
    [[ $# -gt 0 ]] || return 0
    echo ""
    if $HAS_GUM; then
        local rendered=()
        local row=""
        local label value tone
        while [[ $# -ge 2 ]]; do
            label="$1"; value="$2"; tone="${3:-accent}"
            rendered+=("$(tui_badge "$label" "$value" "$tone")")
            shift 3 || true
        done
        local i
        for ((i=0; i<${#rendered[@]}; i++)); do
            [[ "$i" -gt 0 ]] && row+="    "
            row+="${rendered[$i]}"
        done
        echo "$row" | gum style --padding "0 1"
    else
        local first=true
        while [[ $# -ge 2 ]]; do
            $first || printf '    '
            first=false
            printf '%b%s%b %b%s%b' "$STY_FAINT" "$1" "$STY_RST" "$STY_BOLD" "$2" "$STY_RST"
            shift 3 || true
        done
        echo ""
    fi
    echo ""
}

tui_banner() {
    echo ""
    if $HAS_GUM; then
        gum style \
            --foreground "$(_tui_color_value accent)" \
            --align center \
            --width 50 \
            --padding "1 0" \
            "██╗██╗      ███╗   ██╗██╗██████╗ ██╗" \
            "██║██║      ████╗  ██║██║██╔══██╗██║" \
            "██║██║█████╗██╔██╗ ██║██║██████╔╝██║" \
            "██║██║╚════╝██║╚██╗██║██║██╔══██╗██║" \
            "██║██║      ██║ ╚████║██║██║  ██║██║" \
            "╚═╝╚═╝      ╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝╚═╝"
        echo "iNiR — your niri shell" | gum style \
            --foreground "$(_tui_color_value muted)" \
            --align center \
            --width 50
    else
        local tagline="iNiR — your niri shell"
        local banner_width=50
        local left_pad=$(( (banner_width - ${#tagline}) / 2 ))
        (( left_pad < 0 )) && left_pad=0

        echo -e "${STY_PURPLE}${STY_BOLD}"
        cat << 'EOF'
   ██╗██╗      ███╗   ██╗██╗██████╗ ██╗
   ██║██║      ████╗  ██║██║██╔══██╗██║
   ██║██║█████╗██╔██╗ ██║██║██████╔╝██║
   ██║██║╚════╝██║╚██╗██║██║██╔══██╗██║
   ██║██║      ██║ ╚████║██║██║  ██║██║
   ╚═╝╚═╝      ╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝╚═╝
EOF
        echo -e "${STY_RST}"
        printf "%*s%b%s%b\n" "$left_pad" "" "$STY_FAINT" "$tagline" "$STY_RST"
    fi
    echo ""
}

tui_hero_card() {
    local eyebrow="$1" subtitle="$2" detail="${3:-}"

    tui_banner
    if $HAS_GUM; then
        echo "$eyebrow" | gum style --foreground "$(_tui_color_value accent)" --bold --padding "0 1"
        echo "$subtitle" | gum style --foreground "$(_tui_color_value text)" --padding "0 1"
        [[ -n "$detail" ]] && echo "$detail" | gum style --foreground "$(_tui_color_value muted)" --padding "0 1"
    else
        echo -e "  ${STY_PURPLE}${STY_BOLD}${eyebrow}${STY_RST}"
        echo -e "  ${subtitle}"
        [[ -n "$detail" ]] && echo -e "  ${STY_FAINT}${detail}${STY_RST}"
    fi
    echo ""
}

###############################################################################
# Status Display
###############################################################################
tui_status_line() {
    local label="$1" value="$2" status="${3:-}"
    local color="" icon=""
    case "$status" in
        ok)    color="${STY_GREEN}"; icon="$ICON_DOT" ;;
        warn)  color="${STY_YELLOW}"; icon="$ICON_DOT" ;;
        error) color="${STY_RED}"; icon="$ICON_DOT" ;;
        *)     color="${STY_RST}"; icon=" " ;;
    esac
    printf "  ${STY_FAINT}%s${STY_RST} ${STY_BOLD}%-12s${STY_RST} ${color}%s${STY_RST}\n" "$icon" "$label" "$value"
}

tui_divider() {
    local width="${1:-40}"
    echo ""
    _draw_line "dim" "$width"
    echo ""
}

###############################################################################
# Progress Steps
###############################################################################
tui_step() {
    local current="$1" total="$2" description="$3" subtitle="${4:-}"
    echo ""
    if $HAS_GUM; then
        local step_badge step_title
        step_badge=$(echo " $current/$total " | gum style --foreground "$(_tui_color_value text)" --background "$(_tui_color_value accent)")
        step_title=$(echo "$description" | gum style --foreground "$(_tui_color_value accent)" --bold --padding "0 1")
        if [[ -n "$subtitle" ]]; then
            gum join --vertical \
                "$(gum join --horizontal "$step_badge" "$step_title")" \
                "$(echo "$subtitle" | gum style --foreground "$(_tui_color_value muted)")"
        else
            gum join --horizontal "$step_badge" "$step_title"
        fi
    else
        echo -e "  ${STY_PURPLE}${STY_BOLD}[$current/$total]${STY_RST} ${STY_BOLD}$description${STY_RST}"
        [[ -n "$subtitle" ]] && echo -e "  ${STY_FAINT}${subtitle}${STY_RST}"
    fi
    echo ""
}

tui_progress_bar() {
    local current="$1" total="$2" width="${3:-30}"
    local percent=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    local bar="" i
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done
    if $HAS_GUM; then
        echo "$bar $percent%" | gum style --foreground "$(_tui_color_value accent)"
    else
        echo -e "  ${STY_PURPLE}${bar}${STY_RST} ${percent}%"
    fi
}

###############################################################################
# Tables — clean aligned columns, no box drawing
###############################################################################
tui_table_header() {
    local col1="$1" col2="$2" col1_width="${3:-16}" col2_width="${4:-32}"
    echo ""
    printf "  ${STY_BOLD}%-${col1_width}s${STY_RST}  ${STY_BOLD}%-${col2_width}s${STY_RST}\n" "$col1" "$col2"
    local total_width=$((col1_width + col2_width + 2))
    echo -e "  ${STY_FAINT}$(_repeat_char "─" "$total_width")${STY_RST}"
}

tui_table_row() {
    local col1="$1" col2="$2" col1_width="${3:-16}" col2_width="${4:-32}"
    printf "  %-${col1_width}s  %-${col2_width}s\n" "$col1" "$col2"
}

tui_table_footer() {
    local col1_width="${1:-16}" col2_width="${2:-32}"
    echo ""
}

###############################################################################
# Special Components
###############################################################################
tui_header_block() {
    local title="$1" subtitle="${2:-}"
    echo ""
    if $HAS_GUM; then
        if [[ -n "$subtitle" ]]; then
            gum join --vertical \
                "$(echo "$title" | gum style --foreground "$(_tui_color_value accent)" --bold)" \
                "$(echo "$subtitle" | gum style --foreground "$(_tui_color_value muted)")"
        else
            echo "$title" | gum style --foreground "$(_tui_color_value accent)" --bold
        fi
    else
        echo -e "  ${STY_PURPLE}${STY_BOLD}$title${STY_RST}"
        [[ -n "$subtitle" ]] && echo -e "  ${STY_FAINT}$subtitle${STY_RST}"
    fi
    echo ""
}

tui_key_value() {
    local key="$1" value="$2" key_width="${3:-14}"
    printf "  ${STY_FAINT}%-${key_width}s${STY_RST} %s\n" "$key" "$value"
}

tui_list_item() {
    local text="$1" bullet="${2:-$ICON_ARROW}"
    echo -e "  ${STY_PURPLE}$bullet${STY_RST} $text"
}

tui_section_start() {
    local title="$1"
    echo ""
    if $HAS_GUM; then
        echo "$title" | gum style --foreground "$(_tui_color_value accent)" --bold --padding "0 1"
    else
        echo -e "  ${STY_PURPLE}${STY_BOLD}$title${STY_RST}"
    fi
}

tui_section_end() {
    echo ""
}

###############################################################################
# Compact Status
###############################################################################
tui_check_ok() {
    local text="$1"
    echo -e "  ${STY_GREEN}${ICON_CHECK}${STY_RST} $text"
}

tui_check_fail() {
    local text="$1"
    echo -e "  ${STY_RED}${ICON_CROSS}${STY_RST} $text"
}

tui_check_warn() {
    local text="$1"
    echo -e "  ${STY_YELLOW}${ICON_WARN}${STY_RST} $text"
}

tui_check_skip() {
    local text="$1"
    echo -e "  ${STY_FAINT}${ICON_CIRCLE}${STY_RST} ${STY_FAINT}$text${STY_RST}"
}

###############################################################################
# Timer
###############################################################################
tui_elapsed() {
    local start_s="$1"
    local elapsed=$(( SECONDS - start_s ))
    if [[ $elapsed -lt 60 ]]; then
        echo "${elapsed}s"
    else
        echo "$((elapsed/60))m$((elapsed%60))s"
    fi
}

###############################################################################
# Verification
###############################################################################
tui_verify_ok() {
    local label="$1" detail="${2:-}"
    if $HAS_GUM; then
        local line="$ICON_CHECK $label"
        [[ -n "$detail" ]] && line+="  $detail"
        echo "$line" | gum style --foreground "$(_tui_color_value success)"
    elif [[ -n "$detail" ]]; then
        echo -e "  ${STY_GREEN}${ICON_CHECK}${STY_RST} $label  ${STY_FAINT}$detail${STY_RST}"
    else
        echo -e "  ${STY_GREEN}${ICON_CHECK}${STY_RST} $label"
    fi
}

tui_verify_fail() {
    local label="$1" detail="${2:-}"
    if $HAS_GUM; then
        local line="$ICON_CROSS $label"
        [[ -n "$detail" ]] && line+="  $detail"
        echo "$line" | gum style --foreground "$(_tui_color_value error)"
    elif [[ -n "$detail" ]]; then
        echo -e "  ${STY_RED}${ICON_CROSS}${STY_RST} $label  ${STY_FAINT}$detail${STY_RST}"
    else
        echo -e "  ${STY_RED}${ICON_CROSS}${STY_RST} $label"
    fi
}

tui_verify_skip() {
    local label="$1" detail="${2:-}"
    if $HAS_GUM; then
        local line="$ICON_CIRCLE $label"
        [[ -n "$detail" ]] && line+="  $detail"
        echo "$line" | gum style --foreground "$(_tui_color_value muted)"
    elif [[ -n "$detail" ]]; then
        echo -e "  ${STY_FAINT}${ICON_CIRCLE} $label  $detail${STY_RST}"
    else
        echo -e "  ${STY_FAINT}${ICON_CIRCLE} $label${STY_RST}"
    fi
}

###############################################################################
# Stage Header
###############################################################################
tui_stage_header() {
    local step="$1" total="$2" title="$3" start_s="${4:-}"
    local elapsed_str=""
    [[ -n "$start_s" ]] && elapsed_str="  ${STY_FAINT}($(tui_elapsed "$start_s"))${STY_RST}"
    echo ""
    if $HAS_GUM; then
        local stage_badge stage_title
        stage_badge=$(echo " $step/$total " | gum style --foreground "$(_tui_color_value text)" --background "$(_tui_color_value accent)")
        stage_title=$(echo "$title" | gum style --foreground "$(_tui_color_value accent)" --bold --padding "0 1")
        if [[ -n "$start_s" ]]; then
            gum join --horizontal "$stage_badge" "$stage_title" \
                "$(echo "$(tui_elapsed "$start_s")" | gum style --foreground "$(_tui_color_value muted)")"
        else
            gum join --horizontal "$stage_badge" "$stage_title"
        fi
    else
        echo -e "  ${STY_PURPLE}${STY_BOLD}[$step/$total]${STY_RST} ${STY_BOLD}$title${STY_RST}${elapsed_str}"
    fi
    echo ""
}

###############################################################################
# Rich Choose
###############################################################################
tui_choose_rich() {
    local header="$1"; shift
    local items=("$@")

    if $HAS_GUM; then
        local display_items=() labels=() max_label_len=0
        for item in "${items[@]}"; do
            local label; label="$(echo "$item" | cut -d'|' -f2)"
            labels+=("$label")
            local len=${#label}
            (( len > max_label_len )) && max_label_len=$len
        done
        for item in "${items[@]}"; do
            local icon label desc
            icon="$(echo "$item" | cut -d'|' -f1)"
            label="$(echo "$item" | cut -d'|' -f2)"
            desc="$(echo "$item" | cut -d'|' -f3)"
            if [[ -n "$desc" ]]; then
                display_items+=("$(printf '%s %-*s  %s' "$icon" "$max_label_len" "$label" "$desc")")
            else
                display_items+=("$(printf '%s %s' "$icon" "$label")")
            fi
        done
        local chosen
        chosen=$(gum choose --header "$header" \
            --header.foreground "$(_tui_color_value accent)" \
            --cursor.foreground "$(_tui_color_value accent)" \
            --selected.foreground "$(_tui_color_value accent)" \
            --item.foreground "$(_tui_color_value text)" \
            "${display_items[@]}")
        [[ -z "$chosen" ]] && return 1
        for i in "${!display_items[@]}"; do
            if [[ "${display_items[$i]}" == "$chosen" ]]; then
                echo "${labels[$i]}"; return 0
            fi
        done
        echo "$chosen"
    else
        echo -e "\n  ${STY_PURPLE}${STY_BOLD}$header${STY_RST}\n"
        local i=1 labels=() max_label_len=0
        for item in "${items[@]}"; do
            local label; label="$(echo "$item" | cut -d'|' -f2)"
            labels+=("$label")
            local len=${#label}
            (( len > max_label_len )) && max_label_len=$len
        done
        for item in "${items[@]}"; do
            local icon label desc
            icon="$(echo "$item" | cut -d'|' -f1)"
            label="$(echo "$item" | cut -d'|' -f2)"
            desc="$(echo "$item" | cut -d'|' -f3)"
            if [[ -n "$desc" ]]; then
                printf "    ${STY_FAINT}%d)${STY_RST} %s ${STY_BOLD}%-*s${STY_RST}  ${STY_FAINT}%s${STY_RST}\n" "$i" "$icon" "$max_label_len" "$label" "$desc"
            else
                printf "    ${STY_FAINT}%d)${STY_RST} %s %s\n" "$i" "$icon" "$label"
            fi
            ((i++))
        done
        echo ""
        echo -ne "  ${STY_PURPLE}${ICON_ARROW}${STY_RST} "
        read -r selection
        if [[ "$selection" =~ ^[0-9]+$ ]] && [[ "$selection" -ge 1 ]] && [[ "$selection" -le "${#labels[@]}" ]]; then
            echo "${labels[$((selection-1))]}"
        else
            echo "${labels[0]}"
        fi
    fi
}

###############################################################################
# Task List
###############################################################################
declare -a _TUI_TASKS=()
declare -a _TUI_TASK_STATES=()
declare -a _TUI_TASK_DETAILS=()
_TUI_TASK_LINES=0

_tui_task_state_icon() {
    case "$1" in
        pending)  echo -e "${STY_FAINT}·${STY_RST}" ;;
        running)  echo -e "${STY_PURPLE}▸${STY_RST}" ;;
        done)     echo -e "${STY_GREEN}✓${STY_RST}" ;;
        fail)     echo -e "${STY_RED}✗${STY_RST}" ;;
        warn)     echo -e "${STY_YELLOW}⚠${STY_RST}" ;;
        skip)     echo -e "${STY_FAINT}○${STY_RST}" ;;
        *)        echo -e "${STY_FAINT}·${STY_RST}" ;;
    esac
}

_tui_task_state_color() {
    case "$1" in
        pending)  echo "$STY_FAINT" ;;
        running)  echo "$STY_BOLD" ;;
        done)     echo "$STY_GREEN" ;;
        fail)     echo "$STY_RED" ;;
        warn)     echo "$STY_YELLOW" ;;
        skip)     echo "$STY_FAINT" ;;
        *)        echo "$STY_RST" ;;
    esac
}

tui_task_init() {
    _TUI_TASKS=("$@")
    _TUI_TASK_STATES=()
    _TUI_TASK_DETAILS=()
    _TUI_TASK_LINES=0
    for (( i=0; i<${#_TUI_TASKS[@]}; i++ )); do
        _TUI_TASK_STATES+=("pending")
        _TUI_TASK_DETAILS+=("")
    done
    tui_task_render
}

tui_task_run()  { _TUI_TASK_STATES[$1]="running"; [[ -n "${2:-}" ]] && _TUI_TASK_DETAILS[$1]="$2"; tui_task_render; }
tui_task_done() { _TUI_TASK_STATES[$1]="done";    [[ -n "${2:-}" ]] && _TUI_TASK_DETAILS[$1]="$2"; tui_task_render; }
tui_task_fail() { _TUI_TASK_STATES[$1]="fail";    [[ -n "${2:-}" ]] && _TUI_TASK_DETAILS[$1]="$2"; tui_task_render; }
tui_task_warn() { _TUI_TASK_STATES[$1]="warn";    [[ -n "${2:-}" ]] && _TUI_TASK_DETAILS[$1]="$2"; tui_task_render; }
tui_task_skip() { _TUI_TASK_STATES[$1]="skip";    [[ -n "${2:-}" ]] && _TUI_TASK_DETAILS[$1]="$2"; tui_task_render; }

tui_task_render() {
    if [[ $_TUI_TASK_LINES -gt 0 ]]; then
        printf '\033[%dA\033[J' "$_TUI_TASK_LINES"
    fi
    _TUI_TASK_LINES=0
    for (( i=0; i<${#_TUI_TASKS[@]}; i++ )); do
        local state="${_TUI_TASK_STATES[$i]}"
        local icon; icon="$(_tui_task_state_icon "$state")"
        local color; color="$(_tui_task_state_color "$state")"
        local detail="${_TUI_TASK_DETAILS[$i]}"
        local detail_str=""
        [[ -n "$detail" ]] && detail_str=" ${STY_FAINT}${detail}${STY_RST}"
        printf "  %b %b%s%b%b\n" "$icon" "$color" "${_TUI_TASKS[$i]}" "$STY_RST" "$detail_str"
        (( _TUI_TASK_LINES++ ))
    done
}

tui_task_finalize() {
    _TUI_TASK_LINES=0
    echo ""
}

###############################################################################
# Alert — icon + color, no border
###############################################################################
tui_alert() {
    local variant="${1:-info}" title="$2" message="${3:-}"
    local icon color_name
    case "$variant" in
        success) icon="$ICON_CHECK"; color_name="success" ;;
        warning) icon="$ICON_WARN";  color_name="warning" ;;
        error)   icon="$ICON_CROSS"; color_name="error" ;;
        *)       icon="$ICON_INFO";  color_name="info" ;;
    esac

    echo ""
    if $HAS_GUM; then
        echo "$icon $title" | gum style --foreground "$(_tui_color_value "$color_name")" --bold --padding "0 1"
        [[ -n "$message" ]] && echo "$message" | gum style --foreground "$(_tui_color_value text)" --padding "0 3"
    else
        case "$variant" in
            success) echo -e "  ${STY_GREEN}${STY_BOLD}${icon} ${title}${STY_RST}" ;;
            warning) echo -e "  ${STY_YELLOW}${STY_BOLD}${icon} ${title}${STY_RST}" ;;
            error)   echo -e "  ${STY_RED}${STY_BOLD}${icon} ${title}${STY_RST}" ;;
            *)       echo -e "  ${STY_BLUE}${STY_BOLD}${icon} ${title}${STY_RST}" ;;
        esac
        if [[ -n "$message" ]]; then
            while IFS= read -r line || [[ -n "$line" ]]; do
                echo "    $line"
            done <<< "$message"
        fi
    fi
    echo ""
}

###############################################################################
# Filter
###############################################################################
tui_filter() {
    local placeholder="${1:-Filter...}" limit="${2:-1}"
    if $HAS_GUM; then
        gum filter --placeholder "$placeholder" \
            --indicator.foreground "$(_tui_color_value accent)" \
            --match.foreground "$(_tui_color_value accent)" \
            --prompt.foreground "$(_tui_color_value accent)" \
            --header.foreground "$(_tui_color_value muted)" \
            --text.foreground "$(_tui_color_value text)" \
            --limit "$limit"
    else
        echo -ne "  ${STY_PURPLE}?${STY_RST} $placeholder: "
        local query; read -r query
        if [[ -n "$query" ]]; then
            grep -i "$query" || true
        else
            cat
        fi
    fi
}

###############################################################################
# Columns — side by side, no borders
###############################################################################
tui_columns() {
    local left="$1" right="$2" gap="${3:-4}"
    if $HAS_GUM; then
        local left_styled right_styled
        left_styled=$(echo "$left" | gum style --padding "0 2")
        right_styled=$(echo "$right" | gum style --padding "0 2")
        gum join --horizontal "$left_styled" "$(printf '%*s' "$gap" '')" "$right_styled"
    else
        echo "$left"
        echo ""
        echo "$right"
    fi
}

###############################################################################
# Summary Card — title + key-value pairs, no border
###############################################################################
tui_summary_card() {
    local title="$1"; shift
    local pairs=("$@")
    local max_key_len=0

    for pair in "${pairs[@]}"; do
        local key="${pair%%:*}" len=${#key}
        (( len > max_key_len )) && max_key_len=$len
    done

    echo ""
    if $HAS_GUM; then
        echo "$title" | gum style --foreground "$(_tui_color_value accent)" --bold --padding "0 1"
        for pair in "${pairs[@]}"; do
            local key="${pair%%:*}" value="${pair#*:}"
            printf "   ${STY_FAINT}%-*s${STY_RST}  %s\n" "$max_key_len" "$key" "$value"
        done
    else
        echo -e "  ${STY_PURPLE}${STY_BOLD}${title}${STY_RST}"
        for pair in "${pairs[@]}"; do
            local key="${pair%%:*}" value="${pair#*:}"
            printf "    ${STY_FAINT}%-*s${STY_RST}  %s\n" "$max_key_len" "$key" "$value"
        done
    fi
    echo ""
}

###############################################################################
# Keybind Hints
###############################################################################
tui_keyhints() {
    local hints=("$@")
    if $HAS_GUM; then
        local parts=()
        for hint in "${hints[@]}"; do
            local key="${hint%% *}" desc="${hint#* }"
            parts+=("$(gum join --horizontal \
                "$(echo "$key" | gum style --foreground "$(_tui_color_value accent)" --bold)" \
                "$(echo " $desc" | gum style --foreground "$(_tui_color_value muted)")")")
        done
        gum join --horizontal "${parts[@]}" | gum style --margin "0 1"
    else
        local line=""
        for hint in "${hints[@]}"; do
            local key="${hint%% *}" desc="${hint#* }"
            line+="  ${STY_PURPLE}${STY_BOLD}${key}${STY_RST} ${STY_FAINT}${desc}${STY_RST}"
        done
        echo -e "$line"
    fi
}
