# Install dependencies for iNiR on Debian/Ubuntu-based systems
# This script is meant to be sourced, not run directly.

# shellcheck shell=bash

#####################################################################################
# Verify we're on Debian/Ubuntu
#####################################################################################
if ! command -v apt >/dev/null 2>&1; then
  printf "${STY_RED}[$0]: apt not found. This script is for Debian/Ubuntu-based systems only.${STY_RST}\n"
  exit 1
fi

# Detect Ubuntu vs Debian for version-specific handling
IS_UBUNTU=false
IS_DEBIAN=false
UBUNTU_VERSION=""
DEBIAN_VERSION=""
DEBIAN_CODENAME=""

# Also detect Ubuntu derivatives (PikaOS, Pop!_OS, Linux Mint, etc.)
DISTRO_ID=$(grep "^ID=" /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')
DISTRO_ID_LIKE=$(grep "^ID_LIKE=" /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')
DISTRO_NAME=$(grep "^PRETTY_NAME=" /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')

if grep -qi "ubuntu" /etc/os-release 2>/dev/null || [[ "$DISTRO_ID_LIKE" == *"ubuntu"* ]]; then
  IS_UBUNTU=true
  # Try to get Ubuntu base version from derivative or actual Ubuntu
  UBUNTU_VERSION=$(grep "^VERSION_ID=" /etc/os-release | cut -d= -f2 | tr -d '"')
  # Some derivatives use UBUNTU_CODENAME
  UBUNTU_CODENAME=$(grep "^UBUNTU_CODENAME=" /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')
  tui_info "Detected ${DISTRO_NAME:-Ubuntu} (Ubuntu-based)"
elif [[ -f /etc/debian_version ]] || [[ "$DISTRO_ID_LIKE" == *"debian"* ]]; then
  IS_DEBIAN=true
  DEBIAN_VERSION=$(cat /etc/debian_version 2>/dev/null || echo "unknown")
  DEBIAN_CODENAME=$(grep "^VERSION_CODENAME=" /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')
  tui_info "Detected ${DISTRO_NAME:-Debian} (Debian-based)"
fi

# Detect architecture
ARCH=$(dpkg --print-architecture)
tui_info "Architecture: ${ARCH}"

#####################################################################################
# Optional: install only a specific list of missing deps
#####################################################################################
if [[ -n "${ONLY_MISSING_DEPS:-}" ]]; then
  tui_info "Installing missing dependencies only..."

  installflags=""
  $ask || installflags="-y"

  # Doctor reports command IDs, never package names. Keep this explicit so an
  # unknown command can never leak into apt as if it were a Debian package.
  declare -A cmd_to_pkg=(
    [qs]="quickshell" [niri]="niri" [nmcli]="network-manager" [wpctl]="wireplumber"
    [jq]="jq" [rsync]="rsync" [curl]="curl" [git]="git" [python3]="python3"
    [fish]="fish" [magick]="imagemagick" [grim]="grim" [cliphist]="cliphist"
    [wl-copy]="wl-clipboard" [wl-paste]="wl-clipboard" [fuzzel]="fuzzel"
    [hyprpicker]="hyprpicker" [playerctl]="playerctl" [notify-send]="libnotify-bin"
    [flock]="util-linux" [wlsunset]="wlsunset" [easyeffects]="easyeffects"
    [uv]="uv" [cava]="cava" [qalc]="qalc" [yt-dlp]="yt-dlp" [socat]="socat"
    [brightnessctl]="brightnessctl" [slurp]="slurp" [wf-recorder]="wf-recorder"
    [ffmpeg]="ffmpeg" [swappy]="swappy" [tesseract]="tesseract-ocr"
    [blueman-manager]="blueman" [kwriteconfig6]="libkf6config-bin" [ddcutil]="ddcutil"
    [nm-connection-editor]="network-manager-gnome" [xdg-settings]="xdg-utils" [mpv]="mpv"
    [swaylock]="swaylock" [swayidle]="swayidle" [trans]="translate-shell"
    [ocr-eng]="tesseract-ocr-eng" [ocr-spa]="tesseract-ocr-spa" [ocr-rus]="tesseract-ocr-rus"
    [ocr-jpn]="tesseract-ocr-jpn" [ocr-jpn-vert]="tesseract-ocr-jpn-vert"
    [ocr-chi-sim]="tesseract-ocr-chi-sim" [ocr-chi-sim-vert]="tesseract-ocr-chi-sim-vert"
    [ocr-chi-tra]="tesseract-ocr-chi-tra" [ocr-chi-tra-vert]="tesseract-ocr-chi-tra-vert"
  )

  _deb_miss_cmds=()
  _deb_requested_pkgs=()
  _deb_installable_pkgs=()
  _deb_special_cmds=()
  _deb_unresolved=()
  read -r -a _deb_miss_cmds <<<"$ONLY_MISSING_DEPS"

  for cmd in "${_deb_miss_cmds[@]}"; do
    case "$cmd" in
      awww|awww-daemon|gowall|missioncenter|songrec|xwayland-satellite)
        [[ " ${_deb_special_cmds[*]} " == *" ${cmd} "* ]] || _deb_special_cmds+=("$cmd")
        ;;
      checkupdates|go)
        # Legacy/Arch-only or build-only Doctor output.
        ;;
      *)
        _deb_pkg="${cmd_to_pkg[$cmd]:-}"
        if [[ -z "$_deb_pkg" ]]; then
          log_warning "No Debian repair mapping for Doctor command: $cmd"
          _deb_unresolved+=("$cmd")
        elif apt-cache show "$_deb_pkg" &>/dev/null 2>&1; then
          [[ " ${_deb_requested_pkgs[*]} " == *" ${_deb_pkg} "* ]] || _deb_requested_pkgs+=("$_deb_pkg")
        else
          log_warning "Debian package unavailable for $cmd: $_deb_pkg"
          _deb_unresolved+=("$cmd")
        fi
        ;;
    esac
  done

  if [[ ${#_deb_requested_pkgs[@]} -gt 0 ]]; then
    case ${SKIP_SYSUPDATE:-false} in
      true) log_info "Skipping system update" ;;
      *) v sudo apt update ;;
    esac
    sudo apt install $installflags "${_deb_requested_pkgs[@]}" || return 1
  fi

  # Providers which are not native apt packages. Mission Center intentionally
  # uses Flatpak on Debian; expose a host wrapper because iNiR's launcher and
  # Doctor work with executable commands, not desktop-file-only Flatpak apps.
  if [[ " ${_deb_special_cmds[*]} " == *" missioncenter " ]] && ! command -v missioncenter &>/dev/null; then
    sudo apt install $installflags flatpak >/dev/null 2>&1 || true
    if command -v flatpak &>/dev/null; then
      flatpak remote-add --if-not-exists --user flathub https://flathub.org/repo/flathub.flatpakrepo >/dev/null 2>&1 || true
      if flatpak install -y --user flathub io.missioncenter.MissionCenter >/dev/null 2>&1; then
        _mc_wrapper="$(mktemp /tmp/inir-missioncenter.XXXXXX)"
        printf '%s\n' '#!/bin/sh' 'exec flatpak run io.missioncenter.MissionCenter "$@"' > "$_mc_wrapper"
        sudo install -m 0755 "$_mc_wrapper" /usr/local/bin/missioncenter
        rm -f "$_mc_wrapper"
      fi
    fi
  fi

  if [[ " ${_deb_special_cmds[*]} " == *" gowall " ]] && ! command -v gowall &>/dev/null; then
    sudo apt install $installflags golang-go >/dev/null 2>&1 || true
    if command -v go &>/dev/null; then
      _gowall_build="$(mktemp -d /tmp/inir-gowall.XXXXXX)"
      if git clone --depth 1 https://github.com/Achno/gowall.git "$_gowall_build/src" >/dev/null 2>&1 \
          && (cd "$_gowall_build/src" && go build -o "$_gowall_build/gowall" . >/dev/null 2>&1); then
        sudo install -m 0755 "$_gowall_build/gowall" /usr/local/bin/gowall
      fi
      rm -rf "$_gowall_build"
    fi
  fi

  # The remaining special providers already have mature paths later in the full
  # Debian installer (repository/PPA first, then source). Re-enter once with the
  # missing-only flag cleared; package checks make already-satisfied work cheap.
  _deb_need_full_provider=false
  for cmd in "${_deb_special_cmds[@]}"; do
    case "$cmd" in awww|awww-daemon|songrec|xwayland-satellite) _deb_need_full_provider=true ;; esac
  done
  unset ONLY_MISSING_DEPS
  if $_deb_need_full_provider; then
    SKIP_SYSUPDATE=true
    source "${REPO_ROOT}/sdata/dist-debian/install-deps.sh"
  fi

  for cmd in "${_deb_special_cmds[@]}"; do
    case "$cmd" in
      awww|awww-daemon) command -v awww &>/dev/null && command -v awww-daemon &>/dev/null || _deb_unresolved+=("awww") ;;
      *) command -v "$cmd" &>/dev/null || _deb_unresolved+=("$cmd") ;;
    esac
  done

  if [[ ${#_deb_unresolved[@]} -gt 0 ]]; then
    log_error "Could not repair Debian dependencies: $(printf '%s ' "${_deb_unresolved[@]}")"
    return 1
  fi
  return 0
fi

#####################################################################################
# Version warnings
#####################################################################################
if $IS_UBUNTU; then
  case "$UBUNTU_VERSION" in
    22.04|22.10)
      log_warning "Ubuntu ${UBUNTU_VERSION} has older Qt6 packages — Ubuntu 24.04+ recommended"
      ;;
  esac
fi

if $IS_DEBIAN; then
  case "$DEBIAN_VERSION" in
    11*|10*|9*)
      log_error "Debian ${DEBIAN_VERSION} is too old — Qt6 requires Debian 12 (bookworm) or newer"
      exit 1
      ;;
  esac
fi

#####################################################################################
# System update
#####################################################################################
case ${SKIP_SYSUPDATE:-false} in
  true)
    log_info "Skipping system update"
    ;;
  *)
    tui_info "Updating system..."
    v sudo apt update
    v sudo apt upgrade -y
    ;;
