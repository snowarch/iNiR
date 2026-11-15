# shellcheck shell=bash
# Verified upstream downloads and builds for what a distro does not package: themes, fonts, the Darkly Qt style,
# Mission Center and single binaries. Each is pinned by version and sha256 and lands in the user's home (Darkly also
# under a prefix the caller names). Definitions only: setup sources it, each dist-*/providers.sh calls it.
ADW_GTK3_VERSION="6.5"
ADW_GTK3_SHA256="a81780fadfc432be0fc3d89c4ebb41aa28e4f032d42c36f9789c57dd10cfa41c"
ADW_GTK3_URL="https://github.com/lassekongo83/adw-gtk3/releases/download/v${ADW_GTK3_VERSION}/adw-gtk3v${ADW_GTK3_VERSION}.tar.xz"
WHITESUR_ICON_VERSION="2026-09-10"
WHITESUR_ICON_SHA256="406c9cd59705583f1754b0eaca96cc48bafda042b88ef143f16d8ae1820ecd95"
WHITESUR_ICON_URL="https://github.com/vinceliuice/WhiteSur-icon-theme/archive/refs/tags/${WHITESUR_ICON_VERSION}.tar.gz"
CAPITAINE_VERSION="r5"
CAPITAINE_SHA256="60114cf857902a9907780bdcfa995d600618cf14b37f90776565c9de7e5add6c"
CAPITAINE_URL="https://github.com/sainnhe/capitaine-cursors/releases/download/${CAPITAINE_VERSION}/Linux.zip"
MATERIAL_SYMBOLS_COMMIT="40a7a292a79d9394157e1ea24f83d52d5e17c556"
MATERIAL_SYMBOLS_SHA256="f1472f172c0fc4a922be22972e4752ccc54fe795ed82564ab6f6b097782f2dbc"
MATERIAL_SYMBOLS_OUTLINED_SHA256="bf4c94b08c06c6b17e9d1a2d54a68c3f2c3435454761d487768df137a81f851d"
MATERIAL_SYMBOLS_SHARP_SHA256="53f7747272a09f35171452c5cab6f147f32a7e6df30d684b2a5010ad8810eb7c"
ROBOTO_FLEX_VERSION="3.200"
ROBOTO_FLEX_SHA256="6b2b14e11308c7d3e8388b623cf740c46b872e7519198e0cff8062e52b75239b"
ROBOTO_FLEX_FONT_SHA256="a55c1e67f6dcf27f2bb71dc3e4c03d3abcbc5054411aac943b2f94985195825e"
GOOGLE_FONTS_COMMIT="a54f7446f84a1125ef6bf08baa46f3639e8905e0"
GABARITO_SHA256="8650e2bd7747f7d74619fd7aecbcb0309e6f37b7964024f3fb15ae4833b67ca5"
OXANIUM_SHA256="2ce01d946e1e1ffc8d7eecfffbda8623bedd63eaf811a20488c4b69af45babb0"
RUBIK_SHA256="1b3a7437ba2af80e465e773ed60c5036d1ba6ace492d89046dbcf18fb31e4e88"
RUBIK_ITALIC_SHA256="08c6c4018a5ada8b517407b46897e46cf6ebb106853fbd3e89addb51d3b59c62"
SPACE_GROTESK_SHA256="acad6de1fc93436f5c0f1f4137751ef04f1aea3063e7036535970ffcfbd79f72"
READEX_PRO_SHA256="268bba7e1e8f3b14d798b3fb0e40ebaa3fc39308c9ac0020e2faf6df181cc30e"
DARKLY_VERSION="0.5.39"
DARKLY_SOURCE_SHA256="5fed786f78ac3a6153e99920e722c981348c01fc781fb511371f6bfedee0f0c2"
DARKLY_SOURCE_URL="https://github.com/Bali10050/Darkly/archive/refs/tags/v${DARKLY_VERSION}.tar.gz"
JETBRAINS_NERD_VERSION="3.5.1"
JETBRAINS_NERD_SHA256="04d5e8f903693f9dd13e16f867e994834e681eb3c72c0d337a770dcda09010cf"
JETBRAINS_NERD_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v${JETBRAINS_NERD_VERSION}/JetBrainsMono.tar.xz"

