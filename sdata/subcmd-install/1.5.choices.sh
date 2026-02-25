# User choices for ii-niri installer
# This script is meant to be sourced.

# shellcheck shell=bash

#####################################################################################
# Application Choices
#####################################################################################

# Defaults
CHOICE_FILE_MANAGER="dolphin"
CHOICE_TERMINAL="foot"
CHOICE_SHELL="fish"

choose_applications() {
    if ! $ask; then
        return 0
    fi

    tui_title "Application Preferences"
    tui_subtitle "Choose your preferred applications (defaults work fine)"
    echo ""

    # File Manager
    local fm_options=("dolphin" "thunar" "pcmanfm" "nautilus" "nemo" "none")
    if $HAS_GUM; then
        CHOICE_FILE_MANAGER=$(gum choose --header "File Manager:" "${fm_options[@]}")
    else
        echo "File Manager:"
        select fm in "${fm_options[@]}"; do
            [[ -n "$fm" ]] && { CHOICE_FILE_MANAGER="$fm"; break; }
        done
    fi

    # Terminal
    local term_options=("foot" "kitty" "alacritty" "wezterm" "none")
    if $HAS_GUM; then
        CHOICE_TERMINAL=$(gum choose --header "Terminal:" "${term_options[@]}")
    else
        echo "Terminal:"
        select term in "${term_options[@]}"; do
            [[ -n "$term" ]] && { CHOICE_TERMINAL="$term"; break; }
        done
    fi

    # Shell
    local shell_options=("fish" "zsh" "bash" "nushell")
    if $HAS_GUM; then
        CHOICE_SHELL=$(gum choose --header "Shell:" "${shell_options[@]}")
    else
        echo "Shell:"
        select sh in "${shell_options[@]}"; do
            [[ -n "$sh" ]] && { CHOICE_SHELL="$sh"; break; }
        done
    fi

    echo ""
    tui_key_value "File Manager" "$CHOICE_FILE_MANAGER"
    tui_key_value "Terminal" "$CHOICE_TERMINAL"
    tui_key_value "Shell" "$CHOICE_SHELL"
    echo ""
}

# Export for use in dependency installation
export CHOICE_FILE_MANAGER CHOICE_TERMINAL CHOICE_SHELL
