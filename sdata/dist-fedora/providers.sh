# shellcheck shell=bash
# Fedora providers: what sdata/deps.toml calls `build = "<recipe>"` for Fedora, as provider_<recipe>, with the
# helpers they use. Definitions only, no top-level code: install-deps.sh sources it, and so can the inir binary.
dnf_pkg_available() {
  local pkg="$1"
  dnf -q list --available "$pkg" &>/dev/null || dnf -q list --installed "$pkg" &>/dev/null
}

# What the providers read about this system. install-deps.sh runs it first, and `setup provider` too.
fedora_detect() {
  FEDORA_VERSION=$(rpm -E %fedora)
  ARCH=$(uname -m)
  case "$ARCH" in
    x86_64) ARCH_SUFFIX="amd64" ;;
    aarch64) ARCH_SUFFIX="arm64" ;;
    *) ARCH_SUFFIX="$ARCH" ;;
  esac
  installflags=""
  ${ask:-true} || installflags="-y"
}

# Batch check which packages are available from configured repos.
# Populates the arrays passed as $1 (available) and $2 (missing).
dnf_pkgs_available_batch() {
  local -n _avail=$1 _miss=$2
  shift 2
  local -a pkgs=("$@")
  local available_file
  available_file="$(mktemp)"

  # Use repoquery to get just package names — handles missing packages gracefully.
  # --qf '%{name}\n': dnf5 does not end each entry with a newline by itself.
  dnf -q repoquery --qf '%{name}\n' --available "${pkgs[@]}" 2>/dev/null | sort -u > "$available_file" || true
  # Also include already-installed packages (they're definitely "available").
  dnf -q repoquery --qf '%{name}\n' --installed "${pkgs[@]}" 2>/dev/null | sort -u >> "$available_file" || true
  sort -u -o "$available_file" "$available_file"

  for pkg in "${pkgs[@]}"; do
    if grep -qx "$pkg" "$available_file"; then
      _avail+=("$pkg")
    else
      _miss+=("$pkg")
    fi
  done
  rm -f "$available_file"
}

version_at_least() {
  local have="$1"
  local need="$2"
  [[ -n "$have" ]] || return 1
  [[ "$(printf '%s\n%s\n' "$need" "$have" | sort -V | head -1)" == "$need" ]]
}

fedora_quickshell_compatible() {
  # iNiR imports Quickshell.Networking and uses 0.3-era pragmas, so Fedora's
  # current 0.2.1 package is not sufficient even though the package name exists.
  local version=""
  if command -v qs &>/dev/null; then
    version="$(qs --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
    version_at_least "$version" "0.3.0" && return 0
  fi

  version="$(dnf -q repoquery --latest-limit 1 --qf '%{version}' quickshell 2>/dev/null \
    | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
  if [[ -z "$version" ]]; then
    version="$(dnf -q info quickshell 2>/dev/null \
      | awk -F: '/^Version[[:space:]]*:/ {gsub(/[[:space:]]/, "", $2); print $2; exit}' \
      | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
  fi
  version_at_least "$version" "0.3.0"
}

ensure_copr_support() {
  if dnf copr --help &>/dev/null; then
    return 0
  fi
  log_info "Installing Fedora COPR support for compatibility packages..."
  sudo dnf install -y dnf-plugins-core >/dev/null 2>&1 || {
    log_warning "COPR support is unavailable; source/direct fallbacks will be used"
    return 1
  }
}

ensure_fedora_rust_toolchain() {
  if command -v cargo &>/dev/null && command -v rustc &>/dev/null; then
    return 0
  fi
  log_info "Installing Rust toolchain for Fedora source fallbacks..."
  sudo dnf install -y rust cargo >/dev/null 2>&1
}