install_user_adw_gtk3() {
  local data_home theme_dir marker_dir marker temp_dir archive
  data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
  theme_dir="$data_home/themes"
  marker_dir="$data_home/inir/providers"
  marker="$marker_dir/adw-gtk3"

  if [[ -d "$theme_dir/adw-gtk3" && -d "$theme_dir/adw-gtk3-dark" ]] \
      && [[ "$(cat "$marker" 2>/dev/null || true)" == "${ADW_GTK3_VERSION}:${ADW_GTK3_SHA256}" ]]; then
    return 0
  fi

  temp_dir="$(mktemp -d)" || return 1
  archive="$temp_dir/adw-gtk3.tar.xz"
  if ! curl -fsSL --max-time 90 -o "$archive" "$ADW_GTK3_URL" \
      || ! printf '%s  %s\n' "$ADW_GTK3_SHA256" "$archive" | sha256sum -c - >/dev/null \
      || ! mkdir -p "$temp_dir/extract" \
      || ! tar -xJf "$archive" -C "$temp_dir/extract" \
      || [[ ! -d "$temp_dir/extract/adw-gtk3" || ! -d "$temp_dir/extract/adw-gtk3-dark" ]]; then
    rm -rf "$temp_dir"
    log_warning "Could not provision verified adw-gtk3 v${ADW_GTK3_VERSION}"
    return 1
  fi

  mkdir -p "$theme_dir" "$marker_dir"
  rm -rf "$theme_dir/adw-gtk3" "$theme_dir/adw-gtk3-dark"
  if ! cp -a "$temp_dir/extract/adw-gtk3" "$temp_dir/extract/adw-gtk3-dark" "$theme_dir/"; then
    rm -rf "$temp_dir"
    return 1
  fi
  printf '%s\n' "${ADW_GTK3_VERSION}:${ADW_GTK3_SHA256}" > "$marker"
  rm -rf "$temp_dir"
}

install_user_whitesur_icons() {
  local data_home icon_dir marker_dir marker temp_dir archive source_dir stage
  data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
  icon_dir="$data_home/icons"
  marker_dir="$data_home/inir/providers"
  marker="$marker_dir/whitesur-icons"

  if [[ -d "$icon_dir/WhiteSur-dark" ]] \
      && [[ "$(cat "$marker" 2>/dev/null || true)" == "${WHITESUR_ICON_VERSION}:${WHITESUR_ICON_SHA256}" ]]; then
    return 0
  fi

  temp_dir="$(mktemp -d)" || return 1
  archive="$temp_dir/whitesur-icons.tar.gz"
  source_dir="$temp_dir/WhiteSur-icon-theme-${WHITESUR_ICON_VERSION}"
  stage="$temp_dir/stage"
  if ! curl -fsSL --max-time 90 -o "$archive" "$WHITESUR_ICON_URL" \
      || ! printf '%s  %s\n' "$WHITESUR_ICON_SHA256" "$archive" | sha256sum -c - >/dev/null \
      || ! tar -xzf "$archive" -C "$temp_dir" \
      || [[ ! -x "$source_dir/install.sh" ]] \
      || ! mkdir -p "$stage" \
      || ! (cd "$source_dir" && ./install.sh -d "$stage" -t default >/dev/null 2>&1) \
      || [[ ! -d "$stage/WhiteSur-dark" ]]; then
    rm -rf "$temp_dir"
    log_warning "Could not provision verified WhiteSur icons ${WHITESUR_ICON_VERSION}"
    return 1
  fi

  mkdir -p "$icon_dir" "$marker_dir"
  rm -rf "$icon_dir/WhiteSur" "$icon_dir/WhiteSur-dark" "$icon_dir/WhiteSur-light"
  if ! cp -a "$stage/WhiteSur" "$stage/WhiteSur-dark" "$stage/WhiteSur-light" "$icon_dir/"; then
    rm -rf "$temp_dir"
    return 1
  fi
  printf '%s\n' "${WHITESUR_ICON_VERSION}:${WHITESUR_ICON_SHA256}" > "$marker"
  rm -rf "$temp_dir"
}

