#!/usr/bin/env bash
COLOR_FILE_PATH="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/user/generated/color.txt"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/config-path.sh
source "$SCRIPT_DIR/../../lib/config-path.sh"
SHELL_CONFIG_FILE="$(inir_config_file)"

# Define an array of possible VSCode settings file paths for various forks
settings_paths=(
    "${XDG_CONFIG_HOME:-$HOME/.config}/Code/User/settings.json"
    "${XDG_CONFIG_HOME:-$HOME/.config}/VSCodium/User/settings.json"
    "${XDG_CONFIG_HOME:-$HOME/.config}/Code - OSS/User/settings.json"
    "${XDG_CONFIG_HOME:-$HOME/.config}/Code - Insiders/User/settings.json"
    "${XDG_CONFIG_HOME:-$HOME/.config}/Cursor/User/settings.json"
    # Add more paths as needed for other forks
)

# Check if VSCode theming is enabled in config
enable_vscode="true"
if [[ -f "$SHELL_CONFIG_FILE" ]] && command -v jq &>/dev/null; then
    enable_vscode=$(jq -r '.appearance.wallpaperTheming.enableVSCode // true' "$SHELL_CONFIG_FILE" 2>/dev/null || echo "true")
fi

new_color=$(cat "$COLOR_FILE_PATH" 2>/dev/null || echo "")

for CODE_SETTINGS_PATH in "${settings_paths[@]}"; do
    if [[ -f "$CODE_SETTINGS_PATH" ]]; then
        if [[ "$enable_vscode" == "false" ]]; then
            # Comment out the material-code.primaryColor line when VSCode theming is disabled
            if grep -q '"material-code.primaryColor"' "$CODE_SETTINGS_PATH"; then
                sed -i -E \
                    's|^(\s*)(\"material-code\.primaryColor\".*)$|\1// \2|' \
                    "$CODE_SETTINGS_PATH"
            fi
        else
            # Re-enable: uncomment if previously commented out
            if grep -q '//.*"material-code.primaryColor"' "$CODE_SETTINGS_PATH"; then
                sed -i -E \
                    's|^(\s*)//\s*(\"material-code\.primaryColor\".*)$|\1\2|' \
                    "$CODE_SETTINGS_PATH"
            fi
            # Update the color value
            if grep -q '"material-code.primaryColor"' "$CODE_SETTINGS_PATH"; then
                sed -i -E \
                    "s/(\"material-code.primaryColor\"\s*:\s*\")[^\"]*(\")/\1${new_color}\2/" \
                    "$CODE_SETTINGS_PATH"
            else
                # If the key is not already there, add it
                sed -i '$ s/}/,\n  "material-code.primaryColor": "'${new_color}'"\n}/' "$CODE_SETTINGS_PATH"
                sed -i '$ s/,\n,/,/' "$CODE_SETTINGS_PATH"
            fi
        fi
    fi
done
