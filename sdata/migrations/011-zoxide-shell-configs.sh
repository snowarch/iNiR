# Migration: Add zoxide to shell configurations
# zoxide is a smarter cd command that learns your habits
# This migration respects the shell.zoxide config settings

MIGRATION_ID="011-zoxide-shell-configs"
MIGRATION_TITLE="Zoxide Smart cd Integration"
MIGRATION_DESCRIPTION="Adds zoxide initialization to Fish, Bash, and Zsh configs.
  zoxide is a smarter cd command that learns your directory habits.
  After this migration, you can use 'z' instead of 'cd' to jump to directories.
  Example: 'z proj' jumps to the most frequently used directory matching 'proj'.
  This migration respects your shell.zoxide config settings."
MIGRATION_TARGET_FILE="~/.config/fish/config.fish"
MIGRATION_REQUIRED=false

#####################################################################################
# Helper: Read config value from config.json
#####################################################################################
_read_config() {
    local key="$1"
    local config_file="${XDG_CONFIG_HOME:-$HOME/.config}/illogical-impulse/config.json"

    if [[ -f "$config_file" ]] && command -v jq &>/dev/null; then
        jq -r "$key // empty" "$config_file" 2>/dev/null
    else
        echo ""
    fi
}

#####################################################################################
# Check if migration is needed
#####################################################################################
migration_check() {
    local fish_config="${XDG_CONFIG_HOME:-$HOME/.config}/fish/config.fish"
    local bash_config="$HOME/.config/ii/bashrc"
    local zsh_config="$HOME/.config/ii/zshrc"

    # Check if zoxide is installed
    if ! command -v zoxide &>/dev/null && ! [[ -x "$HOME/.local/bin/zoxide" ]]; then
        return 1  # zoxide not installed, skip
    fi

    # Check if zoxide is enabled in config (default to true if not set)
    local zoxide_enabled
    zoxide_enabled=$(_read_config '.shell.zoxide.enable')
    if [[ "$zoxide_enabled" == "false" ]]; then
        return 1  # zoxide disabled in config, skip
    fi

    # Check if any config is missing zoxide
    local needed=false

    if [[ -f "$fish_config" ]] && ! grep -q "zoxide init" "$fish_config"; then
        needed=true
    fi

    if [[ -f "$bash_config" ]] && ! grep -q "zoxide init" "$bash_config"; then
        needed=true
    fi

    if [[ -f "$zsh_config" ]] && ! grep -q "zoxide init" "$zsh_config"; then
        needed=true
    fi

    $needed
}

#####################################################################################
# Preview what will change
#####################################################################################
migration_preview() {
    local fish_config="${XDG_CONFIG_HOME:-$HOME/.config}/fish/config.fish"
    local bash_config="$HOME/.config/ii/bashrc"
    local zsh_config="$HOME/.config/ii/zshrc"

    # Check if cd replacement is enabled (default to true)
    local replace_cd
    replace_cd=$(_read_config '.shell.zoxide.replaceCd')
    [[ -z "$replace_cd" ]] && replace_cd="true"

    local init_cmd="zoxide init"
    if [[ "$replace_cd" == "true" ]]; then
        init_cmd="zoxide init --cmd cd"
    fi

    if [[ -f "$fish_config" ]] && ! grep -q "zoxide init" "$fish_config"; then
        echo -e "${STY_GREEN}+ ${init_cmd} fish | source${STY_RST}  (in config.fish)"
    fi

    if [[ -f "$bash_config" ]] && ! grep -q "zoxide init" "$bash_config"; then
        echo -e "${STY_GREEN}+ eval \"\$(${init_cmd} bash)\"${STY_RST}  (in ii/bashrc)"
    fi

    if [[ -f "$zsh_config" ]] && ! grep -q "zoxide init" "$zsh_config"; then
        echo -e "${STY_GREEN}+ eval \"\$(${init_cmd} zsh)\"${STY_RST}  (in ii/zshrc)"
    fi

    if [[ "$replace_cd" != "true" ]]; then
        echo -e "${STY_YELLOW}Note: cd replacement is disabled. Use 'z' command instead.${STY_RST}"
    fi
}

#####################################################################################
# Apply the migration
#####################################################################################
migration_apply() {
    local fish_config="${XDG_CONFIG_HOME:-$HOME/.config}/fish/config.fish"
    local bash_config="$HOME/.config/ii/bashrc"
    local zsh_config="$HOME/.config/ii/zshrc"

    # Check if zoxide is enabled in config (default to true if not set)
    local zoxide_enabled
    zoxide_enabled=$(_read_config '.shell.zoxide.enable')
    if [[ "$zoxide_enabled" == "false" ]]; then
        return 1  # zoxide disabled, skip
    fi

    # Check if cd replacement is enabled (default to true)
    local replace_cd
    replace_cd=$(_read_config '.shell.zoxide.replaceCd')
    [[ -z "$replace_cd" ]] && replace_cd="true"

    local applied_any=false

    # Determine init command based on config
    local fish_init_cmd="zoxide init fish"
    local bash_init_cmd="zoxide init bash"
    local zsh_init_cmd="zoxide init zsh"

    if [[ "$replace_cd" == "true" ]]; then
        fish_init_cmd="zoxide init --cmd cd fish"
        bash_init_cmd="zoxide init --cmd cd bash"
        zsh_init_cmd="zoxide init --cmd cd zsh"
    fi

    # Add zoxide to Fish config
    if [[ -f "$fish_config" ]] && ! grep -q "zoxide init" "$fish_config"; then
        cat >> "$fish_config" << EOF

# zoxide - smarter cd command
if command -v zoxide > /dev/null
    ${fish_init_cmd} | source
end
EOF
        applied_any=true
    fi

    # Add zoxide to Bash config
    if [[ -f "$bash_config" ]] && ! grep -q "zoxide init" "$bash_config"; then
        cat >> "$bash_config" << EOF

# zoxide - smarter cd command
if command -v zoxide &> /dev/null; then
    eval "\$(${bash_init_cmd})"
elif [[ -x ~/.local/bin/zoxide ]]; then
    eval "\$(~/.local/bin/${bash_init_cmd})"
fi
EOF
        applied_any=true
    fi

    # Add zoxide to Zsh config
    if [[ -f "$zsh_config" ]] && ! grep -q "zoxide init" "$zsh_config"; then
        cat >> "$zsh_config" << EOF

# zoxide - smarter cd command
if command -v zoxide &> /dev/null; then
    eval "\$(${zsh_init_cmd})"
elif [[ -x ~/.local/bin/zoxide ]]; then
    eval "\$(~/.local/bin/${zsh_init_cmd})"
fi
EOF
        applied_any=true
    fi

    if $applied_any; then
        return 0
    else
        return 1
    fi
}
