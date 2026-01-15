# Package installation functions for iNiR
# This is NOT a script for execution, but for loading functions
# Shared across all distros

# shellcheck shell=bash

#####################################################################################
# AUR Helpers (Arch-specific)
#####################################################################################

install-yay(){
  echo -e "${STY_CYAN}Installing yay (AUR helper)...${STY_RST}"

  # Clean up previous attempts
  rm -rf /tmp/buildyay

  # Sync databases and install base-devel
  if ! x sudo pacman -Sy --needed --noconfirm base-devel git; then
      log_error "Failed to install base-devel/git. Check your pacman mirrors."
      return 1
  fi

  # Clone yay-bin (faster than compiling yay)
  x git clone https://aur.archlinux.org/yay-bin.git /tmp/buildyay || return 1

  # Build and install
  x cd /tmp/buildyay
  if ! x makepkg -si --noconfirm; then
      log_error "Failed to build/install yay."
      x cd "${REPO_ROOT}"
      return 1
  fi

  x cd "${REPO_ROOT}"
  rm -rf /tmp/buildyay
}

install-paru(){
  echo -e "${STY_CYAN}Installing paru (AUR helper)...${STY_RST}"
  x sudo pacman -S --needed --noconfirm base-devel git
  x git clone https://aur.archlinux.org/paru-bin.git /tmp/buildparu
  x cd /tmp/buildparu
  x makepkg -si --noconfirm
  x cd "${REPO_ROOT}"
  rm -rf /tmp/buildparu
}

ensure_aur_helper(){
  if command -v yay &>/dev/null; then
    AUR_HELPER="yay"
    return 0
  elif command -v paru &>/dev/null; then
    AUR_HELPER="paru"
    return 0
  fi

  echo -e "${STY_YELLOW}No AUR helper found.${STY_RST}"
  echo "Installing yay..."
  install-yay
  AUR_HELPER="yay"
}

install-local-pkgbuild() {
  local location=$1
  local installflags=$2

  x pushd $location

  source ./PKGBUILD
  x $AUR_HELPER -S --sudoloop $installflags --asdeps "${depends[@]}"
  x makepkg -Afsi --noconfirm
  x popd
}

#####################################################################################
# Python Environment (All distros)
#####################################################################################

install-python-packages(){
  echo -e "${STY_CYAN}Setting up Python virtual environment...${STY_RST}"

  local venv_dir="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/.venv"

  if ! command -v uv &>/dev/null; then
    log_warning "uv not installed, skipping Python venv setup"
    return 0
  fi

  if [[ ! -d "$venv_dir/bin" ]]; then
    x mkdir -p "$(dirname "$venv_dir")"
    x uv venv --prompt ii-venv "$venv_dir" -p 3.12 || uv venv --prompt ii-venv "$venv_dir" || {
      log_warning "Could not create Python venv"
      return 0
    }
  fi

  # Install required packages from requirements.txt
  # Try repo location first (during install), then target location (during doctor)
  local requirements_file="${REPO_ROOT}/sdata/uv/requirements.txt"
  if [[ ! -f "$requirements_file" ]]; then
    requirements_file="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/ii/sdata/uv/requirements.txt"
  fi

  if [[ -f "$requirements_file" ]]; then
    source "$venv_dir/bin/activate"
    x uv pip install -r "$requirements_file"
    deactivate
  else
    log_warning "requirements.txt not found"
  fi

  log_success "Python venv ready at $venv_dir"
}

#####################################################################################
# Font Installation (All distros)
#####################################################################################

install-font-from-url(){
  local font_name="$1"
  local url="$2"
  local font_dir="${HOME}/.local/share/fonts"

  mkdir -p "$font_dir"

  echo -e "${STY_BLUE}Downloading $font_name...${STY_RST}"
  if curl -fsSL -o "$font_dir/${font_name}.ttf" "$url" 2>/dev/null; then
    fc-cache -f "$font_dir" 2>/dev/null
    echo -e "${STY_GREEN}$font_name installed.${STY_RST}"
    return 0
  else
    echo -e "${STY_YELLOW}Could not download $font_name.${STY_RST}"
    return 1
  fi
}

install-material-symbols-rounded(){
  if fc-list | grep -qi "Material Symbols Rounded"; then
    echo -e "${STY_GREEN}Material Symbols Rounded already installed.${STY_RST}"
    return 0
  fi

  install-font-from-url "MaterialSymbolsRounded" \
    "https://raw.githubusercontent.com/google/material-design-icons/master/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf"
}

