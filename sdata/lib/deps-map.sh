# Dependency mapping for iNiR across distributions
# This file maps generic dependency names to distro-specific package names
# Format: DEPS_<CATEGORY>_<GENERIC_NAME>="arch:pkg fedora:pkg debian:pkg opensuse:pkg void:pkg"
#
# Special values:
#   - "AUR:pkg" = Arch AUR package
#   - "COPR:repo/pkg" = Fedora COPR package  
#   - "CARGO:pkg" = Install via cargo
#   - "COMPILE:url" = Must compile from source
#   - "FLATPAK:id" = Flatpak package
#   - "-" = Not available/not needed
#
# shellcheck shell=bash

###############################################################################
# Package manager commands per distro
###############################################################################
declare -A PKG_INSTALL_CMD=(
    [arch]="pacman -S --needed"
    [fedora]="dnf install -y"
    [debian]="apt install -y"
    [ubuntu]="apt install -y"
    [opensuse]="zypper install -y"
    [void]="xbps-install -y"
)

declare -A PKG_UPDATE_CMD=(
    [arch]="pacman -Syu"
    [fedora]="dnf upgrade -y"
    [debian]="apt update && apt upgrade -y"
    [ubuntu]="apt update && apt upgrade -y"
    [opensuse]="zypper refresh && zypper update -y"
    [void]="xbps-install -Su"
)

declare -A AUR_HELPER_CMD=(
    [arch]="yay -S --needed"
)

###############################################################################
# Critical dependencies (shell won't work without these)
###############################################################################

# Quickshell - the shell framework itself
# NOW IN OFFICIAL ARCH REPOS! Fedora has COPR. Others need to compile.
DEPS_CRITICAL_QUICKSHELL="arch:quickshell fedora:COPR:errornointernet/quickshell debian:COMPILE:https://github.com/quickshell-mirror/quickshell ubuntu:COMPILE:https://github.com/quickshell-mirror/quickshell opensuse:COMPILE:https://github.com/quickshell-mirror/quickshell void:COMPILE:https://github.com/quickshell-mirror/quickshell"

# Niri compositor
DEPS_CRITICAL_NIRI="arch:niri fedora:COPR:yalter/niri debian:COMPILE:https://github.com/YaLTeR/niri opensuse:COMPILE:https://github.com/YaLTeR/niri void:niri"

###############################################################################
# Qt6 dependencies
###############################################################################
DEPS_QT6_BASE="arch:qt6-base fedora:qt6-qtbase debian:qt6-base-dev ubuntu:qt6-base-dev opensuse:qt6-base-devel void:qt6-base"
DEPS_QT6_DECLARATIVE="arch:qt6-declarative fedora:qt6-qtdeclarative debian:qt6-declarative-dev ubuntu:qt6-declarative-dev opensuse:qt6-declarative-devel void:qt6-declarative"
DEPS_QT6_SVG="arch:qt6-svg fedora:qt6-qtsvg debian:libqt6svg6-dev ubuntu:libqt6svg6-dev opensuse:qt6-svg-devel void:qt6-svg"
DEPS_QT6_WAYLAND="arch:qt6-wayland fedora:qt6-qtwayland debian:qt6-wayland-dev ubuntu:qt6-wayland-dev opensuse:qt6-wayland-devel void:qt6-wayland"
DEPS_QT6_5COMPAT="arch:qt6-5compat fedora:qt6-qt5compat debian:qt6-5compat-dev ubuntu:qt6-5compat-dev opensuse:qt6-5compat-devel void:qt6-5compat"
DEPS_QT6_MULTIMEDIA="arch:qt6-multimedia fedora:qt6-qtmultimedia debian:qt6-multimedia-dev ubuntu:qt6-multimedia-dev opensuse:qt6-multimedia-devel void:qt6-multimedia"
DEPS_QT6_IMAGEFORMATS="arch:qt6-imageformats fedora:qt6-qtimageformats debian:qt6-image-formats-plugins ubuntu:qt6-image-formats-plugins opensuse:qt6-imageformats void:qt6-imageformats"
DEPS_QT6_VIRTUALKEYBOARD="arch:qt6-virtualkeyboard fedora:qt6-qtvirtualkeyboard debian:qt6-virtualkeyboard-dev ubuntu:qt6-virtualkeyboard-dev opensuse:qt6-virtualkeyboard-devel void:qt6-virtualkeyboard"

