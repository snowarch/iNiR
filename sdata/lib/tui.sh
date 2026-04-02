#!/bin/bash
# TUI functions for iNiR setup
# Professional design with gum fallback
# This script is meant to be sourced.

# shellcheck shell=bash

###############################################################################
# Theme Configuration
###############################################################################
# Primary palette (matches iNiR accent colors)
TUI_ACCENT="212"        # Magenta/Pink - primary accent
TUI_ACCENT_DIM="99"     # Purple - secondary accent
TUI_SUCCESS="82"        # Green
TUI_WARNING="214"       # Orange
TUI_ERROR="196"         # Red
TUI_INFO="39"           # Blue
TUI_MUTED="245"         # Gray
TUI_DIM="240"           # Darker gray

# Rich palette for gum-backed terminals. Falls back to ANSI-safe values above.
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

# Box drawing characters (Unicode)
BOX_TL="╭"  BOX_TR="╮"
BOX_BL="╰"  BOX_BR="╯"
BOX_H="─"   BOX_V="│"
BOX_DTL="╔" BOX_DTR="╗"
BOX_DBL="╚" BOX_DBR="╝"
BOX_DH="═"  BOX_DV="║"

# Icons (Nerd Font compatible, with fallbacks)
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
    local file="$1"
    local key="$2"

    [[ -f "$file" ]] || return 1
    sed -n "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$file" | head -1
}

_tui_use_palette_candidate() {
    local current="$1"
    local candidate="$2"

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
        accent) printf '%s' "$TUI_GUM_ACCENT" ;;
        accent-dim) printf '%s' "$TUI_GUM_ACCENT_DIM" ;;
        success) printf '%s' "$TUI_GUM_SUCCESS" ;;
        warning) printf '%s' "$TUI_GUM_WARNING" ;;
        error) printf '%s' "$TUI_GUM_ERROR" ;;
        info) printf '%s' "$TUI_GUM_INFO" ;;
        muted) printf '%s' "$TUI_GUM_MUTED" ;;
        dim) printf '%s' "$TUI_GUM_DIM" ;;
        surface) printf '%s' "$TUI_GUM_SURFACE" ;;
        surface-alt) printf '%s' "$TUI_GUM_SURFACE_ALT" ;;
        text) printf '%s' "$TUI_GUM_TEXT" ;;
        *) printf '%s' "$tone" ;;
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
        # Map 256 colors to basic ANSI where possible
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

###############################################################################
# Spinner / Progress
###############################################################################
tui_spin() {
    local title="$1"
    shift
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
    if $HAS_GUM; then
        echo ""
        echo "$text" | gum style --foreground "$(_tui_color_value accent)" --bold --padding "0 1"
        _draw_line "accent-dim" 40
    else
        echo ""
        echo -e "${STY_PURPLE}${STY_BOLD}  $text${STY_RST}"
        echo -e "${STY_FAINT}  $(printf '%.0s─' {1..40})${STY_RST}"
    fi
}

tui_subtitle() {
    local text="$1"
    if $HAS_GUM; then
        echo "$text" | gum style --foreground "$(_tui_color_value muted)" --italic
    else
        echo -e "${STY_FAINT}  $text${STY_RST}"
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
    local prompt="${1:-Continue?}"
    local default="${2:-yes}"
    
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
        read -n 1 -r
        echo
        if [[ "$default" == "yes" ]]; then
            [[ ! $REPLY =~ ^[Nn]$ ]]
        else
            [[ $REPLY =~ ^[Yy]$ ]]
        fi
    fi
}

