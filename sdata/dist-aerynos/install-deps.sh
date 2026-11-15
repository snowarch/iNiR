# Install dependencies for iNiR on AerynOS
# This script is meant to be sourced, not run directly.

# shellcheck shell=bash

if ! command -v moss >/dev/null 2>&1; then
  printf "${STY_RED}[$0]: moss not found. This script is for AerynOS only.${STY_RST}\n"
  exit 1
fi

source "${REPO_ROOT}/sdata/dist-aerynos/providers.sh"
aerynos_detect
tui_info "Detected AerynOS ${AERYNOS_VERSION}"

#####################################################################################
# Optional: install only a specific list of missing deps (doctor, update)
#####################################################################################
if [[ -n "${ONLY_MISSING_DEPS:-}" ]]; then
  tui_info "Installing missing dependencies only..."

  # Doctor reports command IDs, not package names: every one maps here or to a recipe below, never straight to moss.
  declare -A cmd_to_pkg=(
    [qs]="quickshell" [niri]="niri" [niri-session]="niri" [nmcli]="networkmanager" [wpctl]="wireplumber"
    [pw-dump]="pipewire" [jq]="jq" [file]="file" [rsync]="rsync" [curl]="curl" [unzip]="unzip" [git]="git"
    [python3]="python" [fish]="fish" [magick]="imagemagick" [grim]="grim"
    [wl-copy]="wl-clipboard-rs" [wl-paste]="wl-clipboard-rs" [awww]="awww" [awww-daemon]="awww"
    [playerctl]="playerctl" [notify-send]="libnotify" [flock]="util-linux" [wlsunset]="wlsunset"
    [easyeffects]="easyeffects" [cava]="cava" [qalc]="qalculate" [yt-dlp]="yt-dlp" [socat]="socat"
    [brightnessctl]="brightnessctl" [slurp]="slurp" [wf-recorder]="wf-recorder" [ffmpeg]="ffmpeg"
    [tesseract]="tesseract" [kwriteconfig6]="kf6-kconfig" [ddcutil]="ddcutil"
    [nm-connection-editor]="nm-connection-editor" [xdg-settings]="xdg-utils" [mpv]="mpv" [swaylock]="swaylock"
    [swayidle]="swayidle" [lsp-plugins-lv2]="lsp-plugins-lv2" [plasma-integration]="plasma-integration"
    [font-noto-color-emoji]="font-noto-emoji"
    [ocr-eng]="tesseract-langpack-eng" [ocr-spa]="tesseract-langpack-spa" [ocr-rus]="tesseract-langpack-rus"
    [ocr-jpn]="tesseract-langpack-jpn" [ocr-jpn-vert]="tesseract-langpack-jpn_vert"
    [ocr-chi-sim]="tesseract-langpack-chi_sim" [ocr-chi-sim-vert]="tesseract-langpack-chi_sim_vert"
    [ocr-chi-tra]="tesseract-langpack-chi_tra" [ocr-chi-tra-vert]="tesseract-langpack-chi_tra_vert"
  )
  declare -A cmd_to_recipe=(
    [power-profiles]="power-profiles" [cliphist]="cliphist" [gowall]="gowall" [trans]="translate-shell"
    [missioncenter]="missioncenter" [hyprpicker]="hyprpicker" [swappy]="swappy" [blueman-manager]="blueman"
    [songrec]="songrec"
  )

  _aeryn_installflags=""
  $ask || _aeryn_installflags="-y"
  _aeryn_miss_cmds=()
  _aeryn_pkgs=()
  _aeryn_recipes=()
  _aeryn_unresolved=()
  read -r -a _aeryn_miss_cmds <<<"$ONLY_MISSING_DEPS"
  declare -A _aeryn_available=()
  while read -r _aeryn_pkg; do _aeryn_available[$_aeryn_pkg]=1; done < <(moss_list --available)

  for cmd in "${_aeryn_miss_cmds[@]}"; do
    if [[ -n "${cmd_to_recipe[$cmd]:-}" ]]; then
      [[ " ${_aeryn_recipes[*]} " == *" ${cmd_to_recipe[$cmd]} "* ]] || _aeryn_recipes+=("${cmd_to_recipe[$cmd]}")
      continue
    fi
    case "$cmd" in
      checkupdates|go) continue ;;  # older doctors listed them; neither is an AerynOS dependency
    esac
    _aeryn_pkg="${cmd_to_pkg[$cmd]:-}"
    if [[ -z "$_aeryn_pkg" ]]; then
      log_warning "No AerynOS repair mapping for Doctor command: $cmd"
      _aeryn_unresolved+=("$cmd")
    elif [[ ${#_aeryn_available[@]} -gt 0 && -z "${_aeryn_available[$_aeryn_pkg]:-}" ]]; then
      log_warning "AerynOS package unavailable for $cmd: $_aeryn_pkg"
      _aeryn_unresolved+=("$cmd")
    else
      [[ " ${_aeryn_pkgs[*]} " == *" ${_aeryn_pkg} "* ]] || _aeryn_pkgs+=("$_aeryn_pkg")
    fi
  done

  # from the index this system was built from: a newer one would want the whole system synced first
  if [[ ${#_aeryn_pkgs[@]} -gt 0 ]]; then
    pkg_sudo moss pkg add $_aeryn_installflags "${_aeryn_pkgs[@]}" || return 1
    aerynos_model_note "${_aeryn_pkgs[@]}"
  fi
  for _aeryn_recipe in "${_aeryn_recipes[@]}"; do
    "provider_${_aeryn_recipe}" || _aeryn_unresolved+=("$_aeryn_recipe")
  done

  unset ONLY_MISSING_DEPS
  if [[ ${#_aeryn_unresolved[@]} -gt 0 ]]; then
    log_error "Could not repair AerynOS dependencies: ${_aeryn_unresolved[*]}"
    return 1
  fi
  return 0
fi

#####################################################################################
# System update (optional): moss builds every transaction from one index, so the system and what is added match
#####################################################################################
case ${SKIP_SYSUPDATE:-false} in
  true)
    log_info "Skipping system update"
    ;;
  *)
    tui_info "Updating system..."
    pkg_sudo moss sync -u -y || log_warning "System update failed; installing from the current package index"
    ;;
esac

#####################################################################################
# Repository packages
#####################################################################################
AERYNOS_CORE_PKGS=(
  quickshell
  niri
  # the GL niri and Quickshell draw with: moss pulls libgbm and glvnd by soname, never the Mesa drivers they load
  mesa-dri-drivers
  mesa-libegl
  mesa-libgl
  sddm

  # Qt6 and KDE pieces the shell and Settings load
  qt6-base
  qt6-declarative
  qt6-svg
  qt6-wayland
  qt6-5compat
  qt6-imageformats
  qt6-multimedia
  qt6-tools
  layer-shell-qt
  kf6-kimageformats
  kf6-kirigami
  kdialog
  kf6-syntax-highlighting
  qt6ct
  kf6-frameworkintegration
  kdecoration
  breeze-icons

  # Session
  polkit
  xdg-desktop-portal
  xdg-desktop-portal-gtk
  xdg-desktop-portal-gnome
  networkmanager
  nm-connection-editor
  gnome-keyring
  libsecret

  # Apps and shell
  nautilus
  kitty
  fish
  xwayland-satellite
  awww
  ffmpegthumbnailer
  ffmpeg
  flatpak
  starship
  eza

  # Basic utilities
  coreutils
  curl
  ripgrep
  jq
  file
  python
  unzip
  xdg-user-dirs
  xdg-utils
  rsync
  git
  wl-clipboard-rs
  libnotify
  wlsunset
  util-linux
  gawk
  # cmp: setup and the colour scripts rewrite a file only when it changed; AerynOS's base has no diffutils
  diffutils

  # Icons and emoji
  hicolor-icon-theme
  adwaita-icon-theme
  papirus-icon-theme
  font-noto-emoji
)

AERYNOS_AUDIO_PKGS=(
  pipewire
  wireplumber
  playerctl
  pavucontrol
  plasma-browser-integration
  cava
  easyeffects
  lsp-plugins-lv2
  mpv
  yt-dlp
  socat
)

AERYNOS_TOOLKIT_PKGS=(
  kf6-kconfig
  upower
  wtype
  ydotool
  fprintd
  brightnessctl
  ddcutil
  geoclue
  swayidle
  swaylock
  qalculate
  bluez
)

AERYNOS_SCREENCAPTURE_PKGS=(
  wf-recorder
)

# Screenshots and text recognition: wanted by the toolkit and by screen capture
AERYNOS_CAPTURE_TOOLS_PKGS=(
  grim
  slurp
  imagemagick
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

AERYNOS_FONT_PKGS=(
  fontconfig
  dejavu-fonts-ttf
  liberation-fonts-ttf
  font-jetbrains-mono-ttf
  font-symbols-nerd
  glib2

  # Qt and GTK theming
  kvantum
  breeze
  plasma-integration
  kde-cli-tools
  adw-gtk3
)

AERYNOS_REPO_PKGS=("${AERYNOS_CORE_PKGS[@]}")
${INSTALL_AUDIO:-true} && AERYNOS_REPO_PKGS+=("${AERYNOS_AUDIO_PKGS[@]}")
${INSTALL_TOOLKIT:-true} && AERYNOS_REPO_PKGS+=("${AERYNOS_TOOLKIT_PKGS[@]}")
${INSTALL_SCREENCAPTURE:-true} && AERYNOS_REPO_PKGS+=("${AERYNOS_SCREENCAPTURE_PKGS[@]}")
{ ${INSTALL_TOOLKIT:-true} || ${INSTALL_SCREENCAPTURE:-true}; } && AERYNOS_REPO_PKGS+=("${AERYNOS_CAPTURE_TOOLS_PKGS[@]}")
${INSTALL_FONTS:-true} && AERYNOS_REPO_PKGS+=("${AERYNOS_FONT_PKGS[@]}")

# moss resolves a transaction whole and refuses it for one unknown name: only what the index has, minus what is in
AERYNOS_INSTALL_PKGS=()
AERYNOS_UNAVAILABLE_PKGS=()
declare -A _aeryn_available=() _aeryn_installed=()
while read -r _aeryn_pkg; do _aeryn_available[$_aeryn_pkg]=1; done < <(moss_list --available)
while read -r _aeryn_pkg; do _aeryn_installed[$_aeryn_pkg]=1; done < <(moss_list --installed)
while read -r _aeryn_pkg; do
  if [[ -n "${_aeryn_installed[$_aeryn_pkg]:-}" ]]; then
    continue
  elif [[ ${#_aeryn_available[@]} -eq 0 || -n "${_aeryn_available[$_aeryn_pkg]:-}" ]]; then
    AERYNOS_INSTALL_PKGS+=("$_aeryn_pkg")
  else
    AERYNOS_UNAVAILABLE_PKGS+=("$_aeryn_pkg")
  fi
done < <(printf '%s\n' "${AERYNOS_REPO_PKGS[@]}" | awk 'NF' | sort -u)

installflags=""
$ask || installflags="-y"
if [[ ${#AERYNOS_INSTALL_PKGS[@]} -gt 0 ]]; then
  tui_info "Installing ${#AERYNOS_INSTALL_PKGS[@]} packages with moss..."
  if ! pkg_sudo moss pkg add $installflags "${AERYNOS_INSTALL_PKGS[@]}"; then
    log_warning "The moss transaction failed; adding the packages one at a time"
    for pkg in "${AERYNOS_INSTALL_PKGS[@]}"; do
      pkg_sudo moss pkg add -y "$pkg" >/dev/null 2>&1 || AERYNOS_UNAVAILABLE_PKGS+=("$pkg")
    done
  fi
  aerynos_model_note "${AERYNOS_INSTALL_PKGS[@]}"
fi
if [[ ${#AERYNOS_UNAVAILABLE_PKGS[@]} -gt 0 ]]; then
  log_warning "Not installed from the AerynOS repository: ${AERYNOS_UNAVAILABLE_PKGS[*]}"
fi
unset AERYNOS_REPO_PKGS AERYNOS_INSTALL_PKGS

if ! command -v qs >/dev/null 2>&1 || ! command -v niri >/dev/null 2>&1; then
  log_error "Quickshell and Niri are required; moss says why with: sudo moss pkg add quickshell niri"
  return 1
fi

#####################################################################################
# What AerynOS does not package: pinned downloads and builds into the home
#####################################################################################
tui_info "Installing what AerynOS does not package..."
provider_gum || log_warning "gum is still missing; setup prompts fall back to plain text"
provider_cliphist || log_warning "cliphist is still missing; clipboard history stays off until it is installed"
provider_power-profiles || log_warning "power-profiles-daemon could not be installed; the profile buttons stay off"
provider_missioncenter || log_warning "Mission Center is still missing; configure another task manager in Settings"
provider_fonts-download || log_warning "Some iNiR fonts could not be installed; run ./setup doctor to retry"
if ${INSTALL_TOOLKIT:-true}; then
  provider_translate-shell || log_warning "translate-shell is still missing; the translator stays off"
  provider_hyprpicker || log_warning "hyprpicker is still missing; the color picker stays off until it is installed"
  provider_blueman || log_warning "Blueman is still missing; set another Bluetooth app in Settings"
  provider_gowall || log_warning "gowall is still missing; wallpaper editing effects stay off"
fi
if ${INSTALL_AUDIO:-true}; then
  provider_songrec || log_warning "songrec is still missing; music recognition stays off"
fi
if ${INSTALL_SCREENCAPTURE:-true}; then
  provider_swappy || log_warning "swappy is still missing; screenshots open without the editor"
fi
if ${INSTALL_FONTS:-true}; then
  provider_darkly || log_warning "Darkly could not be built; Qt apps keep the Breeze style"
  provider_themes-download || log_warning "Icon and cursor themes could not be installed; run ./setup doctor to retry"
fi

#####################################################################################
# Post-install summary
#####################################################################################
echo ""
log_success "════════════════════════════════════════════════════════════════"
log_success "  AerynOS dependencies installed!"
log_success "════════════════════════════════════════════════════════════════"
echo ""
log_info "From moss: Quickshell, Niri, Qt6, KDE theming, PipeWire and the shell's tools"
log_info "In your home (moss owns /usr): gum, cliphist, gowall, translate-shell, Mission Center (Flatpak),"
echo "  hyprpicker, swappy, Blueman, songrec and Darkly built from pinned sources; fonts, icons and cursors"
echo ""

tui_info "Verifying installation:"
for cmd in qs niri fish gum cliphist xwayland-satellite starship eza; do
  if command -v "$cmd" &>/dev/null || command -v ~/.local/bin/$cmd &>/dev/null; then
    log_success "$cmd"
  else
    log_error "$cmd not found; get it with: ./setup doctor"
  fi
done
echo ""