install-material-symbols-outlined(){
  if fc-list | grep -qi "Material Symbols Outlined"; then
    echo -e "${STY_GREEN}Material Symbols Outlined already installed.${STY_RST}"
    return 0
  fi

  install-font-from-url "MaterialSymbolsOutlined" \
    "https://raw.githubusercontent.com/google/material-design-icons/master/variablefont/MaterialSymbolsOutlined%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf"
}

install-jetbrains-mono-nerd(){
  if fc-list | grep -qi "JetBrainsMono Nerd"; then
    echo -e "${STY_GREEN}JetBrains Mono Nerd Font already installed.${STY_RST}"
    return 0
  fi

  echo -e "${STY_BLUE}Downloading JetBrains Mono Nerd Font...${STY_RST}"

  local font_dir="${HOME}/.local/share/fonts"
  local temp_dir="/tmp/nerdfonts-$$"
  mkdir -p "$font_dir" "$temp_dir"

  if curl -fsSL -o "$temp_dir/JetBrainsMono.zip" \
    "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"; then
    unzip -o "$temp_dir/JetBrainsMono.zip" -d "$font_dir" >/dev/null 2>&1
    fc-cache -f "$font_dir"
    echo -e "${STY_GREEN}JetBrains Mono Nerd Font installed.${STY_RST}"
  else
    echo -e "${STY_YELLOW}Could not download JetBrains Mono Nerd Font.${STY_RST}"
  fi

  rm -rf "$temp_dir"
}

install-geist-font(){
  if fc-list | grep -qi "Geist"; then
    echo -e "${STY_GREEN}Geist font already installed.${STY_RST}"
    return 0
  fi

  echo -e "${STY_BLUE}Downloading Geist font...${STY_RST}"

  local font_dir="${HOME}/.local/share/fonts"
  local temp_dir="/tmp/geist-font-$$"
  mkdir -p "$font_dir" "$temp_dir"

  if curl -fsSL -o "$temp_dir/geist.zip" \
    "https://github.com/vercel/geist-font/releases/latest/download/Geist.zip"; then
    unzip -o "$temp_dir/geist.zip" -d "$temp_dir" >/dev/null 2>&1
    find "$temp_dir" -name "*.ttf" -exec cp {} "$font_dir/" \;
    fc-cache -f "$font_dir"
    echo -e "${STY_GREEN}Geist font installed.${STY_RST}"
  else
    echo -e "${STY_YELLOW}Could not download Geist font.${STY_RST}"
  fi

  rm -rf "$temp_dir"
}

install-space-grotesk(){
  if fc-list | grep -qi "Space Grotesk"; then
    echo -e "${STY_GREEN}Space Grotesk already installed.${STY_RST}"
    return 0
  fi

  install-font-from-url "SpaceGrotesk" \
    "https://github.com/floriankarsten/space-grotesk/raw/master/fonts/ttf/SpaceGrotesk%5Bwght%5D.ttf"
}

install-rubik-font(){
  if fc-list | grep -qi "Rubik"; then
    echo -e "${STY_GREEN}Rubik font already installed.${STY_RST}"
    return 0
  fi

  install-font-from-url "Rubik" \
    "https://github.com/googlefonts/rubik/raw/main/fonts/variable/Rubik%5Bwght%5D.ttf"
}

#####################################################################################
# Icon Theme Installation (All distros)
#####################################################################################

install-whitesur-icons(){
  local icon_dir="${HOME}/.local/share/icons"

  if [[ -d "$icon_dir/WhiteSur-dark" ]]; then
    echo -e "${STY_GREEN}WhiteSur icon theme already installed.${STY_RST}"
    return 0
  fi

  echo -e "${STY_BLUE}Installing WhiteSur icon theme...${STY_RST}"

  local temp_dir="/tmp/whitesur-icons-$$"
  mkdir -p "$temp_dir" "$icon_dir"

  if curl -fsSL -o "$temp_dir/whitesur.tar.gz" \
    "https://github.com/vinceliuice/WhiteSur-icon-theme/archive/refs/heads/master.tar.gz"; then
    tar -xzf "$temp_dir/whitesur.tar.gz" -C "$temp_dir"
    cd "$temp_dir/WhiteSur-icon-theme-master"
    ./install.sh -d "$icon_dir" -t default >/dev/null 2>&1 || {
      # Fallback: manual copy
      cp -r src/WhiteSur "$icon_dir/WhiteSur" 2>/dev/null || true
      cp -r src/WhiteSur-dark "$icon_dir/WhiteSur-dark" 2>/dev/null || true
      cp -r src/WhiteSur-light "$icon_dir/WhiteSur-light" 2>/dev/null || true
    }
    cd - >/dev/null
    echo -e "${STY_GREEN}WhiteSur icon theme installed.${STY_RST}"
  else
    echo -e "${STY_YELLOW}Could not download WhiteSur icon theme.${STY_RST}"
  fi

  rm -rf "$temp_dir"
}