install_user_capitaine_cursors() {
  local data_home icon_dir marker_dir marker temp_dir archive extract_dir dark light
  data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
  icon_dir="$data_home/icons"
  marker_dir="$data_home/inir/providers"
  marker="$marker_dir/capitaine-cursors"
  dark="Capitaine Cursors"
  light="Capitaine Cursors - White"

  if [[ -d "$icon_dir/$dark" && -d "$icon_dir/$light" \
      && -L "$icon_dir/capitaine-cursors-light" ]] \
      && [[ "$(cat "$marker" 2>/dev/null || true)" == "${CAPITAINE_VERSION}:${CAPITAINE_SHA256}" ]]; then
    return 0
  fi

  temp_dir="$(mktemp -d)" || return 1
  archive="$temp_dir/capitaine.zip"
  extract_dir="$temp_dir/extract"
  if ! curl -fsSL --max-time 90 -o "$archive" "$CAPITAINE_URL" \
      || ! printf '%s  %s\n' "$CAPITAINE_SHA256" "$archive" | sha256sum -c - >/dev/null \
      || ! mkdir -p "$extract_dir" \
      || ! unzip -q "$archive" -d "$extract_dir" \
      || [[ ! -d "$extract_dir/$dark" || ! -d "$extract_dir/$light" ]]; then
    rm -rf "$temp_dir"
    log_warning "Could not provision verified Capitaine cursors ${CAPITAINE_VERSION}"
    return 1
  fi

  mkdir -p "$icon_dir" "$marker_dir"
  rm -rf "$icon_dir/$dark" "$icon_dir/$light" \
    "$icon_dir/capitaine-cursors" "$icon_dir/capitaine-cursors-light"
  if ! cp -a "$extract_dir/$dark" "$extract_dir/$light" "$icon_dir/" \
      || ! ln -s "$dark" "$icon_dir/capitaine-cursors" \
      || ! ln -s "$light" "$icon_dir/capitaine-cursors-light"; then
    rm -rf "$temp_dir"
    return 1
  fi
  printf '%s\n' "${CAPITAINE_VERSION}:${CAPITAINE_SHA256}" > "$marker"
  rm -rf "$temp_dir"
}

install_user_visual_themes() {
  install_user_adw_gtk3 || return 1
  install_user_whitesur_icons || return 1
  install_user_capitaine_cursors || return 1
  log_success "GTK theme, icons and cursors are ready"
}

install_user_verified_file() {
  local label="$1" url="$2" expected_sha="$3" target="$4"
  local tmp

  if [[ -s "$target" ]] \
      && printf '%s  %s\n' "$expected_sha" "$target" | sha256sum -c - >/dev/null 2>&1; then
    return 0
  fi

  mkdir -p "$(dirname "$target")"
  tmp="${target}.part.$$"
  if ! curl -fsSL --max-time 120 -o "$tmp" "$url" \
      || ! printf '%s  %s\n' "$expected_sha" "$tmp" | sha256sum -c - >/dev/null 2>&1 \
      || ! mv -f "$tmp" "$target"; then
    rm -f "$tmp"
    log_warning "Could not provision verified font: $label"
    return 1
  fi
}

install_user_roboto_flex() {
  local data_home font_dir target temp_dir archive extracted
  data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
  font_dir="$data_home/fonts"
  target="$font_dir/RobotoFlex.ttf"

  if [[ -s "$target" ]] \
      && printf '%s  %s\n' "$ROBOTO_FLEX_FONT_SHA256" "$target" | sha256sum -c - >/dev/null 2>&1; then
    return 0
  fi

  temp_dir="$(mktemp -d)" || return 1
  archive="$temp_dir/roboto-flex.zip"
  extracted="$temp_dir/RobotoFlex.ttf"
  if ! curl -fsSL --max-time 120 -o "$archive" \
      "https://github.com/googlefonts/roboto-flex/releases/download/${ROBOTO_FLEX_VERSION}/roboto-flex-fonts.zip" \
      || ! printf '%s  %s\n' "$ROBOTO_FLEX_SHA256" "$archive" | sha256sum -c - >/dev/null 2>&1 \
      || ! name="$(unzip -Z1 "$archive" | grep -m1 '/variable/.*\.ttf$')" \
      || ! unzip -p "$archive" "${name//\[/[[]}" > "$extracted"; then  # unzip reads [...] as a wildcard: [[] is a [
    rm -rf "$temp_dir"
    log_warning "Could not extract verified Roboto Flex ${ROBOTO_FLEX_VERSION}"
    return 1
  fi
  if ! printf '%s  %s\n' "$ROBOTO_FLEX_FONT_SHA256" "$extracted" | sha256sum -c - >/dev/null 2>&1; then
    rm -rf "$temp_dir"
    log_warning "Roboto Flex extracted font checksum mismatch"
    return 1
  fi
  mkdir -p "$font_dir"
  if ! install -m 0644 "$extracted" "$target"; then
    rm -rf "$temp_dir"
    return 1
  fi
  rm -rf "$temp_dir"
}

