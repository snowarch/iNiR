#!/usr/bin/env bash
# Zoxide setup for iNiR - Cross-distribution installer
# This script is meant to be sourced, not run directly.
# Supports: Arch Linux, Fedora, Debian/Ubuntu, and generic installations

# shellcheck shell=bash

#####################################################################################
# Install zoxide from official installer (cross-platform)
#####################################################################################
install-zoxide() {
  if command -v zoxide &>/dev/null; then
    echo -e "${STY_GREEN}zoxide already installed.${STY_RST}"
    return 0
  fi

  echo -e "${STY_BLUE}Installing zoxide...${STY_RST}"
  
  # Try distro package manager first, fallback to official installer
  case "$OS_GROUP_ID" in
    arch)
      # Arch Linux - use pacman (zoxide is in official repos)
      if command -v pacman &>/dev/null; then
        sudo pacman -S --needed --noconfirm zoxide 2>/dev/null && {
          echo -e "${STY_GREEN}zoxide installed via pacman.${STY_RST}"
          return 0
        }
      fi
      ;;
      
    fedora)
      # Fedora - use dnf (zoxide is in official repos)
      if command -v dnf &>/dev/null; then
        sudo dnf install -y zoxide 2>/dev/null && {
          echo -e "${STY_GREEN}zoxide installed via dnf.${STY_RST}"
          return 0
        }
      fi
      ;;
      
    debian|ubuntu)
      # Debian/Ubuntu - zoxide is in repos for newer versions
      if command -v apt &>/dev/null; then
        sudo apt install -y zoxide 2>/dev/null && {
          echo -e "${STY_GREEN}zoxide installed via apt.${STY_RST}"
          return 0
        }
      fi
      ;;
      
    opensuse)
      # openSUSE - use zypper
      if command -v zypper &>/dev/null; then
        sudo zypper install -y zoxide 2>/dev/null && {
          echo -e "${STY_GREEN}zoxide installed via zypper.${STY_RST}"
          return 0
        }
      fi
      ;;
      
    void)
      # Void Linux - use xbps
      if command -v xbps-install &>/dev/null; then
        sudo xbps-install -Sy zoxide 2>/dev/null && {
          echo -e "${STY_GREEN}zoxide installed via xbps.${STY_RST}"
          return 0
        }
      fi
      ;;
      
    alpine)
      # Alpine Linux - use apk
      if command -v apk &>/dev/null; then
        sudo apk add zoxide 2>/dev/null && {
          echo -e "${STY_GREEN}zoxide installed via apk.${STY_RST}"
          return 0
        }
      fi
      ;;
  esac

  # Fallback: Official installer (works on all Linux distributions)
  echo -e "${STY_BLUE}Installing zoxide via official installer...${STY_RST}"
  
  if curl -sSf https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh; then
    # Add to PATH if installed to ~/.local/bin
    if [[ -f "$HOME/.local/bin/zoxide" ]]; then
      export PATH="$HOME/.local/bin:$PATH"
    fi
    echo -e "${STY_GREEN}zoxide installed successfully.${STY_RST}"
  else
    echo -e "${STY_YELLOW}Failed to install zoxide.${STY_RST}"
    return 1
  fi
}

#####################################################################################
# Setup zoxide for Fish shell
#####################################################################################
setup-zoxide-fish() {
  local fish_config="$HOME/.config/fish/config.fish"
  
  # Create config directory if it doesn't exist
  mkdir -p "$(dirname "$fish_config")"
  
  # Check if zoxide is already configured
  if [[ -f "$fish_config" ]] && grep -q "zoxide init fish" "$fish_config"; then
    echo -e "${STY_CYAN}zoxide already configured for Fish.${STY_RST}"
    return 0
  fi

  echo -e "${STY_BLUE}Setting up zoxide for Fish shell...${STY_RST}"
  
  # Create or append to config.fish
  if [[ ! -f "$fish_config" ]]; then
    cat > "$fish_config" << 'EOF'
function fish_prompt -d "Write out the prompt"
    printf '%s@%s %s%s%s > ' $USER $hostname \
        (set_color $fish_color_cwd) (prompt_pwd) (set_color normal)
end

if status is-interactive

    # No greeting
    set fish_greeting

    # Use starship if available
    if command -v starship > /dev/null
        starship init fish | source
    end

    # Load terminal colors from ii theming
    if test -f ~/.local/state/quickshell/user/generated/terminal/sequences.txt
        cat ~/.local/state/quickshell/user/generated/terminal/sequences.txt
    end

    # zoxide - smarter cd command (replaces cd)
    if command -v zoxide > /dev/null
        zoxide init --cmd cd fish | source
    end

    # Aliases
    if command -v eza > /dev/null
        alias ls 'eza --icons'
    end
    alias clear "printf '\033[2J\033[3J\033[1;1H'"
    alias q 'qs -c ii'

    # Add local bin to PATH
    fish_add_path ~/.local/bin

end
EOF
  else
    # Append zoxide configuration to existing config
    cat >> "$fish_config" << 'EOF'

# zoxide - smarter cd command (replaces cd)
if command -v zoxide > /dev/null
    zoxide init --cmd cd fish | source
end
EOF
  fi
  
  echo -e "${STY_GREEN}zoxide configured for Fish shell.${STY_RST}"
}