install-mactahoe-icons(){
  local icon_dir="${HOME}/.local/share/icons"

  if [[ -d "$icon_dir/MacTahoe" ]]; then
    echo -e "${STY_GREEN}MacTahoe icon theme already installed.${STY_RST}"
    return 0
  fi

  echo -e "${STY_BLUE}Installing MacTahoe icon theme...${STY_RST}"

  local temp_dir="/tmp/mactahoe-icons-$$"
  mkdir -p "$temp_dir" "$icon_dir"

  if curl -fsSL -o "$temp_dir/mactahoe.tar.gz" \
    "https://github.com/vinceliuice/MacTahoe-icon-theme/archive/refs/heads/master.tar.gz"; then
    tar -xzf "$temp_dir/mactahoe.tar.gz" -C "$temp_dir"
    cd "$temp_dir/MacTahoe-icon-theme-master" 2>/dev/null || cd "$temp_dir/MacTahoe-icon-theme-main"
    ./install.sh -d "$icon_dir" >/dev/null 2>&1
    cd - >/dev/null
    echo -e "${STY_GREEN}MacTahoe icon theme installed.${STY_RST}"
  else
    echo -e "${STY_YELLOW}Could not download MacTahoe icon theme.${STY_RST}"
  fi

  rm -rf "$temp_dir"
}

#####################################################################################
# Cursor Theme Installation (All distros)
#####################################################################################

install-bibata-cursors(){
  local icon_dir="${HOME}/.local/share/icons"

  if [[ -d "$icon_dir/Bibata-Modern-Classic" ]]; then
    echo -e "${STY_GREEN}Bibata cursor theme already installed.${STY_RST}"
    return 0
  fi

  echo -e "${STY_BLUE}Installing Bibata cursor theme...${STY_RST}"

  local temp_dir="/tmp/bibata-cursors-$$"
  mkdir -p "$temp_dir" "$icon_dir"

  # Download Bibata Modern Classic (dark)
  if curl -fsSL -o "$temp_dir/bibata-classic.tar.xz" \
    "https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/Bibata-Modern-Classic.tar.xz"; then
    tar -xf "$temp_dir/bibata-classic.tar.xz" -C "$icon_dir"
    echo -e "${STY_GREEN}Bibata Modern Classic cursor installed.${STY_RST}"
  fi

  # Download Bibata Modern Ice (light)
  if curl -fsSL -o "$temp_dir/bibata-ice.tar.xz" \
    "https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/Bibata-Modern-Ice.tar.xz"; then
    tar -xf "$temp_dir/bibata-ice.tar.xz" -C "$icon_dir"
    echo -e "${STY_GREEN}Bibata Modern Ice cursor installed.${STY_RST}"
  fi

  rm -rf "$temp_dir"
}

#####################################################################################
# GitHub Binary Installation (All distros)
#####################################################################################

