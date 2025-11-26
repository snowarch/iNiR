#!/bin/bash

# TUI functions for ii-niri setup
# Uses 'gum' if available, otherwise falls back to simple text menus

function check_gum() {
    command -v gum >/dev/null 2>&1
}

function tui_header() {
    clear
    if check_gum; then
        gum style --foreground 212 --border-foreground 212 --border double --align center --width 50 --margin "1 2" --padding "2 4" "illogical-impulse on Niri" "Setup & Management"
    else
        echo -e "${STY_BOLD}${STY_CYAN}illogical-impulse on Niri - Setup & Management${STY_RST}"
        echo "================================================"
        echo ""
    fi
}

function tui_main_menu() {
    tui_header
    
    local choice
    if check_gum; then
        choice=$(gum choose --header "What would you like to do?" "Install" "Update" "Help" "Exit")
    else
        echo "Select an action:"
        select c in "Install" "Update" "Help" "Exit"; do
            choice=$c
            break
        done
    fi
    
    case "$choice" in
        "Install")
            tui_install_menu
            return 1 # Signal install
            ;;
        "Update")
            return 2 # Signal update
            ;;
        "Help")
            showhelp_global
            exit 0
            ;;
        "Exit")
            exit 0
            ;;
        *)
            exit 0
            ;;
    esac
}

function tui_install_menu() {
    local choices
    if check_gum; then
        choices=$(gum choose --no-limit --selected "Dependencies,System Setup,Config Files" --header "Select components to install (Space to toggle, Enter to confirm)" "Dependencies" "System Setup" "Config Files")
    else
        echo ""
        echo "Install Components Selection:"
        echo "1) Full Install (All)"
        echo "2) Dependencies Only"
        echo "3) System Setup Only"
        echo "4) Config Files Only"
        echo "5) Custom (Manual selection)"
        echo ""
        read -p "Select option [1]: " opt
        case "$opt" in
            2) choices="Dependencies";;
            3) choices="System Setup";;
            4) choices="Config Files";;
            5) 
               echo "Enter components to install (deps, setup, files):"
               read choices
               ;;
            *) choices="Dependencies,System Setup,Config Files";;
        esac
    fi
    
    # Default to skipping all, then enable selected
    # We export these so the main script sees them
    export SKIP_ALLDEPS=true
    export SKIP_ALLSETUPS=true
    export SKIP_ALLFILES=true
    
    if [[ "$choices" == *"Dependencies"* ]] || [[ "$choices" == *"deps"* ]]; then
        export SKIP_ALLDEPS=false
    fi
    
    if [[ "$choices" == *"System Setup"* ]] || [[ "$choices" == *"setup"* ]]; then
        export SKIP_ALLSETUPS=false
    fi
    
    if [[ "$choices" == *"Config Files"* ]] || [[ "$choices" == *"files"* ]]; then
        export SKIP_ALLFILES=false
    fi
}