install_user_fonts() {
  local data_home config_home font_dir fontconfig_dir alias_file alias_tmp
  data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
  config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
  font_dir="$data_home/fonts"
  fontconfig_dir="$config_home/fontconfig/conf.d"
  alias_file="$fontconfig_dir/60-inir-font-aliases.conf"
  mkdir -p "$font_dir"

  install_user_verified_file \
    "Material Symbols Rounded" \
    "https://raw.githubusercontent.com/google/material-design-icons/${MATERIAL_SYMBOLS_COMMIT}/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf" \
    "$MATERIAL_SYMBOLS_SHA256" \
    "$font_dir/MaterialSymbolsRounded.ttf" || return 1
  # The other two glyph sets are a person's pick, never worth failing the install for.
  install_user_verified_file \
    "Material Symbols Outlined" \
    "https://raw.githubusercontent.com/google/material-design-icons/${MATERIAL_SYMBOLS_COMMIT}/variablefont/MaterialSymbolsOutlined%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf" \
    "$MATERIAL_SYMBOLS_OUTLINED_SHA256" \
    "$font_dir/MaterialSymbolsOutlined.ttf" || true
  install_user_verified_file \
    "Material Symbols Sharp" \
    "https://raw.githubusercontent.com/google/material-design-icons/${MATERIAL_SYMBOLS_COMMIT}/variablefont/MaterialSymbolsSharp%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf" \
    "$MATERIAL_SYMBOLS_SHARP_SHA256" \
    "$font_dir/MaterialSymbolsSharp.ttf" || true
  install_user_roboto_flex || return 1
  install_user_verified_file \
    "Gabarito" \
    "https://raw.githubusercontent.com/google/fonts/${GOOGLE_FONTS_COMMIT}/ofl/gabarito/Gabarito%5Bwght%5D.ttf" \
    "$GABARITO_SHA256" \
    "$font_dir/Gabarito.ttf" || return 1
  install_user_verified_file \
    "Oxanium" \
    "https://raw.githubusercontent.com/google/fonts/${GOOGLE_FONTS_COMMIT}/ofl/oxanium/Oxanium%5Bwght%5D.ttf" \
    "$OXANIUM_SHA256" \
    "$font_dir/Oxanium.ttf" || return 1
  install_user_verified_file \
    "Rubik" \
    "https://raw.githubusercontent.com/google/fonts/${GOOGLE_FONTS_COMMIT}/ofl/rubik/Rubik%5Bwght%5D.ttf" \
    "$RUBIK_SHA256" \
    "$font_dir/Rubik.ttf" || return 1
  install_user_verified_file \
    "Rubik Italic" \
    "https://raw.githubusercontent.com/google/fonts/${GOOGLE_FONTS_COMMIT}/ofl/rubik/Rubik-Italic%5Bwght%5D.ttf" \
    "$RUBIK_ITALIC_SHA256" \
    "$font_dir/Rubik-Italic.ttf" || return 1
  # Space Grotesk is the desktop clock's default face and Readex Pro the reading one; the shell falls back without them
  install_user_verified_file \
    "Space Grotesk" \
    "https://raw.githubusercontent.com/google/fonts/${GOOGLE_FONTS_COMMIT}/ofl/spacegrotesk/SpaceGrotesk%5Bwght%5D.ttf" \
    "$SPACE_GROTESK_SHA256" \
    "$font_dir/SpaceGrotesk.ttf" || true
  install_user_verified_file \
    "Readex Pro" \
    "https://raw.githubusercontent.com/google/fonts/${GOOGLE_FONTS_COMMIT}/ofl/readexpro/ReadexPro%5BHEXP%2Cwght%5D.ttf" \
    "$READEX_PRO_SHA256" \
    "$font_dir/ReadexPro.ttf" || true

  mkdir -p "$fontconfig_dir"
  # the alias file's name before it was shared by every distro
  rm -f "$fontconfig_dir/60-inir-void-font-aliases.conf"
  alias_tmp="$(mktemp)" || return 1
  printf '%s\n' \
    '<?xml version="1.0"?>' \
    '<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">' \
    '<fontconfig>' \
    '  <alias binding="same">' \
    '    <family>Google Sans Flex</family>' \
    '    <prefer>' \
    '      <family>Roboto Flex</family>' \
    '    </prefer>' \
    '  </alias>' \
    '</fontconfig>' > "$alias_tmp"
  if [[ ! -f "$alias_file" ]] || ! cmp -s "$alias_tmp" "$alias_file"; then
    if ! install -m 0644 "$alias_tmp" "$alias_file"; then
      rm -f "$alias_tmp"
      return 1
    fi
  fi
  rm -f "$alias_tmp"

  fc-cache -f "$font_dir" >/dev/null 2>&1 || return 1
  log_success "Required fonts are ready"
}