###############################################################################
# Core system utilities
###############################################################################
DEPS_CORE_JQ="arch:jq fedora:jq debian:jq ubuntu:jq opensuse:jq void:jq"
DEPS_CORE_CURL="arch:curl fedora:curl debian:curl ubuntu:curl opensuse:curl void:curl"
DEPS_CORE_WGET="arch:wget fedora:wget debian:wget ubuntu:wget opensuse:wget void:wget"
DEPS_CORE_GIT="arch:git fedora:git debian:git ubuntu:git opensuse:git void:git"
DEPS_CORE_RIPGREP="arch:ripgrep fedora:ripgrep debian:ripgrep ubuntu:ripgrep opensuse:ripgrep void:ripgrep"
DEPS_CORE_RSYNC="arch:rsync fedora:rsync debian:rsync ubuntu:rsync opensuse:rsync void:rsync"
DEPS_CORE_BC="arch:bc fedora:bc debian:bc ubuntu:bc opensuse:bc void:bc"

###############################################################################
# Wayland utilities
###############################################################################
DEPS_WAYLAND_WLCLIPBOARD="arch:wl-clipboard fedora:wl-clipboard debian:wl-clipboard ubuntu:wl-clipboard opensuse:wl-clipboard void:wl-clipboard"
# cliphist is in official Arch repos, Fedora/Debian use GitHub binary releases
DEPS_WAYLAND_CLIPHIST="arch:cliphist fedora:GITHUB:sentriz/cliphist debian:GITHUB:sentriz/cliphist ubuntu:GITHUB:sentriz/cliphist opensuse:cliphist void:cliphist"
DEPS_WAYLAND_GRIM="arch:grim fedora:grim debian:grim ubuntu:grim opensuse:grim void:grim"
DEPS_WAYLAND_SLURP="arch:slurp fedora:slurp debian:slurp ubuntu:slurp opensuse:slurp void:slurp"
DEPS_WAYLAND_SWAPPY="arch:swappy fedora:swappy debian:swappy ubuntu:swappy opensuse:swappy void:swappy"
DEPS_WAYLAND_WFRECORDER="arch:wf-recorder fedora:wf-recorder debian:wf-recorder ubuntu:wf-recorder opensuse:wf-recorder void:wf-recorder"
DEPS_WAYLAND_WLSUNSET="arch:wlsunset fedora:wlsunset debian:wlsunset ubuntu:wlsunset opensuse:wlsunset void:wlsunset"
DEPS_WAYLAND_SWAYIDLE="arch:swayidle fedora:swayidle debian:swayidle ubuntu:swayidle opensuse:swayidle void:swayidle"
DEPS_WAYLAND_SWAYLOCK="arch:swaylock fedora:swaylock debian:swaylock ubuntu:swaylock opensuse:swaylock void:swaylock"
DEPS_WAYLAND_XWAYLANDSATELLITE="arch:xwayland-satellite fedora:COPR:alebastr/sway-extras debian:COMPILE:https://github.com/Supreeeme/xwayland-satellite ubuntu:COMPILE:https://github.com/Supreeeme/xwayland-satellite opensuse:COMPILE:https://github.com/Supreeeme/xwayland-satellite void:xwayland-satellite"

###############################################################################
# Audio stack
###############################################################################
DEPS_AUDIO_PIPEWIRE="arch:pipewire fedora:pipewire debian:pipewire ubuntu:pipewire opensuse:pipewire void:pipewire"
DEPS_AUDIO_PIPEWIRE_PULSE="arch:pipewire-pulse fedora:pipewire-pulseaudio debian:pipewire-pulse ubuntu:pipewire-pulse opensuse:pipewire-pulseaudio void:pipewire-pulse"
DEPS_AUDIO_WIREPLUMBER="arch:wireplumber fedora:wireplumber debian:wireplumber ubuntu:wireplumber opensuse:wireplumber void:wireplumber"
DEPS_AUDIO_PLAYERCTL="arch:playerctl fedora:playerctl debian:playerctl ubuntu:playerctl opensuse:playerctl void:playerctl"
DEPS_AUDIO_PAVUCONTROL="arch:pavucontrol fedora:pavucontrol debian:pavucontrol ubuntu:pavucontrol opensuse:pavucontrol void:pavucontrol"
DEPS_AUDIO_CAVA="arch:AUR:cava fedora:cava debian:COMPILE:https://github.com/karlstav/cava ubuntu:COMPILE:https://github.com/karlstav/cava opensuse:cava void:cava"
DEPS_AUDIO_EASYEFFECTS="arch:easyeffects fedora:easyeffects debian:easyeffects ubuntu:easyeffects opensuse:easyeffects void:easyeffects"
DEPS_AUDIO_MPV="arch:mpv fedora:mpv debian:mpv ubuntu:mpv opensuse:mpv void:mpv"
DEPS_AUDIO_MPV_MPRIS="arch:mpv-mpris fedora:mpv-mpris debian:mpv-mpris ubuntu:mpv-mpris opensuse:mpv-mpris void:mpv-mpris"
DEPS_AUDIO_YTDLP="arch:yt-dlp fedora:yt-dlp debian:yt-dlp ubuntu:yt-dlp opensuse:yt-dlp void:yt-dlp"
DEPS_AUDIO_SOCAT="arch:socat fedora:socat debian:socat ubuntu:socat opensuse:socat void:socat"

