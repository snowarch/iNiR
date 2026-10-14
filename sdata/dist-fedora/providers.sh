# shellcheck shell=bash
# Fedora providers: what sdata/deps.toml calls `build = "<recipe>"` for Fedora, as provider_<recipe>, with the
# helpers they use. Definitions only, no top-level code: install-deps.sh sources it, and so can the inir binary.
# cliphist, starship-eza, darkly, fonts-download and themes-download are still inline in install-deps.sh.
dnf_pkg_available() {
  local pkg="$1"
  dnf -q list --available "$pkg" &>/dev/null || dnf -q list --installed "$pkg" &>/dev/null
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