# JetBrains Mono with Nerd Font glyphs, the shell's monospace face, for a distro that packages only the plain font.
install_user_jetbrains_nerd() {
  local data_home font_dir marker_dir marker temp_dir archive
  data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
  font_dir="$data_home/fonts/JetBrainsMonoNerd"
  marker_dir="$data_home/inir/providers"
  marker="$marker_dir/jetbrains-mono-nerd"

  if compgen -G "$font_dir/JetBrainsMonoNerdFont-*.ttf" >/dev/null \
      && [[ "$(cat "$marker" 2>/dev/null || true)" == "${JETBRAINS_NERD_VERSION}:${JETBRAINS_NERD_SHA256}" ]]; then
    return 0
  fi

  temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/inir-jbm.XXXXXX")" || return 1
  archive="$temp_dir/JetBrainsMono.tar.xz"
  if ! curl -fsSL --max-time 300 -o "$archive" "$JETBRAINS_NERD_URL" \
      || ! printf '%s  %s\n' "$JETBRAINS_NERD_SHA256" "$archive" | sha256sum -c - >/dev/null 2>&1 \
      || ! mkdir -p "$temp_dir/extract" \
      || ! tar -xJf "$archive" -C "$temp_dir/extract" --wildcards 'JetBrainsMonoNerdFont-*.ttf' \
      || ! compgen -G "$temp_dir/extract/JetBrainsMonoNerdFont-*.ttf" >/dev/null; then
    rm -rf "$temp_dir"
    log_warning "Could not provision verified JetBrains Mono Nerd Font ${JETBRAINS_NERD_VERSION}"
    return 1
  fi
  rm -rf "$font_dir"
  mkdir -p "$font_dir" "$marker_dir"
  if ! install -m 0644 "$temp_dir"/extract/JetBrainsMonoNerdFont-*.ttf "$font_dir/"; then
    rm -rf "$temp_dir"
    return 1
  fi
  printf '%s\n' "${JETBRAINS_NERD_VERSION}:${JETBRAINS_NERD_SHA256}" > "$marker"
  rm -rf "$temp_dir"
  fc-cache -f "$data_home/fonts" >/dev/null 2>&1 || true
}

# install_user_binary NAME VERSION URL SHA256 [MEMBER]: a pinned upstream program into XDG_BIN_HOME. MEMBER is its path
# inside a tar archive; without one the download is the program itself.
install_user_binary() {
  local name="$1" version="$2" url="$3" sha="$4" member="${5:-}"
  local target marker_dir marker temp_dir file
  target="${XDG_BIN_HOME:-$HOME/.local/bin}/$name"
  marker_dir="${XDG_DATA_HOME:-$HOME/.local/share}/inir/providers"
  marker="$marker_dir/$name"

  if [[ -x "$target" && "$(cat "$marker" 2>/dev/null || true)" == "${version}:${sha}" ]]; then
    return 0
  fi

  temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/inir-$name.XXXXXX")" || return 1
  file="$temp_dir/download"
  if ! curl -fsSL --max-time 300 -o "$file" "$url" \
      || ! printf '%s  %s\n' "$sha" "$file" | sha256sum -c - >/dev/null 2>&1; then
    rm -rf "$temp_dir"
    log_warning "Could not download verified $name $version"
    return 1
  fi
  if [[ -n "$member" ]]; then
    if ! tar -xf "$file" -C "$temp_dir" "$member" 2>/dev/null; then
      rm -rf "$temp_dir"
      log_warning "$name $version: $member is not in the archive"
      return 1
    fi
    file="$temp_dir/$member"
  fi
  if [[ ! -s "$file" ]] || ! install -Dm755 "$file" "$target"; then
    rm -rf "$temp_dir"
    log_warning "Could not install $name to $target"
    return 1
  fi
  mkdir -p "$marker_dir"
  printf '%s\n' "${version}:${sha}" > "$marker"
  rm -rf "$temp_dir"
  log_success "$name $version installed"
}