###############################################################################
# Network
###############################################################################
DEPS_NET_NETWORKMANAGER="arch:networkmanager fedora:NetworkManager debian:network-manager ubuntu:network-manager opensuse:NetworkManager void:NetworkManager"
DEPS_NET_GNOMEKEYRING="arch:gnome-keyring fedora:gnome-keyring debian:gnome-keyring ubuntu:gnome-keyring opensuse:gnome-keyring void:gnome-keyring"
DEPS_NET_BLUEMAN="arch:blueman fedora:blueman debian:blueman ubuntu:blueman opensuse:blueman void:blueman"

###############################################################################
# Theming and appearance
###############################################################################
DEPS_THEME_MATUGEN="arch:matugen fedora:CARGO:matugen debian:CARGO:matugen ubuntu:CARGO:matugen opensuse:CARGO:matugen void:CARGO:matugen"
DEPS_THEME_QT6CT="arch:qt6ct fedora:qt6ct debian:qt6ct ubuntu:qt6ct opensuse:qt6ct void:qt6ct"
DEPS_THEME_KVANTUM="arch:kvantum fedora:kvantum debian:qt6-style-kvantum ubuntu:qt6-style-kvantum opensuse:kvantum-qt6 void:kvantum"
DEPS_THEME_BREEZE="arch:breeze fedora:breeze-gtk debian:breeze-gtk-theme ubuntu:breeze-gtk-theme opensuse:metatheme-breeze-common void:breeze"

###############################################################################
# Fonts (critical for UI)
###############################################################################
DEPS_FONT_MATERIAL_SYMBOLS="arch:AUR:ttf-material-symbols-variable-git fedora:COMPILE:google-material-symbols debian:COMPILE:google-material-symbols ubuntu:COMPILE:google-material-symbols opensuse:COMPILE:google-material-symbols void:COMPILE:google-material-symbols"
DEPS_FONT_JETBRAINS_MONO="arch:AUR:ttf-jetbrains-mono-nerd fedora:jetbrains-mono-fonts-all debian:fonts-jetbrains-mono ubuntu:fonts-jetbrains-mono opensuse:jetbrains-mono-fonts void:font-jetbrains-mono-nerd"
DEPS_FONT_DEJAVU="arch:ttf-dejavu fedora:dejavu-fonts-all debian:fonts-dejavu ubuntu:fonts-dejavu opensuse:dejavu-fonts void:dejavu-fonts-ttf"
DEPS_FONT_TWEMOJI="arch:AUR:ttf-twemoji fedora:twitter-twemoji-fonts debian:fonts-twemoji ubuntu:fonts-twemoji opensuse:twemoji-color-font void:twemoji"

###############################################################################
# Development/Build tools (needed for compiling deps on some distros)
###############################################################################
DEPS_BUILD_CMAKE="arch:cmake fedora:cmake debian:cmake ubuntu:cmake opensuse:cmake void:cmake"
DEPS_BUILD_MESON="arch:meson fedora:meson debian:meson ubuntu:meson opensuse:meson void:meson"
DEPS_BUILD_NINJA="arch:ninja fedora:ninja-build debian:ninja-build ubuntu:ninja-build opensuse:ninja void:ninja"
DEPS_BUILD_GCC="arch:gcc fedora:gcc debian:build-essential ubuntu:build-essential opensuse:gcc void:gcc"
DEPS_BUILD_RUST="arch:rust fedora:rust debian:rustc ubuntu:rustc opensuse:rust void:rust"
DEPS_BUILD_CARGO="arch:rust fedora:cargo debian:cargo ubuntu:cargo opensuse:cargo void:cargo"