install_awww_fedora() {
  if command -v awww &>/dev/null && command -v awww-daemon &>/dev/null; then
    return 0
  fi

  # Fedora has no official awww package, but scottames/awww publishes a focused
  # RPM containing both awww and awww-daemon for current Fedora releases. Prefer
  # the prebuilt package to making every user compile Rust dependencies locally.
  # The COPR explicitly describes itself as personal/unofficial, so keep the
  # upstream Codeberg build below as a real fallback rather than a hard dependency.
  if ensure_copr_support; then
    if ! dnf copr list --enabled 2>/dev/null | grep -q 'scottames/awww'; then
      sudo dnf copr enable -y scottames/awww >/dev/null 2>&1 || true
    fi
    sudo dnf install -y awww >/dev/null 2>&1 || true
  fi
  if command -v awww &>/dev/null && command -v awww-daemon &>/dev/null; then
    return 0
  fi

  ensure_fedora_rust_toolchain || return 1
  sudo dnf install -y lz4-devel libxkbcommon-devel wayland-devel wayland-protocols-devel >/dev/null 2>&1 || return 1

  local temp_root
  temp_root="$(mktemp -d /tmp/inir-awww.XXXXXX)" || return 1
  if cargo install --root "$temp_root" --git https://codeberg.org/LGFae/awww.git awww >/dev/null 2>&1 \
      && [[ -x "$temp_root/bin/awww" && -x "$temp_root/bin/awww-daemon" ]]; then
    sudo install -m 0755 "$temp_root/bin/awww" "$temp_root/bin/awww-daemon" /usr/local/bin/
  fi
  rm -rf "$temp_root"
  command -v awww &>/dev/null && command -v awww-daemon &>/dev/null
}

install_gowall_fedora() {
  command -v gowall &>/dev/null && return 0

  # Upstream's documented Fedora path is the achno/gowall COPR. Keep a source
  # fallback for derivatives or networks where that repository is unavailable.
  if ensure_copr_support; then
    if ! dnf copr list --enabled 2>/dev/null | grep -q 'achno/gowall'; then
      sudo dnf copr enable -y achno/gowall >/dev/null 2>&1 || true
    fi
    sudo dnf install -y gowall >/dev/null 2>&1 || true
  fi
  command -v gowall &>/dev/null && return 0

  sudo dnf install -y golang >/dev/null 2>&1 || return 1
  local build_dir
  build_dir="$(mktemp -d /tmp/inir-gowall.XXXXXX)" || return 1
  if git clone --depth 1 https://github.com/Achno/gowall.git "$build_dir/src" >/dev/null 2>&1 \
      && (cd "$build_dir/src" && go build -o "$build_dir/gowall" . >/dev/null 2>&1); then
    sudo install -m 0755 "$build_dir/gowall" /usr/local/bin/gowall
  fi
  rm -rf "$build_dir"
  command -v gowall &>/dev/null
}

install_missioncenter_fedora() {
  command -v missioncenter &>/dev/null && return 0
  sudo dnf install -y flatpak >/dev/null 2>&1 || return 1
  flatpak remote-add --if-not-exists --user flathub https://flathub.org/repo/flathub.flatpakrepo >/dev/null 2>&1 || true
  flatpak install -y --user flathub io.missioncenter.MissionCenter >/dev/null 2>&1 || return 1

  local wrapper
  wrapper="$(mktemp /tmp/inir-missioncenter.XXXXXX)" || return 1
  printf '%s\n' '#!/bin/sh' 'exec flatpak run io.missioncenter.MissionCenter "$@"' > "$wrapper"
  sudo install -m 0755 "$wrapper" /usr/local/bin/missioncenter
  rm -f "$wrapper"
  command -v missioncenter &>/dev/null
}

