# Package installation functions for iNiR
# This is NOT a script for execution, but for loading functions
# Shared across all distros

# shellcheck shell=bash

#####################################################################################
# Privilege escalation helper with environment detection
#####################################################################################

# Detect if we're in a graphical environment
_is_graphical_env() {
  [[ -n "${DISPLAY}" ]] || [[ -n "${WAYLAND_DISPLAY}" ]] || [[ -n "${XDG_SESSION_TYPE}" && "${XDG_SESSION_TYPE}" == "wayland" || "${XDG_SESSION_TYPE}" == "x11" ]]
}

# Detect available privilege escalation methods
_detect_privilege_method() {
  local method=""
  
  # Check for graphical methods first (polkit-based)
  if command -v pkexec &>/dev/null && [[ -n "${DBUS_SESSION_BUS_ADDRESS}" ]]; then
    # Test if polkit can authenticate
    if pkexec --version &>/dev/null; then
      method="pkexec"
    fi
  fi
  
  # Check for elevate (available in some graphical environments)
  if [[ -z "$method" ]] && command -v elevate &>/dev/null; then
    method="elevate"
  fi
  
  # Check for sudo
  if [[ -z "$method" ]] && command -v sudo &>/dev/null; then
    # Test if user has sudo permissions (non-interactive)
    if sudo -n true 2>/dev/null; then
      method="sudo"
    fi
  fi
  
  # Check for su (requires root password, not sudo password)
  if [[ -z "$method" ]] && command -v su &>/dev/null && [[ -r /etc/shadow || $(id -u) -eq 0 ]]; then
    method="su"
  fi
  
  echo "$method"
}

# Show environment-specific instructions
_show_privilege_instructions() {
  local reason="$1"
  
  echo -e "${STY_RED}Error: $reason${STY_RST}" >&2
  echo "" >&2
  
  if _is_graphical_env; then
    # Graphical environment detected
    echo -e "${STY_YELLOW}Detected: Graphical environment (Wayland/X11)${STY_RST}" >&2
    echo "" >&2
    echo -e "${STY_CYAN}Recommended solutions:${STY_RST}" >&2
    echo "  1. Use a polkit authentication agent (recommended for Wayland):" >&2
    echo "     - Install: polkit-kde-authentication-agent-1 or polkit-gnome" >&2
    echo "     - It should auto-launch in your graphical session" >&2
    echo "" >&2
    echo "  2. Configure sudo with passwordless NOPASSWD (quick fix):" >&2
    echo "     sudo visudo" >&2
    echo "     # Add line: $(whoami) ALL=(ALL) NOPASSWD: ALL" >&2
    echo "" >&2
  else
    # TTY/Console environment
    echo -e "${STY_YELLOW}Detected: Console/TTY (no graphical session)${STY_RST}" >&2
    echo "" >&2
    echo -e "${STY_CYAN}Recommended solutions:${STY_RST}" >&2
    echo "  1. Switch to a virtual terminal (Ctrl+Alt+F2-F6) and login as root" >&2
    echo "" >&2
    echo "  2. Use 'su' with root password (set during Arch installation):" >&2
    echo "     su -c 'pacman -S sudo'" >&2
    echo "     # Then configure visudo as below" >&2
    echo "" >&2
    echo "  3. Boot from Arch ISO and chroot:" >&2
    echo "     mount /dev/sdX1 /mnt" >&2
    echo "     arch-chroot /mnt" >&2
    echo "     pacman -S sudo" >&2
    echo "" >&2
  fi
  
  # Common configuration instructions
  echo -e "${STY_CYAN}After installing sudo, configure it:${STY_RST}" >&2
  echo "  sudo visudo" >&2
  echo "  # Option A: Allow wheel group (recommended)" >&2
  echo "  %wheel ALL=(ALL) ALL" >&2
  echo "" >&2
  echo "  # Option B: Allow specific user" >&2
  echo "  $(whoami) ALL=(ALL) ALL" >&2
  echo "" >&2
  echo "  # Option C: Passwordless (not recommended for daily use)" >&2
  echo "  $(whoami) ALL=(ALL) NOPASSWD: ALL" >&2
}