###############################################################################
# Miscellaneous tools
###############################################################################
DEPS_MISC_FISH="arch:fish fedora:fish debian:fish ubuntu:fish opensuse:fish void:fish"
DEPS_MISC_GUM="arch:gum fedora:COPR:atim/gum debian:COMPILE:https://github.com/charmbracelet/gum ubuntu:COMPILE:https://github.com/charmbracelet/gum opensuse:gum void:gum"
DEPS_MISC_STARSHIP="arch:starship fedora:starship debian:GITHUB:starship/starship ubuntu:GITHUB:starship/starship opensuse:starship void:starship"
DEPS_MISC_DUNST="arch:dunst fedora:dunst debian:dunst ubuntu:dunst opensuse:dunst void:dunst"
DEPS_MISC_LIBNOTIFY="arch:libnotify fedora:libnotify debian:libnotify-bin ubuntu:libnotify-bin opensuse:libnotify-tools void:libnotify"
DEPS_MISC_IMAGEMAGICK="arch:imagemagick fedora:ImageMagick debian:imagemagick ubuntu:imagemagick opensuse:ImageMagick void:ImageMagick"
DEPS_MISC_FFMPEG="arch:ffmpeg fedora:ffmpeg debian:ffmpeg ubuntu:ffmpeg opensuse:ffmpeg void:ffmpeg"
DEPS_MISC_TESSERACT="arch:tesseract fedora:tesseract debian:tesseract-ocr ubuntu:tesseract-ocr opensuse:tesseract-ocr void:tesseract-ocr"
DEPS_MISC_LIBQALCULATE="arch:libqalculate fedora:libqalculate debian:qalc ubuntu:qalc opensuse:libqalculate void:libqalculate"
DEPS_MISC_BRIGHTNESSCTL="arch:brightnessctl fedora:brightnessctl debian:brightnessctl ubuntu:brightnessctl opensuse:brightnessctl void:brightnessctl"
DEPS_MISC_DOLPHIN="arch:dolphin fedora:dolphin debian:dolphin ubuntu:dolphin opensuse:dolphin void:dolphin"
DEPS_MISC_FOOT="arch:foot fedora:foot debian:foot ubuntu:foot opensuse:foot void:foot"
DEPS_MISC_KITTY="arch:kitty fedora:kitty debian:kitty ubuntu:kitty opensuse:kitty void:kitty"
DEPS_MISC_POLKIT="arch:polkit fedora:polkit debian:policykit-1 ubuntu:policykit-1 opensuse:polkit void:polkit"
DEPS_MISC_UV="arch:AUR:uv fedora:CARGO:uv debian:CARGO:uv ubuntu:CARGO:uv opensuse:CARGO:uv void:CARGO:uv"
DEPS_MISC_KCONFIG="arch:kconfig fedora:kf6-kconfig debian:libkf6config-bin ubuntu:libkf6config-bin opensuse:kconfig void:kconfig"

###############################################################################
# XDG Portals
###############################################################################
DEPS_PORTAL_BASE="arch:xdg-desktop-portal fedora:xdg-desktop-portal debian:xdg-desktop-portal ubuntu:xdg-desktop-portal opensuse:xdg-desktop-portal void:xdg-desktop-portal"
DEPS_PORTAL_GTK="arch:xdg-desktop-portal-gtk fedora:xdg-desktop-portal-gtk debian:xdg-desktop-portal-gtk ubuntu:xdg-desktop-portal-gtk opensuse:xdg-desktop-portal-gtk void:xdg-desktop-portal-gtk"
DEPS_PORTAL_GNOME="arch:xdg-desktop-portal-gnome fedora:xdg-desktop-portal-gnome debian:xdg-desktop-portal-gnome ubuntu:xdg-desktop-portal-gnome opensuse:xdg-desktop-portal-gnome void:xdg-desktop-portal-gnome"

###############################################################################
# Helper functions
###############################################################################

# Get package name for current distro
# Usage: get_pkg_name "DEPS_CORE_JQ"
get_pkg_name() {
    local dep_var="$1"
    local distro="${OS_GROUP_ID:-arch}"
    local dep_string="${!dep_var}"
    
    if [[ -z "$dep_string" ]]; then
        echo ""
        return 1
    fi
    
    # Parse the dependency string
    local pkg=""
    for entry in $dep_string; do
        local entry_distro="${entry%%:*}"
        local entry_pkg="${entry#*:}"
        
        if [[ "$entry_distro" == "$distro" ]]; then
            pkg="$entry_pkg"
            break
        fi
    done
    
    echo "$pkg"
}