install-github-binary(){
  local name="$1"
  local repo="$2"
  local asset_pattern="$3"
  local install_path="${4:-/usr/local/bin}"

  if command -v "$name" &>/dev/null; then
    echo -e "${STY_GREEN}$name already installed.${STY_RST}"
    return 0
  fi

  echo -e "${STY_BLUE}Installing $name from GitHub...${STY_RST}"

  local download_url
  download_url=$(curl -s "https://api.github.com/repos/${repo}/releases/latest" | \
    jq -r ".assets[] | select(.name | test(\"${asset_pattern}\")) | .browser_download_url" | head -1)

  if [[ -z "$download_url" || "$download_url" == "null" ]]; then
    echo -e "${STY_YELLOW}Could not find $name binary, skipping...${STY_RST}"
    return 1
  fi

  local temp_dir="/tmp/${name}-install-$$"
  mkdir -p "$temp_dir"

  local filename=$(basename "$download_url")
  if curl -fsSL -o "$temp_dir/$filename" "$download_url"; then
    case "$filename" in
      *.tar.gz|*.tgz)
        tar -xzf "$temp_dir/$filename" -C "$temp_dir"
        local binary=$(find "$temp_dir" -type f -name "$name" -o -type f -executable | grep -v "\.tar" | head -1)
        [[ -n "$binary" ]] && sudo cp "$binary" "$install_path/$name"
        ;;
      *.zip)
        unzip -o "$temp_dir/$filename" -d "$temp_dir" >/dev/null
        local binary=$(find "$temp_dir" -type f -name "$name" | head -1)
        [[ -n "$binary" ]] && sudo cp "$binary" "$install_path/$name"
        ;;
      *.rpm)
        sudo dnf install -y "$temp_dir/$filename" 2>/dev/null || \
        sudo rpm -i "$temp_dir/$filename" 2>/dev/null
        ;;
      *.deb)
        sudo dpkg -i "$temp_dir/$filename" 2>/dev/null || \
        sudo apt-get install -f -y 2>/dev/null
        ;;
      *)
        # Direct binary
        sudo cp "$temp_dir/$filename" "$install_path/$name"
        ;;
    esac
    sudo chmod +x "$install_path/$name" 2>/dev/null
    echo -e "${STY_GREEN}$name installed successfully.${STY_RST}"
  else
    echo -e "${STY_YELLOW}Failed to download $name.${STY_RST}"
  fi

  rm -rf "$temp_dir"
}

install-cliphist(){
  install-github-binary "cliphist" "sentriz/cliphist" "linux-amd64$"
}

install-matugen(){
  install-github-binary "matugen" "InioX/matugen" "x86_64.*tar.gz"
}

install-starship(){
  if command -v starship &>/dev/null; then
    echo -e "${STY_GREEN}Starship already installed.${STY_RST}"
    return 0
  fi

  echo -e "${STY_BLUE}Installing Starship prompt...${STY_RST}"

  mkdir -p ~/.local/bin
  curl -sS https://starship.rs/install.sh | sh -s -- -y -b ~/.local/bin 2>/dev/null

  if command -v ~/.local/bin/starship &>/dev/null; then
    echo -e "${STY_GREEN}Starship installed.${STY_RST}"
  else
    echo -e "${STY_YELLOW}Could not install Starship.${STY_RST}"
  fi
}

install-eza(){
  if command -v eza &>/dev/null; then
    echo -e "${STY_GREEN}Eza already installed.${STY_RST}"
    return 0
  fi

  echo -e "${STY_BLUE}Installing Eza...${STY_RST}"

  mkdir -p ~/.local/bin
  if curl -fsSL -o /tmp/eza.tar.gz \
    'https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-musl.tar.gz'; then
    tar -xzf /tmp/eza.tar.gz -C ~/.local/bin
    chmod +x ~/.local/bin/eza
    echo -e "${STY_GREEN}Eza installed.${STY_RST}"
  else
    echo -e "${STY_YELLOW}Could not install Eza.${STY_RST}"
  fi

  rm -f /tmp/eza.tar.gz
}

install-uv(){
  if command -v uv &>/dev/null; then
    echo -e "${STY_GREEN}uv already installed.${STY_RST}"
    return 0
  fi

  echo -e "${STY_BLUE}Installing uv (Python package manager)...${STY_RST}"

  curl -LsSf https://astral.sh/uv/install.sh | sh 2>/dev/null || {
    echo -e "${STY_YELLOW}Could not install uv.${STY_RST}"
    return 1
  }

  echo -e "${STY_GREEN}uv installed.${STY_RST}"
}

#####################################################################################
# Config File Setup (All distros)
#####################################################################################

setup-gtk-config(){
  local cursor_theme="${1:-Bibata-Modern-Classic}"
  local icon_theme="${2:-WhiteSur-dark}"
  local gtk_theme="${3:-adw-gtk3-dark}"
  local font="${4:-Geist}"

  echo -e "${STY_BLUE}Setting up GTK configuration...${STY_RST}"

  # GTK 3
  mkdir -p ~/.config/gtk-3.0
  cat > ~/.config/gtk-3.0/settings.ini << EOF
[Settings]
gtk-theme-name=${gtk_theme}
gtk-icon-theme-name=${icon_theme}
gtk-font-name=${font}
gtk-cursor-theme-name=${cursor_theme}
gtk-cursor-theme-size=24
gtk-toolbar-style=3
gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
gtk-button-images=0
gtk-menu-images=0
gtk-enable-event-sounds=1
gtk-enable-input-feedback-sounds=0
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintslight
gtk-xft-rgba=rgb
gtk-application-prefer-dark-theme=1
gtk-decoration-layout=icon:minimize,maximize,close
gtk-enable-animations=true
gtk-primary-button-warps-slider=true
EOF

  # GTK 4
  mkdir -p ~/.config/gtk-4.0
  cp ~/.config/gtk-3.0/settings.ini ~/.config/gtk-4.0/settings.ini

  echo -e "${STY_GREEN}GTK configuration set.${STY_RST}"
}

