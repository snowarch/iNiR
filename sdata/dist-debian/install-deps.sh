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

source "${REPO_ROOT}/sdata/dist-debian/providers.sh"
debian_detect
if $IS_UBUNTU; then
  tui_info "Detected ${DISTRO_NAME:-Ubuntu} (Ubuntu-based)"
elif $IS_DEBIAN; then
  tui_info "Detected ${DISTRO_NAME:-Debian} (Debian-based)"
fi
tui_info "Architecture: ${ARCH}"

#####################################################################################
# Optional: install only a specific list of missing deps
#####################################################################################
if [[ -n "${ONLY_MISSING_DEPS:-}" ]]; then
  tui_info "Installing missing dependencies only..."
  # not a package: the recipe picks what this machine takes and turns it on, once apt's lists are fresh
  _deb_power_profiles=false
  if [[ " $ONLY_MISSING_DEPS " == *" power-profiles "* ]]; then
    _deb_power_profiles=true
    ONLY_MISSING_DEPS="$(tr ' ' '\n' <<<"$ONLY_MISSING_DEPS" | grep -vx power-profiles | xargs)"
  fi

  installflags=""
  $ask || installflags="-y"

  # Doctor reports command IDs, never package names. Keep this explicit so an
  # unknown command can never leak into apt as if it were a Debian package.
  declare -A cmd_to_pkg=(
    [qs]="quickshell" [niri]="niri" [nmcli]="network-manager" [wpctl]="wireplumber" [pw-dump]="pipewire-bin"
    [jq]="jq" [rsync]="rsync" [curl]="curl" [git]="git" [python3]="python3"
    [cairo-headers]="libcairo2-dev" [gi-headers]="libgirepository-2.0-dev" [dbus-headers]="libdbus-1-dev"
    [fish]="fish" [magick]="imagemagick" [grim]="grim" [cliphist]="cliphist"
    [wl-copy]="wl-clipboard" [wl-paste]="wl-clipboard"
    [hyprpicker]="hyprpicker" [playerctl]="playerctl" [notify-send]="libnotify-bin"
    [flock]="util-linux" [wlsunset]="wlsunset" [easyeffects]="easyeffects"
    [uv]="uv" [cava]="cava" [qalc]="qalc" [yt-dlp]="yt-dlp" [socat]="socat"
    [brightnessctl]="brightnessctl" [slurp]="slurp" [wf-recorder]="wf-recorder"
    [ffmpeg]="ffmpeg" [swappy]="swappy" [tesseract]="tesseract-ocr"
    [blueman-manager]="blueman" [kwriteconfig6]="libkf6config-bin" [ddcutil]="ddcutil"
    [nm-connection-editor]="network-manager-gnome" [xdg-settings]="xdg-utils" [mpv]="mpv"
    [swaylock]="swaylock" [swayidle]="swayidle" [trans]="translate-shell"
    [lsp-plugins-lv2]="lsp-plugins-lv2"
    [ocr-eng]="tesseract-ocr-eng" [ocr-spa]="tesseract-ocr-spa" [ocr-rus]="tesseract-ocr-rus"
    [ocr-jpn]="tesseract-ocr-jpn" [ocr-jpn-vert]="tesseract-ocr-jpn-vert"
    [ocr-chi-sim]="tesseract-ocr-chi-sim" [ocr-chi-sim-vert]="tesseract-ocr-chi-sim-vert"
    [ocr-chi-tra]="tesseract-ocr-chi-tra" [ocr-chi-tra-vert]="tesseract-ocr-chi-tra-vert"
    [plasma-integration]="plasma-integration" [font-noto-color-emoji]="fonts-noto-color-emoji"
  )

  _deb_miss_cmds=()
  _deb_requested_pkgs=()
  _deb_installable_pkgs=()
  _deb_special_cmds=()
  _deb_unresolved=()
  _deb_deferred=()
  read -r -a _deb_miss_cmds <<<"$ONLY_MISSING_DEPS"

  # Candidates come from the package index; an empty or stale one makes every package look
  # unavailable. Refreshing the index is not a system upgrade, so SKIP_SYSUPDATE does not apply.
  v sudo apt update
  if $_deb_power_profiles; then
    provider_power-profiles || log_warning "power-profiles-daemon could not be installed; the profile buttons stay off"
  fi

  for cmd in "${_deb_miss_cmds[@]}"; do
    case "$cmd" in
      awww|awww-daemon|gowall|missioncenter|songrec|xwayland-satellite|niri-session)
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
        elif [[ "$(apt-cache policy "$_deb_pkg" 2>/dev/null | awk '/Candidate:/ { print $2; exit }')" =~ ^[^\(] ]]; then
          [[ " ${_deb_requested_pkgs[*]} " == *" ${_deb_pkg} "* ]] || _deb_requested_pkgs+=("$_deb_pkg")
        elif [[ "$cmd" == qs || "$cmd" == niri ]]; then
          # Not in the archive: the full installer brings them from the PPA or builds them.
          _deb_special_cmds+=("$cmd")
        else
          # Not in the enabled archives (translate-shell is in contrib, hyprpicker in backports): the full
          # installer enables those and has source fallbacks, so defer instead of failing here.
          _deb_deferred+=("$cmd:$_deb_pkg")
        fi
        ;;
    esac
  done

  if [[ ${#_deb_requested_pkgs[@]} -gt 0 ]]; then
    sudo apt install $installflags "${_deb_requested_pkgs[@]}" || return 1
  fi

  # Providers which are not native apt packages. Mission Center intentionally
  # uses Flatpak on Debian; expose a host wrapper because iNiR's launcher and
  # Doctor work with executable commands, not desktop-file-only Flatpak apps.
  if [[ " ${_deb_special_cmds[*]} " == *" missioncenter " ]] && ! command -v missioncenter &>/dev/null; then
    sudo apt install $installflags flatpak >/dev/null 2>&1 || true
    if command -v flatpak &>/dev/null; then
      flatpak remote-add --if-not-exists --user flathub https://flathub.org/repo/flathub.flatpakrepo >/dev/null 2>&1 || true
      _mc_log="$(mktemp /tmp/inir-missioncenter-log.XXXXXX)"
      if flatpak install -y --user flathub io.missioncenter.MissionCenter >"$_mc_log" 2>&1; then
        _mc_wrapper="$(mktemp /tmp/inir-missioncenter.XXXXXX)"
        printf '%s\n' '#!/bin/sh' 'exec flatpak run io.missioncenter.MissionCenter "$@"' > "$_mc_wrapper"
        sudo install -m 0755 "$_mc_wrapper" /usr/local/bin/missioncenter
        rm -f "$_mc_wrapper"
      else
        log_warning "Mission Center Flatpak installation failed: $(tail -n 3 "$_mc_log" | tr '\n' ' ')"
      fi
      rm -f "$_mc_log"
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
  [[ ${#_deb_deferred[@]} -gt 0 ]] && _deb_need_full_provider=true
  for cmd in "${_deb_special_cmds[@]}"; do
    case "$cmd" in awww|awww-daemon|songrec|xwayland-satellite|qs|niri|niri-session) _deb_need_full_provider=true ;; esac
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

  for _deb_item in "${_deb_deferred[@]}"; do
    cmd="${_deb_item%%:*}" _deb_pkg="${_deb_item#*:}"
    command -v "$cmd" &>/dev/null \
      || dpkg-query -W -f='${Status}' "$_deb_pkg" 2>/dev/null | grep -q 'install ok installed' \
      || _deb_unresolved+=("$cmd")
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
# iNiR needs Qt 6.9 or newer (QtQuick.Effects shadows, typed nested functions); Quickshell itself
# needs 6.6. Stop early instead of failing after a long source build.
if $IS_UBUNTU; then
  case "$UBUNTU_VERSION" in
    2[0-4].*|25.04)
      log_error "Ubuntu ${UBUNTU_VERSION} ships Qt older than 6.9, which iNiR needs. Use Ubuntu 26.04 LTS or newer."
      exit 1
      ;;
  esac
fi

if $IS_DEBIAN; then
  case "$DEBIAN_VERSION" in
    12*|11*|10*|9*)
      log_error "Debian ${DEBIAN_VERSION} ships Qt older than 6.9, which iNiR needs. Use Debian 14 (forky) or testing."
      exit 1
      ;;
    13*)
      log_warning "Debian 13 ships Qt 6.8; iNiR needs 6.9. Some surfaces may not load until Qt 6.9 is available (testing or backports)."
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


provider_repos

#####################################################################################
# Install official repository packages
#####################################################################################
tui_info "Installing packages from official repositories..."

# Core system packages
DEBIAN_CORE_PKGS=(
  # Basic utilities
  coreutils
  curl
  ripgrep
  jq
  xdg-user-dirs
  rsync
  git
  wl-clipboard
  libnotify-bin
  wlsunset
  unzip
  
  # XDG Portals
  xdg-desktop-portal
  xdg-desktop-portal-gtk
  xdg-desktop-portal-gnome
  
  # Network (network-manager-gnome: nm-connection-editor, the network panel's advanced settings)
  network-manager
  network-manager-gnome
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
  # pycairo, pygobject and dbus-python build in the venv
  libcairo2-dev
  libgirepository-2.0-dev
  libdbus-1-dev

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

# Polkit daemon and pkexec (split into polkitd/pkexec in Debian 13). No graphical
# agent: the shell answers password requests itself.
if apt_pkg_available policykit-1; then
  DEBIAN_CORE_PKGS+=(policykit-1)
else
  apt_pkg_available polkitd && DEBIAN_CORE_PKGS+=(polkitd)
  apt_pkg_available pkexec && DEBIAN_CORE_PKGS+=(pkexec)
fi

# Qt6 packages - ONLY dev packages, runtime libs are auto-installed as dependencies
# This avoids conflicts with t64 transition packages (libqt6core6t64 vs libqt6core6)
DEBIAN_QT6_PKGS=(
  # Core Qt6 development (runtime libs installed as deps)
  qt6-base-dev
  qt6-declarative-dev
  qt6-svg-dev
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
  pavucontrol
  easyeffects
  lsp-plugins-lv2
  mpv
  yt-dlp
  socat
)

# Toolkit packages
DEBIAN_TOOLKIT_PKGS=(
  upower
  wtype
  ydotool
  python3-pil
  python3-cairo
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
  # KDE platform theme: Qt apps follow the shell colors (doctor checks for it).
  plasma-integration
  fonts-dejavu
  fonts-liberation
  fonts-noto-color-emoji
  fonts-jetbrains-mono
  
  # Launcher
  
)

# Kvantum is qt6-style-kvantum on Ubuntu and qt-style-kvantum on Debian 13.
for _kvantum_pkg in qt6-style-kvantum qt-style-kvantum kvantum; do
  if apt_pkg_available "$_kvantum_pkg"; then
    DEBIAN_FONT_PKGS+=("$_kvantum_pkg")
    break
  fi
done

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

# The launcher's math runs the qalc CLI; the GUI is extra (qalculate-qt preferred).
DEBIAN_TOOLKIT_PKGS+=(qalc)
if apt_pkg_available qalculate-qt; then
  DEBIAN_TOOLKIT_PKGS+=(qalculate-qt)
elif apt_pkg_available qalculate-gtk; then
  DEBIAN_TOOLKIT_PKGS+=(qalculate-gtk)
fi

# kwriteconfig6 (KDE color schemes). kf6-kconfig is only the source package's name.
if apt_pkg_available libkf6config-bin; then
  DEBIAN_FONT_PKGS+=(libkf6config-bin)
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
# Install packages from GitHub releases (precompiled binaries)
#####################################################################################
tui_info "Installing packages from GitHub releases..."

provider_gum

provider_cliphist

provider_songrec

provider_missioncenter

provider_gowall

provider_power-profiles || log_warning "power-profiles-daemon could not be installed; the profile buttons stay off"

provider_darkly

debian_gtk_themes

provider_swappy

#####################################################################################
# Install uv (Python package manager) - from official installer
#####################################################################################
tui_info "Installing uv (Python package manager)..."

# Ensure ~/.local/bin is in PATH (uv installs there)
export PATH="$HOME/.local/bin:$PATH"

provider_uv

provider_starship-eza

#####################################################################################
# Install Niri (PPA for Ubuntu 25.10+, compile for others)
#####################################################################################
tui_info "Installing Niri compositor..."

provider_niri || return 1

#####################################################################################
# Install xwayland-satellite
#####################################################################################
provider_xwayland-satellite

#####################################################################################
# Install awww (wallpaper daemon)
#####################################################################################
provider_awww

#####################################################################################
# Install hyprpicker (Wayland color picker - compile from source)
#####################################################################################
tui_info "Installing hyprpicker..."

provider_hyprpicker

#####################################################################################
# Install Quickshell (0.3+ required for Quickshell.Networking and other APIs)
#####################################################################################
tui_info "Installing Quickshell..."

provider_quickshell

#####################################################################################
# Install cava if not available in repos
#####################################################################################
provider_cava

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
debian_icon_themes

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

# PATH reminder
if [[ ":$PATH:" != *":$HOME/.cargo/bin:"* ]] || [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
  log_info "Add to your shell config (~/.bashrc or ~/.config/fish/config.fish):"
  echo '  export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"'
  echo ""
fi
