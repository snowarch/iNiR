# shellcheck shell=bash
# Debian/Ubuntu providers: what sdata/deps.toml calls `build = "<recipe>"`, as provider_<recipe>. Each one is
# the install step it was inline in install-deps.sh, unchanged: it runs when its tool is missing and leaves
# the rest alone. Definitions only, no top-level code; install-deps.sh sources it before checking repos, and so
# can the inir binary to run one provider.

# --- helpers the providers use -------------------------------------------------

# What the providers read about this system. install-deps.sh runs it first, and `setup provider` too.
debian_detect() {
  IS_UBUNTU=false
  IS_DEBIAN=false
  UBUNTU_VERSION=""
  UBUNTU_CODENAME=""
  DEBIAN_VERSION=""
  DEBIAN_CODENAME=""
  # Ubuntu derivatives (PikaOS, Pop!_OS, Linux Mint...) count as Ubuntu.
  DISTRO_ID=$(grep "^ID=" /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')
  DISTRO_ID_LIKE=$(grep "^ID_LIKE=" /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')
  DISTRO_NAME=$(grep "^PRETTY_NAME=" /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')
  if grep -qi "ubuntu" /etc/os-release 2>/dev/null || [[ "$DISTRO_ID_LIKE" == *"ubuntu"* ]]; then
    IS_UBUNTU=true
    UBUNTU_VERSION=$(grep "^VERSION_ID=" /etc/os-release | cut -d= -f2 | tr -d '"')
    UBUNTU_CODENAME=$(grep "^UBUNTU_CODENAME=" /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')
  elif [[ -f /etc/debian_version ]] || [[ "$DISTRO_ID_LIKE" == *"debian"* ]]; then
    IS_DEBIAN=true
    DEBIAN_VERSION=$(cat /etc/debian_version 2>/dev/null || echo "unknown")
    DEBIAN_CODENAME=$(grep "^VERSION_CODENAME=" /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')
  fi
  ARCH=$(dpkg --print-architecture)
  installflags=""
  ${ask:-true} || installflags="-y"
}

declare -a APT_COMPONENTS=()
declare -a MISSING_REPO_PKGS=()
declare -A APT_PKG_AVAILABLE_CACHE=()

read_apt_components() {
  local -a components=()
  local file line

  for file in /etc/apt/sources.list /etc/apt/sources.list.d/*.list; do
    [[ -f "$file" ]] || continue
    while IFS= read -r line; do
      line="${line%%#*}"
      [[ -z "$line" ]] && continue
      [[ "$line" =~ ^[[:space:]]*deb[[:space:]] ]] || continue

      line="${line#deb }"
      if [[ "$line" =~ ^\[[^]]+\][[:space:]]+ ]]; then
        line="${line#*] }"
      fi

      local uri distro comps
      uri=""
      distro=""
      comps=""
      read -r uri distro comps <<<"$line"
      for comp in $comps; do
        components+=("$comp")
      done
    done < "$file"
  done

  for file in /etc/apt/sources.list.d/*.sources /etc/apt/sources.list.d/*/*.sources; do
    [[ -f "$file" ]] || continue
    while IFS= read -r line; do
      line="${line%%#*}"
      [[ "$line" =~ ^[[:space:]]*Components: ]] || continue
      line="${line#*:}"
      for comp in $line; do
        components+=("$comp")
      done
    done < "$file"
  done

  if [[ ${#components[@]} -gt 0 ]]; then
    APT_COMPONENTS=($(printf "%s\n" "${components[@]}" | awk 'NF{print $1}' | sort -u))
  else
    APT_COMPONENTS=()
  fi
}

apt_component_enabled() {
  local component="$1"
  local comp
  for comp in "${APT_COMPONENTS[@]}"; do
    if [[ "$comp" == "$component" ]]; then
      return 0
    fi
  done
  return 1
}

log_repo_context() {
  if ! ${quiet:-false}; then
    if [[ ${#APT_COMPONENTS[@]} -gt 0 ]]; then
      log_info "APT components: ${APT_COMPONENTS[*]}"
    else
      log_warning "Could not determine APT components from sources lists"
    fi
  fi
}

ensure_add_apt_repository() {
  if command -v add-apt-repository &>/dev/null; then
    return 0
  fi

  log_info "Installing software-properties-common..."
  sudo apt install $installflags software-properties-common 2>/dev/null || return 1
  return 0
}

ensure_ubuntu_component() {
  local component="$1"

  if ! $IS_UBUNTU; then
    return 0
  fi

  if apt_component_enabled "$component"; then
    return 0
  fi

  log_info "Enabling Ubuntu component '${component}'..."
  if ! ensure_add_apt_repository; then
    log_warning "add-apt-repository unavailable, skipping ${component}"
    return 1
  fi

  if ! command -v add-apt-repository &>/dev/null; then
    log_warning "add-apt-repository still missing, skipping ${component}"
    return 1
  fi

  sudo add-apt-repository -y "$component" || {
    log_warning "Failed to enable ${component}"
    return 1
  }

  v sudo apt update
  read_apt_components
  return 0
}

apt_pkg_available() {
  local pkg="$1"

  if [[ -n "${APT_PKG_AVAILABLE_CACHE[$pkg]+x}" ]]; then
    [[ "${APT_PKG_AVAILABLE_CACHE[$pkg]}" == "yes" ]]
    return $?
  fi

  # `apt-cache show` also succeeds for names only other packages mention (Debian 13
  # still knows policykit-1 that way), so require a version apt can install.
  local candidate
  candidate="$(apt-cache policy "$pkg" 2>/dev/null | awk '/Candidate:/ { print $2; exit }')"
  if [[ -n "$candidate" && "$candidate" != "(none)" ]]; then
    APT_PKG_AVAILABLE_CACHE["$pkg"]="yes"
    return 0
  fi

  APT_PKG_AVAILABLE_CACHE["$pkg"]="no"
  return 1
}

quickshell_installed_compatible() {
  local version=""
  command -v qs &>/dev/null || return 1
  version="$(qs --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
  [[ -n "$version" ]] && dpkg --compare-versions "$version" ge "0.3.0"
}

apt_quickshell_compatible() {
  local candidate=""
  apt_pkg_available quickshell || return 1
  candidate="$(apt-cache policy quickshell 2>/dev/null | awk '/Candidate:/ {print $2; exit}')"
  [[ -n "$candidate" && "$candidate" != "(none)" ]] || return 1
  dpkg --compare-versions "$candidate" ge "0.3.0"
}

get_debian_primary_mirror() {
  local codename="${DEBIAN_CODENAME:-}"
  local mirror=""

  [[ -n "$codename" ]] || return 1

  mirror=$(sed -nE "s|^[[:space:]]*deb[[:space:]]+(\\[[^]]+\\][[:space:]]+)?([^[:space:]]+)[[:space:]]+${codename}([[:space:]].*)?$|\\2|p" \
    /etc/apt/sources.list /etc/apt/sources.list.d/*.list 2>/dev/null \
    | grep -vi '/security' | head -1)

  if [[ -z "$mirror" ]]; then
    mirror=$(awk -v suite="$codename" '
      BEGIN { RS=""; FS="\n" }
      {
        uris=""; suites=""
        for (i=1; i<=NF; i++) {
          if ($i ~ /^[[:space:]]*URIs:/) { uris=$i; sub(/^[^:]*:[[:space:]]*/, "", uris) }
          if ($i ~ /^[[:space:]]*Suites:/) { suites=$i; sub(/^[^:]*:[[:space:]]*/, "", suites) }
        }
        if (suites ~ "(^|[[:space:]])" suite "([[:space:]]|$)" && uris !~ /security/) {
          split(uris, u, /[[:space:]]+/); print u[1]; exit
        }
      }
    ' /etc/apt/sources.list.d/*.sources 2>/dev/null)
  fi

  [[ -n "$mirror" ]] || mirror="http://deb.debian.org/debian"
  printf '%s\n' "$mirror"
}

ensure_debian_component() {
  local component="$1"

  if ! $IS_DEBIAN || [[ -z "$DEBIAN_CODENAME" ]]; then
    return 0
  fi
  if apt_component_enabled "$component"; then
    return 0
  fi

  local mirror
  mirror="$(get_debian_primary_mirror)" || return 1
  log_info "Enabling Debian '${component}' component using ${mirror}..."
  printf 'deb %s %s %s\n' "$mirror" "$DEBIAN_CODENAME" "$component" \
    | sudo tee "/etc/apt/sources.list.d/inir-${DEBIAN_CODENAME}-${component}.list" >/dev/null || return 1

  if ! sudo apt update; then
    log_warning "Could not refresh Debian '${component}' component"
    return 1
  fi
  APT_PKG_AVAILABLE_CACHE=()
  read_apt_components
}

ensure_debian_backports() {
  # Prefer the user's existing Debian mirror so installations in region-limited
  # networks do not get forced onto a new host just to obtain backports.
  if ! $IS_DEBIAN || [[ -z "$DEBIAN_CODENAME" ]]; then
    return 0
  fi

  local suite="${DEBIAN_CODENAME}-backports"

  if grep -RqsE "(^|[[:space:]])${suite}([[:space:]]|$)" \
      /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null; then
    return 0
  fi

  local mirror
  mirror="$(get_debian_primary_mirror)" || return 1

  log_info "Enabling Debian ${suite} using ${mirror}..."
  printf 'deb %s %s main\n' "$mirror" "$suite" \
    | sudo tee "/etc/apt/sources.list.d/inir-${suite}.list" >/dev/null || return 1
  if ! sudo apt update; then
    log_warning "Could not refresh ${suite}; source-build fallbacks remain available"
    return 1
  fi

  # Availability checks performed before the repo was enabled must be retried.
  APT_PKG_AVAILABLE_CACHE=()
}

ensure_rust_toolchain() {
  [[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"
  command -v cargo &>/dev/null && return 0

  log_info "Rust is required for this source fallback — installing via rustup..."
  if curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y; then
    source "$HOME/.cargo/env"
    command -v cargo &>/dev/null
    return $?
  fi

  log_warning "Could not install Rust toolchain"
  return 1
}

filter_available_packages() {
  local pkg_array_name="$1"
  local -n pkgs="$pkg_array_name"
  local -a available=()
  local pkg

  for pkg in "${pkgs[@]}"; do
    if apt_pkg_available "$pkg"; then
      available+=("$pkg")
    else
      MISSING_REPO_PKGS+=("$pkg")
    fi
  done

  pkgs=("${available[@]}")
}

# niri and xwayland-satellite are in neither archive, and Quickshell only in Debian backports (older).
# DankLinux builds all three for Debian (OBS) and Ubuntu (Launchpad PPA), the same packages
# DankMaterialShell installs; without it each one is a Rust or C++ build on the user's machine.
ensure_danklinux_repo() {
  if $IS_UBUNTU; then
    grep -qs "avengemedia/danklinux" /etc/apt/sources.list.d/* && return 0
    ensure_add_apt_repository || return 1
    sudo add-apt-repository -y ppa:avengemedia/danklinux || return 1
  elif $IS_DEBIAN; then
    local target list=/etc/apt/sources.list.d/inir-danklinux.list key=/etc/apt/keyrings/inir-danklinux.asc
    case "$DEBIAN_CODENAME" in
      trixie) target=Debian_13 ;;
      forky) target=Debian_Testing ;;
      sid) target=Debian_Unstable ;;
      *) return 1 ;;
    esac
    [[ -f "$list" ]] && return 0
    local url="https://download.opensuse.org/repositories/home:/AvengeMedia:/danklinux/${target}"
    sudo install -d -m 0755 /etc/apt/keyrings || return 1
    curl -fsSL "$url/Release.key" | sudo tee "$key" >/dev/null || return 1
    echo "deb [signed-by=$key] $url/ /" | sudo tee "$list" >/dev/null || return 1
  else
    return 1
  fi
  sudo apt update
  APT_PKG_AVAILABLE_CACHE=()
}

#####################################################################################
# Helper function to download and install from GitHub
#####################################################################################
install_github_binary() {
  local name="$1"
  local repo="$2"
  local asset_pattern="$3"
  local install_path="${4:-/usr/local/bin}"
  
  if command -v "$name" &>/dev/null; then
    log_success "$name already installed"
    return 0
  fi
  
  log_info "Installing $name from GitHub releases..."
  
  local download_url
  download_url=$(curl -s "https://api.github.com/repos/${repo}/releases/latest" | \
    jq -r ".assets[] | select(.name | test(\"${asset_pattern}\")) | .browser_download_url" | head -1)
  
  if [[ -z "$download_url" || "$download_url" == "null" ]]; then
    log_warning "Could not find $name binary for your architecture"
    return 1
  fi
  
  local temp_dir="${TMPDIR:-/tmp}/${name}-install-$$"
  mkdir -p "$temp_dir"
  
  local filename=$(basename "$download_url")
  log_info "Downloading: $filename"
  
  if curl -fsSL -o "$temp_dir/$filename" "$download_url"; then
    case "$filename" in
      *.tar.gz|*.tgz)
        tar -xzf "$temp_dir/$filename" -C "$temp_dir"
        local binary=$(find "$temp_dir" -type f -name "$name" 2>/dev/null | head -1)
        [[ -z "$binary" ]] && binary=$(find "$temp_dir" -type f -executable 2>/dev/null | grep -v "\.tar" | head -1)
        [[ -n "$binary" ]] && sudo cp "$binary" "$install_path/$name"
        ;;
      *.zip)
        unzip -o "$temp_dir/$filename" -d "$temp_dir" >/dev/null
        local binary=$(find "$temp_dir" -type f -name "$name" 2>/dev/null | head -1)
        [[ -n "$binary" ]] && sudo cp "$binary" "$install_path/$name"
        ;;
      *.deb)
        sudo dpkg -i "$temp_dir/$filename" || sudo apt install -f -y
        rm -rf "$temp_dir"
        return 0
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
    rm -rf "$temp_dir"
    return 1
  fi
  
  rm -rf "$temp_dir"
}

# --- providers ------------------------------------------------------------------

provider_power-profiles() {
  power_profiles_wanted || return 0
  command -v powerprofilesctl &>/dev/null || pkg_sudo apt-get install -y power-profiles-daemon || return 1
  power_profiles_enable power-profiles-daemon.service
}

provider_gum() {
# gum - TUI tool (download .deb from GitHub if not in repos)
if ! command -v gum &>/dev/null; then
  log_info "Installing gum from GitHub..."
  GUM_DEB_URL=$(curl -s "https://api.github.com/repos/charmbracelet/gum/releases/latest" | \
    jq -r ".assets[] | select(.name | test(\"_${ARCH}.deb$\")) | .browser_download_url" | head -1)
  if [[ -n "$GUM_DEB_URL" && "$GUM_DEB_URL" != "null" ]]; then
    TEMP_DEB="${TMPDIR:-/tmp}/gum-$$.deb"
    if curl -fsSL -o "$TEMP_DEB" "$GUM_DEB_URL"; then
      sudo dpkg -i "$TEMP_DEB" 2>/dev/null || sudo apt install -f -y
      rm -f "$TEMP_DEB"
      log_success "gum installed"
    else
      log_warning "Failed to download gum"
    fi
  else
    log_warning "Could not find gum .deb for architecture ${ARCH}"
  fi
fi
}

provider_cliphist() {
# cliphist - clipboard manager (if not in repos)
if ! command -v cliphist &>/dev/null; then
  install_github_binary "cliphist" "sentriz/cliphist" "linux-amd64$"
fi
}

provider_songrec() {
# songrec - music recognition (PPA for Ubuntu, Cargo for Debian)
if ! command -v songrec &>/dev/null; then
  log_info "Installing songrec (music recognition)..."
  
  SONGREC_INSTALLED=false
  
  # Try Ubuntu PPA first (only for Ubuntu)
  if [[ "$IS_UBUNTU" == "true" ]]; then
    log_info "Trying songrec PPA for Ubuntu..."
    if sudo add-apt-repository -y ppa:marin-m/songrec 2>/dev/null; then
      sudo apt update
      APT_PKG_AVAILABLE_CACHE=()
      if sudo apt install $installflags songrec 2>/dev/null; then
        log_success "songrec installed from PPA"
        SONGREC_INSTALLED=true
      fi
    fi
  fi
  
  # Fallback: compile with Cargo
  if [[ "$SONGREC_INSTALLED" == "false" ]]; then
    log_info "Compiling songrec from source with Cargo..."
    
    # Install build dependencies
    # songrec 0.7 is GTK4/libadwaita; libspa-sys runs bindgen, which needs libclang.
    SONGREC_DEPS=(
      build-essential
      pkg-config
      libasound2-dev
      libpulse-dev
      libdbus-1-dev
      libssl-dev
      libgtk-4-dev
      libadwaita-1-dev
      libsoup-3.0-dev
      libpipewire-0.3-dev
      libclang-dev
    )
    sudo apt install $installflags "${SONGREC_DEPS[@]}" 2>/dev/null || true
    
    # Rust is only needed when the repository/PPA paths above were unavailable.
    if ensure_rust_toolchain; then
      SONGREC_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/inir-songrec.XXXXXX")"
      if cargo install --root "$SONGREC_ROOT" songrec 2>/dev/null \
          && [[ -x "$SONGREC_ROOT/bin/songrec" ]]; then
        sudo install -m 0755 "$SONGREC_ROOT/bin/songrec" /usr/local/bin/songrec
        log_success "songrec installed via Cargo"
        SONGREC_INSTALLED=true
      else
        log_warning "songrec build failed"
      fi
      rm -rf "$SONGREC_ROOT"
    else
      log_warning "Cargo not available, skipping songrec source fallback"
    fi
  fi
fi
}

provider_missioncenter() {
# Mission Center - Debian/Ubuntu provider. Flathub is the cross-distro
# package source already documented by iNiR; add a host command wrapper so the
# launcher and Doctor can treat it like every other configured application.
if ! command -v missioncenter &>/dev/null; then
  log_info "Installing Mission Center from Flathub..."
  sudo apt install $installflags flatpak >/dev/null 2>&1 || true
  if command -v flatpak &>/dev/null; then
    flatpak remote-add --if-not-exists --user flathub https://flathub.org/repo/flathub.flatpakrepo >/dev/null 2>&1 || true
    _mc_log="$(mktemp "${TMPDIR:-/tmp}/inir-missioncenter-log.XXXXXX")"
    if flatpak install -y --user flathub io.missioncenter.MissionCenter >"$_mc_log" 2>&1; then
      _mc_wrapper="$(mktemp "${TMPDIR:-/tmp}/inir-missioncenter.XXXXXX")"
      printf '%s\n' '#!/bin/sh' 'exec flatpak run io.missioncenter.MissionCenter "$@"' > "$_mc_wrapper"
      sudo install -m 0755 "$_mc_wrapper" /usr/local/bin/missioncenter
      rm -f "$_mc_wrapper"
      log_success "Mission Center installed"
    else
      log_warning "Mission Center Flatpak installation failed: $(tail -n 3 "$_mc_log" | tr '\n' ' ')"
    fi
    rm -f "$_mc_log"
  fi
fi
}

provider_gowall() {
# Gowall - no stable Debian package is assumed. Build the tiny Go CLI only when
# the exposed wallpaper editor needs its command and it is not already present.
if ${INSTALL_TOOLKIT:-true} && ! command -v gowall &>/dev/null; then
  log_info "Installing gowall wallpaper editor..."
  sudo apt install $installflags golang-go >/dev/null 2>&1 || true
  if command -v go &>/dev/null; then
    _gowall_build="$(mktemp -d "${TMPDIR:-/tmp}/inir-gowall.XXXXXX")"
    if git clone --depth 1 https://github.com/Achno/gowall.git "$_gowall_build/src" >/dev/null 2>&1 \
        && (cd "$_gowall_build/src" && go build -o "$_gowall_build/gowall" . >/dev/null 2>&1); then
      sudo install -m 0755 "$_gowall_build/gowall" /usr/local/bin/gowall
      log_success "gowall installed"
    else
      log_warning "gowall source build failed"
    fi
    rm -rf "$_gowall_build"
  fi
fi
}

provider_darkly() {
# darkly - Qt theme (download .deb from GitHub)
if ${INSTALL_FONTS:-true}; then
  if ! dpkg -l 2>/dev/null | grep -q darkly; then
    log_info "Installing darkly theme from GitHub..."
    DARKLY_DEB_URL=$(curl -s "https://api.github.com/repos/Bali10050/darkly/releases/latest" | \
      jq -r '.assets[] | select(.name | test("debian.*amd64.deb$")) | .browser_download_url' | head -1)
    
    if [[ -n "$DARKLY_DEB_URL" && "$DARKLY_DEB_URL" != "null" ]]; then
      TEMP_DEB="${TMPDIR:-/tmp}/darkly-$$.deb"
      curl -fsSL -o "$TEMP_DEB" "$DARKLY_DEB_URL"
      sudo dpkg -i "$TEMP_DEB" || sudo apt install -f -y
      rm -f "$TEMP_DEB"
      log_success "darkly installed"
    fi
  fi
fi
}

debian_gtk_themes() {
# adw-gtk3 - GTK3/4 theme (download tarball from GitHub)
if ${INSTALL_FONTS:-true}; then
  THEME_DIR="$HOME/.local/share/themes"
  if [[ ! -d "$THEME_DIR/adw-gtk3" ]]; then
    log_info "Installing adw-gtk3 theme from GitHub..."
    mkdir -p "$THEME_DIR"
    
    ADW_GTK3_URL=$(curl -s "https://api.github.com/repos/lassekongo83/adw-gtk3/releases/latest" | \
      jq -r '.assets[] | select(.name | test("adw-gtk3.*\\.tar\\.xz$")) | .browser_download_url' | head -1)
    
    if [[ -n "$ADW_GTK3_URL" && "$ADW_GTK3_URL" != "null" ]]; then
      TEMP_DIR="${TMPDIR:-/tmp}/adw-gtk3-$$"
      mkdir -p "$TEMP_DIR"
      
      if curl -fsSL -o "$TEMP_DIR/adw-gtk3.tar.xz" "$ADW_GTK3_URL"; then
        tar -xJf "$TEMP_DIR/adw-gtk3.tar.xz" -C "$THEME_DIR"
        log_success "adw-gtk3 theme installed"
      fi
      
      rm -rf "$TEMP_DIR"
    else
      log_warning "Could not find adw-gtk3 release"
    fi
  fi
fi

# twemoji-color-font - Twitter emoji font (download .deb from GitHub)
if ${INSTALL_FONTS:-true}; then
  if ! fc-list | grep -qi "Twemoji"; then
    log_info "Installing twemoji-color-font from GitHub..."
    TWEMOJI_DEB_URL=$(curl -s "https://api.github.com/repos/13rac1/twemoji-color-font/releases/latest" | \
      jq -r '.assets[] | select(.name | test("fonts-twemoji-svginot.*_all.deb$")) | .browser_download_url' | head -1)
    
    if [[ -n "$TWEMOJI_DEB_URL" && "$TWEMOJI_DEB_URL" != "null" ]]; then
      TEMP_DEB="${TMPDIR:-/tmp}/twemoji-$$.deb"
      if curl -fsSL -o "$TEMP_DEB" "$TWEMOJI_DEB_URL"; then
        sudo dpkg -i "$TEMP_DEB" || sudo apt install -f -y
        rm -f "$TEMP_DEB"
        log_success "twemoji-color-font installed"
      fi
    else
      log_warning "Could not find twemoji-color-font release"
    fi
  fi
fi
}

provider_swappy() {
# swappy - screenshot annotation (not in bookworm, compile from source)
if ${INSTALL_SCREENCAPTURE:-true}; then
  if ! command -v swappy &>/dev/null; then
    log_info "Installing swappy from source..."
    sudo apt install $installflags libgtk-3-dev libcairo2-dev libpango1.0-dev scdoc 2>/dev/null || true
    
    SWAPPY_BUILD_DIR="${TMPDIR:-/tmp}/swappy-build-$$"
    if git clone https://github.com/jtheoof/swappy.git "$SWAPPY_BUILD_DIR" 2>/dev/null; then
      cd "$SWAPPY_BUILD_DIR"
      if meson setup build && ninja -C build; then
        sudo ninja -C build install
        log_success "swappy installed"
      else
        log_warning "swappy build failed, skipping"
      fi
      cd "${REPO_ROOT}"
      rm -rf "$SWAPPY_BUILD_DIR"
    fi
  fi
fi
}


provider_starship-eza() {
# Debian 13 carries both tools directly. Older Debian/Ubuntu releases retain
# the project's upstream installers instead of silently missing shell helpers.
if ! command -v starship &>/dev/null; then
  install-starship
fi
if ! command -v eza &>/dev/null; then
  install-eza
fi
}

# niri's session files where its docs put them for a build without a package: the login runs niri-session, which
# starts niri.service, which starts inir.service
_niri_session_files() {
  sudo install -Dm755 "$1/resources/niri-session" /usr/local/bin/niri-session \
    && sudo install -Dm644 "$1/resources/niri.desktop" /usr/local/share/wayland-sessions/niri.desktop \
    && sudo install -Dm644 "$1/resources/niri-portals.conf" /usr/local/share/xdg-desktop-portal/niri-portals.conf \
    && sudo install -Dm644 "$1/resources/niri.service" /etc/systemd/user/niri.service \
    && sudo install -Dm644 "$1/resources/niri-shutdown.target" /etc/systemd/user/niri-shutdown.target \
    && { systemctl --user daemon-reload 2>/dev/null || true; }
}

provider_niri() {
# the release inir's config is written for
local NIRI_TAG=v26.04
if ! command -v niri &>/dev/null; then
  # Check for Ubuntu 25.10+ which has PPA available
  if $IS_UBUNTU && [[ "${UBUNTU_VERSION%%.*}" -ge 25 ]]; then
    log_success "Ubuntu 25.10+ detected — using PPA (no compilation!)"
    if ! grep -q "avengemedia/danklinux" /etc/apt/sources.list.d/* 2>/dev/null; then
      if ensure_add_apt_repository; then
        sudo add-apt-repository -y ppa:avengemedia/danklinux || {
          log_warning "PPA failed, falling back to source compilation"
        }
        sudo apt update
        APT_PKG_AVAILABLE_CACHE=()
      else
        log_warning "add-apt-repository unavailable, skipping PPA"
      fi
    fi
    if sudo apt install -y niri 2>/dev/null; then
      log_success "Niri installed from PPA!"
    fi
  fi

  # Try distro repositories (PikaOS/derivatives may ship niri)
  if ! command -v niri &>/dev/null; then
    if apt_pkg_available niri; then
      if sudo apt install $installflags niri 2>/dev/null; then
        log_success "Niri installed from distro repositories"
      fi
    fi
  fi
  
  # If still not installed, compile from source
  if ! command -v niri &>/dev/null; then
    log_info "Niri not in repos — compiling from source..."
    if ! ensure_rust_toolchain; then
      log_error "Niri source fallback requires Rust: sudo apt install cargo, then ./setup install"
      return 1
    fi
  
    log_info "Installing Niri build dependencies..."
    
    NIRI_BUILD_DEPS=(
      gcc
      clang
      libudev-dev
      libgbm-dev
      libxkbcommon-dev
      libegl1-mesa-dev
      libwayland-dev
      libinput-dev
      libdbus-1-dev
      libsystemd-dev
      libseat-dev
      libpipewire-0.3-dev
      libpango1.0-dev
    )
    
    # libdisplay-info-dev: available in trixie/sid and Ubuntu 24.04+, backports for bookworm
    if apt_pkg_available libdisplay-info-dev; then
      NIRI_BUILD_DEPS+=(libdisplay-info-dev)
    else
      log_warning "libdisplay-info-dev not in repos, trying backports..."
      # Try to enable backports for bookworm
      if $IS_DEBIAN && [[ "$DEBIAN_VERSION" == 12* ]]; then
        ensure_debian_backports || true
        sudo apt install -t bookworm-backports libdisplay-info-dev 2>/dev/null || true
      fi
    fi
    
    sudo apt install $installflags "${NIRI_BUILD_DEPS[@]}" 2>/dev/null || {
      log_warning "Some niri deps failed, trying individually..."
      for pkg in "${NIRI_BUILD_DEPS[@]}"; do
        sudo apt install $installflags "$pkg" 2>/dev/null || true
      done
    }
    
    # on disk: Debian keeps /tmp in RAM and the release build outgrows it there
    NIRI_BUILD_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/inir/build/niri-$$"
    mkdir -p "${NIRI_BUILD_DIR%/*}"

    log_info "Cloning Niri ${NIRI_TAG}..."
    if git clone -q --depth 1 --branch "$NIRI_TAG" https://github.com/YaLTeR/niri.git "$NIRI_BUILD_DIR"; then
      log_info "Building Niri (this may take a while)..."
      cd "$NIRI_BUILD_DIR"
      if cargo build --release; then
        log_info "Installing Niri..."
        sudo install -Dm755 target/release/niri /usr/local/bin/niri
        _niri_session_files "$NIRI_BUILD_DIR" || log_error "Niri's session files did not install; retry with: ./setup install"
        log_success "Niri installed!"
      else
        log_error "Niri build failed (the output is above); retry with: ./setup install"
      fi
      cd "${REPO_ROOT}"
      rm -rf "$NIRI_BUILD_DIR"
    else
      log_error "Failed to clone Niri repository; once online run: ./setup install"
    fi
    command -v niri &>/dev/null || return 1
  fi
else
  log_success "Niri already installed"
  # a niri this provider built before 10-28 came without them: no session started the shell
  if ! command -v niri-session &>/dev/null && [[ -d /run/systemd/system ]]; then
    local niri_src="${XDG_CACHE_HOME:-$HOME/.cache}/inir/build/niri-session-$$"
    mkdir -p "${niri_src%/*}"
    git clone -q --depth 1 --branch "$NIRI_TAG" https://github.com/YaLTeR/niri.git "$niri_src" \
      && _niri_session_files "$niri_src" && log_success "Niri's session files installed"
    rm -rf "$niri_src"
  fi
fi
command -v niri-session &>/dev/null || [[ ! -d /run/systemd/system ]] || return 1
}

provider_xwayland-satellite() {
if ! command -v xwayland-satellite &>/dev/null; then
  log_info "Installing xwayland-satellite..."

  # Try distro repositories first
  if apt_pkg_available xwayland-satellite; then
    if sudo apt install $installflags xwayland-satellite 2>/dev/null; then
      log_success "xwayland-satellite installed from distro repositories"
    fi
  fi

  if command -v xwayland-satellite &>/dev/null; then
    true
  else
  if ! ensure_rust_toolchain; then
    log_warning "xwayland-satellite source fallback requires Rust"
  else
  
  # Install xwayland-satellite build dependencies
  sudo apt install $installflags \
    libxcb1-dev \
    libxcb-composite0-dev \
    libxcb-cursor-dev \
    libxcb-render0-dev \
    libxcb-xfixes0-dev \
    libclang-dev 2>/dev/null || true
  
  # xwayland-satellite is not on crates.io, must compile from source
  XWSAT_BUILD_DIR="${TMPDIR:-/tmp}/xwayland-satellite-build-$$"
  if git clone https://github.com/Supreeeme/xwayland-satellite.git "$XWSAT_BUILD_DIR"; then
    cd "$XWSAT_BUILD_DIR"
    if cargo build --release; then
      sudo cp target/release/xwayland-satellite /usr/local/bin/
      log_success "xwayland-satellite installed"
    else
      log_warning "xwayland-satellite build failed"
    fi
    cd "${REPO_ROOT}"
    rm -rf "$XWSAT_BUILD_DIR"
  fi
  fi
  fi
fi
}

provider_awww() {
if ! command -v awww &>/dev/null; then
  log_info "Installing awww (wallpaper daemon)..."

  if ! ensure_rust_toolchain; then
    log_warning "awww source fallback requires Rust"
  else

  # awww needs libxkbcommon and lz4
  sudo apt install $installflags libxkbcommon-dev liblz4-dev 2>/dev/null || true

  AWWW_BUILD_DIR="${TMPDIR:-/tmp}/awww-build-$$"
  if git clone https://codeberg.org/LGFae/awww.git "$AWWW_BUILD_DIR"; then
    cd "$AWWW_BUILD_DIR"
    if cargo build --release; then
      sudo cp target/release/awww target/release/awww-daemon /usr/local/bin/
      log_success "awww installed"
    else
      log_warning "awww build failed"
    fi
    cd "${REPO_ROOT}"
    rm -rf "$AWWW_BUILD_DIR"
  else
    log_warning "Failed to clone awww repository"
  fi
  fi
fi
}

provider_hyprpicker() {
if ! command -v hyprpicker &>/dev/null; then
  log_info "hyprpicker not found, compiling from source..."
  
  # Install build dependencies
  HYPRPICKER_DEPS=(
    cmake
    pkg-config
    libpango1.0-dev
    libcairo2-dev
    libwayland-dev
    wayland-protocols
    libxkbcommon-dev
  )
  
  # hyprutils is required - check if available
  if apt_pkg_available libhyprutils-dev; then
    HYPRPICKER_DEPS+=(libhyprutils-dev)
  fi
  
  # hyprwayland-scanner is required for building - need the -dev package for .pc file
  if apt_pkg_available libhyprwayland-scanner-dev; then
    HYPRPICKER_DEPS+=(libhyprwayland-scanner-dev)
  elif apt_pkg_available hyprwayland-scanner; then
    HYPRPICKER_DEPS+=(hyprwayland-scanner)
  fi
  
  sudo apt install $installflags "${HYPRPICKER_DEPS[@]}" 2>/dev/null || true
  
  # Check if hyprutils is installed (either from package or needs compilation)
  HYPRUTILS_INSTALLED=false
  if pkg-config --exists hyprutils 2>/dev/null; then
    HYPRUTILS_INSTALLED=true
  fi
  
  # Compile hyprutils if not available
  if [[ "$HYPRUTILS_INSTALLED" == "false" ]]; then
    log_info "hyprutils not found, compiling from source..."
    HYPRUTILS_BUILD_DIR="${TMPDIR:-/tmp}/hyprutils-build-$$"
    
    if git clone --depth 1 https://github.com/hyprwm/hyprutils.git "$HYPRUTILS_BUILD_DIR" 2>/dev/null; then
      cd "$HYPRUTILS_BUILD_DIR"
      if cmake -B build && cmake --build build && sudo cmake --install build; then
        log_success "hyprutils installed"
        HYPRUTILS_INSTALLED=true
      else
        log_warning "hyprutils build failed"
      fi
      cd "${REPO_ROOT}"
      rm -rf "$HYPRUTILS_BUILD_DIR"
    fi
  fi
  
  # Now compile hyprpicker
  if [[ "$HYPRUTILS_INSTALLED" == "true" ]]; then
    HYPRPICKER_BUILD_DIR="${TMPDIR:-/tmp}/hyprpicker-build-$$"
    
    if git clone --depth 1 https://github.com/hyprwm/hyprpicker.git "$HYPRPICKER_BUILD_DIR" 2>/dev/null; then
      cd "$HYPRPICKER_BUILD_DIR"
      if cmake -B build && cmake --build build; then
        sudo cp build/hyprpicker /usr/local/bin/
        log_success "hyprpicker installed"
      else
        log_warning "hyprpicker build failed"
      fi
      cd "${REPO_ROOT}"
      rm -rf "$HYPRPICKER_BUILD_DIR"
    fi
  else
    log_warning "Skipping hyprpicker (hyprutils not available)"
  fi
fi
}

provider_quickshell() {
if ! quickshell_installed_compatible; then
  # Try a compatible distro/backports/PPA package first. Do not accept an older
  # quickshell merely because a binary named `qs` happens to be installed.
  if apt_quickshell_compatible; then
    sudo apt install $installflags quickshell 2>/dev/null || true
  fi

  if ! quickshell_installed_compatible; then
    log_info "Quickshell 0.3+ not in repos — compiling the current stable release from source..."
  
  log_info "Installing Quickshell build dependencies..."
  
  # Base dependencies (always required)
  QUICKSHELL_BASE_DEPS=(
    cmake
    ninja-build
    pkg-config
    spirv-tools
    # Qt6 core
    qt6-base-dev
    qt6-base-private-dev
    qt6-declarative-dev
    qt6-declarative-private-dev
    qt6-svg-dev
    # Wayland support
    qt6-wayland-dev
    libwayland-dev
    wayland-protocols
    # Services and buffers Quickshell builds by default (Debian's quickshell Build-Depends)
    libjemalloc-dev
    libpipewire-0.3-dev
    libpam0g-dev
    libpolkit-agent-1-dev
    libpolkit-gobject-1-dev
    libglib2.0-dev
    libdrm-dev
    libgbm-dev
    libegl-dev
    libgles-dev
    libvulkan-dev
    libxcb1-dev
  )

  # The crash handler needs cpptrace (Debian 13 backports and newer); build without it elsewhere.
  QUICKSHELL_CRASH_HANDLER=OFF
  if apt_pkg_available libcpptrace-dev; then
    QUICKSHELL_BASE_DEPS+=(libcpptrace-dev)
    QUICKSHELL_CRASH_HANDLER=ON
  fi
  
  # qt6-wayland-private-dev: only in trixie/sid, not bookworm
  if apt_pkg_available qt6-wayland-private-dev; then
    QUICKSHELL_BASE_DEPS+=(qt6-wayland-private-dev)
  fi
  
  # Qt6 ShaderTools - package name varies by distro/version
  # trixie/sid: qt6-shadertools-dev
  # bookworm: libqt6shadertools6-dev (may not exist)
  # Ubuntu 24.04+: qt6-shadertools-dev
  SHADERTOOLS_INSTALLED=false
  for pkg in qt6-shadertools-dev libqt6shadertools6-dev; do
    if apt_pkg_available "$pkg"; then
      QUICKSHELL_BASE_DEPS+=("$pkg")
      SHADERTOOLS_INSTALLED=true
      break
    fi
  done
  
  if ! $SHADERTOOLS_INSTALLED; then
    log_warning "Qt6 ShaderTools not found — Quickshell may fail to build"
    log_warning "Consider upgrading to Debian trixie/sid or Ubuntu 24.04+"
  fi
  
  # cli11 - header-only library, package name varies
  for pkg in libcli11-dev cli11-dev; do
    if apt_pkg_available "$pkg"; then
      QUICKSHELL_BASE_DEPS+=("$pkg")
      break
    fi
  done
  
  sudo apt install $installflags "${QUICKSHELL_BASE_DEPS[@]}" 2>/dev/null || {
    log_warning "Some quickshell deps failed, trying individually..."
    for pkg in "${QUICKSHELL_BASE_DEPS[@]}"; do
      sudo apt install $installflags "$pkg" 2>/dev/null || true
    done
  }
  
  QUICKSHELL_BUILD_DIR="${TMPDIR:-/tmp}/quickshell-build-$$"
  
  log_info "Cloning Quickshell..."
  if git clone --depth 1 --branch v0.3.1 --recursive https://github.com/quickshell-mirror/quickshell.git "$QUICKSHELL_BUILD_DIR"; then
    log_info "Building Quickshell (this may take a while)..."
    cd "$QUICKSHELL_BUILD_DIR"
    if cmake -B build -G Ninja \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=/usr/local \
      -DCRASH_HANDLER="$QUICKSHELL_CRASH_HANDLER" \
      -DSERVICE_PIPEWIRE=ON \
      -DSERVICE_PAM=ON \
      -DSERVICE_POLKIT=ON && cmake --build build -j$(nproc); then
      sudo cmake --install build
      log_success "Quickshell installed!"
    else
      log_error "Quickshell build failed (the output is above); retry with: ./setup install"
    fi
    cd "${REPO_ROOT}"
    rm -rf "$QUICKSHELL_BUILD_DIR"
  else
    log_error "Failed to clone Quickshell repository; once online run: ./setup install"
  fi
  fi
else
  log_success "Quickshell already installed"
fi
}

provider_cava() {
if ! command -v cava &>/dev/null; then
  log_info "Installing cava from source..."
  sudo apt install $installflags \
    libfftw3-dev \
    libasound2-dev \
    libpulse-dev \
    libpipewire-0.3-dev \
    libncursesw5-dev \
    libiniparser-dev \
    autoconf \
    automake \
    libtool 2>/dev/null || true
  
  CAVA_BUILD_DIR="${TMPDIR:-/tmp}/cava-build-$$"
  if git clone https://github.com/karlstav/cava.git "$CAVA_BUILD_DIR"; then
    cd "$CAVA_BUILD_DIR"
    if ./autogen.sh && ./configure && make -j$(nproc); then
      sudo make install
      log_success "cava installed"
    else
      log_warning "cava build failed, skipping"
    fi
    cd "${REPO_ROOT}"
    rm -rf "$CAVA_BUILD_DIR"
  fi
fi
}

debian_icon_themes() {
tui_info "Installing icon themes..."

ICON_DIR="$HOME/.local/share/icons"
mkdir -p "$ICON_DIR"

# WhiteSur icon theme
if [[ ! -d "$ICON_DIR/WhiteSur-dark" ]]; then
  log_info "Installing WhiteSur icon theme..."
  
  TEMP_DIR="${TMPDIR:-/tmp}/whitesur-icons-$$"
  mkdir -p "$TEMP_DIR"
  
  if curl -fsSL -o "$TEMP_DIR/whitesur.tar.gz" \
    "https://github.com/vinceliuice/WhiteSur-icon-theme/archive/refs/heads/master.tar.gz"; then
    tar -xzf "$TEMP_DIR/whitesur.tar.gz" -C "$TEMP_DIR"
    cd "$TEMP_DIR/WhiteSur-icon-theme-master"
    ./install.sh -d "$ICON_DIR" -t default >/dev/null 2>&1 || {
      cp -r src/WhiteSur "$ICON_DIR/WhiteSur" 2>/dev/null || true
      cp -r src/WhiteSur-dark "$ICON_DIR/WhiteSur-dark" 2>/dev/null || true
      cp -r src/WhiteSur-light "$ICON_DIR/WhiteSur-light" 2>/dev/null || true
    }
    cd - >/dev/null
    log_success "WhiteSur icon theme installed"
  fi
  
  rm -rf "$TEMP_DIR"
fi

# MacTahoe icon theme (dock icons)
if [[ ! -d "$ICON_DIR/MacTahoe" ]]; then
  log_info "Installing MacTahoe icon theme..."
  
  TEMP_DIR="${TMPDIR:-/tmp}/mactahoe-icons-$$"
  mkdir -p "$TEMP_DIR"
  
  if curl -fsSL -o "$TEMP_DIR/mactahoe.tar.gz" \
    "https://github.com/vinceliuice/MacTahoe-icon-theme/archive/refs/heads/main.tar.gz"; then
    tar -xzf "$TEMP_DIR/mactahoe.tar.gz" -C "$TEMP_DIR"
    cd "$TEMP_DIR/MacTahoe-icon-theme-main"
    ./install.sh -d "$ICON_DIR" >/dev/null 2>&1 || {
      cp -r src/MacTahoe "$ICON_DIR/MacTahoe" 2>/dev/null || true
    }
    cd - >/dev/null
    log_success "MacTahoe icon theme installed"
  fi
  
  rm -rf "$TEMP_DIR"
fi

#####################################################################################
# Cursor themes (Bibata, Capitaine)
#####################################################################################
tui_info "Installing cursor themes..."

CURSOR_DIR="$HOME/.local/share/icons"

# Bibata Modern Classic cursor
if [[ ! -d "$CURSOR_DIR/Bibata-Modern-Classic" ]]; then
  log_info "Installing Bibata Modern Classic cursor..."
  
  BIBATA_URL=$(curl -s "https://api.github.com/repos/ful1e5/Bibata_Cursor/releases/latest" | \
    jq -r '.assets[] | select(.name | test("Bibata-Modern-Classic.tar.xz$")) | .browser_download_url' | head -1)
  
  if [[ -n "$BIBATA_URL" && "$BIBATA_URL" != "null" ]]; then
    TEMP_DIR="${TMPDIR:-/tmp}/bibata-$$"
    mkdir -p "$TEMP_DIR"
    
    if curl -fsSL -o "$TEMP_DIR/bibata.tar.xz" "$BIBATA_URL"; then
      tar -xJf "$TEMP_DIR/bibata.tar.xz" -C "$CURSOR_DIR"
      log_success "Bibata Modern Classic cursor installed"
    fi
    
    rm -rf "$TEMP_DIR"
  fi
fi

# Bibata Modern Ice cursor
if [[ ! -d "$CURSOR_DIR/Bibata-Modern-Ice" ]]; then
  log_info "Installing Bibata Modern Ice cursor..."
  
  BIBATA_URL=$(curl -s "https://api.github.com/repos/ful1e5/Bibata_Cursor/releases/latest" | \
    jq -r '.assets[] | select(.name | test("Bibata-Modern-Ice.tar.xz$")) | .browser_download_url' | head -1)
  
  if [[ -n "$BIBATA_URL" && "$BIBATA_URL" != "null" ]]; then
    TEMP_DIR="${TMPDIR:-/tmp}/bibata-ice-$$"
    mkdir -p "$TEMP_DIR"
    
    if curl -fsSL -o "$TEMP_DIR/bibata.tar.xz" "$BIBATA_URL"; then
      tar -xJf "$TEMP_DIR/bibata.tar.xz" -C "$CURSOR_DIR"
      log_success "Bibata Modern Ice cursor installed"
    fi
    
    rm -rf "$TEMP_DIR"
  fi
fi

# Capitaine cursors (download from sainnhe fork with extra variants)
if [[ ! -d "$CURSOR_DIR/capitaine-cursors-light" ]]; then
  log_info "Installing Capitaine cursors..."
  
  CAPITAINE_URL=$(curl -s "https://api.github.com/repos/sainnhe/capitaine-cursors/releases/latest" | \
    jq -r '.assets[] | select(.name == "Linux.zip") | .browser_download_url' | head -1)
  
  if [[ -n "$CAPITAINE_URL" && "$CAPITAINE_URL" != "null" ]]; then
    TEMP_DIR="${TMPDIR:-/tmp}/capitaine-$$"
    mkdir -p "$TEMP_DIR"
    
    if curl -fsSL -o "$TEMP_DIR/capitaine.zip" "$CAPITAINE_URL"; then
      unzip -o "$TEMP_DIR/capitaine.zip" -d "$TEMP_DIR" >/dev/null 2>&1
      # Copy all cursor variants to icons dir
      for variant in "$TEMP_DIR"/capitaine-cursors*; do
        [[ -d "$variant" ]] && cp -r "$variant" "$CURSOR_DIR/"
      done
      # Also copy Capitaine Cursors variants (with spaces in name)
      for variant in "$TEMP_DIR"/Capitaine\ Cursors*; do
        [[ -d "$variant" ]] && cp -r "$variant" "$CURSOR_DIR/"
      done
      log_success "Capitaine cursors installed"
    fi
    
    rm -rf "$TEMP_DIR"
  else
    log_warning "Could not find Capitaine cursors release"
  fi
fi
}

provider_themes-download() { debian_gtk_themes && debian_icon_themes; }

# The package sources the rest needs: universe (Ubuntu), contrib and backports (Debian), DankLinux.
provider_repos() {
read_apt_components
if $IS_UBUNTU; then
  ensure_ubuntu_component "universe"
fi
if $IS_DEBIAN; then
  # translate-shell is distributed in Debian contrib. Enable the component on
  # the same mirror the user already trusts instead of adding a third-party
  # repository or silently leaving the translation feature unavailable.
  ensure_debian_component "contrib" || true
fi

# Quickshell and Hyprpicker are prebuilt in Debian 13 backports. Enable that
# official suite only when stable repositories do not already provide them.
if $IS_DEBIAN && [[ "$DEBIAN_CODENAME" == "trixie" ]]; then
  if ! apt_quickshell_compatible || ! apt_pkg_available hyprpicker; then
    ensure_debian_backports || true
  fi
fi

ensure_danklinux_repo || log_warning "DankLinux repository unavailable: niri, Quickshell and xwayland-satellite will be built from source"
log_repo_context
}