esac

#####################################################################################
# Repository context & package availability
#####################################################################################
installflags=""
$ask || installflags="-y"

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

  v sudo add-apt-repository -y "$component" || {
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

  if apt-cache show "$pkg" &>/dev/null 2>&1; then
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

  if ! v sudo apt update; then
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
  if ! v sudo apt update; then
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
log_repo_context

#####################################################################################
# Install official repository packages
#####################################################################################
tui_info "Installing packages from official repositories..."

# Core system packages
DEBIAN_CORE_PKGS=(
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
  wl-clipboard
  libnotify-bin
  wlsunset
  dunst
  unzip
  
  # XDG Portals
  xdg-desktop-portal
  xdg-desktop-portal-gtk
  xdg-desktop-portal-gnome
  
  # Network
  network-manager
  gnome-keyring
  
  # File manager
  nautilus
  
  # KDE frameworks (CRITICAL — Quickshell needs these at runtime)
  libkf6syntaxhighlighting6
  qml6-module-org-kde-kirigami
  kdialog
  
  # Terminal
  kitty
  
  # Shell (required for scripts)
  fish
  
  # Thumbnails
  ffmpegthumbnailer
  tumbler
  
  # Translation widget
  translate-shell
  
  # Build essentials (needed for compiling niri/quickshell)
  build-essential
  cmake
  ninja-build
  pkg-config

  # Icon themes - fallbacks (always available from repos)
  hicolor-icon-theme
  adwaita-icon-theme
  papirus-icon-theme
)

# Prefer distro packages whenever the currently enabled suite provides them.
# This covers Debian 13 backports and newer Debian/Ubuntu derivatives while
# leaving the existing source/release fallbacks intact elsewhere.
for pkg in quickshell niri xwayland-satellite awww starship eza uv; do
  if [[ "$pkg" == "quickshell" ]] && ! apt_quickshell_compatible; then
    continue
  fi
  if apt_pkg_available "$pkg"; then
    DEBIAN_CORE_PKGS+=("$pkg")
  fi
done

# Polkit package names changed in Debian 13. Keep Bookworm/Ubuntu compatibility
# while ensuring Trixie receives both the daemon/tools and a graphical agent.
if apt_pkg_available policykit-1; then
  DEBIAN_CORE_PKGS+=(policykit-1)
else
  apt_pkg_available polkitd && DEBIAN_CORE_PKGS+=(polkitd)
  apt_pkg_available pkexec && DEBIAN_CORE_PKGS+=(pkexec)
fi
if apt_pkg_available policykit-1-gnome; then
  DEBIAN_CORE_PKGS+=(policykit-1-gnome)
elif apt_pkg_available polkit-kde-agent-1; then
  DEBIAN_CORE_PKGS+=(polkit-kde-agent-1)
fi

# Qt6 packages - ONLY dev packages, runtime libs are auto-installed as dependencies
# This avoids conflicts with t64 transition packages (libqt6core6t64 vs libqt6core6)
DEBIAN_QT6_PKGS=(
  # Core Qt6 development (runtime libs installed as deps)
  qt6-base-dev
  qt6-declarative-dev
  libqt6svg6-dev
  qt6-wayland-dev
  qt6-5compat-dev
  qt6-multimedia-dev
  qt6-image-formats-plugins
  
  # System libs
  libjemalloc-dev
  libpipewire-0.3-dev
  libxcb1-dev
  libwayland-dev
  libdrm-dev
  
  # KDE integration
  kdialog
  
  # Qt theming
  qt6ct
  kde-config-gtk-style
  breeze-gtk-theme
)

# Audio packages
DEBIAN_AUDIO_PKGS=(
  pipewire
  pipewire-pulse
  pipewire-alsa
  wireplumber
  playerctl
  plasma-browser-integration
  libdbusmenu-gtk3-4
  pavucontrol
  easyeffects
  mpv
  yt-dlp
  socat
)

# Toolkit packages
DEBIAN_TOOLKIT_PKGS=(
  upower
  wtype
  ydotool
  python3-evdev
  python3-pil
  python3-cairo
  libgirepository-2.0-dev
  brightnessctl
  ddcutil
  geoclue-2.0
  swayidle
  swaylock
  grim
  slurp
  imagemagick
  blueman
  fprintd
  tesseract-ocr
  tesseract-ocr-eng
  tesseract-ocr-spa
  tesseract-ocr-rus
  tesseract-ocr-jpn
  tesseract-ocr-jpn-vert
  tesseract-ocr-chi-sim
  tesseract-ocr-chi-sim-vert
  tesseract-ocr-chi-tra
  tesseract-ocr-chi-tra-vert
)

if apt_pkg_available hyprpicker; then
  DEBIAN_TOOLKIT_PKGS+=(hyprpicker)
fi

# Screen capture packages
DEBIAN_SCREENCAPTURE_PKGS=(
  grim
  slurp
  wf-recorder
  imagemagick
  ffmpeg
  tesseract-ocr
  tesseract-ocr-eng
  tesseract-ocr-spa
  tesseract-ocr-rus
  tesseract-ocr-jpn
  tesseract-ocr-jpn-vert
  tesseract-ocr-chi-sim
  tesseract-ocr-chi-sim-vert
  tesseract-ocr-chi-tra
  tesseract-ocr-chi-tra-vert
)

# Check if swappy is available (only in trixie/sid, not bookworm)
if apt_pkg_available swappy; then
  DEBIAN_SCREENCAPTURE_PKGS+=(swappy)
fi

# Font packages
DEBIAN_FONT_PKGS=(
  fontconfig
  fonts-dejavu
  fonts-liberation
  fonts-noto-color-emoji
  fonts-jetbrains-mono
  
  # Launcher
  fuzzel
  
  # Qt theming
  kvantum
)

# Wayland packages - only dev packages, runtime libs installed as deps
DEBIAN_WAYLAND_PKGS=(
  wayland-protocols
  libwayland-dev
  libxkbcommon-dev
)

# Check if cliphist is available in repos (Ubuntu 24.04+, PikaOS, etc.)
if apt_pkg_available cliphist; then
  DEBIAN_CORE_PKGS+=(cliphist)
fi

# Check if gum is available in repos (PikaOS has it)
if apt_pkg_available gum; then
  DEBIAN_CORE_PKGS+=(gum)
fi

# Check if cava is available in repos
if apt_pkg_available cava; then
  DEBIAN_AUDIO_PKGS+=(cava)
fi

if apt_pkg_available songrec; then
  DEBIAN_AUDIO_PKGS+=(songrec)
fi

# Check if qalculate-qt is available (preferred over qalculate)
if apt_pkg_available qalculate-qt; then
  DEBIAN_TOOLKIT_PKGS+=(qalculate-qt)
elif apt_pkg_available qalculate-gtk; then
  DEBIAN_TOOLKIT_PKGS+=(qalculate-gtk)
fi

# Check if kf6-kconfig is available (Ubuntu 24.04+, Debian trixie+)
if apt_pkg_available kf6-kconfig; then
  DEBIAN_FONT_PKGS+=(kf6-kconfig)
fi

# Fix any broken packages first
log_info "Fixing any broken packages..."
sudo apt --fix-broken install -y 2>/dev/null || true

# Helper function to install packages with fallback
install_packages() {
  local pkg_array_name="$1"
  local description="$2"
  local -n pkgs="$pkg_array_name"

  filter_available_packages "$pkg_array_name"

  if [[ ${#pkgs[@]} -eq 0 ]]; then
    log_warning "No ${description} available in current repositories, skipping"
    return 0
  fi

  log_info "Installing ${description}..."

  # Try to install all at once first
  if sudo apt install $installflags "${pkgs[@]}" 2>/dev/null; then
    return 0
  fi

  # If that fails, try one by one (skip unavailable)
  log_warning "Batch install failed, trying packages individually..."
  local failed_pkgs=()
  for pkg in "${pkgs[@]}"; do
    if ! sudo apt install $installflags "$pkg" 2>/dev/null; then
      failed_pkgs+=("$pkg")
    fi
  done

  if [[ ${#failed_pkgs[@]} -gt 0 ]]; then
    log_warning "Could not install: ${failed_pkgs[*]}"
  fi
}

# Install core packages
install_packages DEBIAN_CORE_PKGS "core packages"

# Install Qt6 packages
install_packages DEBIAN_QT6_PKGS "Qt6 packages"

# Install Wayland packages
install_packages DEBIAN_WAYLAND_PKGS "Wayland packages"

# Install based on flags
if ${INSTALL_AUDIO:-true}; then
  install_packages DEBIAN_AUDIO_PKGS "audio packages"
fi

if ${INSTALL_TOOLKIT:-true}; then
  install_packages DEBIAN_TOOLKIT_PKGS "toolkit packages"
fi

if ${INSTALL_SCREENCAPTURE:-true}; then
  install_packages DEBIAN_SCREENCAPTURE_PKGS "screen capture packages"
fi

if ${INSTALL_FONTS:-true}; then
  install_packages DEBIAN_FONT_PKGS "font packages"
fi

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
  
  local temp_dir="/tmp/${name}-install-$$"
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

#####################################################################################
# Install packages from GitHub releases (precompiled binaries)
#####################################################################################
tui_info "Installing packages from GitHub releases..."

# gum - TUI tool (download .deb from GitHub if not in repos)
if ! command -v gum &>/dev/null; then
  log_info "Installing gum from GitHub..."
  GUM_DEB_URL=$(curl -s "https://api.github.com/repos/charmbracelet/gum/releases/latest" | \
    jq -r ".assets[] | select(.name | test(\"_${ARCH}.deb$\")) | .browser_download_url" | head -1)
  if [[ -n "$GUM_DEB_URL" && "$GUM_DEB_URL" != "null" ]]; then
    TEMP_DEB="/tmp/gum-$$.deb"
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

# cliphist - clipboard manager (if not in repos)
if ! command -v cliphist &>/dev/null; then
  install_github_binary "cliphist" "sentriz/cliphist" "linux-amd64$"
fi

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
    SONGREC_DEPS=(
      build-essential
      libasound2-dev
      libgtk-3-dev
      libssl-dev
      pkg-config
    )
    sudo apt install $installflags "${SONGREC_DEPS[@]}" 2>/dev/null || true
    
    # Rust is only needed when the repository/PPA paths above were unavailable.
    if ensure_rust_toolchain; then
      SONGREC_ROOT="$(mktemp -d /tmp/inir-songrec.XXXXXX)"
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

# Mission Center - Debian/Ubuntu provider. Flathub is the cross-distro
# package source already documented by iNiR; add a host command wrapper so the
# launcher and Doctor can treat it like every other configured application.
if ! command -v missioncenter &>/dev/null; then
  log_info "Installing Mission Center from Flathub..."
  sudo apt install $installflags flatpak >/dev/null 2>&1 || true
  if command -v flatpak &>/dev/null; then
    flatpak remote-add --if-not-exists --user flathub https://flathub.org/repo/flathub.flatpakrepo >/dev/null 2>&1 || true
    if flatpak install -y --user flathub io.missioncenter.MissionCenter >/dev/null 2>&1; then
      _mc_wrapper="$(mktemp /tmp/inir-missioncenter.XXXXXX)"
      printf '%s\n' '#!/bin/sh' 'exec flatpak run io.missioncenter.MissionCenter "$@"' > "$_mc_wrapper"
      sudo install -m 0755 "$_mc_wrapper" /usr/local/bin/missioncenter
      rm -f "$_mc_wrapper"
      log_success "Mission Center installed"
    else
      log_warning "Mission Center Flatpak installation failed"
    fi
  fi
fi

# Gowall - no stable Debian package is assumed. Build the tiny Go CLI only when
# the exposed wallpaper editor needs its command and it is not already present.
if ${INSTALL_TOOLKIT:-true} && ! command -v gowall &>/dev/null; then
  log_info "Installing gowall wallpaper editor..."
  sudo apt install $installflags golang-go >/dev/null 2>&1 || true
  if command -v go &>/dev/null; then
    _gowall_build="$(mktemp -d /tmp/inir-gowall.XXXXXX)"
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

# darkly - Qt theme (download .deb from GitHub)
if ${INSTALL_FONTS:-true}; then
  if ! dpkg -l 2>/dev/null | grep -q darkly; then
    log_info "Installing darkly theme from GitHub..."
    DARKLY_DEB_URL=$(curl -s "https://api.github.com/repos/Bali10050/darkly/releases/latest" | \
      jq -r '.assets[] | select(.name | test("debian.*amd64.deb$")) | .browser_download_url' | head -1)
    
    if [[ -n "$DARKLY_DEB_URL" && "$DARKLY_DEB_URL" != "null" ]]; then
      TEMP_DEB="/tmp/darkly-$$.deb"
      curl -fsSL -o "$TEMP_DEB" "$DARKLY_DEB_URL"
      sudo dpkg -i "$TEMP_DEB" || sudo apt install -f -y
      rm -f "$TEMP_DEB"
      log_success "darkly installed"
    fi
  fi
fi

# adw-gtk3 - GTK3/4 theme (download tarball from GitHub)
if ${INSTALL_FONTS:-true}; then
  THEME_DIR="$HOME/.local/share/themes"
  if [[ ! -d "$THEME_DIR/adw-gtk3" ]]; then
    log_info "Installing adw-gtk3 theme from GitHub..."
    mkdir -p "$THEME_DIR"
    
    ADW_GTK3_URL=$(curl -s "https://api.github.com/repos/lassekongo83/adw-gtk3/releases/latest" | \
      jq -r '.assets[] | select(.name | test("adw-gtk3.*\\.tar\\.xz$")) | .browser_download_url' | head -1)
    
    if [[ -n "$ADW_GTK3_URL" && "$ADW_GTK3_URL" != "null" ]]; then
      TEMP_DIR="/tmp/adw-gtk3-$$"
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
      TEMP_DEB="/tmp/twemoji-$$.deb"
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

# swappy - screenshot annotation (not in bookworm, compile from source)
if ${INSTALL_SCREENCAPTURE:-true}; then
  if ! command -v swappy &>/dev/null; then
    log_info "Installing swappy from source..."
    sudo apt install $installflags libgtk-3-dev libcairo2-dev libpango1.0-dev scdoc 2>/dev/null || true
    
    SWAPPY_BUILD_DIR="/tmp/swappy-build-$$"
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

#####################################################################################
# Install uv (Python package manager) - from official installer
#####################################################################################
tui_info "Installing uv (Python package manager)..."

# Ensure ~/.local/bin is in PATH (uv installs there)
export PATH="$HOME/.local/bin:$PATH"

if ! command -v uv &>/dev/null; then
  curl -LsSf https://astral.sh/uv/install.sh | sh 2>/dev/null || {
    if command -v cargo &>/dev/null; then
      cargo install uv
    fi
  }
  # Re-add to PATH after install
  export PATH="$HOME/.local/bin:$PATH"
fi

# Debian 13 carries both tools directly. Older Debian/Ubuntu releases retain
# the project's upstream installers instead of silently missing shell helpers.
if ! command -v starship &>/dev/null; then
  install-starship
fi
if ! command -v eza &>/dev/null; then
  install-eza
fi

#####################################################################################
# Install Niri (PPA for Ubuntu 25.10+, compile for others)
#####################################################################################
tui_info "Installing Niri compositor..."

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
      log_error "Niri source fallback requires Rust"
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
    
    NIRI_BUILD_DIR="/tmp/niri-build-$$"
    
    log_info "Cloning Niri..."
    if git clone https://github.com/YaLTeR/niri.git "$NIRI_BUILD_DIR"; then
      log_info "Building Niri (this may take a while)..."
      cd "$NIRI_BUILD_DIR"
      if cargo build --release; then
        log_info "Installing Niri..."
        sudo cp target/release/niri /usr/local/bin/
        sudo cp resources/niri.desktop /usr/share/wayland-sessions/ 2>/dev/null || true
        sudo cp resources/niri-portals.conf /usr/share/xdg-desktop-portal/ 2>/dev/null || true
        log_success "Niri installed!"
      else
        log_error "Niri build failed!"
      fi
      cd "${REPO_ROOT}"
      rm -rf "$NIRI_BUILD_DIR"
    else
      log_error "Failed to clone Niri repository"
    fi
  fi
else
  log_success "Niri already installed"
fi

#####################################################################################
# Install xwayland-satellite
#####################################################################################
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
    libxcb-render0-dev \
    libxcb-xfixes0-dev \
    libclang-dev 2>/dev/null || true
  
  # xwayland-satellite is not on crates.io, must compile from source
  XWSAT_BUILD_DIR="/tmp/xwayland-satellite-build-$$"
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

#####################################################################################
# Install awww (wallpaper daemon)
#####################################################################################
if ! command -v awww &>/dev/null; then
  log_info "Installing awww (wallpaper daemon)..."

  if ! ensure_rust_toolchain; then
    log_warning "awww source fallback requires Rust"
  else

  # awww needs libxkbcommon and lz4
  sudo apt install $installflags libxkbcommon-dev liblz4-dev 2>/dev/null || true

  AWWW_BUILD_DIR="/tmp/awww-build-$$"
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

#####################################################################################
# Install hyprpicker (Wayland color picker - compile from source)
#####################################################################################
tui_info "Installing hyprpicker..."

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
    HYPRUTILS_BUILD_DIR="/tmp/hyprutils-build-$$"
    
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
    HYPRPICKER_BUILD_DIR="/tmp/hyprpicker-build-$$"
    
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

#####################################################################################
# Install Quickshell (0.3+ required for Quickshell.Networking and other APIs)
#####################################################################################
tui_info "Installing Quickshell..."

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
    libqt6svg6-dev
    # Wayland support
    qt6-wayland-dev
    libwayland-dev
    wayland-protocols
    # Optional but recommended
    libjemalloc-dev
    libpipewire-0.3-dev
    libpam0g-dev
    libdrm-dev
    libgbm-dev
    libxcb1-dev
  )
  
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
  
  QUICKSHELL_BUILD_DIR="/tmp/quickshell-build-$$"
  
  log_info "Cloning Quickshell..."
  if git clone --depth 1 --branch v0.3.1 --recursive https://github.com/quickshell-mirror/quickshell.git "$QUICKSHELL_BUILD_DIR"; then
    log_info "Building Quickshell (this may take a while)..."
    cd "$QUICKSHELL_BUILD_DIR"
    if cmake -B build -G Ninja \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=/usr/local \
      -DSERVICE_PIPEWIRE=ON \
      -DSERVICE_PAM=ON && cmake --build build -j$(nproc); then
      sudo cmake --install build
      log_success "Quickshell installed!"
    else
      log_error "Quickshell build failed!"
    fi
    cd "${REPO_ROOT}"
    rm -rf "$QUICKSHELL_BUILD_DIR"
  else
    log_error "Failed to clone Quickshell repository"
  fi
  fi
else
  log_success "Quickshell already installed"
fi

#####################################################################################
# Install cava if not available in repos
#####################################################################################
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
  
  CAVA_BUILD_DIR="/tmp/cava-build-$$"
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

#####################################################################################
# Install critical fonts
#####################################################################################
tui_info "Installing critical fonts..."

FONT_DIR="$HOME/.local/share/fonts"
mkdir -p "$FONT_DIR"

# JetBrains Mono Nerd Font
if ! fc-list | grep -qi "JetBrainsMono Nerd"; then
  log_info "Downloading JetBrains Mono Nerd Font..."
  
  NERD_FONTS_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
  TEMP_DIR="/tmp/nerdfonts-$$"
  mkdir -p "$TEMP_DIR"
  
  if curl -fsSL -o "$TEMP_DIR/JetBrainsMono.zip" "$NERD_FONTS_URL"; then
    unzip -o "$TEMP_DIR/JetBrainsMono.zip" -d "$FONT_DIR" >/dev/null 2>&1
    fc-cache -f "$FONT_DIR"
    log_success "JetBrains Mono Nerd Font installed"
  fi
  
  rm -rf "$TEMP_DIR"
fi

# Material Symbols fonts (CRITICAL - UI icons)
if ! fc-list | grep -qi "Material Symbols Rounded"; then
  log_info "Downloading Material Symbols Rounded font..."
  
  MATERIAL_URL="https://raw.githubusercontent.com/google/material-design-icons/master/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf"
  
  if curl -fsSL -o "$FONT_DIR/MaterialSymbolsRounded.ttf" "$MATERIAL_URL"; then
    log_success "Material Symbols Rounded font installed"
  else
    log_error "CRITICAL: Could not download Material Symbols — UI icons will be broken!"
  fi
fi

if ! fc-list | grep -qi "Material Symbols Outlined"; then
  log_info "Downloading Material Symbols Outlined font..."
  
  MATERIAL_URL="https://raw.githubusercontent.com/google/material-design-icons/master/variablefont/MaterialSymbolsOutlined%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf"
  
  if curl -fsSL -o "$FONT_DIR/MaterialSymbolsOutlined.ttf" "$MATERIAL_URL"; then
    log_success "Material Symbols Outlined font installed"
  fi
fi

# Refresh font cache
fc-cache -f "$FONT_DIR" 2>/dev/null

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
  
  TEMP_DIR="/tmp/mactahoe-icons-$$"
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
    TEMP_DIR="/tmp/bibata-$$"
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
    TEMP_DIR="/tmp/bibata-ice-$$"
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
    TEMP_DIR="/tmp/capitaine-$$"
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

#####################################################################################
# Post-install summary
#####################################################################################
echo ""
log_success "════════════════════════════════════════════════════════════════"
log_success "  Debian/Ubuntu dependencies installed!"
log_success "════════════════════════════════════════════════════════════════"
echo ""

if [[ ${#MISSING_REPO_PKGS[@]} -gt 0 ]]; then
  log_warning "Packages missing from current repositories:"
  printf '  - %s\n' $(printf "%s\n" "${MISSING_REPO_PKGS[@]}" | awk 'NF{print $1}' | sort -u)
  echo ""
fi
log_info "Repository-first packages:"
echo "  - Debian 13: quickshell/hyprpicker from trixie-backports; starship/eza from stable"
echo "  - Ubuntu/derivatives: configured distro repositories are preferred whenever available"
echo ""
log_info "Fallback downloads/builds when repositories do not provide a dependency:"
echo "  - gum, cliphist, darkly, songrec (PPA/Cargo)"
echo "  - twemoji-color-font, adw-gtk3 theme"
echo "  - Material Symbols fonts, JetBrains Mono Nerd Font"
echo "  - WhiteSur, MacTahoe icon themes"
echo "  - Bibata, Capitaine cursor themes"
echo ""
echo "  - source fallback remains for niri, quickshell, xwayland-satellite, hyprpicker, cava, swappy, awww"
echo ""

# Verify critical commands
tui_info "Verifying installation:"
for cmd in qs niri fish gum cliphist; do
  if command -v "$cmd" &>/dev/null; then
    log_success "$cmd"
  else
    log_error "$cmd not found"
  fi
done
echo ""

# Run compatibility fixes for Debian/Ubuntu QML stack
if [[ -f "${SCRIPT_DIR}/../lib/compat-debian.sh" ]]; then
  bash "${SCRIPT_DIR}/../lib/compat-debian.sh"
fi

# PATH reminder
if [[ ":$PATH:" != *":$HOME/.cargo/bin:"* ]] || [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
  log_info "Add to your shell config (~/.bashrc or ~/.config/fish/config.fish):"
  echo '  export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"'
  echo ""
fi
