# shellcheck shell=bash
# AerynOS providers: what sdata/deps.toml calls `build = "<recipe>"` for AerynOS, as provider_<recipe>. moss replaces
# the whole of /usr on every transaction, so nothing here writes under it: each recipe lands in the home (pinned
# downloads through sdata/lib/user-providers.sh, source builds into ~/.local), Umbriel in /usr/local (a link to
# /var/local here, which no transaction touches). Definitions only, no top-level code: install-deps.sh sources it,
# and so does compositor_install_umbriel_package (scripts/lib/compositor.sh).
GUM_VERSION="2.0.2"
GUM_SHA256="d842e06d93dbed90af48cb8dd10698db6f22e331fc40346bb37bbc753109edc2"
CLIPHIST_VERSION="0.7.0"
CLIPHIST_SHA256="d21ca6846bd25f7bd2dabb157912e2e07226db76be32885bc53d7f27db98d08a"
GOWALL_VERSION="0.2.4"
GOWALL_SHA256="dab486d5028e5f790fbd92dd26022ac5670b0d01adef4bd632ba7115c2d34ad3"
TRANS_VERSION="0.9.7.1"
TRANS_COMMIT="ffa4f340d857571a4a834bbbe80204883c357145"
TRANS_SHA256="4169d50782fddd648eb390fe853e55ecb6580777761ca25e9d84eb1b77dbf7bb"
HYPRPICKER_VERSION="0.4.8"
HYPRPICKER_SHA256="b3c1714d25bed3a1d59b813a7c59156a7c55f1f1cf2bea2306ba6b01cf8d49a7"
SWAPPY_VERSION="1.8.0"
SWAPPY_SHA256="f615cc4c61e033cddc60093003ef03646d246a0ac14becb9cdac9b5fabf37bbe"
BLUEMAN_VERSION="2.4.6"
BLUEMAN_SHA256="c712a737f9855906684c074d166d4f10c7f165378af96612818bbffcfbf8e566"
SONGREC_VERSION="0.8.2"

# aerynos_detect: AERYNOS_VERSION from os-release (/etc first, then the stateless /usr/lib copy)
aerynos_detect() {
  AERYNOS_VERSION="$(. /etc/os-release 2>/dev/null || . /usr/lib/os-release 2>/dev/null; printf '%s' "${VERSION_ID:-rolling}")"
  export AERYNOS_VERSION
}

# moss_list FLAG: package names of `moss pkg list FLAG` (--installed, --available), without its colours
moss_list() {
  moss pkg list "$1" 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | awk 'NF >= 2 { print $1 }'
}

moss_installed() { moss_list --installed | grep -qxF -- "$1"; }