install_hyprpicker_fedora() {
  command -v hyprpicker &>/dev/null && return 0
  if dnf_pkg_available hyprpicker; then
    sudo dnf install -y hyprpicker >/dev/null 2>&1 && return 0
  fi
  # hyprpicker was retired from current Fedora releases, but its build-time
  # libraries (hyprutils + hyprwayland-scanner) are official packages. Compile
  # only the tiny picker itself; this avoids enabling a broad Hyprland COPR that
  # could replace unrelated system packages.
  tui_info "Installing hyprpicker fallback..."
  sudo dnf install -y cmake gcc-c++ ninja-build cairo-devel libjpeg-turbo-devel pango-devel \
    wayland-devel wayland-protocols-devel libxkbcommon-devel hyprutils-devel hyprwayland-scanner-devel \
    >/dev/null 2>&1 || { log_warning "Could not install hyprpicker build dependencies"; return 1; }
  local build_dir
  build_dir="$(mktemp -d /tmp/inir-hyprpicker.XXXXXX)" || return 1
  if ! git clone --depth 1 --branch v0.4.7 https://github.com/hyprwm/hyprpicker.git "$build_dir/src" 2>/dev/null; then
    rm -rf "$build_dir"
    log_warning "Could not reach hyprpicker upstream; install the Fedora-compatible package manually"
    return 1
  fi
  if cmake -S "$build_dir/src" -B "$build_dir/build" -G Ninja -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr >/dev/null 2>&1 \
      && cmake --build "$build_dir/build" >/dev/null 2>&1 \
      && sudo cmake --install "$build_dir/build" >/dev/null 2>&1; then
    log_success "hyprpicker installed from upstream source"
  else
    log_warning "hyprpicker source build failed"
  fi
  rm -rf "$build_dir"
  command -v hyprpicker &>/dev/null
}

install_songrec_fedora() {
  command -v songrec &>/dev/null && return 0
  ensure_fedora_rust_toolchain || return 1
  # clang-devel: libspa-sys runs bindgen, which needs libclang.
  sudo dnf install -y \
    alsa-lib-devel pulseaudio-libs-devel pipewire-devel openssl-devel dbus-devel \
    pkgconf-pkg-config glib2-devel gtk4-devel libsoup3-devel libadwaita-devel clang-devel \
    >/dev/null 2>&1 || return 1

  local temp_root
  temp_root="$(mktemp -d /tmp/inir-songrec.XXXXXX)" || return 1
  if cargo install --root "$temp_root" songrec --no-default-features -F gui,ffmpeg,pulse,mpris >/dev/null 2>&1 \
      && [[ -x "$temp_root/bin/songrec" ]]; then
    sudo install -m 0755 "$temp_root/bin/songrec" /usr/local/bin/songrec
  fi
  rm -rf "$temp_root"
  command -v songrec &>/dev/null
}

# Helper function to download and install from GitHub
install_github_binary() {
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
  download_url=$(curl -s --connect-timeout 10 --max-time 30 "https://api.github.com/repos/${repo}/releases/latest" | \
    jq -r ".assets[] | select(.name | test(\"${asset_pattern}\")) | .browser_download_url" | head -1)
  
  if [[ -z "$download_url" || "$download_url" == "null" ]]; then
    log_warning "Could not find $name binary, skipping"
    return 1
  fi
  
  local temp_dir="/tmp/${name}-install-$$"
  mkdir -p "$temp_dir"
  
  local filename=$(basename "$download_url")
  if curl -fsSL --connect-timeout 10 --speed-limit 1024 --speed-time 30 -o "$temp_dir/$filename" "$download_url"; then
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
        sudo dnf install -y "$temp_dir/$filename"
        ;;
      *)
        # Direct binary
        sudo cp "$temp_dir/$filename" "$install_path/$name"
        ;;
    esac
    sudo chmod +x "$install_path/$name" 2>/dev/null
    log_success "$name installed"
  else
    log_warning "Failed to download $name"
  fi
  
  rm -rf "$temp_dir"
}

# deps.toml recipe names.
provider_awww() { install_awww_fedora "$@"; }
provider_gowall() { install_gowall_fedora "$@"; }
provider_missioncenter() { install_missioncenter_fedora "$@"; }
provider_hyprpicker() { install_hyprpicker_fedora "$@"; }
provider_songrec() { install_songrec_fedora "$@"; }