#####################################################################################
# Setup zoxide for Bash shell
#####################################################################################
setup-zoxide-bash() {
  local ii_config="$HOME/.config/ii/bashrc"
  
  mkdir -p "$(dirname "$ii_config")"
  
  # Check if zoxide is already configured
  if [[ -f "$ii_config" ]] && grep -q "zoxide init bash" "$ii_config"; then
    echo -e "${STY_CYAN}zoxide already configured for Bash.${STY_RST}"
    return 0
  fi

  echo -e "${STY_BLUE}Setting up zoxide for Bash shell...${STY_RST}"
  
  # Create or update ii bash config
  if [[ ! -f "$ii_config" ]]; then
    cat > "$ii_config" << 'EOF'
# ii shell integration - starship prompt and terminal colors

# Load terminal colors from ii theming
if [[ -f ~/.local/state/quickshell/user/generated/terminal/sequences.txt ]]; then
    cat ~/.local/state/quickshell/user/generated/terminal/sequences.txt
fi

# Use starship if available
if command -v starship &> /dev/null; then
    eval "$(starship init bash)"
elif [[ -x ~/.local/bin/starship ]]; then
    eval "$(~/.local/bin/starship init bash)"
fi

# zoxide - smarter cd command (replaces cd)
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init --cmd cd bash)"
elif [[ -x ~/.local/bin/zoxide ]]; then
    eval "$(~/.local/bin/zoxide init --cmd cd bash)"
fi

# Aliases
if command -v eza &> /dev/null; then
    alias ls='eza --icons'
elif [[ -x ~/.local/bin/eza ]]; then
    alias ls='~/.local/bin/eza --icons'
fi
alias q='qs -c ii'

# Add local bin to PATH
export PATH="$HOME/.local/bin:$PATH"
EOF
  else
    # Append zoxide configuration
    cat >> "$ii_config" << 'EOF'

# zoxide - smarter cd command (replaces cd)
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init --cmd cd bash)"
elif [[ -x ~/.local/bin/zoxide ]]; then
    eval "$(~/.local/bin/zoxide init --cmd cd bash)"
fi
EOF
  fi
  
  # Ensure .bashrc sources ii config
  local bashrc="$HOME/.bashrc"
  if [[ -f "$bashrc" ]]; then
    if ! grep -q "source.*ii/bashrc" "$bashrc" && ! grep -q "\..*ii/bashrc" "$bashrc"; then
      echo -e "\n# ii shell integration\n[[ -f ~/.config/ii/bashrc ]] && source ~/.config/ii/bashrc" >> "$bashrc"
    fi
  fi
  
  echo -e "${STY_GREEN}zoxide configured for Bash shell.${STY_RST}"
}

#####################################################################################
# Setup zoxide for Zsh shell
#####################################################################################
setup-zoxide-zsh() {
  local ii_config="$HOME/.config/ii/zshrc"
  
  mkdir -p "$(dirname "$ii_config")"
  
  # Check if zoxide is already configured
  if [[ -f "$ii_config" ]] && grep -q "zoxide init zsh" "$ii_config"; then
    echo -e "${STY_CYAN}zoxide already configured for Zsh.${STY_RST}"
    return 0
  fi

  echo -e "${STY_BLUE}Setting up zoxide for Zsh shell...${STY_RST}"
  
  # Create or update ii zsh config
  if [[ ! -f "$ii_config" ]]; then
    cat > "$ii_config" << 'EOF'
# ii shell integration - starship prompt and terminal colors

# Load terminal colors from ii theming
if [[ -f ~/.local/state/quickshell/user/generated/terminal/sequences.txt ]]; then
    cat ~/.local/state/quickshell/user/generated/terminal/sequences.txt
fi

# Use starship if available
if command -v starship &> /dev/null; then
    eval "$(starship init zsh)"
elif [[ -x ~/.local/bin/starship ]]; then
    eval "$(~/.local/bin/starship init zsh)"
fi

# zoxide - smarter cd command (replaces cd)
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init --cmd cd zsh)"
elif [[ -x ~/.local/bin/zoxide ]]; then
    eval "$(~/.local/bin/zoxide init --cmd cd zsh)"
fi

