# Install dependencies for iNiR on Void Linux
# This script is meant to be sourced, not run directly.

# shellcheck shell=bash

if ! command -v xbps-install >/dev/null 2>&1; then
  printf "${STY_RED}[$0]: xbps-install not found. This script is for Void Linux only.${STY_RST}\n"
  exit 1
fi


VOID_BASE_PACKAGES=(
  # Core compositor, shell, and graphical login
  niri
  quickshell
  fish-shell
  sddm
  xorg-minimal

  # Qt6 (required for Quickshell)
  qt6-base
  qt6-declarative
  qt6-svg
  qt6-wayland
  qt6-qt5compat
  qt6-multimedia
  qt6-webengine
  layer-shell-qt
  qt6-imageformats
  qt6-virtualkeyboard
  kf6-syntax-highlighting
  kf6-kirigami
  kdialog
  breeze-icons
  qt6ct

  # Session services (system services enabled separately in setup)
  elogind
  dbus
  polkit
  seatd
  turnstile

  # XDG Portals
  xdg-desktop-portal
  xdg-desktop-portal-gtk
  xdg-desktop-portal-wlr

  # Polkit agent
  polkit-gnome

  # Network
  NetworkManager
  network-manager-applet

  # Power profiles exposed directly by Quickshell
  power-profiles-daemon

  # Wayland utilities
  wl-clipboard
  cliphist
  grim
  slurp
  wlsunset
  fuzzel

  # Idle/lock
  swayidle
  swaylock

  # Essential utilities
  gum
  dunst
  jq
  curl
  wget
  git
  ripgrep
  bc
  xdg-utils
  xdg-user-dirs
  libnotify

  # Default desktop/runtime providers
  xwayland-satellite
  xdg-desktop-portal-gnome
  gnome-keyring
  libsecret
  nautilus
  kitty

  # Default wallpaper backend
  awww

  # UV (fast Python package manager, in Void repo)
  uv

  # Build/runtime deps for Python native extensions (pycairo, pygobject)
  rsync
  base-devel
  pkg-config
  cairo-devel
  python3-devel
  glib-devel
  gobject-introspection
  python3-gobject-devel
  libffi-devel
)

# Audio: optional audio stack
VOID_AUDIO_PACKAGES=(
  pipewire
  wireplumber
  alsa-pipewire
  playerctl
  libdbusmenu-gtk3
  pavucontrol
  easyeffects
  mpv
  mpv-mpris
  yt-dlp
  socat
  cava
  plasma-browser-integration
  lsp-plugins-lv2
  libspa-bluetooth
  songrec
)

# Toolkit: input, desktop, backlight, bluetooth, OCR, KDE integration
VOID_TOOLKIT_PACKAGES=(
  cmake
  upower
  wtype
  python3-Pillow
  ImageMagick
  hyprpicker
  translate-shell
  fprintd

  # Backlight control
  brightnessctl
  ddcutil
  geoclue2
  qalculate
  gowall

  # Bluetooth
  bluez
  blueman

  # KDE integration (kwriteconfig6)
  kf6-kconfig

  # Desktop applications delivered through maintained Flatpaks
  flatpak

)

# OCR is shared by the toolkit and screencapture profiles. Keep the package
# set independent so --no-toolkit does not silently disable screenshot OCR.
VOID_OCR_PACKAGES=(
  tesseract-ocr
  tesseract-ocr-eng
  tesseract-ocr-spa
  tesseract-ocr-rus
  tesseract-ocr-jpn
  tesseract-ocr-chi_sim
  tesseract-ocr-chi_tra
)

# Screencapture: screenshot, recording, annotation
VOID_SCREENCAPTURE_PACKAGES=(
  swappy
  wf-recorder
  ImageMagick
  ffmpeg
)