# Use elevate() when USE_ELEVATE is set (graphical mode), otherwise use sudo
pkg_sudo() {
  # Priority 1: USE_ELEVATE environment variable (for custom elevation)
  if [[ "${USE_ELEVATE:-false}" == "true" ]] && type elevate &>/dev/null; then
    elevate "$@"
    return $?
  fi
  
  # Priority 2: Try sudo first (standard method)
  if command -v sudo &>/dev/null; then
    # Try non-interactive first (already has cached credentials)
    if sudo -n true 2>/dev/null; then
      sudo "$@"
      return $?
    fi
    # Try interactive sudo - it will prompt for password if needed
    sudo "$@"
    return $?
  fi
  
  # Priority 3: Fallback to pkexec (polkit) - works in graphical environments
  # without requiring sudo configuration
  if command -v pkexec &>/dev/null; then
    # In graphical environments, polkit usually works
    # Don't test with -n as it may not work - just try it
    if pkexec --version &>/dev/null; then
      # Check if we have D-Bus session (needed for polkit in most cases)
      # OR if we're in a graphical environment
      if [[ -n "${DBUS_SESSION_BUS_ADDRESS}" ]] || _is_graphical_env; then
        pkexec "$@"
        return $?
      fi
    fi
  fi
  
  # Priority 4: Fallback to su (for TTY/console environments)
  # su requires root password (set during Arch installation)
  if command -v su &>/dev/null; then
    # Only use su in non-graphical environments (no D-Bus, no XDG)
    if ! _is_graphical_env && [[ -z "${DBUS_SESSION_BUS_ADDRESS}" ]]; then
      # Try su with root password - this will prompt
      # The "-" makes it a login shell (loads profile)
      su - -c "$*"
      return $?
    fi
  fi
  
  # Priority 5: Fallback to elevate if not already tried
  if type elevate &>/dev/null; then
    elevate "$@"
    return $?
  fi
  
  # No privilege escalation method available
  _show_privilege_instructions "No privilege escalation method available (tried: sudo, pkexec, elevate)"
  return 1
}

#####################################################################################
# AUR Helpers (Arch-specific)
#####################################################################################

install-yay(){
  tui_info "Installing yay (AUR helper)..."

  # Clean up previous attempts
  rm -rf /tmp/buildyay

  # Sync databases and install base-devel
  if ! x pkg_sudo pacman -Sy --needed --noconfirm base-devel git; then
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
  tui_info "Installing paru (AUR helper)..."
  x pkg_sudo pacman -S --needed --noconfirm base-devel git
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

  log_warning "No AUR helper found — installing yay..."
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
  tui_info "Setting up Python virtual environment..."

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

  log_info "Downloading $font_name..."
  if curl -fsSL -o "$font_dir/${font_name}.ttf" "$url" 2>/dev/null; then
    fc-cache -f "$font_dir" 2>/dev/null
    log_success "$font_name installed"
    return 0
  else
    log_warning "Could not download $font_name"
    return 1
  fi
}

install-material-symbols-rounded(){
  if fc-list | grep -qi "Material Symbols Rounded"; then
    log_success "Material Symbols Rounded already installed"
    return 0
  fi

  install-font-from-url "MaterialSymbolsRounded" \
    "https://raw.githubusercontent.com/google/material-design-icons/master/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf"
}

install-material-symbols-outlined(){
  if fc-list | grep -qi "Material Symbols Outlined"; then
    log_success "Material Symbols Outlined already installed"
    return 0
  fi

  install-font-from-url "MaterialSymbolsOutlined" \
    "https://raw.githubusercontent.com/google/material-design-icons/master/variablefont/MaterialSymbolsOutlined%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf"
}

install-jetbrains-mono-nerd(){
  if fc-list | grep -qi "JetBrainsMono Nerd"; then
    log_success "JetBrains Mono Nerd Font already installed"
    return 0
  fi

  log_info "Downloading JetBrains Mono Nerd Font..."

  local font_dir="${HOME}/.local/share/fonts"
  local temp_dir="/tmp/nerdfonts-$$"
  mkdir -p "$font_dir" "$temp_dir"

  if curl -fsSL -o "$temp_dir/JetBrainsMono.zip" \
    "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"; then
    unzip -o "$temp_dir/JetBrainsMono.zip" -d "$font_dir" >/dev/null 2>&1
    fc-cache -f "$font_dir"
    log_success "JetBrains Mono Nerd Font installed"
  else
    log_warning "Could not download JetBrains Mono Nerd Font"
  fi

  rm -rf "$temp_dir"
}

install-geist-font(){
  if fc-list | grep -qi "Geist"; then
    log_success "Geist font already installed"
    return 0
  fi

  log_info "Downloading Geist font..."

  local font_dir="${HOME}/.local/share/fonts"
  local temp_dir="/tmp/geist-font-$$"
  mkdir -p "$font_dir" "$temp_dir"

  if curl -fsSL -o "$temp_dir/geist.zip" \
    "https://github.com/vercel/geist-font/releases/latest/download/Geist.zip"; then
    unzip -o "$temp_dir/geist.zip" -d "$temp_dir" >/dev/null 2>&1
    find "$temp_dir" -name "*.ttf" -exec cp {} "$font_dir/" \;
    fc-cache -f "$font_dir"
    log_success "Geist font installed"
  else
    log_warning "Could not download Geist font"
  fi

  rm -rf "$temp_dir"
}