# darkly_find SUBDIR NAME [PLUGIN_DIR]: Darkly's NAME under SUBDIR of the Qt plugin dirs, PLUGIN_DIR first
darkly_find() {
  local subdir="$1" name="$2" first="${3:-}" qt_dir="" dir
  if command -v qtpaths6 >/dev/null 2>&1; then
    qt_dir="$(qtpaths6 --plugin-dir 2>/dev/null || true)"
  elif command -v qtpaths >/dev/null 2>&1; then
    qt_dir="$(qtpaths --plugin-dir 2>/dev/null || true)"
  fi
  for dir in \
      "$first" \
      "$qt_dir" \
      /usr/lib64/qt6/plugins \
      /usr/lib/qt6/plugins \
      /usr/lib/x86_64-linux-gnu/qt6/plugins; do
    [[ -n "$dir" && -d "$dir/$subdir" ]] || continue
    find "$dir/$subdir" -maxdepth 1 -type f -iname "$name" -print -quit 2>/dev/null
  done | head -n1
}

darkly_plugin_path() { darkly_find styles '*darkly*.so' "$@"; }
darkly_kcm_path() { darkly_find org.kde.kdecoration3.kcm kcm_darklydecoration.so "$@"; }

# install_darkly_source PREFIX: Darkly from its pinned source. /usr goes into Qt's own plugin dir through sudo; a
# prefix in the home (a distro whose /usr belongs to its package manager) puts the plugins in PREFIX/lib/qt6/plugins,
# which QT_PLUGIN_PATH has to name for apps to load them.
install_darkly_source() {
  local prefix="${1:-/usr}" plugin_dir=""
  local data_home marker_dir marker plugin kcm temp_dir archive source_dir build_dir jobs verify_output
  local -a layout=(-DKDE_INSTALL_USE_QT_SYS_PATHS=ON) install=(pkg_sudo cmake --install)
  if [[ "$prefix" != /usr ]]; then
    plugin_dir="$prefix/lib/qt6/plugins"
    layout=(-DKDE_INSTALL_USE_QT_SYS_PATHS=OFF -DKDE_INSTALL_LIBDIR=lib -DKDE_INSTALL_QTPLUGINDIR=lib/qt6/plugins)
    install=(cmake --install)
  fi
  data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
  marker_dir="$data_home/inir/providers"
  marker="$marker_dir/darkly"
  plugin="$(darkly_plugin_path "$plugin_dir" || true)"
  kcm="$(darkly_kcm_path "$plugin_dir" || true)"

  if [[ -n "$plugin" ]] \
      && [[ -n "$kcm" ]] \
      && [[ "$(cat "$marker" 2>/dev/null || true)" == "${DARKLY_VERSION}:${DARKLY_SOURCE_SHA256}" ]] \
      && ! ldd "$plugin" 2>/dev/null | grep -Fq 'not found' \
      && ! ldd "$kcm" 2>/dev/null | grep -Fq 'not found'; then
    return 0
  fi

  temp_dir="$(mktemp -d)" || return 1
  archive="$temp_dir/darkly.tar.gz"
  source_dir="$temp_dir/Darkly-${DARKLY_VERSION}"
  build_dir="$temp_dir/build"
  if ! curl -fsSL --max-time 120 -o "$archive" "$DARKLY_SOURCE_URL" \
      || ! printf '%s  %s\n' "$DARKLY_SOURCE_SHA256" "$archive" | sha256sum -c - >/dev/null 2>&1 \
      || ! tar -xzf "$archive" -C "$temp_dir"; then
    rm -rf "$temp_dir"
    log_warning "Could not fetch verified Darkly v${DARKLY_VERSION} source"
    return 1
  fi
  # the one find_package line, exactly once, or the patch no longer applies
  if ! awk -v old='find_package(Qt6 ${QT_MIN_VERSION} REQUIRED CONFIG COMPONENTS Widgets DBus)' \
        -v new='find_package(Qt6 ${QT_MIN_VERSION} REQUIRED CONFIG COMPONENTS Widgets DBus OpenGL)' '
        { while ((i = index($0, old))) { n++; printf "%s", substr($0, 1, i - 1) new; $0 = substr($0, i + length(old)) } print }
        END { exit n != 1 }' "$source_dir/CMakeLists.txt" > "$source_dir/CMakeLists.txt.new" \
      || ! mv -f "$source_dir/CMakeLists.txt.new" "$source_dir/CMakeLists.txt"; then
    rm -rf "$temp_dir"
    log_warning "Darkly v${DARKLY_VERSION} Qt6 build patch no longer applies"
    return 1
  fi

  jobs="$(nproc)"
  (( jobs > 2 )) && jobs=2
  if ! cmake -S "$source_dir" -B "$build_dir" \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX="$prefix" \
      "${layout[@]}" \
      -DBUILD_QT5=OFF \
      -DBUILD_QT6=ON \
      -DWITH_DECORATIONS=ON \
      -DBUILD_TESTING=OFF \
      || ! cmake --build "$build_dir" -j"$jobs" \
      || ! "${install[@]}" "$build_dir"; then
    rm -rf "$temp_dir"
    log_warning "Darkly v${DARKLY_VERSION} Qt6 build/install failed"
    return 1
  fi
  rm -rf "$temp_dir"

  plugin="$(darkly_plugin_path "$plugin_dir" || true)"
  kcm="$(darkly_kcm_path "$plugin_dir" || true)"
  if [[ -z "$plugin" ]] || ldd "$plugin" 2>/dev/null | grep -Fq 'not found'; then
    log_warning "Darkly Qt6 plugin was not installed with usable runtime dependencies"
    return 1
  fi
  if [[ -z "$kcm" ]] || ldd "$kcm" 2>/dev/null | grep -Fq 'not found'; then
    log_warning "Darkly settings KCM was not installed with usable runtime dependencies"
    return 1
  fi
  verify_output="$(timeout 3 env QT_PLUGIN_PATH="${plugin_dir:+$plugin_dir:}${QT_PLUGIN_PATH:-}" \
    QT_QPA_PLATFORM=offscreen QT_STYLE_OVERRIDE=Darkly qt6ct 2>&1 || true)"
  if grep -Fq "invalid style override 'Darkly'" <<<"$verify_output"; then
    log_warning "Qt6 rejected the installed Darkly style"
    return 1
  fi

  mkdir -p "$marker_dir"
  printf '%s\n' "${DARKLY_VERSION}:${DARKLY_SOURCE_SHA256}" > "$marker"
  log_success "Darkly v${DARKLY_VERSION} Qt6 style and settings KCM installed"
}

