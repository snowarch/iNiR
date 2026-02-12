# Migration: Add zoxide to shell configurations
# zoxide is a smarter cd command that learns your habits

MIGRATION_ID="011-zoxide-shell-configs"
MIGRATION_TITLE="Zoxide Smart cd Integration"
MIGRATION_DESCRIPTION="Adds zoxide initialization to Fish, Bash, and Zsh configs.
  zoxide is a smarter cd command that learns your directory habits.
  After this migration, you can use 'z' instead of 'cd' to jump to directories.
  Example: 'z proj' jumps to the most frequently used directory matching 'proj'."
MIGRATION_TARGET_FILE="~/.config/fish/config.fish"
MIGRATION_REQUIRED=false

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

    # Check if any config is missing zoxide
    local needed=false

    if [[ -f "$fish_config" ]] && ! grep -q "zoxide init fish" "$fish_config"; then
        needed=true
    fi

    if [[ -f "$bash_config" ]] && ! grep -q "zoxide init bash" "$bash_config"; then
        needed=true
    fi

    if [[ -f "$zsh_config" ]] && ! grep -q "zoxide init zsh" "$zsh_config"; then
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

    if [[ -f "$fish_config" ]] && ! grep -q "zoxide init fish" "$fish_config"; then
        echo -e "${STY_GREEN}+ zoxide init fish | source${STY_RST}  (in config.fish)"
    fi

    if [[ -f "$bash_config" ]] && ! grep -q "zoxide init bash" "$bash_config"; then
        echo -e "${STY_GREEN}+ eval \"\$(zoxide init bash)\"${STY_RST}  (in ii/bashrc)"
    fi

    if [[ -f "$zsh_config" ]] && ! grep -q "zoxide init zsh" "$zsh_config"; then
        echo -e "${STY_GREEN}+ eval \"\$(zoxide init zsh)\"${STY_RST}  (in ii/zshrc)"
    fi
}

#####################################################################################
# Apply the migration
#####################################################################################
migration_apply() {
    local fish_config="${XDG_CONFIG_HOME:-$HOME/.config}/fish/config.fish"
    local bash_config="$HOME/.config/ii/bashrc"
    local zsh_config="$HOME/.config/ii/zshrc"

    local applied_any=false

    # Add zoxide to Fish config
    if [[ -f "$fish_config" ]] && ! grep -q "zoxide init fish" "$fish_config"; then
        cat >> "$fish_config" << 'EOF'

# zoxide - smarter cd command (replaces cd)
if command -v zoxide > /dev/null
    zoxide init fish | source
    alias cd z
end
EOF
        applied_any=true
    fi

    # Add zoxide to Bash config
    if [[ -f "$bash_config" ]] && ! grep -q "zoxide init bash" "$bash_config"; then
        cat >> "$bash_config" << 'EOF'

# zoxide - smarter cd command (replaces cd)
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init bash)"
    alias cd='z'
elif [[ -x ~/.local/bin/zoxide ]]; then
    eval "$(~/.local/bin/zoxide init bash)"
    alias cd='z'
fi
EOF
        applied_any=true
    fi

    # Add zoxide to Zsh config
    if [[ -f "$zsh_config" ]] && ! grep -q "zoxide init zsh" "$zsh_config"; then
        cat >> "$zsh_config" << 'EOF'

# zoxide - smarter cd command (replaces cd)
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init zsh)"
    alias cd='z'
elif [[ -x ~/.local/bin/zoxide ]]; then
    eval "$(~/.local/bin/zoxide init zsh)"
    alias cd='z'
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