# moss_add PKG...: one transaction; pkg add records them in the system-model, so the next sync keeps them
moss_add() {
  [[ $# -gt 0 ]] || return 0
  pkg_sudo moss pkg add -y "$@"
}

# aerynos_model_note PKG...: an explicit system-model (/etc/moss/system-model.kdl) is the person's list of what the
# system has, and a sync drops anything outside it: what setup added is named for them to keep there
aerynos_model_note() {
  [[ $# -gt 0 && -f /etc/moss/system-model.kdl ]] || return 0
  log_warning "This system follows /etc/moss/system-model.kdl: add these packages there or the next moss sync removes them:"
  printf '  %s\n' "$*"
}

# aerynos_build_current NAME VERSION SHA256 PATH: a home build at its pinned version that still runs on today's /usr
aerynos_build_current() {
  local marker="${XDG_DATA_HOME:-$HOME/.local/share}/inir/providers/$1"
  [[ "$(cat "$marker" 2>/dev/null || true)" == "$2:$3" ]] && home_build_runs "$4"
}

aerynos_build_record() {
  local dir="${XDG_DATA_HOME:-$HOME/.local/share}/inir/providers"
  mkdir -p "$dir" && printf '%s\n' "$2:$3" > "$dir/$1"
}

# aerynos_fetch_source NAME URL SHA256 DIR: the verified tarball unpacked in DIR; prints the source folder
aerynos_fetch_source() {
  local name="$1" url="$2" sha="$3" dir="$4" archive="$4/source"
  if ! curl -fsSL --max-time 300 -o "$archive" "$url" \
      || ! printf '%s  %s\n' "$sha" "$archive" | sha256sum -c - >/dev/null 2>&1 \
      || ! tar -xf "$archive" -C "$dir"; then
    log_warning "Could not fetch verified $name source"
    return 1
  fi
  find "$dir" -mindepth 1 -maxdepth 1 -type d -print -quit
}

provider_power-profiles() {
  power_profiles_wanted || return 0
  moss_installed power-profiles-daemon || moss_add power-profiles-daemon || return 1
  power_profiles_enable power-profiles-daemon.service
}

provider_gum() {
  install_user_binary gum "$GUM_VERSION" \
    "https://github.com/charmbracelet/gum/releases/download/v${GUM_VERSION}/gum_${GUM_VERSION}_Linux_x86_64.tar.gz" \
    "$GUM_SHA256" "gum_${GUM_VERSION}_Linux_x86_64/gum"
}

provider_cliphist() {
  install_user_binary cliphist "$CLIPHIST_VERSION" \
    "https://github.com/sentriz/cliphist/releases/download/v${CLIPHIST_VERSION}/v${CLIPHIST_VERSION}-linux-amd64" \
    "$CLIPHIST_SHA256"
}

provider_gowall() {
  install_user_binary gowall "$GOWALL_VERSION" \
    "https://github.com/Achno/gowall/releases/download/v${GOWALL_VERSION}/gowall-amd64-linux.tar.gz" \
    "$GOWALL_SHA256" gowall
}

# translate-shell is one gawk script; upstream's release tag points at this commit
provider_translate-shell() {
  install_user_binary trans "$TRANS_VERSION" \
    "https://raw.githubusercontent.com/soimort/translate-shell/${TRANS_COMMIT}/trans" "$TRANS_SHA256"
}

provider_missioncenter() { install_user_missioncenter "$@"; }

provider_hyprpicker() {
  local prefix="$HOME/.local" temp_dir src
  aerynos_build_current hyprpicker "$HYPRPICKER_VERSION" "$HYPRPICKER_SHA256" "$prefix/bin/hyprpicker" && return 0
  moss_add clang cmake ninja pkgconf wayland-devel wayland-protocols-devel libxkbcommon-devel cairo-devel pango-devel \
    libjpeg-turbo-devel hyprutils-devel hyprwayland-scanner || return 1
  temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/inir-hyprpicker.XXXXXX")" || return 1
  src="$(aerynos_fetch_source hyprpicker \
    "https://github.com/hyprwm/hyprpicker/archive/refs/tags/v${HYPRPICKER_VERSION}.tar.gz" \
    "$HYPRPICKER_SHA256" "$temp_dir")" || { rm -rf "$temp_dir"; return 1; }
  if cmake -S "$src" -B "$temp_dir/build" -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$prefix" \
      && cmake --build "$temp_dir/build" \
      && cmake --install "$temp_dir/build"; then
    aerynos_build_record hyprpicker "$HYPRPICKER_VERSION" "$HYPRPICKER_SHA256"
  fi
  rm -rf "$temp_dir"
  home_build_runs "$prefix/bin/hyprpicker" || { log_warning "hyprpicker $HYPRPICKER_VERSION build failed"; return 1; }
  log_success "hyprpicker $HYPRPICKER_VERSION installed"
}

provider_swappy() {
  local prefix="$HOME/.local" temp_dir src
  aerynos_build_current swappy "$SWAPPY_VERSION" "$SWAPPY_SHA256" "$prefix/bin/swappy" && return 0
  moss_add clang meson ninja pkgconf gettext gtk-3-devel cairo-devel pango-devel glib2-devel libnotify-devel || return 1
  temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/inir-swappy.XXXXXX")" || return 1
  src="$(aerynos_fetch_source swappy \
    "https://github.com/jtheoof/swappy/releases/download/v${SWAPPY_VERSION}/swappy-${SWAPPY_VERSION}.tar.gz" \
    "$SWAPPY_SHA256" "$temp_dir")" || { rm -rf "$temp_dir"; return 1; }
  # its meson.build asks git for the commit with check:true, so the release tarball fails wherever git is installed
  sed -i 's/check:true)/check:false)/' "$src/meson.build"
  if meson setup "$temp_dir/build" "$src" --prefix "$prefix" --buildtype release -Dman-pages=disabled -Dwerror=false \
      && meson compile -C "$temp_dir/build" \
      && meson install -C "$temp_dir/build"; then
    aerynos_build_record swappy "$SWAPPY_VERSION" "$SWAPPY_SHA256"
  fi
  rm -rf "$temp_dir"
  home_build_runs "$prefix/bin/swappy" || { log_warning "swappy $SWAPPY_VERSION build failed"; return 1; }
  log_success "swappy $SWAPPY_VERSION installed"
}

# Blueman is Python with one compiled module: it goes to the user site of the Python there is now, its settings schema
# to the home's schema dir. Its system half (mechanism, polkit, D-Bus) lands under ~/.local unused: the shell drives
# BlueZ itself and opens blueman-manager only as the Bluetooth app.
provider_blueman() {
  local prefix="$HOME/.local" temp_dir src site
  aerynos_build_current blueman "$BLUEMAN_VERSION" "$BLUEMAN_SHA256" "$prefix/bin/blueman-manager" && return 0
  moss_add clang meson ninja pkgconf gettext cython python python-devel python-pygobject python-pygobject-devel \
    python-cairo gtk-3 libnotify bluez bluez-devel glib2-devel || return 1
  site="$(python3 -c 'import site; print(site.getusersitepackages())')" || return 1
  temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/inir-blueman.XXXXXX")" || return 1
  src="$(aerynos_fetch_source blueman \
    "https://github.com/blueman-project/blueman/releases/download/${BLUEMAN_VERSION}/blueman-${BLUEMAN_VERSION}.tar.xz" \
    "$BLUEMAN_SHA256" "$temp_dir")" || { rm -rf "$temp_dir"; return 1; }
  if meson setup "$temp_dir/build" "$src" --prefix "$prefix" --buildtype release \
        -Dpython.purelibdir="$site" -Dpython.platlibdir="$site" \
        -Dsystemdsystemunitdir=lib/systemd/system -Dsystemduserunitdir=lib/systemd/user \
        -Dsendto-plugins=[] -Dthunar-sendto=false -Druntime_deps_check=false \
      && meson compile -C "$temp_dir/build" \
      && meson install -C "$temp_dir/build" \
      && glib-compile-schemas "$prefix/share/glib-2.0/schemas"; then
    aerynos_build_record blueman "$BLUEMAN_VERSION" "$BLUEMAN_SHA256"
  fi
  rm -rf "$temp_dir"
  home_build_runs "$prefix/bin/blueman-manager" || { log_warning "blueman $BLUEMAN_VERSION build failed"; return 1; }
  log_success "blueman $BLUEMAN_VERSION installed"
}

# songrec from crates.io at a pinned version with its lockfile; cargo's registry and target stay in the build folder
provider_songrec() {
  local prefix="$HOME/.local" temp_dir
  aerynos_build_current songrec "$SONGREC_VERSION" crates.io "$prefix/bin/songrec" && return 0
  # clang-devel: libspa-sys runs bindgen, which needs libclang; binutils: cc-rs archives its C parts with ar
  moss_add rust clang clang-devel binutils pkgconf alsa-lib-devel pulseaudio-devel pipewire-devel openssl-devel dbus-devel \
    glib2-devel gtk-4-devel libsoup-devel libadwaita-devel || return 1
  temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/inir-songrec.XXXXXX")" || return 1
  if CARGO_HOME="$temp_dir/cargo" CARGO_TARGET_DIR="$temp_dir/target" cargo install --locked --root "$temp_dir/root" \
        songrec --version "$SONGREC_VERSION" --no-default-features -F gui,ffmpeg,pulse,mpris \
      && install -Dm755 "$temp_dir/root/bin/songrec" "$prefix/bin/songrec"; then
    aerynos_build_record songrec "$SONGREC_VERSION" crates.io
  fi
  rm -rf "$temp_dir"
  home_build_runs "$prefix/bin/songrec" || { log_warning "songrec $SONGREC_VERSION build failed"; return 1; }
  log_success "songrec $SONGREC_VERSION installed"
}

# Umbriel, which AerynOS doesn't package, from what moss has (wlroots 0.20 among it). /usr/local is where systemd
# looks for its user units and the login screen for its session, and Umbriel finds its data under the prefix it was
# built for. Run again by the update when the pin moves or a library under it did.
# Umbriel and its portal, built at their pins (build_umbriel_source, sdata/lib/user-providers.sh)
provider_umbriel() {
  umbriel_build_current && return 0
  moss_add clang meson ninja pkgconf xwayland 'binary(wayland-scanner)' 'binary(glib-compile-resources)' \
    'pkgconfig(wayland-server)' 'pkgconfig(wayland-client)' 'pkgconfig(wayland-protocols)' 'pkgconfig(wlroots-0.20)' \
    'pkgconfig(xkbcommon)' 'pkgconfig(libinput)' 'pkgconfig(libeis-1.0)' 'pkgconfig(pixman-1)' \
    'pkgconfig(tomlplusplus)' 'pkgconfig(nlohmann_json)' 'pkgconfig(cairo)' 'pkgconfig(pangocairo)' \
    'pkgconfig(libdrm)' 'pkgconfig(libdisplay-info)' 'pkgconfig(libudev)' 'pkgconfig(libsystemd)' 'pkgconfig(lcms2)' \
    'pkgconfig(egl)' 'pkgconfig(glesv2)' 'pkgconfig(gbm)' 'pkgconfig(jemalloc)' 'pkgconfig(xcb)' \
    'pkgconfig(xcb-icccm)' 'pkgconfig(xcb-ewmh)' 'pkgconfig(xcb-shape)' 'pkgconfig(xcb-randr)' 'pkgconfig(xcb-render)' \
    'pkgconfig(sdbus-c++)' 'pkgconfig(libpipewire-0.3)' 'pkgconfig(gtk4)' || return 1
  build_umbriel_source
}

# Darkly builds into ~/.local; Qt finds a plugin there only through QT_PLUGIN_PATH, which the user manager takes from
# environment.d at login, so apps started by the compositor or the shell load it
provider_darkly() {
  local prefix="$HOME/.local" env_file
  ${INSTALL_FONTS:-true} || return 0
  moss_add clang cmake make pkgconf extra-cmake-modules gettext qt6-base-devel qt6-declarative-devel qt6ct \
    kf6-kcoreaddons-devel kf6-kcmutils-devel kf6-kcolorscheme-devel kf6-kconfig-devel kf6-kguiaddons-devel \
    kf6-ki18n-devel kf6-kiconthemes-devel kf6-kwindowsystem-devel kf6-kirigami-devel \
    kf6-frameworkintegration-devel kdecoration-devel || return 1
  install_darkly_source "$prefix" || return 1
  env_file="${XDG_CONFIG_HOME:-$HOME/.config}/environment.d/inir.conf"
  if ! grep -qxF 'QT_PLUGIN_PATH=${HOME}/.local/lib/qt6/plugins${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}' "$env_file" 2>/dev/null; then
    mkdir -p "$(dirname "$env_file")"
    printf '%s\n' '# iNiR: Qt plugins setup builds into the home (Darkly)' \
      'QT_PLUGIN_PATH=${HOME}/.local/lib/qt6/plugins${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}' >> "$env_file"
  fi
}

provider_fonts-download() { install_user_fonts && install_user_jetbrains_nerd; }

# adw-gtk3 is a moss package; the icon and cursor themes are not
provider_themes-download() { install_user_whitesur_icons && install_user_capitaine_cursors; }