provider_cliphist() {
# Fedora 43 did not ship cliphist, while newer releases do. Keep the existing
# upstream static-binary route only as a fallback after the configured mirrors
# have been tried, so Fedora 44+ never need GitHub for this dependency.
if ! command -v cliphist &>/dev/null; then
  install_github_binary "cliphist" "sentriz/cliphist" "linux-${ARCH_SUFFIX}$" || \
    log_warning "cliphist is still missing — clipboard history will not work until it is installed"
fi
}

provider_darkly() {
# darkly - Qt theme (download .rpm from GitHub)
if ${INSTALL_FONTS:-true}; then
  if ! rpm -q darkly &>/dev/null; then
    log_info "Installing darkly theme from GitHub..."
    DARKLY_RPM_URL=$(curl -s --connect-timeout 10 --max-time 30 "https://api.github.com/repos/Bali10050/darkly/releases/latest" | \
      jq -r ".assets[] | select(.name | test(\"fc${FEDORA_VERSION}.*x86_64.rpm$\")) | .browser_download_url" | head -1)
    
    # Fallback to any Fedora RPM if exact version not found
    if [[ -z "$DARKLY_RPM_URL" || "$DARKLY_RPM_URL" == "null" ]]; then
      DARKLY_RPM_URL=$(curl -s --connect-timeout 10 --max-time 30 "https://api.github.com/repos/Bali10050/darkly/releases/latest" | \
        jq -r '.assets[] | select(.name | test("fc[0-9]+.*x86_64.rpm$")) | .browser_download_url' | head -1)
    fi
    
    if [[ -n "$DARKLY_RPM_URL" && "$DARKLY_RPM_URL" != "null" ]]; then
      v sudo dnf install -y "$DARKLY_RPM_URL"
    else
      log_warning "darkly RPM not found for Fedora ${FEDORA_VERSION}"
    fi
  fi
fi
}

fedora_critical_fonts() {
tui_info "Installing critical fonts..."

FONT_DIR="$HOME/.local/share/fonts"
mkdir -p "$FONT_DIR"

# Material Symbols Rounded (icons) - this is the font iNiR actually uses
if ! fc-list | grep -qi "Material Symbols Rounded"; then
  log_info "Downloading Material Symbols Rounded font..."
  
  # Direct download from raw.githubusercontent
  MATERIAL_URL="https://raw.githubusercontent.com/google/material-design-icons/master/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf"
  
  if curl -fsSL --connect-timeout 10 --speed-limit 1024 --speed-time 30 -o "$FONT_DIR/MaterialSymbolsRounded.ttf" "$MATERIAL_URL"; then
    fc-cache -fv "$FONT_DIR" 2>/dev/null
    log_success "Material Symbols Rounded font installed"
  else
    log_warning "Could not download Material Symbols Rounded"
    log_warning "Download from: https://fonts.google.com/icons"
  fi
fi

# Also install Outlined variant (used by nts)
if ! fc-list | grep -qi "Material Symbols Outlined"; then
  log_info "Downloading Material Symbols Outlined font..."
  
  MATERIAL_URL="https://raw.githubusercontent.com/google/material-design-icons/master/variablefont/MaterialSymbolsOutlined%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf"
  
  if curl -fsSL --connect-timeout 10 --speed-limit 1024 --speed-time 30 -o "$FONT_DIR/MaterialSymbolsOutlined.ttf" "$MATERIAL_URL"; then
    fc-cache -fv "$FONT_DIR" 2>/dev/null
    log_success "Material Symbols Outlined font installed"
  else
    log_warning "Could not download Material Symbols Outlined"
  fi
fi

# JetBrains Mono Nerd Font (if not installed via dnf)
if ! fc-list | grep -qi "JetBrainsMono Nerd"; then
  log_info "Downloading JetBrains Mono Nerd Font..."
  
  NERD_FONTS_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
  TEMP_DIR="/tmp/nerdfonts-$$"
  mkdir -p "$TEMP_DIR"
  
  if curl -fsSL --connect-timeout 10 --speed-limit 1024 --speed-time 30 -o "$TEMP_DIR/JetBrainsMono.zip" "$NERD_FONTS_URL"; then
    unzip -o "$TEMP_DIR/JetBrainsMono.zip" -d "$FONT_DIR" >/dev/null 2>&1
    fc-cache -f "$FONT_DIR"
    log_success "JetBrains Mono Nerd Font installed"
  else
    log_warning "Could not download JetBrains Mono Nerd Font"
  fi
  
  rm -rf "$TEMP_DIR"
fi
}