install-space-grotesk(){
  if fc-list | grep -qi "Space Grotesk"; then
    log_success "Space Grotesk already installed"
    return 0
  fi

  install-font-from-url "SpaceGrotesk" \
    "https://github.com/floriankarsten/space-grotesk/raw/master/fonts/ttf/SpaceGrotesk%5Bwght%5D.ttf"
}

install-rubik-font(){
  if fc-list | grep -qi "Rubik"; then
    log_success "Rubik font already installed"
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
    log_success "WhiteSur icon theme already installed"
    return 0
  fi

  log_info "Installing WhiteSur icon theme..."

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
    log_success "WhiteSur icon theme installed"
  else
    log_warning "Could not download WhiteSur icon theme"
  fi

  rm -rf "$temp_dir"
}

install-mactahoe-icons(){
  local icon_dir="${HOME}/.local/share/icons"

  if [[ -d "$icon_dir/MacTahoe" ]]; then
    log_success "MacTahoe icon theme already installed"
    return 0
  fi

  log_info "Installing MacTahoe icon theme..."

  local temp_dir="/tmp/mactahoe-icons-$$"
  mkdir -p "$temp_dir" "$icon_dir"

  if curl -fsSL -o "$temp_dir/mactahoe.tar.gz" \
    "https://github.com/vinceliuice/MacTahoe-icon-theme/archive/refs/heads/master.tar.gz"; then
    tar -xzf "$temp_dir/mactahoe.tar.gz" -C "$temp_dir"
    cd "$temp_dir/MacTahoe-icon-theme-master" 2>/dev/null || cd "$temp_dir/MacTahoe-icon-theme-main"
    ./install.sh -d "$icon_dir" >/dev/null 2>&1
    cd - >/dev/null
    log_success "MacTahoe icon theme installed"
  else
    log_warning "Could not download MacTahoe icon theme"
  fi

  rm -rf "$temp_dir"
}

#####################################################################################
# Cursor Theme Installation (All distros)
#####################################################################################

install-bibata-cursors(){
  local icon_dir="${HOME}/.local/share/icons"

  if [[ -d "$icon_dir/Bibata-Modern-Classic" ]]; then
    log_success "Bibata cursor theme already installed"
    return 0
  fi

  log_info "Installing Bibata cursor theme..."

  local temp_dir="/tmp/bibata-cursors-$$"
  mkdir -p "$temp_dir" "$icon_dir"

  # Download Bibata Modern Classic (dark)
  if curl -fsSL -o "$temp_dir/bibata-classic.tar.xz" \
    "https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/Bibata-Modern-Classic.tar.xz"; then
    tar -xf "$temp_dir/bibata-classic.tar.xz" -C "$icon_dir"
    log_success "Bibata Modern Classic cursor installed"
  fi

  # Download Bibata Modern Ice (light)
  if curl -fsSL -o "$temp_dir/bibata-ice.tar.xz" \
    "https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/Bibata-Modern-Ice.tar.xz"; then
    tar -xf "$temp_dir/bibata-ice.tar.xz" -C "$icon_dir"
    log_success "Bibata Modern Ice cursor installed"
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
    log_success "$name already installed"
    return 0
  fi

  log_info "Installing $name from GitHub..."

  local download_url
  download_url=$(curl -s "https://api.github.com/repos/${repo}/releases/latest" | \
    jq -r ".assets[] | select(.name | test(\"${asset_pattern}\")) | .browser_download_url" | head -1)

  if [[ -z "$download_url" || "$download_url" == "null" ]]; then
    log_warning "Could not find $name binary, skipping"
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
        [[ -n "$binary" ]] && pkg_sudo cp "$binary" "$install_path/$name"
        ;;
      *.zip)
        unzip -o "$temp_dir/$filename" -d "$temp_dir" >/dev/null
        local binary=$(find "$temp_dir" -type f -name "$name" | head -1)
        [[ -n "$binary" ]] && pkg_sudo cp "$binary" "$install_path/$name"
        ;;
      *.rpm)
        pkg_sudo dnf install -y "$temp_dir/$filename" 2>/dev/null || \
        pkg_sudo rpm -i "$temp_dir/$filename" 2>/dev/null
        ;;
      *.deb)
        pkg_sudo dpkg -i "$temp_dir/$filename" 2>/dev/null || \
        pkg_sudo apt-get install -f -y 2>/dev/null
        ;;
      *)
        # Direct binary
        pkg_sudo cp "$temp_dir/$filename" "$install_path/$name"
        ;;
    esac
    pkg_sudo chmod +x "$install_path/$name" 2>/dev/null
    log_success "$name installed"
  else
    log_warning "Failed to download $name"
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
    log_success "Starship already installed"
    return 0
  fi

  log_info "Installing Starship prompt..."

  mkdir -p ~/.local/bin
  curl -sS https://starship.rs/install.sh | sh -s -- -y -b ~/.local/bin 2>/dev/null

  if command -v ~/.local/bin/starship &>/dev/null; then
    log_success "Starship installed"
  else
    log_warning "Could not install Starship"
  fi
}