tui_input() {
    local prompt="$1"
    local default="$2"
    
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
    local header="$1"
    shift
    local options=("$@")
    
    if $HAS_GUM; then
        gum choose --header "$header" \
            --header.foreground "$(_tui_color_value accent)" \
            --cursor.foreground "$(_tui_color_value accent)" \
            --selected.foreground "$(_tui_color_value accent)" \
            "${options[@]}"
    else
        echo -e "\n  ${STY_PURPLE}${STY_BOLD}$header${STY_RST}"
        echo ""
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
    local header="$1"
    shift
    local options=("$@")
    
    if $HAS_GUM; then
        gum choose --no-limit --header "$header" \
            --header.foreground "$(_tui_color_value accent)" \
            --cursor.foreground "$(_tui_color_value accent)" \
            --selected.foreground "$(_tui_color_value accent)" \
            "${options[@]}"
    else
        echo -e "\n  ${STY_PURPLE}${STY_BOLD}$header${STY_RST}"
        echo -e "  ${STY_FAINT}(enter numbers separated by space, or 'all')${STY_RST}"
        echo ""
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
# Drawing Helpers
###############################################################################
_repeat_char() {
    local char="$1"
    local count="$2"
    local result=""
    local i
    for ((i=0; i<count; i++)); do
        result+="$char"
    done
    echo "$result"
}

_draw_line() {
    local color="${1:-$TUI_DIM}"
    local width="${2:-50}"
    local char="${3:-$BOX_H}"
    local line=$(_repeat_char "$char" "$width")
    
    if $HAS_GUM; then
        echo "$line" | gum style --foreground "$(_tui_color_value "$color")"
    else
        echo -e "${STY_FAINT}  ${line}${STY_RST}"
    fi
}

###############################################################################
# Boxes & Panels
###############################################################################
tui_box() {
    local content="$1"
    local title="${2:-}"
    local color="${3:-$TUI_ACCENT_DIM}"
    local width="${4:-56}"
    
    if $HAS_GUM; then
        if [[ -n "$title" ]]; then
            gum join --vertical \
                "$(echo "$title" | gum style --foreground "$(_tui_color_value accent)" --bold --padding '0 1')" \
                "$(echo "$content" | gum style --border rounded --border-foreground "$(_tui_color_value "$color")" --padding '0 2' --margin '0 1')"
        else
            echo "$content" | gum style \
                --border rounded \
                --border-foreground "$(_tui_color_value "$color")" \
                --padding "0 2" \
                --margin "0 1"
        fi
    else
        local inner_width=$((width - 4))
        local h_line=$(_repeat_char "$BOX_H" $((width-2)))
        
        [[ -n "$title" ]] && echo -e "  ${STY_PURPLE}${STY_BOLD}${title}${STY_RST}"

        # Top border
        echo -e "  ${STY_FAINT}${BOX_TL}${h_line}${BOX_TR}${STY_RST}"
        
        # Content
        while IFS= read -r line || [[ -n "$line" ]]; do
            printf "  ${STY_FAINT}${BOX_V}${STY_RST} %-${inner_width}s ${STY_FAINT}${BOX_V}${STY_RST}\n" "$line"
        done <<< "$content"
        
        # Bottom border
        echo -e "  ${STY_FAINT}${BOX_BL}${h_line}${BOX_BR}${STY_RST}"
    fi
}

tui_badge() {
    local label="$1"
    local value="$2"
    local tone="${3:-accent}"

    if $HAS_GUM; then
        gum style \
            --foreground "$(_tui_color_value text)" \
            --background "$(_tui_color_value surface)" \
            --border rounded \
            --border-foreground "$(_tui_color_value "$tone")" \
            --padding "0 1" \
            "${label}: ${value}"
    else
        printf '%b[%s: %s]%b' "$STY_BOLD" "$label" "$value" "$STY_RST"
    fi
}

tui_badge_row() {
    [[ $# -gt 0 ]] || return 0

    if $HAS_GUM; then
        local rendered=()
        local label value tone
        while [[ $# -ge 2 ]]; do
            label="$1"
            value="$2"
            tone="${3:-accent}"
            rendered+=("$(tui_badge "$label" "$value" "$tone")")
            shift 3 || true
        done
        gum join --horizontal "${rendered[@]}"
    else
        local first=true
        while [[ $# -ge 2 ]]; do
            $first || printf ' '
            first=false
            tui_badge "$1" "$2" "${3:-accent}"
            shift 3 || true
        done
        echo ""
    fi
}

tui_banner() {
    if $HAS_GUM; then
        gum style \
            --foreground "$(_tui_color_value accent)" \
            --border-foreground "$(_tui_color_value accent-dim)" \
            --border double \
            --align center \
            --width 70 \
            --margin "1 0" \
            --padding "1" \
            "██╗██╗      ███╗   ██╗██╗██████╗ ██╗" \
            "██║██║      ████╗  ██║██║██╔══██╗██║" \
            "██║██║█████╗██╔██╗ ██║██║██████╔╝██║" \
            "██║██║╚════╝██║╚██╗██║██║██╔══██╗██║" \
            "██║██║      ██║ ╚████║██║██║  ██║██║" \
            "╚═╝╚═╝      ╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝╚═╝" \
            "" \
            "$(gum style --foreground "$(_tui_color_value muted)" 'iNiR — your niri shell')"
    else
        echo ""
        echo -e "${STY_PURPLE}${STY_BOLD}"
        cat << 'EOF'
 ╔═══════════════════════════════════════════════════════════════════╗
 ║                                                                   ║
 ║   ██╗██╗      ███╗   ██╗██╗██████╗ ██╗                            ║
 ║   ██║██║      ████╗  ██║██║██╔══██╗██║                            ║
 ║   ██║██║█████╗██╔██╗ ██║██║██████╔╝██║                            ║
 ║   ██║██║╚════╝██║╚██╗██║██║██╔══██╗██║                            ║
 ║   ██║██║      ██║ ╚████║██║██║  ██║██║                            ║
 ║   ╚═╝╚═╝      ╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝╚═╝                            ║
 ║                                                                   ║
 ║                    iNiR — your niri shell                          ║
 ║                                                                   ║
 ╚═══════════════════════════════════════════════════════════════════╝
EOF
        echo -e "${STY_RST}"
    fi
}

tui_hero_card() {
    local eyebrow="$1"
    local subtitle="$2"
    local detail="${3:-}"

    tui_banner
    if $HAS_GUM; then
        local card
        card=$(gum join --vertical \
            "$(echo "$eyebrow" | gum style --foreground "$(_tui_color_value accent)" --bold)" \
            "$(echo "$subtitle" | gum style --foreground "$(_tui_color_value text)")")
        if [[ -n "$detail" ]]; then
            card=$(gum join --vertical "$card" "$(echo "$detail" | gum style --foreground "$(_tui_color_value muted)")")
        fi
        echo "$card" | gum style --border rounded --border-foreground "$(_tui_color_value accent-dim)" --padding "0 2" --margin "0 1"
    else
        echo -e "  ${STY_PURPLE}${STY_BOLD}${eyebrow}${STY_RST}"
        echo -e "  ${subtitle}"
        [[ -n "$detail" ]] && echo -e "  ${STY_FAINT}${detail}${STY_RST}"
        echo ""
    fi
}

###############################################################################
# Status Display
###############################################################################
tui_status_line() {
    local label="$1"
    local value="$2"
    local status="${3:-}"  # ok, warn, error, or empty
    
    local color=""
    local icon=""
    case "$status" in
        ok)    color="${STY_GREEN}"; icon="$ICON_DOT" ;;
        warn)  color="${STY_YELLOW}"; icon="$ICON_DOT" ;;
        error) color="${STY_RED}"; icon="$ICON_DOT" ;;
        *)     color="${STY_RST}"; icon=" " ;;
    esac
    
    printf "  ${STY_FAINT}%s${STY_RST} ${STY_BOLD}%-12s${STY_RST} ${color}%s${STY_RST}\n" "$icon" "$label" "$value"
}

tui_divider() {
    local width="${1:-48}"
    _draw_line "dim" "$width"
}

###############################################################################
# Progress Steps
###############################################################################
tui_step() {
    local current="$1"
    local total="$2"
    local description="$3"
    local subtitle="${4:-}"
    
    echo ""
    if $HAS_GUM; then
        local step_badge
        local step_title
        step_badge=$(echo " $current/$total " | gum style --foreground "$(_tui_color_value text)" --background "$(_tui_color_value accent)")
        step_title=$(echo "$description" | gum style --foreground "$(_tui_color_value accent)" --bold --padding "0 1")
        if [[ -n "$subtitle" ]]; then
            gum join --vertical \
                "$(gum join --horizontal "$step_badge" "$step_title")" \
                "$(echo "$subtitle" | gum style --foreground "$(_tui_color_value muted)")"
        else
            gum join --horizontal \
                "$step_badge" \
                "$step_title"
        fi
    else
        echo -e "  ${STY_PURPLE}${STY_BOLD}[$current/$total]${STY_RST} ${STY_BOLD}$description${STY_RST}"
        [[ -n "$subtitle" ]] && echo -e "  ${STY_FAINT}${subtitle}${STY_RST}"
    fi
    _draw_line "dim" 40
}

tui_progress_bar() {
    local current="$1"
    local total="$2"
    local width="${3:-30}"
    
    local percent=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    local bar=""
    local i
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done
    
    if $HAS_GUM; then
        echo "$bar $percent%" | gum style --foreground "$(_tui_color_value accent)"
    else
        echo -e "  ${STY_PURPLE}${bar}${STY_RST} ${percent}%"
    fi
}

###############################################################################
# Tables (Professional Unicode borders)
###############################################################################
tui_table_header() {
    local col1="$1"
    local col2="$2"
    local col1_width="${3:-16}"
    local col2_width="${4:-32}"
    
    local line1=$(_repeat_char "$BOX_H" $((col1_width+2)))
    local line2=$(_repeat_char "$BOX_H" $((col2_width+2)))
    
    # Top border
    echo -e "  ${STY_FAINT}${BOX_TL}${line1}┬${line2}${BOX_TR}${STY_RST}"
    
    # Header row
    printf "  ${STY_FAINT}${BOX_V}${STY_RST} ${STY_BOLD}%-${col1_width}s${STY_RST} ${STY_FAINT}${BOX_V}${STY_RST} ${STY_BOLD}%-${col2_width}s${STY_RST} ${STY_FAINT}${BOX_V}${STY_RST}\n" "$col1" "$col2"
    
    # Separator
    echo -e "  ${STY_FAINT}├${line1}┼${line2}┤${STY_RST}"
}

tui_table_row() {
    local col1="$1"
    local col2="$2"
    local col1_width="${3:-16}"
    local col2_width="${4:-32}"
    
    printf "  ${STY_FAINT}${BOX_V}${STY_RST} %-${col1_width}s ${STY_FAINT}${BOX_V}${STY_RST} %-${col2_width}s ${STY_FAINT}${BOX_V}${STY_RST}\n" "$col1" "$col2"
}

tui_table_footer() {
    local col1_width="${1:-16}"
    local col2_width="${2:-32}"
    
    local line1=$(_repeat_char "$BOX_H" $((col1_width+2)))
    local line2=$(_repeat_char "$BOX_H" $((col2_width+2)))
    
    echo -e "  ${STY_FAINT}${BOX_BL}${line1}┴${line2}${BOX_BR}${STY_RST}"
}

###############################################################################
# Special Components
###############################################################################
tui_header_block() {
    local title="$1"
    local subtitle="${2:-}"
    
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
    local key="$1"
    local value="$2"
    local key_width="${3:-14}"
    
    printf "  ${STY_FAINT}%-${key_width}s${STY_RST} %s\n" "$key" "$value"
}

tui_list_item() {
    local text="$1"
    local bullet="${2:-$ICON_ARROW}"
    
    echo -e "  ${STY_PURPLE}$bullet${STY_RST} $text"
}

tui_section_start() {
    local title="$1"
    echo ""
    if $HAS_GUM; then
        echo " $title" | gum style --foreground "$(_tui_color_value accent)" --bold --border-foreground "$(_tui_color_value dim)" --border normal --padding "0 1"
    else
        echo -e "  ${STY_FAINT}┌─${STY_RST} ${STY_PURPLE}${STY_BOLD}$title${STY_RST} ${STY_FAINT}─────────────────────────────${STY_RST}"
    fi
}

tui_section_end() {
    if ! $HAS_GUM; then
        echo -e "  ${STY_FAINT}└──────────────────────────────────────────────${STY_RST}"
    fi
    echo ""
}

###############################################################################
# Compact Status (for doctor/status commands)
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
# Timer / Elapsed Helpers
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
# Verification Item Display (for post-install/uninstall checks)
###############################################################################
tui_verify_ok() {
    local label="$1"
    local detail="${2:-}"
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
    local label="$1"
    local detail="${2:-}"
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
    local label="$1"
    local detail="${2:-}"
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
# Stage Header with Step Counter and Elapsed Time
###############################################################################
tui_stage_header() {
    local step="$1"
    local total="$2"
    local title="$3"
    local start_s="${4:-}"
    local elapsed_str=""
    [[ -n "$start_s" ]] && elapsed_str="  ${STY_FAINT}($(tui_elapsed "$start_s"))${STY_RST}"
    echo ""
    if $HAS_GUM; then
        local stage_badge
        local stage_title
        stage_badge=$(echo " $step/$total " | gum style --foreground "$(_tui_color_value text)" --background "$(_tui_color_value accent)")
        stage_title=$(echo "$title" | gum style --foreground "$(_tui_color_value accent)" --bold --padding "0 1")
        if [[ -n "$start_s" ]]; then
            gum join --horizontal \
                "$stage_badge" \
                "$stage_title" \
                "$(echo "$(tui_elapsed "$start_s")" | gum style --foreground "$(_tui_color_value muted)")"
        else
            gum join --horizontal \
                "$stage_badge" \
                "$stage_title"
        fi
    else
        echo -e "  ${STY_PURPLE}${STY_BOLD}[$step/$total]${STY_RST} ${STY_BOLD}$title${STY_RST}${elapsed_str}"
    fi
    _draw_line "dim" 40
}