fedora_icon_themes() {
tui_info "Installing icon themes..."

ICON_DIR="$HOME/.local/share/icons"
mkdir -p "$ICON_DIR"

# WhiteSur icon theme
if [[ ! -d "$ICON_DIR/WhiteSur-dark" ]]; then
  log_info "Installing WhiteSur icon theme..."
  
  TEMP_DIR="/tmp/whitesur-icons-$$"
  mkdir -p "$TEMP_DIR"
  
  if curl -fsSL --connect-timeout 10 --speed-limit 1024 --speed-time 30 -o "$TEMP_DIR/whitesur.tar.gz" \
    "https://github.com/vinceliuice/WhiteSur-icon-theme/archive/refs/heads/master.tar.gz"; then
    tar -xzf "$TEMP_DIR/whitesur.tar.gz" -C "$TEMP_DIR"
    cd "$TEMP_DIR/WhiteSur-icon-theme-master"
    ./install.sh -d "$ICON_DIR" -t default >/dev/null 2>&1 || {
      # Fallback: manual copy of canonical theme dirs
      cp -r src/WhiteSur "$ICON_DIR/WhiteSur" 2>/dev/null || true
      cp -r src/WhiteSur-dark "$ICON_DIR/WhiteSur-dark" 2>/dev/null || true
      cp -r src/WhiteSur-light "$ICON_DIR/WhiteSur-light" 2>/dev/null || true
    }
    cd - >/dev/null
    log_success "WhiteSur icon theme installed"
  else
    log_warning "Could not download WhiteSur icon theme"
  fi
  
  rm -rf "$TEMP_DIR"
fi

# MacTahoe icon theme (for dock)
if [[ ! -d "$ICON_DIR/MacTahoe" ]]; then
  log_info "Installing MacTahoe icon theme..."
  
  TEMP_DIR="/tmp/mactahoe-icons-$$"
  mkdir -p "$TEMP_DIR"
  
  if curl -fsSL --connect-timeout 10 --speed-limit 1024 --speed-time 30 -o "$TEMP_DIR/mactahoe.tar.gz" \
    "https://github.com/vinceliuice/MacTahoe-icon-theme/archive/refs/heads/master.tar.gz"; then
    tar -xzf "$TEMP_DIR/mactahoe.tar.gz" -C "$TEMP_DIR"
    cd "$TEMP_DIR/MacTahoe-icon-theme-master" 2>/dev/null || cd "$TEMP_DIR/MacTahoe-icon-theme-main"
    ./install.sh -d "$ICON_DIR" >/dev/null 2>&1
    cd - >/dev/null
    log_success "MacTahoe icon theme installed"
  else
    log_warning "Could not download MacTahoe icon theme"
  fi
  
  rm -rf "$TEMP_DIR"
fi
}

fedora_cursor_themes() {
tui_info "Installing cursor themes..."

# Bibata Modern cursors (popular, well-maintained)
if [[ ! -d "$ICON_DIR/Bibata-Modern-Classic" ]]; then
  log_info "Installing Bibata cursor theme..."
  
  TEMP_DIR="/tmp/bibata-cursors-$$"
  mkdir -p "$TEMP_DIR"
  
  # Download Bibata Modern Classic (dark)
  if curl -fsSL --connect-timeout 10 --speed-limit 1024 --speed-time 30 -o "$TEMP_DIR/bibata-classic.tar.xz" \
    "https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/Bibata-Modern-Classic.tar.xz"; then
    tar -xf "$TEMP_DIR/bibata-classic.tar.xz" -C "$ICON_DIR"
    log_success "Bibata Modern Classic cursor installed"
  fi
  
  # Download Bibata Modern Ice (light)
  if curl -fsSL --connect-timeout 10 --speed-limit 1024 --speed-time 30 -o "$TEMP_DIR/bibata-ice.tar.xz" \
    "https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/Bibata-Modern-Ice.tar.xz"; then
    tar -xf "$TEMP_DIR/bibata-ice.tar.xz" -C "$ICON_DIR"
    log_success "Bibata Modern Ice cursor installed"
  fi
  
  rm -rf "$TEMP_DIR"
fi
}

