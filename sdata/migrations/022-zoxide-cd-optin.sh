#!/usr/bin/env bash
# Migration: Offer zoxide as default cd replacement
#
# Zoxide is a smarter cd command that learns your habits.
# This migration offers to replace the built-in cd with zoxide's
# smart directory jumper (cd becomes zoxide-powered).
# If zoxide is not installed, it will be skipped.

MIGRATION_ID="022-zoxide-cd-optin"
MIGRATION_TITLE="Use zoxide as default cd command"
MIGRATION_DESCRIPTION="Replace cd with zoxide's smart directory jumper.
  Zoxide remembers your frequently-visited directories so you can
  jump to them with partial path matches (e.g. 'cd proj' instead of
  'cd ~/projects'). This changes the cd command to use zoxide under
  the hood. The 'z' command is always available regardless of this
  setting — this migration only controls whether cd itself uses zoxide."
MIGRATION_TARGET_FILE="~/.bashrc, ~/.zshrc, ~/.config/fish/conf.d/inir-zoxide.fish"
MIGRATION_REQUIRED=false

_oxd_config_file() {
    local xdg="${XDG_CONFIG_HOME:-$HOME/.config}"
    if [[ -d "${xdg}/inir" ]]; then
        printf '%s\n' "${xdg}/inir/config.json"
    elif [[ -d "${xdg}/illogical-impulse" ]]; then
        printf '%s\n' "${xdg}/illogical-impulse/config.json"
    else
        printf '%s\n' "${xdg}/inir/config.json"
    fi
}

_oxd_is_zoxide_cd_configured() {
    local config_file
    config_file="$(_oxd_config_file)"
    if command -v jq &>/dev/null && [[ -f "$config_file" ]]; then
        [[ "$(jq -r '.apps.zoxideAsCd // false' "$config_file" 2>/dev/null)" == "true" ]]
        return $?
    fi
    return 1
}

_oxd_has_zoxide_init() {
    local found=0
    if [[ -f "$HOME/.bashrc" ]] && grep -q 'iNiR zoxide init' "$HOME/.bashrc" 2>/dev/null; then
        found=1
    fi
    if [[ -f "$HOME/.zshrc" ]] && grep -q 'iNiR zoxide init' "$HOME/.zshrc" 2>/dev/null; then
        found=1
    fi
    local fish_conf="${XDG_CONFIG_HOME:-$HOME/.config}/fish/conf.d/inir-zoxide.fish"
    if [[ -f "$fish_conf" ]]; then
        found=1
    fi
    return $((1 - found))
}

_oxd_has_zoxide_cd_flag() {
    if [[ -f "$HOME/.bashrc" ]] && grep -q 'zoxide init bash.*--cmd cd' "$HOME/.bashrc" 2>/dev/null; then
        return 0
    fi
    if [[ -f "$HOME/.zshrc" ]] && grep -q 'zoxide init zsh.*--cmd cd' "$HOME/.zshrc" 2>/dev/null; then
        return 0
    fi
    local fish_conf="${XDG_CONFIG_HOME:-$HOME/.config}/fish/conf.d/inir-zoxide.fish"
    if [[ -f "$fish_conf" ]] && grep -q 'zoxide init fish.*--cmd cd' "$fish_conf" 2>/dev/null; then
        return 0
    fi
    return 1
}

migration_check() {
    if ! command -v zoxide &>/dev/null; then
        return 1
    fi

    if _oxd_is_zoxide_cd_configured; then
        return 1
    fi

    if _oxd_has_zoxide_cd_flag; then
        return 1
    fi

    if [[ -f "$HOME/.bashrc" ]] && grep -q 'zoxide init' "$HOME/.bashrc" 2>/dev/null; then
        if ! grep -q 'iNiR zoxide init' "$HOME/.bashrc" 2>/dev/null; then
            return 1
        fi
    fi
    if [[ -f "$HOME/.zshrc" ]] && grep -q 'zoxide init' "$HOME/.zshrc" 2>/dev/null; then
        if ! grep -q 'iNiR zoxide init' "$HOME/.zshrc" 2>/dev/null; then
            return 1
        fi
    fi

    return 0
}

