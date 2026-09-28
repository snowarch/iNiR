# Install dependencies for iNiR on Fedora-based systems
# This script is meant to be sourced, not run directly.

# shellcheck shell=bash

#####################################################################################
# Verify we're on Fedora
#####################################################################################
if ! command -v dnf >/dev/null 2>&1; then
  printf "${STY_RED}[$0]: dnf not found. This script is for Fedora-based systems only.${STY_RST}\n"
  exit 1
fi

# Check for immutable variants
if is_immutable_distro 2>/dev/null; then
  printf "${STY_YELLOW}[$0]: Detected immutable Fedora variant (${OS_SPECIFIC_ID}).${STY_RST}\n"
  printf "${STY_YELLOW}[$0]: You may need to use rpm-ostree or toolbox for some packages.${STY_RST}\n"
  printf "${STY_YELLOW}[$0]: Consider using Flatpak for applications where available.${STY_RST}\n"
  echo ""
fi

# Detect Fedora version
FEDORA_VERSION=$(rpm -E %fedora)
tui_info "Detected Fedora ${FEDORA_VERSION}"

dnf_pkg_available() {
  local pkg="$1"
  dnf -q list --available "$pkg" &>/dev/null || dnf -q list --installed "$pkg" &>/dev/null
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

install_songrec_fedora() {
  command -v songrec &>/dev/null && return 0
  ensure_fedora_rust_toolchain || return 1
  sudo dnf install -y \
    alsa-lib-devel pulseaudio-libs-devel pipewire-devel openssl-devel dbus-devel \
    pkgconf-pkg-config glib2-devel gtk4-devel libsoup3-devel libadwaita-devel \
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

#####################################################################################
# Optional: install only a specific list of missing deps
#####################################################################################
if [[ -n "${ONLY_MISSING_DEPS:-}" ]]; then
  tui_info "Installing missing dependencies only..."

  # Doctor reports command IDs, not package names. Keep this mapping exhaustive
  # for Fedora and never pass an unknown command ID directly to dnf.
  declare -A cmd_to_pkg=(
    [qs]="quickshell" [niri]="niri" [nmcli]="NetworkManager" [wpctl]="wireplumber"
    [jq]="jq" [rsync]="rsync" [curl]="curl" [git]="git" [python3]="python3"
    [fish]="fish" [magick]="ImageMagick" [grim]="grim" [cliphist]="cliphist"
    [wl-copy]="wl-clipboard" [wl-paste]="wl-clipboard" [fuzzel]="fuzzel"
    [hyprpicker]="hyprpicker" [playerctl]="playerctl" [notify-send]="libnotify"
    [flock]="util-linux" [wlsunset]="wlsunset" [easyeffects]="easyeffects"
    [uv]="uv" [cava]="cava" [qalc]="qalculate" [yt-dlp]="yt-dlp"
    [socat]="socat" [brightnessctl]="brightnessctl" [slurp]="slurp"
    [wf-recorder]="wf-recorder" [ffmpeg]="ffmpeg" [swappy]="swappy"
    [tesseract]="tesseract" [blueman-manager]="blueman" [kwriteconfig6]="kf6-kconfig"
    [ddcutil]="ddcutil" [nm-connection-editor]="nm-connection-editor"
    [xdg-settings]="xdg-utils" [mpv]="mpv" [swaylock]="swaylock"
    [swayidle]="swayidle" [trans]="translate-shell"
    [ocr-eng]="tesseract-langpack-eng" [ocr-spa]="tesseract-langpack-spa"
    [ocr-rus]="tesseract-langpack-rus" [ocr-jpn]="tesseract-langpack-jpn"
    [ocr-jpn-vert]="tesseract-langpack-jpn_vert"
    [ocr-chi-sim]="tesseract-langpack-chi_sim" [ocr-chi-sim-vert]="tesseract-langpack-chi_sim_vert"
    [ocr-chi-tra]="tesseract-langpack-chi_tra" [ocr-chi-tra-vert]="tesseract-langpack-chi_tra_vert"
  )

  _fed_installflags=""
  $ask || _fed_installflags="-y"
  _fed_miss_cmds=()
  _fed_miss_pkgs=()
  _fed_special_cmds=()
  _fed_unresolved=()
  read -r -a _fed_miss_cmds <<<"$ONLY_MISSING_DEPS"

  for cmd in "${_fed_miss_cmds[@]}"; do
    case "$cmd" in
      awww|awww-daemon|gowall|missioncenter|songrec)
        [[ " ${_fed_special_cmds[*]} " == *" ${cmd} "* ]] || _fed_special_cmds+=("$cmd")
        ;;
      checkupdates|go)
        # Legacy Doctor output from older iNiR versions. Neither is a Fedora
        # runtime dependency: checkupdates is Arch-only and Go is only a build fallback.
        ;;
      *)
        _fed_pkg="${cmd_to_pkg[$cmd]:-}"
        if [[ -z "$_fed_pkg" ]]; then
          log_warning "No Fedora repair mapping for Doctor command: $cmd"
          _fed_unresolved+=("$cmd")
        elif dnf_pkg_available "$_fed_pkg"; then
          [[ " ${_fed_miss_pkgs[*]} " == *" ${_fed_pkg} "* ]] || _fed_miss_pkgs+=("$_fed_pkg")
        else
          log_warning "Fedora package unavailable for $cmd: $_fed_pkg"
          _fed_unresolved+=("$cmd")
        fi
        ;;
    esac
  done

  if [[ ${#_fed_miss_pkgs[@]} -gt 0 ]]; then
    case ${SKIP_SYSUPDATE:-false} in
      true) log_info "Skipping system update" ;;
      *) v sudo dnf upgrade -y --refresh ;;
    esac

    if [[ " ${_fed_miss_pkgs[*]} " == *" quickshell " ]] && ! fedora_quickshell_compatible; then
      if ! dnf copr list --enabled 2>/dev/null | grep -q "errornointernet/quickshell"; then
        ensure_copr_support && v sudo dnf copr enable -y errornointernet/quickshell
      fi
    fi
    if [[ " ${_fed_miss_pkgs[*]} " == *" niri " ]] && ! dnf_pkg_available niri; then
      if ! dnf copr list --enabled 2>/dev/null | grep -q "yalter/niri"; then
        ensure_copr_support && v sudo dnf copr enable -y yalter/niri
      fi
    fi

    v sudo dnf install $_fed_installflags --allowerasing "${_fed_miss_pkgs[@]}" || return 1
  fi

  # Special providers do not correspond 1:1 to a Fedora package name.
  for cmd in "${_fed_special_cmds[@]}"; do
    case "$cmd" in
      awww|awww-daemon)
        if ! command -v awww &>/dev/null || ! command -v awww-daemon &>/dev/null; then
          install_awww_fedora || _fed_unresolved+=("awww")
        fi
        ;;
      gowall) install_gowall_fedora || _fed_unresolved+=("gowall") ;;
      missioncenter) install_missioncenter_fedora || _fed_unresolved+=("missioncenter") ;;
      songrec) install_songrec_fedora || _fed_unresolved+=("songrec") ;;
    esac
  done

  unset ONLY_MISSING_DEPS
  if [[ ${#_fed_unresolved[@]} -gt 0 ]]; then
    log_error "Could not repair Fedora dependencies: $(printf '%s ' "${_fed_unresolved[@]}")"
    return 1
  fi
  return 0
fi

#####################################################################################
# System update (optional)
#####################################################################################
case ${SKIP_SYSUPDATE:-false} in
  true)
    log_info "Skipping system update"
    ;;
  *)
    tui_info "Updating system..."
    v sudo dnf upgrade -y --refresh
    ;;
esac

#####################################################################################
# Enable compatibility COPR repositories when official repos do not provide
# the package. This keeps Fedora 43 / derivative support without routing modern
# Fedora installs through third-party repositories unnecessarily.
#####################################################################################
tui_info "Checking Fedora package sources..."

# Fedora 44+ has a quickshell package, but iNiR currently needs Quickshell 0.3+.
# Prefer an official package as soon as Fedora catches up; until then use the
# release COPR rather than silently installing an incompatible 0.2.x runtime.
if fedora_quickshell_compatible; then
  log_info "Compatible Quickshell available from configured Fedora repositories"
elif ! dnf copr list --enabled 2>/dev/null | grep -q "errornointernet/quickshell"; then
  log_info "Quickshell 0.3+ not in configured repos — enabling release COPR..."
  ensure_copr_support && v sudo dnf copr enable -y errornointernet/quickshell || {
    log_error "Failed to enable Quickshell COPR"
    log_warning "Install quickshell from a compatible repository and rerun setup"
  }
fi

# Niri is official on supported Fedora releases; retain COPR for derivatives
# or older Fedora installations whose repository set does not include it.
if dnf_pkg_available niri; then
  log_info "Niri available from configured Fedora repositories"
elif ! dnf copr list --enabled 2>/dev/null | grep -q "yalter/niri"; then
  log_info "Niri not in configured repos — enabling compatibility COPR..."
  ensure_copr_support && v sudo dnf copr enable -y yalter/niri
fi

#####################################################################################
# Enable RPM Fusion Free (for ffmpeg, etc.)
#####################################################################################
tui_info "Checking RPM Fusion Free..."

if ! rpm -q rpmfusion-free-release &>/dev/null; then
  v sudo dnf install -y \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VERSION}.noarch.rpm"
