#!/usr/bin/env bash

# KDE Material You Colors wrapper - optional integration
# Requires: kde-material-you-colors (pip install kde-material-you-colors)
# If not installed, this script silently exits

XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

# Check if kde-material-you-colors is available
if ! command -v kde-material-you-colors &>/dev/null; then
    # Not installed, silently exit (KDE theming is optional)
    exit 0
fi

color=$(tr -d '\n' < "$XDG_STATE_HOME/quickshell/user/generated/color.txt" 2>/dev/null)
if [[ -z "$color" ]]; then
    exit 0
fi

current_mode=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null | tr -d "'")
if [[ "$current_mode" == "prefer-dark" ]]; then
    mode_flag="-d"
else
    mode_flag="-l"
fi

# Parse --scheme-variant flag
scheme_variant_str=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --scheme-variant)
            scheme_variant_str="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# Map string variant to integer
case "$scheme_variant_str" in
    scheme-content) sv_num=0 ;;
    scheme-expressive) sv_num=1 ;;
    scheme-fidelity) sv_num=2 ;;
    scheme-monochrome) sv_num=3 ;;
    scheme-neutral) sv_num=4 ;;
    scheme-tonal-spot) sv_num=5 ;;
    scheme-vibrant) sv_num=6 ;;
    scheme-rainbow) sv_num=7 ;;
    scheme-fruit-salad) sv_num=8 ;;
    "") sv_num=5 ;;
    *)
        echo "Unknown scheme variant: $scheme_variant_str" >&2
        exit 1
        ;;
esac

# Activate venv if available, run command, deactivate
if [[ -n "$ILLOGICAL_IMPULSE_VIRTUAL_ENV" ]]; then
    source "$(eval echo $ILLOGICAL_IMPULSE_VIRTUAL_ENV)/bin/activate" 2>/dev/null || true
fi
kde-material-you-colors "$mode_flag" --color "$color" -sv "$sv_num" 2>/dev/null
deactivate 2>/dev/null || true