install_user_missioncenter() {
  local app_id="io.missioncenter.MissionCenter"
  local wrapper_dir wrapper_path wrapper

  wrapper_dir="${XDG_BIN_HOME:-$HOME/.local/bin}"
  wrapper_path="$wrapper_dir/missioncenter"

  if command -v flatpak >/dev/null 2>&1 \
      && flatpak info --user "$app_id" >/dev/null 2>&1 \
      && [[ -x "$wrapper_path" ]] \
      && grep -Fq 'exec flatpak run io.missioncenter.MissionCenter "$@"' "$wrapper_path"; then
    log_success "Mission Center already installed"
    return 0
  fi

  if ! command -v flatpak >/dev/null 2>&1; then
    log_warning "Mission Center needs Flatpak"
    return 1
  fi

  tui_info "Installing Mission Center from Flathub..."
  if ! flatpak remote-add --if-not-exists --user flathub \
      https://flathub.org/repo/flathub.flatpakrepo >/dev/null 2>&1 \
      || ! flatpak install -y --user flathub "$app_id" >/dev/null 2>&1; then
    log_warning "Mission Center Flatpak installation failed"
    return 1
  fi

  wrapper="$(mktemp)" || return 1
  printf '%s\n' '#!/bin/sh' 'exec flatpak run io.missioncenter.MissionCenter "$@"' > "$wrapper"
  if ! install -Dm755 "$wrapper" "$wrapper_path"; then
    rm -f "$wrapper"
    log_warning "Could not install the Mission Center launcher"
    return 1
  fi
  rm -f "$wrapper"

  if [[ ! -x "$wrapper_path" ]] \
      || ! grep -Fq 'exec flatpak run io.missioncenter.MissionCenter "$@"' "$wrapper_path"; then
    log_warning "Mission Center launcher verification failed: $wrapper_path"
    return 1
  fi

  log_success "Mission Center installed"
}

# home_build_runs PATH: a program setup built into the home still finds every library it links. A rolling /usr
# (AerynOS replaces it whole on each moss transaction) can move a soname under it; a Python program also needs its
# compiled module for the Python there is now (blueman-manager: _blueman*.so in that Python's user site).
home_build_runs() {
  local path="$1" py site mod
  [[ -x "$path" ]] || return 1
  if [[ "$(head -c4 "$path" 2>/dev/null)" != $'\x7fELF' ]]; then
    py="$(readlink -f /usr/bin/python3 2>/dev/null)" || return 0
    [[ -n "$py" ]] || return 0
    site="$HOME/.local/lib/${py##*/}/site-packages"
    mod="$(compgen -G "$site/_$(basename "$path" -manager)*.so" | head -n1)"
    [[ -n "$mod" ]] || return 1
    path="$mod"
  fi
  ! ldd "$path" 2>/dev/null | grep -q 'not found'
}