migration_preview() {
    echo -e "Will configure zoxide as your default cd command:"
    echo ""
    echo -e "${STY_GREEN}+ cd will use zoxide's smart directory matching${STY_RST}"
    echo -e "${STY_GREEN}+ 'cd proj' jumps to ~/projects (or your most-visited proj* dir)${STY_RST}"
    echo -e "${STY_GREEN}+ 'z' command remains available as a shorter alias${STY_RST}"
    echo ""
    echo "Shell config files that will be updated:"
    if [[ -f "$HOME/.bashrc" ]]; then echo "  ~/.bashrc"; fi
    if [[ -f "$HOME/.zshrc" ]]; then echo "  ~/.zshrc"; fi
    echo "  ~/.config/fish/conf.d/inir-zoxide.fish"
    echo ""
    echo "Note: zoxide must be installed. If it's not, this migration"
    echo "will be skipped automatically."
}

migration_diff() {
    local has_bash=false has_zsh=false has_fish=true
    [[ -f "$HOME/.bashrc" ]] && has_bash=true
    [[ -f "$HOME/.zshrc" ]] && has_zsh=true

    echo "Current zoxide init lines (without --cmd cd):"
    echo ""

    if $has_bash; then
        echo "  ~/.bashrc:"
        echo -e "    ${STY_RED}- eval \"\$(zoxide init bash)\"${STY_RST}"
        echo -e "    ${STY_GREEN}+ eval \"\$(zoxide init bash --cmd cd)\"${STY_RST}"
    fi

    if $has_zsh; then
        echo "  ~/.zshrc:"
        echo -e "    ${STY_RED}- eval \"\$(zoxide init zsh)\"${STY_RST}"
        echo -e "    ${STY_GREEN}+ eval \"\$(zoxide init zsh --cmd cd)\"${STY_RST}"
    fi

    echo "  fish/conf.d/inir-zoxide.fish:"
    echo -e "    ${STY_RED}- zoxide init fish | source${STY_RST}"
    echo -e "    ${STY_GREEN}+ zoxide init fish --cmd cd | source${STY_RST}"
}

migration_apply() {
    local config_file
    config_file="$(_oxd_config_file)"
    local marker="# iNiR zoxide init"
    local end_marker="# end iNiR zoxide"
    local fish_conf_dir="${XDG_CONFIG_HOME:-$HOME/.config}/fish/conf.d"
    local fish_conf="${fish_conf_dir}/inir-zoxide.fish"
    local changed=0

    if ! command -v zoxide &>/dev/null; then
        echo "  zoxide is not installed — skipping"
        return 0
    fi

    mkdir -p "$(dirname "$config_file")"

    if command -v jq &>/dev/null && [[ -f "$config_file" ]]; then
        local tmp_file
        tmp_file="$(mktemp)"
        jq '.apps.zoxideAsCd = true' "$config_file" > "$tmp_file" && mv "$tmp_file" "$config_file"
        echo "  Updated config.json: apps.zoxideAsCd = true"
    else
        mkdir -p "$(dirname "$config_file")"
        if [[ -f "$config_file" ]]; then
            sed -i 's/"zoxideAsCd": false/"zoxideAsCd": true/' "$config_file" 2>/dev/null
            echo "  Updated config.json: apps.zoxideAsCd = true"
        fi
    fi

    if [[ -f "$HOME/.bashrc" ]]; then
        sed -i "/${marker}/,/${end_marker}/d" "$HOME/.bashrc"
        cat >> "$HOME/.bashrc" << BEOF

${marker}
if command -v zoxide &>/dev/null; then
  eval "$(zoxide init bash --cmd cd)"
fi
${end_marker}
BEOF
        echo "  Updated ~/.bashrc with zoxide --cmd cd"
        ((changed++)) || true
    fi

    if [[ -f "$HOME/.zshrc" ]]; then
        sed -i "/${marker}/,/${end_marker}/d" "$HOME/.zshrc"
        cat >> "$HOME/.zshrc" << ZEOF

${marker}
if command -v zoxide &>/dev/null; then
  eval "$(zoxide init zsh --cmd cd)"
fi
${end_marker}
ZEOF
        echo "  Updated ~/.zshrc with zoxide --cmd cd"
        ((changed++)) || true
    fi

    mkdir -p "$fish_conf_dir"
    cat > "$fish_conf" << FEOF
# iNiR zoxide init — auto-generated by migration
if command -v zoxide &>/dev/null
    zoxide init fish --cmd cd | source
end
FEOF
    echo "  Updated fish/conf.d/inir-zoxide.fish with zoxide --cmd cd"
    ((changed++)) || true

    if [[ $changed -eq 0 ]]; then
        echo "  No shell configs were updated"
    fi
}