setup-kvantum-config(){
  local theme="${1:-MaterialAdw}"

  echo -e "${STY_BLUE}Setting up Kvantum configuration...${STY_RST}"

  mkdir -p ~/.config/Kvantum
  cat > ~/.config/Kvantum/kvantum.kvconfig << EOF
[General]
theme=${theme}
EOF

  echo -e "${STY_GREEN}Kvantum configuration set.${STY_RST}"
}

setup-environment-config(){
  local cursor_theme="${1:-Bibata-Modern-Classic}"

  echo -e "${STY_BLUE}Setting up environment variables...${STY_RST}"

  mkdir -p ~/.config/environment.d
  cat > ~/.config/environment.d/inir.conf << EOF
# iNiR environment variables
XCURSOR_THEME=${cursor_theme}
XCURSOR_SIZE=24
QT_QPA_PLATFORM=wayland
QT_QPA_PLATFORMTHEME=kde
QT_STYLE_OVERRIDE=Darkly
GTK_THEME=adw-gtk3-dark
ELECTRON_OZONE_PLATFORM_HINT=auto
ILLOGICAL_IMPULSE_VIRTUAL_ENV=\$HOME/.local/state/quickshell/.venv
EOF

  echo -e "${STY_GREEN}Environment configuration set.${STY_RST}"
}

setup-foot-config(){
  echo -e "${STY_BLUE}Setting up Foot terminal configuration...${STY_RST}"

  mkdir -p ~/.config/foot

  # Only create if doesn't exist or is minimal
  if [[ ! -f ~/.config/foot/foot.ini ]] || [[ $(wc -l < ~/.config/foot/foot.ini) -lt 5 ]]; then
    cat > ~/.config/foot/foot.ini << 'EOF'
shell=fish
term=xterm-256color

title=foot

font=JetBrainsMono Nerd Font:size=11
letter-spacing=0
dpi-aware=no

pad=25x25

bold-text-in-bright=no

include=~/.config/foot/colors.ini

[scrollback]
lines=10000

[cursor]
style=beam
blink=no
beam-thickness=1.5

[key-bindings]
scrollback-up-page=Page_Up
scrollback-down-page=Page_Down
clipboard-copy=Control+c
clipboard-paste=Control+v
search-start=Control+f
font-increase=Control+plus Control+equal Control+KP_Add
font-decrease=Control+minus Control+KP_Subtract
font-reset=Control+0 Control+KP_0

[search-bindings]
cancel=Escape
find-prev=Shift+F3
find-next=F3 Control+G
delete-prev-word=Control+BackSpace

[text-bindings]
\x03=Control+Shift+c
EOF
  else
    # Existing config - ensure include line is present for theming
    if ! grep -q "include=.*colors.ini" ~/.config/foot/foot.ini; then
      echo -e "${STY_YELLOW}Adding colors.ini include to existing foot.ini...${STY_RST}"
      # Add include at the top of the file (before any sections)
      sed -i '1i include=~/.config/foot/colors.ini' ~/.config/foot/foot.ini
    fi
  fi

  echo -e "${STY_GREEN}Foot terminal configuration set.${STY_RST}"
}

setup-fish-config(){
  echo -e "${STY_BLUE}Setting up Fish shell configuration...${STY_RST}"

  mkdir -p ~/.config/fish

  # Only create if doesn't exist
  if [[ ! -f ~/.config/fish/config.fish ]]; then
    cat > ~/.config/fish/config.fish << 'EOF'
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
  fi

  echo -e "${STY_GREEN}Fish shell configuration set.${STY_RST}"
}