fi

#####################################################################################
# Install official repository packages
#####################################################################################
tui_info "Installing packages from repositories..."

# Core system packages (including Quickshell and Niri from COPR)
FEDORA_CORE_PKGS=(
  # Niri is official. Quickshell uses the same package name from either Fedora
  # (once it provides >=0.3) or the release COPR selected above.
  quickshell
  niri

  # Login manager required by the shipped ii-pixel login theme.
  sddm
  
  # Build tools (needed for Python packages like dbus-python, pycairo, pygobject)
  gcc
  gcc-c++
  make
  meson
  ninja-build
  cmake
  pkg-config
  python3-devel
  dbus-devel
  cairo-devel
  cairo-gobject-devel
  gobject-introspection-devel
  gtk3-devel
  glib2-devel
  
  # Basic utilities
  bc
  coreutils
  curl
  wget
  ripgrep
  jq
  xdg-user-dirs
  rsync
  git
  unzip
  wl-clipboard
  libnotify
  wlsunset
  dunst
  gum
  cliphist
  uv
  eza
  
  # XDG Portals
  xdg-desktop-portal
  xdg-desktop-portal-gtk
  xdg-desktop-portal-gnome
  
  # Polkit
  polkit
  
  # Network
  NetworkManager
  nm-connection-editor
  gnome-keyring
  
  # File manager
  nautilus
  
  # Terminal - kitty is default, configurable in Settings
  kitty
  
  # Shell (required for scripts)
  fish
  
  # X11 compatibility
  xwayland-satellite
  
  # Thumbnails
  ffmpegthumbnailer
  tumbler
  
  # Translation
  translate-shell
)

