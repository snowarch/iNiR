#!/bin/bash
# TUI functions for ii-niri setup
# Professional design with gum fallback
# This script is meant to be sourced.

# shellcheck shell=bash

###############################################################################
# Theme Configuration
###############################################################################
# Primary palette (matches ii-niri accent colors)
TUI_ACCENT="212"        # Magenta/Pink - primary accent
TUI_ACCENT_DIM="99"     # Purple - secondary accent
TUI_SUCCESS="82"        # Green
TUI_WARNING="214"       # Orange
TUI_ERROR="196"         # Red
TUI_INFO="39"           # Blue
TUI_MUTED="245"         # Gray
TUI_DIM="240"           # Darker gray

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
# Gum Detection & Fallback
###############################################################################
HAS_GUM=false
command -v gum &>/dev/null && HAS_GUM=true

###############################################################################
# Core Styling Helpers
###############################################################################
_color() {
    local fg="$1" text="$2"
    if $HAS_GUM; then
        echo "$text" | gum style --foreground "$fg"
    else
        # Map 256 colors to basic ANSI where possible
        case "$fg" in
            212|99)  echo -e "${STY_PURPLE}${text}${STY_RST}" ;;
            82)      echo -e "${STY_GREEN}${text}${STY_RST}" ;;
            214|208) echo -e "${STY_YELLOW}${text}${STY_RST}" ;;
            196)     echo -e "${STY_RED}${text}${STY_RST}" ;;
            39)      echo -e "${STY_BLUE}${text}${STY_RST}" ;;
            245|240) echo -e "${STY_FAINT}${text}${STY_RST}" ;;
            *)       echo -e "${text}" ;;
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
        gum spin --spinner dot --title "$title" --spinner.foreground "$TUI_ACCENT" -- "$@"
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
        echo "$text" | gum style --foreground "$TUI_ACCENT" --bold --padding "0 1"
        _draw_line "$TUI_ACCENT_DIM" 40
    else
        echo ""
        echo -e "${STY_PURPLE}${STY_BOLD}  $text${STY_RST}"
        echo -e "${STY_FAINT}  $(printf '%.0s─' {1..40})${STY_RST}"
    fi
}

tui_subtitle() {
    local text="$1"
    if $HAS_GUM; then
        echo "$text" | gum style --foreground "$TUI_MUTED" --italic
    else
        echo -e "${STY_FAINT}  $text${STY_RST}"
    fi
}

tui_success() {
    local text="$1"
    if $HAS_GUM; then
        echo "$ICON_CHECK $text" | gum style --foreground "$TUI_SUCCESS"
    else
        echo -e "  ${STY_GREEN}${ICON_CHECK}${STY_RST} $text"
    fi
}

tui_error() {
    local text="$1"
    if $HAS_GUM; then
        echo "$ICON_CROSS $text" | gum style --foreground "$TUI_ERROR"
    else
        echo -e "  ${STY_RED}${ICON_CROSS}${STY_RST} $text"
    fi
}

tui_warn() {
    local text="$1"
    if $HAS_GUM; then
        echo "$ICON_WARN $text" | gum style --foreground "$TUI_WARNING"
    else
        echo -e "  ${STY_YELLOW}${ICON_WARN}${STY_RST} $text"
    fi
}

tui_info() {
    local text="$1"
    if $HAS_GUM; then
        echo "$ICON_INFO $text" | gum style --foreground "$TUI_INFO"
    else
        echo -e "  ${STY_BLUE}${ICON_INFO}${STY_RST} $text"
    fi
}

tui_dim() {
    local text="$1"
    if $HAS_GUM; then
        echo "$text" | gum style --foreground "$TUI_DIM"
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
            gum confirm --default=yes --prompt.foreground "$TUI_ACCENT" "$prompt"
        else
            gum confirm --default=no --prompt.foreground "$TUI_ACCENT" "$prompt"
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
            --prompt.foreground "$TUI_ACCENT" \
            --cursor.foreground "$TUI_ACCENT"
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
            --header.foreground "$TUI_ACCENT" \
            --cursor.foreground "$TUI_ACCENT" \
            --selected.foreground "$TUI_ACCENT" \
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
            --header.foreground "$TUI_ACCENT" \
            --cursor.foreground "$TUI_ACCENT" \
            --selected.foreground "$TUI_ACCENT" \
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
        echo "$line" | gum style --foreground "$color"
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
        echo "$content" | gum style \
            --border rounded \
            --border-foreground "$color" \
            --padding "0 2" \
            --margin "0 1"
    else
        local inner_width=$((width - 4))
        local h_line=$(_repeat_char "$BOX_H" $((width-2)))
        
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

tui_banner() {
    if $HAS_GUM; then
        gum style \
            --foreground "$TUI_ACCENT" \
            --border-foreground "$TUI_ACCENT_DIM" \
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
            "$(gum style --foreground 245 'illogical-impulse on Niri')"
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
 ║                  illogical-impulse on Niri                        ║
 ║                                                                   ║
 ╚═══════════════════════════════════════════════════════════════════╝
EOF
        echo -e "${STY_RST}"
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
    _draw_line "$TUI_DIM" "$width"
}

###############################################################################
# Progress Steps
###############################################################################
tui_step() {
    local current="$1"
    local total="$2"
    local description="$3"
    
    echo ""
    if $HAS_GUM; then
        echo "[$current/$total] $description" | gum style --foreground "$TUI_ACCENT" --bold
    else
        echo -e "  ${STY_PURPLE}${STY_BOLD}[$current/$total]${STY_RST} ${STY_BOLD}$description${STY_RST}"
    fi
    _draw_line "$TUI_DIM" 40
}

tui_progress_bar() {
    local current="$1"
    local total="$2"
    local width="${3:-30}"
    
    local percent=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done
    
    if $HAS_GUM; then
        echo "$bar $percent%" | gum style --foreground "$TUI_ACCENT"
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
                "$(echo "$title" | gum style --foreground "$TUI_ACCENT" --bold)" \
                "$(echo "$subtitle" | gum style --foreground "$TUI_MUTED")"
        else
            echo "$title" | gum style --foreground "$TUI_ACCENT" --bold
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
        echo " $title" | gum style --foreground "$TUI_ACCENT" --bold --border-foreground "$TUI_DIM" --border normal --padding "0 1"
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
