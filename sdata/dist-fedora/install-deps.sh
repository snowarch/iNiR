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
source "${REPO_ROOT}/sdata/dist-fedora/providers.sh"
fedora_detect
tui_info "Detected Fedora ${FEDORA_VERSION}"


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
    [wl-copy]="wl-clipboard" [wl-paste]="wl-clipboard"
    [playerctl]="playerctl" [notify-send]="libnotify"
    [flock]="util-linux" [wlsunset]="wlsunset" [easyeffects]="easyeffects"
    [uv]="uv" [cava]="cava" [qalc]="qalculate" [yt-dlp]="yt-dlp"
    [socat]="socat" [brightnessctl]="brightnessctl" [slurp]="slurp"
    [wf-recorder]="wf-recorder" [ffmpeg]="ffmpeg" [swappy]="swappy"
    [tesseract]="tesseract" [blueman-manager]="blueman" [kwriteconfig6]="kf6-kconfig"
    [ddcutil]="ddcutil" [nm-connection-editor]="nm-connection-editor"
    [xdg-settings]="xdg-utils" [mpv]="mpv" [swaylock]="swaylock"
    [swayidle]="swayidle" [trans]="translate-shell" [lsp-plugins-lv2]="lsp-plugins-lv2"
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
      awww|awww-daemon|gowall|hyprpicker|missioncenter|songrec)
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
        elif [[ "$_fed_pkg" == ffmpeg ]] && ! dnf_pkg_available ffmpeg && dnf_pkg_available ffmpeg-free; then
          # Without RPM Fusion, Fedora's own ffmpeg-free provides the command.
          [[ " ${_fed_miss_pkgs[*]} " == *" ffmpeg-free "* ]] || _fed_miss_pkgs+=("ffmpeg-free")
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

    sudo dnf install $_fed_installflags --allowerasing "${_fed_miss_pkgs[@]}" || return 1
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
      hyprpicker) install_hyprpicker_fedora || _fed_unresolved+=("hyprpicker") ;;
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
provider_repos

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
  coreutils
  curl
  ripgrep
  jq
  xdg-user-dirs
  rsync
  git
  unzip
  wl-clipboard
  libnotify
  wlsunset
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
  golang
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

# Pre-flight: ensure metadata cache is fresh so availability checks are fast.
tui_info "Refreshing package metadata..."
sudo dnf makecache --timer >/dev/null 2>&1 || sudo dnf makecache >/dev/null 2>&1 || true

# Batch-check availability instead of per-package dnf calls (much faster).
FEDORA_INSTALLABLE_PKGS=()
FEDORA_REPO_FALLBACK_PKGS=()

# Separate quickshell if it needs special handling
_quickshell_pkgs=()
_regular_pkgs=()
for pkg in "${FEDORA_REPO_PKGS[@]}"; do
  if [[ "$pkg" == "quickshell" ]] && ! fedora_quickshell_compatible; then
    FEDORA_REPO_FALLBACK_PKGS+=("$pkg")
  elif [[ "$pkg" == "quickshell" ]]; then
    _quickshell_pkgs+=("$pkg")
  else
    _regular_pkgs+=("$pkg")
  fi
done

dnf_pkgs_available_batch FEDORA_INSTALLABLE_PKGS FEDORA_REPO_FALLBACK_PKGS "${_regular_pkgs[@]}" "${_quickshell_pkgs[@]}"

if [[ ${#FEDORA_INSTALLABLE_PKGS[@]} -gt 0 ]]; then
  log_info "Installing ${#FEDORA_INSTALLABLE_PKGS[@]} packages from Fedora/RPM Fusion repositories..."
  if ! sudo dnf install $installflags --allowerasing "${FEDORA_INSTALLABLE_PKGS[@]}"; then
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



provider_cliphist

if ${INSTALL_TOOLKIT:-true}; then
  install_hyprpicker_fedora || log_warning "hyprpicker is still missing; the color picker stays off until it is installed"
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

provider_darkly

#####################################################################################
# uv fallback for Fedora derivatives that do not carry the package
#####################################################################################
if ! command -v uv &>/dev/null; then
  tui_info "Installing uv fallback..."
  curl -LsSf --connect-timeout 10 --speed-limit 1024 --speed-time 30 https://astral.sh/uv/install.sh | sh 2>/dev/null || {
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
fedora_critical_fonts

#####################################################################################
# Icon themes (WhiteSur, MacTahoe)
#####################################################################################
fedora_icon_themes

#####################################################################################
# Cursor themes
#####################################################################################
fedora_cursor_themes

#####################################################################################
# Optional fonts (nice to have)
#####################################################################################
fedora_optional_fonts

#####################################################################################
# Install CLI tools (starship, eza)
#####################################################################################
provider_starship-eza

#####################################################################################
# Install adw-gtk3 theme
#####################################################################################
fedora_gtk_theme

# User configuration (GTK, Kvantum, terminals, fish) is installed by
# sdata/subcmd-install/3.files.sh for every distro; a dependency step that wrote
# its own copies here overwrote the user's choices on every reinstall.

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