# Fonts and theming
VOID_FONTS_PACKAGES=(
  curl
  unzip
  fontconfig
  cmake
  extra-cmake-modules
  qt6-base-devel
  qt6-declarative-devel
  kf6-kcoreaddons-devel
  kf6-kcmutils-devel
  kf6-kcolorscheme-devel
  kf6-kconfig-devel
  kf6-kguiaddons-devel
  kf6-ki18n-devel
  kf6-kiconthemes-devel
  kf6-kwindowsystem-devel
  kf6-kirigami-devel
  kf6-frameworkintegration-devel
  kf6-kdecoration-devel
  dejavu-fonts-ttf
  twemoji
  nerd-fonts-ttf
  kvantum
  breeze
  plasma-integration
  kde-cli-tools
  # adw-gtk3, capitaine-cursors, and whitesur-icon-theme are not in Void repos.
  noto-fonts-emoji
)

source "${REPO_ROOT}/sdata/dist-void/providers.sh"

if [[ -n "${ONLY_MISSING_DEPS:-}" ]]; then
  tui_info "Installing missing dependencies only..."

  declare -A cmd_to_pkg=(
    [qs]="quickshell"
    [niri]="niri"
    [nmcli]="NetworkManager"
    [wpctl]="wireplumber"
    [pw-dump]="pipewire"
    [awww-daemon]="awww"
    [flock]="util-linux"
    [kwriteconfig6]="kf6-kconfig"
    [trans]="translate-shell"
    [qt-webengine]="qt6-webengine"
    [layer-shell-qt]="layer-shell-qt"
    [jq]="jq"
    [rsync]="rsync"
    [curl]="curl"
    [git]="git"
    [python3]="python3"
    [wlsunset]="wlsunset"
    [dunstify]="dunst"
    [fish]="fish-shell"
    [magick]="ImageMagick"
    [tesseract]="tesseract-ocr"
    [blueman-manager]="blueman"
    [swaylock]="swaylock"
    [swayidle]="swayidle"
    [grim]="grim"
    [mpv]="mpv"
    [cliphist]="cliphist"
    [wl-copy]="wl-clipboard"
    [wl-paste]="wl-clipboard"
    [fuzzel]="fuzzel"
    [qalc]="qalculate"
    [gowall]="gowall"
    [nm-connection-editor]="network-manager-applet"
    [songrec]="songrec"
    [notify-send]="libnotify"
    [xdg-settings]="xdg-utils"
    [secret-tool]="libsecret"
    [gnome-keyring-daemon]="gnome-keyring"
    [powerprofilesctl]="power-profiles-daemon"
    [pkg-config]="pkg-config"
    [cc]="gcc"
    [gcc]="gcc"
    [python3-devel]="python3-devel"
    [cairo-devel]="cairo-devel"
    [gobject-introspection]="gobject-introspection"
    [python3-gobject-devel]="python3-gobject-devel"
    [glib-devel]="glib-devel"
    [libffi-devel]="libffi-devel"
    [ocr-eng]="tesseract-ocr-eng"
    [ocr-spa]="tesseract-ocr-spa"
    [ocr-rus]="tesseract-ocr-rus"
    [ocr-jpn]="tesseract-ocr-jpn"
    [ocr-chi-sim]="tesseract-ocr-chi_sim"
    [ocr-chi-tra]="tesseract-ocr-chi_tra"
    [font-jetbrains-mono-nerd]="nerd-fonts-ttf"
    [plasma-integration]="plasma-integration"
    [font-noto-color-emoji]="noto-fonts-emoji"
  )

  _miss_installflags=(-S)
  $ask || _miss_installflags+=(-y)

  _miss_pkgs=()
  _miss_cmds=()
  _need_ydotool=false
  _need_missioncenter=false
  _need_tesseract_adapter=false
  _need_visual_providers=false
  _need_font_providers=false
  _need_darkly=false
  _ocr_fallback_models=()
  read -r -a _miss_cmds <<<"$ONLY_MISSING_DEPS"
  for cmd in "${_miss_cmds[@]}"; do
    if [[ "$cmd" == ydotool || "$cmd" == ydotoold ]]; then
      _need_ydotool=true
      for _miss_pkg in curl cmake; do
        [[ " ${_miss_pkgs[*]} " == *" ${_miss_pkg} "* ]] || _miss_pkgs+=("$_miss_pkg")
      done
      continue
    fi
    if [[ "$cmd" == missioncenter ]]; then
      _need_missioncenter=true
      [[ " ${_miss_pkgs[*]} " == *" flatpak "* ]] || _miss_pkgs+=(flatpak)
      continue
    fi
    if [[ "$cmd" == tesseract ]]; then
      _need_tesseract_adapter=true
    fi
    if [[ "$cmd" == adw-gtk3 || "$cmd" == whitesur-icon-theme || "$cmd" == capitaine-cursors ]]; then
      _need_visual_providers=true
      for _miss_pkg in curl unzip; do
        [[ " ${_miss_pkgs[*]} " == *" ${_miss_pkg} "* ]] || _miss_pkgs+=("$_miss_pkg")
      done
      continue
    fi
    if [[ "$cmd" == font-providers ]]; then
      _need_font_providers=true
      for _miss_pkg in curl unzip python3 fontconfig; do
        [[ " ${_miss_pkgs[*]} " == *" ${_miss_pkg} "* ]] || _miss_pkgs+=("$_miss_pkg")
      done
      continue
    fi
    if [[ "$cmd" == darkly ]]; then
      _need_darkly=true
      for _miss_pkg in \
          curl cmake extra-cmake-modules qt6-base-devel qt6-declarative-devel \
          kf6-kcoreaddons-devel kf6-kcmutils-devel kf6-kcolorscheme-devel \
          kf6-kconfig-devel kf6-kguiaddons-devel kf6-ki18n-devel \
          kf6-kiconthemes-devel kf6-kwindowsystem-devel kf6-kirigami-devel \
          kf6-frameworkintegration-devel kf6-kdecoration-devel; do
        [[ " ${_miss_pkgs[*]} " == *" ${_miss_pkg} "* ]] || _miss_pkgs+=("$_miss_pkg")
      done
      continue
    fi
    case "$cmd" in
      ocr-jpn-vert)
        _ocr_fallback_models+=(jpn_vert)
        continue
        ;;
      ocr-chi-sim-vert)
        _ocr_fallback_models+=(chi_sim_vert)
        continue
        ;;
      ocr-chi-tra-vert)
        _ocr_fallback_models+=(chi_tra_vert)
        continue
        ;;
    esac
    _miss_pkg="${cmd_to_pkg[$cmd]:-$cmd}"
    [[ " ${_miss_pkgs[*]} " == *" ${_miss_pkg} "* ]] || _miss_pkgs+=("$_miss_pkg")
  done

  if [[ ${#_miss_pkgs[@]} -gt 0 ]]; then
    _pending_pkgs=()
    for _miss_pkg in "${_miss_pkgs[@]}"; do
      if ! xbps-query -p pkgver "$_miss_pkg" >/dev/null 2>&1; then
        _pending_pkgs+=("$_miss_pkg")
      fi
    done
    _miss_pkgs=("${_pending_pkgs[@]}")
  fi

  if [[ ${#_miss_pkgs[@]} -gt 0 ]]; then
    check_void_install_space "${_miss_pkgs[@]}" || return 1
    v pkg_sudo xbps-install "${_miss_installflags[@]}" "${_miss_pkgs[@]}"
  fi
  if $_need_ydotool; then
    install_void_ydotool || return 1
  fi
  if $_need_missioncenter; then
    install_void_missioncenter || return 1
  fi
  if $_need_tesseract_adapter; then
    configure_void_tesseract_command || return 1
  fi
  if $_need_visual_providers; then
    install_void_visual_providers || return 1
  fi
  if $_need_font_providers; then
    install_void_font_providers || return 1
  fi
  if $_need_darkly; then
    install_void_darkly || return 1
  fi
  if [[ ${#_ocr_fallback_models[@]} -gt 0 ]]; then
    install_void_ocr_models "${_ocr_fallback_models[@]}" || return 1
  fi

  unset ONLY_MISSING_DEPS
  return 0
fi

_void_selected_packages=("${VOID_BASE_PACKAGES[@]}")
if ${INSTALL_AUDIO:-true}; then
  _void_selected_packages+=("${VOID_AUDIO_PACKAGES[@]}")
fi
if ${INSTALL_TOOLKIT:-true}; then
  _void_selected_packages+=("${VOID_TOOLKIT_PACKAGES[@]}")
fi
if ${INSTALL_SCREENCAPTURE:-true}; then
  _void_selected_packages+=("${VOID_SCREENCAPTURE_PACKAGES[@]}")
fi
if ${INSTALL_TOOLKIT:-true} || ${INSTALL_SCREENCAPTURE:-true}; then
  _void_selected_packages+=("${VOID_OCR_PACKAGES[@]}")
fi
if ${INSTALL_FONTS:-true}; then
  _void_selected_packages+=("${VOID_FONTS_PACKAGES[@]}")
fi
check_void_install_space "${_void_selected_packages[@]}" || return 1
unset _void_selected_packages

case ${SKIP_SYSUPDATE:-false} in
  true) sleep 0;;
  *)
    if $ask; then
      v pkg_sudo xbps-install -Su
    else
      v pkg_sudo xbps-install -Su -y
    fi
    ;;
esac

tui_info "Installing base packages..."

installflags=(-S)
$ask || installflags+=(-y)

_install_base=("${VOID_BASE_PACKAGES[@]}")

v pkg_sudo xbps-install "${installflags[@]}" "${_install_base[@]}"

if ${INSTALL_AUDIO:-true}; then
  tui_info "Installing audio packages..."
  v pkg_sudo xbps-install "${installflags[@]}" "${VOID_AUDIO_PACKAGES[@]}"
fi

if ${INSTALL_TOOLKIT:-true}; then
  tui_info "Installing toolkit packages..."
  v pkg_sudo xbps-install "${installflags[@]}" "${VOID_TOOLKIT_PACKAGES[@]}"
  install_void_ydotool || return 1
  install_void_missioncenter || return 1
fi

if ${INSTALL_SCREENCAPTURE:-true}; then
  tui_info "Installing screencapture packages..."
  v pkg_sudo xbps-install "${installflags[@]}" "${VOID_SCREENCAPTURE_PACKAGES[@]}"
fi

# OCR belongs to both toolkit utilities and screencapture. Provision it once
# whenever either profile is selected, including the pinned vertical models.
if ${INSTALL_TOOLKIT:-true} || ${INSTALL_SCREENCAPTURE:-true}; then
  tui_info "Installing OCR packages..."
  v pkg_sudo xbps-install "${installflags[@]}" "${VOID_OCR_PACKAGES[@]}"
  configure_void_tesseract_command || return 1
  install_void_ocr_models jpn_vert chi_sim_vert chi_tra_vert || return 1
fi

if ${INSTALL_FONTS:-true}; then
  tui_info "Installing fonts and theming packages..."
  v pkg_sudo xbps-install "${installflags[@]}" "${VOID_FONTS_PACKAGES[@]}"
  install_void_font_providers || return 1
  install_void_visual_providers || return 1
  install_void_darkly || return 1
fi

if command -v qs >/dev/null 2>&1; then
  qs_abi_output="$(timeout 5 env QT_QPA_PLATFORM=offscreen qs --version 2>&1 || true)"
  if echo "$qs_abi_output" | grep -qiE "built against Qt|Qt.*mismatch|incompatible Qt"; then
    log_warning "Quickshell was built for another Qt version. Until it is rebuilt it can crash."
    log_warning "Void rebuilds quickshell with Qt updates. To reinstall it now: inir doctor --fix-abi"
  fi
fi

log_success "Dependencies installed"