# ── Umbriel from source ──────────────────────────────────────────────────────────────────────────────────────────
# Where no repository packages Umbriel (AerynOS, Void), setup builds it and xdg-desktop-portal-umbriel (screen
# sharing) into /usr/local, which no package manager touches. Neither has releases: the pins are the commits iNiR's
# defaults/umbriel was last proved on in a VM (the portal's is the one Noctalia's own Debian packages carry). A
# distro's provider_umbriel installs the build dependencies, then calls build_umbriel_source. The record says what is
# built; doctor asks for a rebuild when a pin moves or a library under either program went away.
UMBRIEL_COMMIT="70b3724f3a192b3f05562f3c28df84564df5fa06"
UMBRIEL_SHA256="f3455efbbfe032e743ef9b06d803f7eff4e9be9f17b583f78267d814b3fbbfaa"
UMBRIEL_PORTAL_COMMIT="56951426eb9931db3f1c57348f226c2427fba4f3"
UMBRIEL_PORTAL_SHA256="9b06e0b352499dce6a6ed3147998645a0d9959f959c7480da5b6bc0fc41256a8"
UMBRIEL_PREFIX=/usr/local

umbriel_build_record() { printf '%s\n' "${XDG_DATA_HOME:-$HOME/.local/share}/inir/providers/umbriel"; }

# umbriel_build_current: both pins are what is built here, and both programs still start on today's libraries
umbriel_build_current() {
  [[ "$(cat "$(umbriel_build_record)" 2>/dev/null)" == "$UMBRIEL_COMMIT:$UMBRIEL_PORTAL_COMMIT" ]] \
    && home_build_runs "$UMBRIEL_PREFIX/bin/umbriel" \
    && home_build_runs "$UMBRIEL_PREFIX/libexec/xdg-desktop-portal-umbriel"
}

# umbriel_meson_install NAME COMMIT SHA256 DIR JOBS MESON_OPTION...: one noctalia-dev project at its commit, checked
# against its sha256, built in DIR and installed under UMBRIEL_PREFIX
umbriel_meson_install() {
  local name="$1" commit="$2" sha="$3" dir="$4/$1" jobs="$5"
  shift 5
  mkdir -p "$dir" || return 1
  if ! curl -fsSL --max-time 300 -o "$dir.tar.gz" "https://github.com/noctalia-dev/$name/archive/$commit.tar.gz" \
      || ! printf '%s  %s\n' "$sha" "$dir.tar.gz" | sha256sum -c - >/dev/null 2>&1 \
      || ! tar -xf "$dir.tar.gz" -C "$dir"; then
    log_warning "Could not fetch verified $name source"
    return 1
  fi
  meson setup "$dir/build" "$dir/$name-$commit" --prefix "$UMBRIEL_PREFIX" --buildtype release "$@" \
    && meson compile -C "$dir/build" -j "$jobs" \
    && pkg_sudo meson install -C "$dir/build" --no-rebuild
}

build_umbriel_source() {
  umbriel_build_current && return 0
  local temp_dir jobs record ok=false
  temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/inir-umbriel.XXXXXX")" || return 1
  # a C++23 unit of Umbriel takes up to 1.5 GB: one job per 1.5 GB free, never more than the cores
  jobs="$(awk '/^MemAvailable:/ { print int($2 / 1500000) }' /proc/meminfo)"
  (( jobs < 1 )) && jobs=1
  (( jobs > $(nproc) )) && jobs="$(nproc)"
  tui_info "Building Umbriel ${UMBRIEL_COMMIT:0:12} and its screen-sharing portal (not packaged here; a few minutes)..."
  if umbriel_meson_install umbriel "$UMBRIEL_COMMIT" "$UMBRIEL_SHA256" "$temp_dir" "$jobs" \
        -Dtests=disabled -Dharness=disabled \
      && umbriel_meson_install xdg-desktop-portal-umbriel "$UMBRIEL_PORTAL_COMMIT" "$UMBRIEL_PORTAL_SHA256" \
        "$temp_dir" "$jobs" -Dtests=false; then
    record="$(umbriel_build_record)"
    mkdir -p "${record%/*}" && printf '%s\n' "$UMBRIEL_COMMIT:$UMBRIEL_PORTAL_COMMIT" > "$record" && ok=true
  fi
  rm -rf "$temp_dir"
  if ! $ok || ! umbriel_build_current; then
    log_warning "Umbriel ${UMBRIEL_COMMIT:0:12} build failed"
    return 1
  fi
  log_success "Umbriel ${UMBRIEL_COMMIT:0:12} and its portal installed in $UMBRIEL_PREFIX"
}