# Check if package requires special handling
# Returns: "normal", "aur", "copr", "cargo", "compile", "flatpak", "github", or "unavailable"
get_pkg_type() {
    local pkg="$1"
    
    case "$pkg" in
        AUR:*) echo "aur" ;;
        COPR:*) echo "copr" ;;
        CARGO:*) echo "cargo" ;;
        COMPILE:*) echo "compile" ;;
        FLATPAK:*) echo "flatpak" ;;
        GITHUB:*) echo "github" ;;
        -) echo "unavailable" ;;
        "") echo "unavailable" ;;
        *) echo "normal" ;;
    esac
}

# Extract actual package name from special format
# e.g., "AUR:quickshell-git" -> "quickshell-git"
get_pkg_value() {
    local pkg="$1"
    echo "${pkg#*:}"
}

# Get all packages of a category for current distro
# Usage: get_category_packages "CORE"
get_category_packages() {
    local category="$1"
    local distro="${OS_GROUP_ID:-arch}"
    local packages=()
    
    # Find all DEPS_<category>_* variables
    for var in $(compgen -v | grep "^DEPS_${category}_"); do
        local pkg=$(get_pkg_name "$var")
        if [[ -n "$pkg" && "$pkg" != "-" ]]; then
            packages+=("$pkg")
        fi
    done
    
    echo "${packages[@]}"
}

# Check if a command exists
cmd_exists() {
    command -v "$1" &>/dev/null
}

# Install a package using the appropriate method for current distro
install_package() {
    local pkg="$1"
    local pkg_type=$(get_pkg_type "$pkg")
    local pkg_value=$(get_pkg_value "$pkg")
    local distro="${OS_GROUP_ID:-arch}"
    
    case "$pkg_type" in
        normal)
            local cmd="${PKG_INSTALL_CMD[$distro]}"
            if [[ -n "$cmd" ]]; then
                sudo $cmd "$pkg_value"
            else
                echo "Unknown distro: $distro"
                return 1
            fi
            ;;
        aur)
            if [[ "$distro" == "arch" ]]; then
                local aur_cmd="${AUR_HELPER_CMD[$distro]}"
                $aur_cmd "$pkg_value"
            else
                echo "AUR packages only available on Arch"
                return 1
            fi
            ;;
        copr)
            if [[ "$distro" == "fedora" ]]; then
                local repo="${pkg_value%%/*}"
                local pkg_name="${pkg_value#*/}"
                sudo dnf copr enable -y "$repo"
                sudo dnf install -y "$pkg_name"
            else
                echo "COPR packages only available on Fedora"
                return 1
            fi
            ;;
        cargo)
            if cmd_exists cargo; then
                cargo install "$pkg_value"
            else
                echo "Cargo not installed"
                return 1
            fi
            ;;
        compile)
            echo "Package $pkg_value must be compiled from source: $pkg_value"
            echo "Please follow the instructions at the URL above"
            return 2
            ;;
        github)
            # Install from GitHub releases (binary)
            local repo="$pkg_value"
            local cmd_name="${repo##*/}"
            echo "Installing $cmd_name from GitHub releases: $repo"
            # This is handled by distro-specific installers with proper download logic
            return 2
            ;;
        flatpak)
            if cmd_exists flatpak; then
                flatpak install -y "$pkg_value"
            else
                echo "Flatpak not installed"
                return 1
            fi
            ;;
        unavailable)
            echo "Package not available for $distro"
            return 1
            ;;
    esac
}

# List all dependencies that need manual compilation for current distro
list_compile_deps() {
    local distro="${OS_GROUP_ID:-arch}"
    local compile_deps=()
    
    for var in $(compgen -v | grep "^DEPS_"); do
        local pkg=$(get_pkg_name "$var")
        local pkg_type=$(get_pkg_type "$pkg")
        
        if [[ "$pkg_type" == "compile" ]]; then
            local name="${var#DEPS_*_}"
            local url=$(get_pkg_value "$pkg")
            compile_deps+=("$name:$url")
        fi
    done
    
    printf '%s\n' "${compile_deps[@]}"
}

# List all dependencies that need cargo for current distro
list_cargo_deps() {
    local distro="${OS_GROUP_ID:-arch}"
    local cargo_deps=()
    
    for var in $(compgen -v | grep "^DEPS_"); do
        local pkg=$(get_pkg_name "$var")
        local pkg_type=$(get_pkg_type "$pkg")
        
        if [[ "$pkg_type" == "cargo" ]]; then
            local pkg_name=$(get_pkg_value "$pkg")
            cargo_deps+=("$pkg_name")
        fi
    done
    
    printf '%s\n' "${cargo_deps[@]}"
}