install-eza(){
  if command -v eza &>/dev/null; then
    log_success "Eza already installed"
    return 0
  fi

  log_info "Installing Eza..."

  mkdir -p ~/.local/bin
  if curl -fsSL -o /tmp/eza.tar.gz \
    'https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-musl.tar.gz'; then
    tar -xzf /tmp/eza.tar.gz -C ~/.local/bin
    chmod +x ~/.local/bin/eza
    log_success "Eza installed"
  else
    log_warning "Could not install Eza"
  fi

  rm -f /tmp/eza.tar.gz
}

install-uv(){
  if command -v uv &>/dev/null; then
    log_success "uv already installed"
    return 0
  fi

  log_info "Installing uv (Python package manager)..."

  curl -LsSf https://astral.sh/uv/install.sh | sh 2>/dev/null || {
    log_warning "Could not install uv"
    return 1
  }

  log_success "uv installed"
}

#####################################################################################
# Config File Setup (All distros)
#####################################################################################

setup-gtk-config(){
  local cursor_theme="${1:-Bibata-Modern-Classic}"
  local icon_theme="${2:-WhiteSur-dark}"
  local gtk_theme="${3:-adw-gtk3-dark}"
  local font="${4:-Geist}"

  log_info "Setting up GTK configuration..."

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

  log_success "GTK configuration set"
}

setup-kvantum-config(){
  local theme="${1:-MaterialAdw}"

  log_info "Setting up Kvantum configuration..."

  mkdir -p ~/.config/Kvantum
  cat > ~/.config/Kvantum/kvantum.kvconfig << EOF
[General]
theme=${theme}
EOF

  log_success "Kvantum configuration set"
}

setup-environment-config(){
  local cursor_theme="${1:-Bibata-Modern-Classic}"

  log_info "Setting up environment variables..."

  # Detect Qt platform theme: use kde if Plasma is installed, qt6ct otherwise
  local qt_theme="qt6ct"
  if pacman -Q plasma-desktop &>/dev/null 2>&1 || pacman -Q plasma-workspace &>/dev/null 2>&1 || \
     dpkg -l plasma-desktop 2>/dev/null | grep -q '^ii' || \
     rpm -q plasma-desktop &>/dev/null 2>&1; then
    qt_theme="kde"
  fi

  mkdir -p ~/.config/environment.d
  cat > ~/.config/environment.d/inir.conf << EOF
# iNiR environment variables
XCURSOR_THEME=${cursor_theme}
XCURSOR_SIZE=24
QT_QPA_PLATFORM=wayland
QT_QPA_PLATFORMTHEME=${qt_theme}
QT_STYLE_OVERRIDE=Darkly
GTK_THEME=adw-gtk3-dark
ELECTRON_OZONE_PLATFORM_HINT=auto
ILLOGICAL_IMPULSE_VIRTUAL_ENV=\$HOME/.local/state/quickshell/.venv
EOF

  log_success "Environment configuration set"
}

setup-foot-config(){
  log_info "Setting up Foot terminal configuration..."

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

include=~/.config/foot/inir-colors.ini

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
    if ! grep -q "include=.*inir-colors\.ini" ~/.config/foot/foot.ini; then
      log_info "Adding inir-colors.ini include to existing foot.ini..."
      sed -i '1i include=~/.config/foot/inir-colors.ini' ~/.config/foot/foot.ini
    fi
    # Remove stale colors.ini include if present (legacy matugen terminal template)
    sed -i '/^include=.*\/colors\.ini$/d' ~/.config/foot/foot.ini
  fi

  log_success "Foot terminal configuration set"
}