# Qt6 packages
FEDORA_QT6_PKGS=(
  qt6-qtbase
  qt6-qtdeclarative
  qt6-qtsvg
  qt6-qtwayland
  qt6-qt5compat
  qt6-qtmultimedia
  qt6-qtimageformats
  qt6-qtvirtualkeyboard
  qt6-qtpositioning
  qt6-qtsensors
  qt6-qttools
  
  # System libs
  jemalloc
  libxcb
  libdrm
  mesa-dri-drivers
  
  # KDE integration
  kf6-kirigami
  kdialog
  kf6-syntax-highlighting
  
  # Qt theming
  qt6ct
  kde-gtk-config
  breeze-gtk
)

# Audio packages
FEDORA_AUDIO_PKGS=(
  pipewire
  pipewire-pulseaudio
  pipewire-alsa
  wireplumber
  playerctl
  plasma-browser-integration
  libdbusmenu-gtk3
  pavucontrol
  cava
  easyeffects
  lsp-plugins-lv2
  mpv
  yt-dlp
  socat
)

# Toolkit packages
FEDORA_TOOLKIT_PKGS=(
  upower
  wtype
  ydotool
  python3-evdev
  python3-pillow
  brightnessctl
  ddcutil
  geoclue2
  swayidle
  swaylock
  grim
  slurp
  hyprpicker
  ImageMagick
  qalculate
  blueman
  fprintd
  kf6-kconfig
  tesseract
  tesseract-langpack-eng
  tesseract-langpack-spa
  tesseract-langpack-rus
  tesseract-langpack-jpn
  tesseract-langpack-jpn_vert
  tesseract-langpack-chi_sim
  tesseract-langpack-chi_sim_vert
  tesseract-langpack-chi_tra
  tesseract-langpack-chi_tra_vert
)