fedora_optional_fonts() {
tui_info "Installing optional fonts..."

# Space Grotesk
if ! fc-list | grep -qi "Space Grotesk"; then
  log_info "Downloading Space Grotesk font..."
  curl -fsSL --connect-timeout 10 --speed-limit 1024 --speed-time 30 -o "$FONT_DIR/SpaceGrotesk.ttf" \
    "https://github.com/floriankarsten/space-grotesk/raw/master/fonts/ttf/SpaceGrotesk%5Bwght%5D.ttf" 2>/dev/null && \
    log_success "Space Grotesk installed"
fi

# Rubik
if ! fc-list | grep -qi "Rubik"; then
  log_info "Downloading Rubik font..."
  curl -fsSL --connect-timeout 10 --speed-limit 1024 --speed-time 30 -o "$FONT_DIR/Rubik.ttf" \
    "https://github.com/googlefonts/rubik/raw/main/fonts/variable/Rubik%5Bwght%5D.ttf" 2>/dev/null && \
    log_success "Rubik installed"
fi

# Geist (used by default in iNiR)
if ! fc-list | grep -qi "Geist"; then
  log_info "Downloading Geist font..."
  TEMP_DIR="/tmp/geist-font-$$"
  mkdir -p "$TEMP_DIR"
  if curl -fsSL --connect-timeout 10 --speed-limit 1024 --speed-time 30 -o "$TEMP_DIR/geist.zip" \
    "https://github.com/vercel/geist-font/releases/latest/download/Geist.zip"; then
    unzip -o "$TEMP_DIR/geist.zip" -d "$TEMP_DIR" >/dev/null 2>&1
    find "$TEMP_DIR" -name "*.ttf" -exec cp {} "$FONT_DIR/" \;
    log_success "Geist font installed"
  fi
  rm -rf "$TEMP_DIR"
fi

# Refresh font cache
fc-cache -f "$FONT_DIR" 2>/dev/null
}

provider_starship-eza() {
tui_info "Installing CLI tools..."

# Starship prompt
if ! command -v starship &>/dev/null; then
  log_info "Installing Starship prompt..."
  mkdir -p ~/.local/bin
  curl -sS --connect-timeout 10 --speed-limit 1024 --speed-time 30 https://starship.rs/install.sh | sh -s -- -y -b ~/.local/bin 2>/dev/null || \
    log_warning "Could not install Starship"
fi

# Eza is in Fedora repositories; keep the release binary as a derivative/
# restricted-repository fallback only.
if ! command -v eza &>/dev/null; then
  log_info "Installing Eza..."
  mkdir -p ~/.local/bin
  if curl -fsSL --connect-timeout 10 --speed-limit 1024 --speed-time 30 -o /tmp/eza.tar.gz \
    'https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-musl.tar.gz'; then
    tar -xzf /tmp/eza.tar.gz -C ~/.local/bin
    chmod +x ~/.local/bin/eza
    log_success "Eza installed"
  fi
  rm -f /tmp/eza.tar.gz
fi
}

fedora_gtk_theme() {
tui_info "Installing GTK themes..."

if ! rpm -q adw-gtk3-theme &>/dev/null; then
  v sudo dnf install -y adw-gtk3-theme
fi
}

provider_fonts-download() { fedora_critical_fonts && fedora_optional_fonts; }
provider_themes-download() { fedora_icon_themes && fedora_cursor_themes && fedora_gtk_theme; }