setup-kitty-config(){
  log_info "Setting up Kitty terminal configuration..."

  mkdir -p ~/.config/kitty

  # Only create if doesn't exist or is minimal
  if [[ ! -f ~/.config/kitty/kitty.conf ]] || [[ $(wc -l < ~/.config/kitty/kitty.conf) -lt 5 ]]; then
    cat > ~/.config/kitty/kitty.conf << 'EOF'
# iNiR wallpaper theming - colors from quickshell
include current-theme.conf

# Font configuration
font_family      JetBrainsMono Nerd Font
font_size        11.0

# Cursor
cursor_shape beam
cursor_beam_thickness 1.5
cursor_blink_interval 0

# Scrollback
scrollback_lines 10000

# Terminal bell
enable_audio_bell no
visual_bell_duration 0.0

# Window
window_padding_width 25
hide_window_decorations yes
confirm_os_window_close 0

# Transparency and blur (Wayland)
background_opacity 0.85
background_blur 32

# Remote control for live color reload
listen_on unix:/tmp/kitty-socket
allow_remote_control socket-only

# Tab bar
tab_bar_style powerline

# Performance
repaint_delay 10
input_delay 3
sync_to_monitor yes

# Keyboard shortcuts
map ctrl+c copy_or_interrupt
map ctrl+v paste_from_clipboard
map ctrl+shift+c copy_to_clipboard
map ctrl+shift+v paste_from_clipboard
map ctrl+plus change_font_size all +1.0
map ctrl+minus change_font_size all -1.0
map ctrl+0 change_font_size all 0
EOF
  else
    # Existing config - ensure include line is present for theming
    if ! grep -q "include.*current-theme.conf" ~/.config/kitty/kitty.conf; then
      log_info "Adding current-theme.conf include to kitty.conf..."
      sed -i '1i include current-theme.conf' ~/.config/kitty/kitty.conf
    fi
    # Add transparency if not present
    if ! grep -q "background_opacity" ~/.config/kitty/kitty.conf; then
      log_info "Adding transparency settings to kitty.conf..."
      printf '\n# Transparency and blur (Wayland)\nbackground_opacity 0.85\nbackground_blur 32\n' >> ~/.config/kitty/kitty.conf
    fi
    # Add remote control socket if not present
    if ! grep -q "listen_on" ~/.config/kitty/kitty.conf; then
      log_info "Adding remote control socket to kitty.conf..."
      printf '\n# Remote control for live color reload\nlisten_on unix:/tmp/kitty-socket\nallow_remote_control socket-only\n' >> ~/.config/kitty/kitty.conf
    fi
  fi

  log_success "Kitty terminal configuration set"
}

setup-fish-config(){
  log_info "Setting up Fish shell configuration..."

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

  log_success "Fish shell configuration set"
}

setup-bash-config(){
  log_info "Setting up Bash shell configuration..."

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
      log_success "Added ii integration to .bashrc"
    else
      log_info "ii integration already in .bashrc"
    fi
  else
    echo -e "# ii shell integration\n[[ -f ~/.config/ii/bashrc ]] && source ~/.config/ii/bashrc" > "$bashrc"
    log_success "Created .bashrc with ii integration"
  fi

  log_success "Bash shell configuration set"
}

setup-zsh-config(){
  log_info "Setting up Zsh shell configuration..."

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
      log_success "Added ii integration to .zshrc"
    else
      log_info "ii integration already in .zshrc"
    fi
  else
    # Don't create .zshrc if it doesn't exist - user might not use zsh
    log_info "No .zshrc found, skipping zsh setup"
  fi

  log_success "Zsh shell configuration set"
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
  tui_info "Installing all required fonts..."

  install-material-symbols-rounded
  install-material-symbols-outlined
  install-jetbrains-mono-nerd
  install-geist-font
  install-space-grotesk
  install-rubik-font

  # Refresh font cache
  fc-cache -f ~/.local/share/fonts 2>/dev/null

  log_success "All fonts installed"
}

install-all-themes(){
  tui_info "Installing all themes..."

  install-whitesur-icons
  install-mactahoe-icons
  install-bibata-cursors

  log_success "All themes installed"
}

install-all-tools(){
  tui_info "Installing CLI tools..."

  install-starship
  install-eza
  install-uv
  install-cliphist
  install-matugen

  log_success "All tools installed"
}

setup-all-configs(){
  tui_info "Setting up all configurations..."

  setup-gtk-config
  setup-kvantum-config
  setup-environment-config
  setup-kitty-config
  setup-foot-config
  setup-fish-config
  setup-bash-config
  setup-zsh-config

  log_success "All configurations set"
}