# Screen capture packages
# Note: ffmpeg from rpmfusion conflicts with ffmpeg-free, use --allowerasing
FEDORA_SCREENCAPTURE_PKGS=(
  grim
  slurp
  swappy
  wf-recorder
  ImageMagick
  tesseract
  tesseract-langpack-eng
  tesseract-langpack-spa
  tesseract-langpack-rus
  tesseract-langpack-jpn
  tesseract-langpack-jpn_vert
  tesseract-langpack-chi_sim
  tesseract-langpack-chi_sim_vert
  tesseract-langpack-chi_tra
  tesseract-langpack-chi_tra_vert
)

# Font packages
FEDORA_FONT_PKGS=(
  fontconfig
  dejavu-fonts-all
  liberation-fonts
  google-noto-emoji-fonts
  jetbrains-mono-fonts-all
  
  # Launcher
  fuzzel
  glib2
  
  # Qt theming
  kvantum

  # Icon themes - fallbacks (always available from repos)
  hicolor-icon-theme
  adwaita-icon-theme
  papirus-icon-theme
)

installflags=""
$ask || installflags="-y"

# Build one repository transaction from the selected feature groups. Fedora's
# package manager already resolves the dependency graph; splitting this into six
# transactions only repeats metadata/dependency work and makes partial failures
# harder to reason about.
FEDORA_REPO_PKGS=("${FEDORA_CORE_PKGS[@]}" "${FEDORA_QT6_PKGS[@]}")
${INSTALL_AUDIO:-true} && FEDORA_REPO_PKGS+=("${FEDORA_AUDIO_PKGS[@]}")
${INSTALL_TOOLKIT:-true} && FEDORA_REPO_PKGS+=("${FEDORA_TOOLKIT_PKGS[@]}")
${INSTALL_SCREENCAPTURE:-true} && FEDORA_REPO_PKGS+=("${FEDORA_SCREENCAPTURE_PKGS[@]}")
${INSTALL_FONTS:-true} && FEDORA_REPO_PKGS+=("${FEDORA_FONT_PKGS[@]}")

mapfile -t FEDORA_REPO_PKGS < <(printf '%s\n' "${FEDORA_REPO_PKGS[@]}" | awk 'NF' | sort -u)
FEDORA_INSTALLABLE_PKGS=()
FEDORA_REPO_FALLBACK_PKGS=()
for pkg in "${FEDORA_REPO_PKGS[@]}"; do
  if [[ "$pkg" == "quickshell" ]] && ! fedora_quickshell_compatible; then
    FEDORA_REPO_FALLBACK_PKGS+=("$pkg")
    continue
  fi
  if dnf_pkg_available "$pkg"; then
    FEDORA_INSTALLABLE_PKGS+=("$pkg")
  else
    FEDORA_REPO_FALLBACK_PKGS+=("$pkg")
  fi