# Aliases
if command -v eza &> /dev/null; then
    alias ls='eza --icons'
elif [[ -x ~/.local/bin/eza ]]; then
    alias ls='~/.local/bin/eza --icons'
fi
alias q='qs -c ii'

# Add local bin to PATH
export PATH="$HOME/.local/bin:$PATH"
EOF
  else
    # Append zoxide configuration
    cat >> "$ii_config" << 'EOF'

# zoxide - smarter cd command (replaces cd)
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init --cmd cd zsh)"
elif [[ -x ~/.local/bin/zoxide ]]; then
    eval "$(~/.local/bin/zoxide init --cmd cd zsh)"
fi
EOF
  fi
  
  # Ensure .zshrc sources ii config
  local zshrc="$HOME/.zshrc"
  if [[ -f "$zshrc" ]]; then
    if ! grep -q "source.*ii/zshrc" "$zshrc" && ! grep -q "\..*ii/zshrc" "$zshrc"; then
      echo -e "\n# ii shell integration\n[[ -f ~/.config/ii/zshrc ]] && source ~/.config/ii/zshrc" >> "$zshrc"
    fi
  fi
  
  echo -e "${STY_GREEN}zoxide configured for Zsh shell.${STY_RST}"
}

#####################################################################################
# Main zoxide setup function
#####################################################################################
setup-zoxide() {
  echo ""
  echo -e "${STY_CYAN}${STY_BOLD}Setting up zoxide (smart cd replacement)...${STY_RST}"
  echo ""
  
  # Step 1: Install zoxide
  install-zoxide
  
  # Step 2: Setup for available shells
  if command -v fish &>/dev/null; then
    setup-zoxide-fish
  fi
  
  # Always setup bash (most common)
  setup-zoxide-bash
  
  # Setup zsh if it exists
  if command -v zsh &>/dev/null || [[ -f "$HOME/.zshrc" ]]; then
    setup-zoxide-zsh
  fi
  
  echo ""
  echo -e "${STY_GREEN}zoxide setup complete!${STY_RST}"
  echo -e "${STY_DIM}Usage: Use 'z' instead of 'cd' for smart directory jumping.${STY_RST}"
  echo -e "${STY_DIM}Examples:${STY_RST}"
  echo -e "${STY_DIM}  z proj      # Jump to most frequently used 'proj' directory${STY_RST}"
  echo -e "${STY_DIM}  z foo bar   # Jump to directory matching 'foo' and 'bar'${STY_RST}"
  echo -e "${STY_DIM}  zi          # Interactive selection with fzf (if installed)${STY_RST}"
  echo ""
}

#####################################################################################
# Check if zoxide is installed and configured
#####################################################################################
check-zoxide() {
  local status=0
  
  if ! command -v zoxide &>/dev/null && ! [[ -x "$HOME/.local/bin/zoxide" ]]; then
    echo "zoxide: not installed"
    return 1
  fi
  
  # Check shell configurations
  if [[ -f "$HOME/.config/fish/config.fish" ]] && grep -q "zoxide init fish" "$HOME/.config/fish/config.fish"; then
    echo "zoxide: configured for Fish ✓"
  fi
  
  if [[ -f "$HOME/.config/ii/bashrc" ]] && grep -q "zoxide init bash" "$HOME/.config/ii/bashrc"; then
    echo "zoxide: configured for Bash ✓"
  fi
  
  if [[ -f "$HOME/.config/ii/zshrc" ]] && grep -q "zoxide init zsh" "$HOME/.config/ii/zshrc"; then
    echo "zoxide: configured for Zsh ✓"
  fi
  
  return 0
}

# Run setup if called directly (for standalone usage)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # Try to detect distro if not already set
  if [[ -z "$OS_GROUP_ID" ]]; then
    if command -v pacman &>/dev/null; then
      OS_GROUP_ID="arch"
    elif command -v dnf &>/dev/null; then
      OS_GROUP_ID="fedora"
    elif command -v apt &>/dev/null; then
      OS_GROUP_ID="debian"
    elif command -v zypper &>/dev/null; then
      OS_GROUP_ID="opensuse"
    elif command -v xbps-install &>/dev/null; then
      OS_GROUP_ID="void"
    elif command -v apk &>/dev/null; then
      OS_GROUP_ID="alpine"
    else
      OS_GROUP_ID="generic"
    fi
  fi
  
  # Load styling if available (for standalone usage)
  if [[ -f "./sdata/lib/functions.sh" ]]; then
    source "./sdata/lib/functions.sh"
  fi
  
  case "${1:-setup}" in
    install) install-zoxide ;;
    setup) setup-zoxide ;;
    check) check-zoxide ;;
    *) echo "Usage: $0 {install|setup|check}" ;;
  esac
fi