setup-bash-config(){
  echo -e "${STY_BLUE}Setting up Bash shell configuration...${STY_RST}"

  local bashrc="$HOME/.bashrc"
  local ii_config="$HOME/.config/ii/bashrc"

  mkdir -p ~/.config/ii

  # Create ii bash config
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

  # Add source line to .bashrc if not present
  if [[ -f "$bashrc" ]]; then
    if ! grep -q "source.*ii/bashrc" "$bashrc" && ! grep -q "\..*ii/bashrc" "$bashrc"; then
      echo -e "\n# ii shell integration\n[[ -f ~/.config/ii/bashrc ]] && source ~/.config/ii/bashrc" >> "$bashrc"
      echo -e "${STY_GREEN}Added ii integration to .bashrc${STY_RST}"
    else
      echo -e "${STY_CYAN}ii integration already in .bashrc${STY_RST}"
    fi
  else
    echo -e "# ii shell integration\n[[ -f ~/.config/ii/bashrc ]] && source ~/.config/ii/bashrc" > "$bashrc"
    echo -e "${STY_GREEN}Created .bashrc with ii integration${STY_RST}"
  fi

  echo -e "${STY_GREEN}Bash shell configuration set.${STY_RST}"
}

setup-zsh-config(){
  echo -e "${STY_BLUE}Setting up Zsh shell configuration...${STY_RST}"

  local zshrc="$HOME/.zshrc"
  local ii_config="$HOME/.config/ii/zshrc"

  mkdir -p ~/.config/ii

  # Create ii zsh config
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

  # Add source line to .zshrc if not present
  if [[ -f "$zshrc" ]]; then
    if ! grep -q "source.*ii/zshrc" "$zshrc" && ! grep -q "\..*ii/zshrc" "$zshrc"; then
      echo -e "\n# ii shell integration\n[[ -f ~/.config/ii/zshrc ]] && source ~/.config/ii/zshrc" >> "$zshrc"
      echo -e "${STY_GREEN}Added ii integration to .zshrc${STY_RST}"
    else
      echo -e "${STY_CYAN}ii integration already in .zshrc${STY_RST}"
    fi
  else
    # Don't create .zshrc if it doesn't exist - user might not use zsh
    echo -e "${STY_CYAN}No .zshrc found, skipping zsh setup${STY_RST}"
  fi

  echo -e "${STY_GREEN}Zsh shell configuration set.${STY_RST}"
}

#####################################################################################
# Distro-specific Polkit Agent Detection
#####################################################################################

get-polkit-agent(){
  # Returns the path to the polkit authentication agent for the current distro
  local agents=(
    "/usr/libexec/kf6/polkit-kde-authentication-agent-1"
    "/usr/lib/polkit-kde-authentication-agent-1"
    "/usr/libexec/polkit-kde-authentication-agent-1"
    "/usr/lib/mate-polkit/polkit-mate-authentication-agent-1"
    "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1"
    "/usr/libexec/polkit-gnome-authentication-agent-1"
    "/usr/lib/lxpolkit/lxpolkit"
  )

  for agent in "${agents[@]}"; do
    if [[ -x "$agent" ]]; then
      echo "$agent"
      return 0
    fi
  done

  # Not found
  echo ""
  return 1
}

#####################################################################################
# All-in-one Setup Functions
#####################################################################################

install-all-fonts(){
  echo -e "${STY_CYAN}Installing all required fonts...${STY_RST}"

  install-material-symbols-rounded
  install-material-symbols-outlined
  install-jetbrains-mono-nerd
  install-geist-font
  install-space-grotesk
  install-rubik-font

  # Refresh font cache
  fc-cache -f ~/.local/share/fonts 2>/dev/null

  echo -e "${STY_GREEN}All fonts installed.${STY_RST}"
}

install-all-themes(){
  echo -e "${STY_CYAN}Installing all themes...${STY_RST}"

  install-whitesur-icons
  install-mactahoe-icons
  install-bibata-cursors

  echo -e "${STY_GREEN}All themes installed.${STY_RST}"
}

install-all-tools(){
  echo -e "${STY_CYAN}Installing CLI tools...${STY_RST}"

  install-starship
  install-eza
  install-uv
  install-cliphist
  install-matugen

  echo -e "${STY_GREEN}All tools installed.${STY_RST}"
}

setup-all-configs(){
  echo -e "${STY_CYAN}Setting up all configurations...${STY_RST}"

  setup-gtk-config
  setup-kvantum-config
  setup-environment-config
  setup-foot-config
  setup-fish-config
  setup-bash-config
  setup-zsh-config

  echo -e "${STY_GREEN}All configurations set.${STY_RST}"
}