done

if [[ ${#FEDORA_INSTALLABLE_PKGS[@]} -gt 0 ]]; then
  log_info "Installing ${#FEDORA_INSTALLABLE_PKGS[@]} packages from Fedora/RPM Fusion repositories..."
  if ! v sudo dnf install $installflags --allowerasing "${FEDORA_INSTALLABLE_PKGS[@]}"; then
    log_warning "Fedora package batch failed — retrying individually"
    for pkg in "${FEDORA_INSTALLABLE_PKGS[@]}"; do
      sudo dnf install $installflags --allowerasing "$pkg" >/dev/null 2>&1 || \
        FEDORA_REPO_FALLBACK_PKGS+=("$pkg")
    done
  fi
fi

if [[ ${#FEDORA_REPO_FALLBACK_PKGS[@]} -gt 0 ]]; then
  log_warning "Not available from configured Fedora repositories: ${FEDORA_REPO_FALLBACK_PKGS[*]}"
fi
unset FEDORA_REPO_PKGS FEDORA_INSTALLABLE_PKGS

if ! fedora_quickshell_compatible; then
  log_error "Quickshell 0.3+ is required by iNiR but is unavailable from the configured Fedora repositories"
  log_warning "Fedora's current official quickshell package is 0.2.x; enable a compatible Quickshell repository and rerun setup"
  return 1
fi

#####################################################################################
# Install packages from GitHub releases (precompiled binaries)
#####################################################################################
tui_info "Installing packages from GitHub releases..."

ARCH=$(uname -m)
case "$ARCH" in
  x86_64) ARCH_SUFFIX="amd64" ;;
  aarch64) ARCH_SUFFIX="arm64" ;;
  *) ARCH_SUFFIX="$ARCH" ;;
esac

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

# Fedora 43 did not ship cliphist, while newer releases do. Keep the existing
# upstream static-binary route only as a fallback after the configured mirrors
# have been tried, so Fedora 44+ never need GitHub for this dependency.
if ! command -v cliphist &>/dev/null; then
  install_github_binary "cliphist" "sentriz/cliphist" "linux-${ARCH_SUFFIX}$" || \
    log_warning "cliphist is still missing — clipboard history will not work until it is installed"
fi

# hyprpicker was retired from current Fedora releases, but its build-time
# libraries (hyprutils + hyprwayland-scanner) are official packages. Compile
# only the tiny picker itself when the user's configured repos do not carry it;
# this avoids enabling a broad Hyprland COPR that could replace unrelated
# system packages.
if ${INSTALL_TOOLKIT:-true} && ! command -v hyprpicker &>/dev/null; then
  tui_info "Installing hyprpicker fallback..."
  HYPRPICKER_BUILD_DEPS=(
    cmake
    gcc-c++
    ninja-build
    cairo-devel
    libjpeg-turbo-devel
    pango-devel
    wayland-devel
    wayland-protocols-devel
    libxkbcommon-devel
    hyprutils-devel
    hyprwayland-scanner-devel
  )
  if sudo dnf install -y "${HYPRPICKER_BUILD_DEPS[@]}" >/dev/null 2>&1; then
    HYPRPICKER_BUILD_DIR="/tmp/hyprpicker-build-$$"
    if git clone --depth 1 --branch v0.4.7 https://github.com/hyprwm/hyprpicker.git "$HYPRPICKER_BUILD_DIR" 2>/dev/null; then
      if cmake -S "$HYPRPICKER_BUILD_DIR" -B "$HYPRPICKER_BUILD_DIR/build" \
          -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr \
          >/dev/null 2>&1 \
          && cmake --build "$HYPRPICKER_BUILD_DIR/build" >/dev/null 2>&1 \
          && sudo cmake --install "$HYPRPICKER_BUILD_DIR/build" >/dev/null 2>&1; then
        log_success "hyprpicker installed from upstream source"
      else
        log_warning "hyprpicker source build failed"
      fi
    else
      log_warning "Could not reach hyprpicker upstream; install the Fedora-compatible package manually"
    fi
    rm -rf "$HYPRPICKER_BUILD_DIR"
  else
    log_warning "Could not install hyprpicker build dependencies"
  fi
  unset HYPRPICKER_BUILD_DEPS HYPRPICKER_BUILD_DIR
fi

# Non-repository runtime providers. These are required by exposed iNiR
# features, so a successful fresh install must leave their host commands usable.
if ! install_awww_fedora; then
  log_warning "awww/awww-daemon are still missing — the internal wallpaper renderer will be used"
fi
if ${INSTALL_TOOLKIT:-true} && ! install_gowall_fedora; then
  log_warning "gowall is still missing — wallpaper editing effects will be unavailable"
fi
if ! install_missioncenter_fedora; then
  log_warning "Mission Center is still missing — configure another task manager in Settings"
fi
if ${INSTALL_AUDIO:-true} && ! install_songrec_fedora; then
  log_warning "songrec is still missing — music recognition will be unavailable"
fi

# darkly - Qt theme (download .rpm from GitHub)
if ${INSTALL_FONTS:-true}; then
  if ! rpm -q darkly &>/dev/null; then
    log_info "Installing darkly theme from GitHub..."
    DARKLY_RPM_URL=$(curl -s "https://api.github.com/repos/Bali10050/darkly/releases/latest" | \
      jq -r ".assets[] | select(.name | test(\"fc${FEDORA_VERSION}.*x86_64.rpm$\")) | .browser_download_url" | head -1)
    
    # Fallback to any Fedora RPM if exact version not found
    if [[ -z "$DARKLY_RPM_URL" || "$DARKLY_RPM_URL" == "null" ]]; then
      DARKLY_RPM_URL=$(curl -s "https://api.github.com/repos/Bali10050/darkly/releases/latest" | \
        jq -r '.assets[] | select(.name | test("fc[0-9]+.*x86_64.rpm$")) | .browser_download_url' | head -1)
    fi
    
    if [[ -n "$DARKLY_RPM_URL" && "$DARKLY_RPM_URL" != "null" ]]; then
      v sudo dnf install -y "$DARKLY_RPM_URL"
    else
      log_warning "darkly RPM not found for Fedora ${FEDORA_VERSION}"
    fi
  fi
fi

#####################################################################################
# uv fallback for Fedora derivatives that do not carry the package
#####################################################################################
if ! command -v uv &>/dev/null; then
  tui_info "Installing uv fallback..."
  curl -LsSf https://astral.sh/uv/install.sh | sh 2>/dev/null || {
    if command -v cargo &>/dev/null; then
      cargo install uv
    else
      log_warning "Could not install uv"
    fi
  }
fi

#####################################################################################
# Install critical fonts
#####################################################################################
tui_info "Installing critical fonts..."

FONT_DIR="$HOME/.local/share/fonts"
mkdir -p "$FONT_DIR"

# Material Symbols Rounded (icons) - this is the font iNiR actually uses
if ! fc-list | grep -qi "Material Symbols Rounded"; then
  log_info "Downloading Material Symbols Rounded font..."
  
  # Direct download from raw.githubusercontent
  MATERIAL_URL="https://raw.githubusercontent.com/google/material-design-icons/master/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf"
  
  if curl -fsSL -o "$FONT_DIR/MaterialSymbolsRounded.ttf" "$MATERIAL_URL"; then
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
  
  if curl -fsSL -o "$FONT_DIR/MaterialSymbolsOutlined.ttf" "$MATERIAL_URL"; then
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
  
  if curl -fsSL -o "$TEMP_DIR/JetBrainsMono.zip" "$NERD_FONTS_URL"; then
    unzip -o "$TEMP_DIR/JetBrainsMono.zip" -d "$FONT_DIR" >/dev/null 2>&1
    fc-cache -f "$FONT_DIR"
    log_success "JetBrains Mono Nerd Font installed"
  else
    log_warning "Could not download JetBrains Mono Nerd Font"
  fi
  
  rm -rf "$TEMP_DIR"
fi

#####################################################################################
# Icon themes (WhiteSur, MacTahoe)
#####################################################################################
tui_info "Installing icon themes..."

ICON_DIR="$HOME/.local/share/icons"
mkdir -p "$ICON_DIR"

# WhiteSur icon theme
if [[ ! -d "$ICON_DIR/WhiteSur-dark" ]]; then
  log_info "Installing WhiteSur icon theme..."
  
  TEMP_DIR="/tmp/whitesur-icons-$$"
  mkdir -p "$TEMP_DIR"
  
  if curl -fsSL -o "$TEMP_DIR/whitesur.tar.gz" \
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
  
  if curl -fsSL -o "$TEMP_DIR/mactahoe.tar.gz" \
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

#####################################################################################
# Cursor themes
#####################################################################################
tui_info "Installing cursor themes..."

# Bibata Modern cursors (popular, well-maintained)
if [[ ! -d "$ICON_DIR/Bibata-Modern-Classic" ]]; then
  log_info "Installing Bibata cursor theme..."
  
  TEMP_DIR="/tmp/bibata-cursors-$$"
  mkdir -p "$TEMP_DIR"
  
  # Download Bibata Modern Classic (dark)
  if curl -fsSL -o "$TEMP_DIR/bibata-classic.tar.xz" \
    "https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/Bibata-Modern-Classic.tar.xz"; then
    tar -xf "$TEMP_DIR/bibata-classic.tar.xz" -C "$ICON_DIR"
    log_success "Bibata Modern Classic cursor installed"
  fi
  
  # Download Bibata Modern Ice (light)
  if curl -fsSL -o "$TEMP_DIR/bibata-ice.tar.xz" \
    "https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/Bibata-Modern-Ice.tar.xz"; then
    tar -xf "$TEMP_DIR/bibata-ice.tar.xz" -C "$ICON_DIR"
    log_success "Bibata Modern Ice cursor installed"
  fi
  
  rm -rf "$TEMP_DIR"
fi

#####################################################################################
# Optional fonts (nice to have)
#####################################################################################
tui_info "Installing optional fonts..."

# Space Grotesk
if ! fc-list | grep -qi "Space Grotesk"; then
  log_info "Downloading Space Grotesk font..."
  curl -fsSL -o "$FONT_DIR/SpaceGrotesk.ttf" \
    "https://github.com/floriankarsten/space-grotesk/raw/master/fonts/ttf/SpaceGrotesk%5Bwght%5D.ttf" 2>/dev/null && \
    log_success "Space Grotesk installed"
fi

# Rubik
if ! fc-list | grep -qi "Rubik"; then
  log_info "Downloading Rubik font..."
  curl -fsSL -o "$FONT_DIR/Rubik.ttf" \
    "https://github.com/googlefonts/rubik/raw/main/fonts/variable/Rubik%5Bwght%5D.ttf" 2>/dev/null && \
    log_success "Rubik installed"
fi

# Geist (used by default in iNiR)
if ! fc-list | grep -qi "Geist"; then
  log_info "Downloading Geist font..."
  TEMP_DIR="/tmp/geist-font-$$"
  mkdir -p "$TEMP_DIR"
  if curl -fsSL -o "$TEMP_DIR/geist.zip" \
    "https://github.com/vercel/geist-font/releases/latest/download/Geist.zip"; then
    unzip -o "$TEMP_DIR/geist.zip" -d "$TEMP_DIR" >/dev/null 2>&1
    find "$TEMP_DIR" -name "*.ttf" -exec cp {} "$FONT_DIR/" \;
    log_success "Geist font installed"
  fi
  rm -rf "$TEMP_DIR"
fi

# Refresh font cache
fc-cache -f "$FONT_DIR" 2>/dev/null

#####################################################################################
# Install CLI tools (starship, eza)
#####################################################################################
tui_info "Installing CLI tools..."

# Starship prompt
if ! command -v starship &>/dev/null; then
  log_info "Installing Starship prompt..."
  mkdir -p ~/.local/bin
  curl -sS https://starship.rs/install.sh | sh -s -- -y -b ~/.local/bin 2>/dev/null || \
    log_warning "Could not install Starship"
fi

# Eza is in Fedora repositories; keep the release binary as a derivative/
# restricted-repository fallback only.
if ! command -v eza &>/dev/null; then
  log_info "Installing Eza..."
  mkdir -p ~/.local/bin
  if curl -fsSL -o /tmp/eza.tar.gz \
    'https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-musl.tar.gz'; then
    tar -xzf /tmp/eza.tar.gz -C ~/.local/bin
    chmod +x ~/.local/bin/eza
    log_success "Eza installed"
  fi
  rm -f /tmp/eza.tar.gz
fi

#####################################################################################
# Install adw-gtk3 theme
#####################################################################################
tui_info "Installing GTK themes..."

if ! rpm -q adw-gtk3-theme &>/dev/null; then
  v sudo dnf install -y adw-gtk3-theme
fi

#####################################################################################
# Install polkit-e (for authentication dialogs)
#####################################################################################
tui_info "Installing polkit agent..."

if ! rpm -q polkit-kde &>/dev/null; then
  v sudo dnf install -y polkit-kde
fi

#####################################################################################
# Setup configuration files
#####################################################################################
tui_info "Setting up configuration files..."

# GTK configuration
setup-gtk-config "Bibata-Modern-Classic" "WhiteSur-dark" "adw-gtk3-dark" "Geist"

# Kvantum configuration
setup-kvantum-config "MaterialAdw"

# Environment variables
setup-environment-config "Bibata-Modern-Classic"

# Terminal configuration
setup-kitty-config
setup-foot-config

# Fish shell configuration
setup-fish-config

#####################################################################################
# Post-install summary
#####################################################################################
echo ""
log_success "════════════════════════════════════════════════════════════════"
log_success "  Fedora dependencies installed!"
log_success "════════════════════════════════════════════════════════════════"
echo ""
log_info "Fedora package sources:"
echo "  - niri: Fedora repositories (COPR fallback when unavailable)"
echo "  - quickshell: compatible Fedora package when >=0.3, otherwise release COPR"
echo "  - awww: scottames/awww COPR (upstream source fallback)"
echo "  - gowall: achno/gowall COPR (upstream source fallback)"
echo ""
log_info "Installed from repos:"
echo "  - gum, cliphist (Fedora 44+), xwayland-satellite, swappy, uv, eza"
echo ""
log_info "Fallback sources when Fedora lacks a package:"
echo "  - cliphist/static release, hyprpicker/source, darkly RPM, starship installer"
echo ""
log_info "Themes configured:"
echo "  - GTK: adw-gtk3-dark"
echo "  - Icons: WhiteSur-dark, MacTahoe"
echo "  - Cursor: Bibata-Modern-Classic"
echo "  - Qt/Kvantum: MaterialAdw + Darkly"
echo ""

# Verify critical commands
tui_info "Verifying installation:"
for cmd in qs niri fish gum cliphist xwayland-satellite starship eza; do
  if command -v "$cmd" &>/dev/null || command -v ~/.local/bin/$cmd &>/dev/null; then
    log_success "$cmd"
  else
    log_error "$cmd not found"
  fi
done
echo ""

# Detect and show polkit agent path
POLKIT_AGENT=$(get-polkit-agent 2>/dev/null)
if [[ -n "$POLKIT_AGENT" ]]; then
  log_info "Polkit agent: $POLKIT_AGENT"
  log_info "Update your niri config spawn-at-startup if this differs"
fi
echo ""
