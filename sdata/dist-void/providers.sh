# shellcheck shell=bash
# Void providers: what sdata/deps.toml calls `build = "<recipe>"` for Void, as provider_<recipe>, plus the
# pinned versions and checksums they verify. Definitions only, no top-level code: install-deps.sh sources
# it, and so can the inir binary to run one provider.
YDOTOOL_VERSION="1.0.4"
YDOTOOL_SOURCE_SHA256="ba075a43aa6ead51940e892ecffa4d0b8b40c241e4e2bc4bd9bd26b61fde23bd"
TESSDATA_FAST_COMMIT="87416418657359cb625c412a48b6e1d6d41c29bd"
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
ROBOTO_FLEX_VERSION="3.200"
ROBOTO_FLEX_SHA256="6b2b14e11308c7d3e8388b623cf740c46b872e7519198e0cff8062e52b75239b"
ROBOTO_FLEX_FONT_SHA256="a55c1e67f6dcf27f2bb71dc3e4c03d3abcbc5054411aac943b2f94985195825e"
GOOGLE_FONTS_COMMIT="a54f7446f84a1125ef6bf08baa46f3639e8905e0"
GABARITO_SHA256="8650e2bd7747f7d74619fd7aecbcb0309e6f37b7964024f3fb15ae4833b67ca5"
OXANIUM_SHA256="2ce01d946e1e1ffc8d7eecfffbda8623bedd63eaf811a20488c4b69af45babb0"
RUBIK_SHA256="1b3a7437ba2af80e465e773ed60c5036d1ba6ace492d89046dbcf18fb31e4e88"
RUBIK_ITALIC_SHA256="08c6c4018a5ada8b517407b46897e46cf6ebb106853fbd3e89addb51d3b59c62"
DARKLY_VERSION="0.5.39"
DARKLY_SOURCE_SHA256="5fed786f78ac3a6153e99920e722c981348c01fc781fb511371f6bfedee0f0c2"
DARKLY_SOURCE_URL="https://github.com/Bali10050/Darkly/archive/refs/tags/v${DARKLY_VERSION}.tar.gz"
VOID_INSTALL_SPACE_MARGIN_BYTES=$((2 * 1024 * 1024 * 1024))

declare -A VOID_OCR_MODEL_SHA256=(
  [jpn_vert]="bf1e2640954691797e2dc14f38533e601b59ee37958698ae0f0b81dc6f09c71b"
  [chi_sim_vert]="20590de84725bab69cde93bd6e8ed360a13cc5421a7e7364ddeb93e9af53d6da"
  [chi_tra_vert]="1df02a4b210e5c217b783819538b63e9dfe6904e2b5e53b62664f1b9f7a989d0"
)

check_void_install_space() {
  local dry_run required_bytes available_kib available_bytes needed_bytes
  local needed_gib available_gib
  local margin_bytes="${VOID_INSTALL_SPACE_MARGIN_BYTES:-2147483648}"

  [[ $# -gt 0 ]] || return 0

  if ! dry_run="$(xbps-install -n "$@" 2>/dev/null)"; then
    log_warning "Could not estimate Void dependency disk usage; continuing without a space preflight"
    return 0
  fi

  required_bytes="$(awk '
    $5 ~ /^[0-9]+$/ && $6 ~ /^[0-9]+$/ { total += $5 + $6 }
    END { printf "%.0f\n", total + 0 }
  ' <<<"$dry_run")"
  [[ "$required_bytes" =~ ^[0-9]+$ ]] || {
    log_warning "Could not parse Void dependency disk usage; continuing without a space preflight"
    return 0
  }
  (( required_bytes > 0 )) || return 0

  available_kib="$(df -Pk / 2>/dev/null | awk 'NR == 2 { print $4 }')"
  [[ "$available_kib" =~ ^[0-9]+$ ]] || {
    log_warning "Could not determine free root filesystem space; continuing without a space preflight"
    return 0
  }

  available_bytes=$((available_kib * 1024))
  needed_bytes=$((required_bytes + margin_bytes))
  if (( available_bytes < needed_bytes )); then
    needed_gib="$(awk -v bytes="$needed_bytes" 'BEGIN { printf "%.1f", bytes / 1073741824 }')"
    available_gib="$(awk -v bytes="$available_bytes" 'BEGIN { printf "%.1f", bytes / 1073741824 }')"
    log_warning "Not enough free space for the selected Void dependency profiles"
    log_warning "Need about ${needed_gib} GiB including download/build headroom; ${available_gib} GiB is free on /"
    log_warning "Free disk space, disable optional profiles, or enlarge the root filesystem before retrying"
    return 1
  fi

  return 0
}

install_void_ocr_models() {
  local data_home tessdata_dir lang expected_sha target tmp url
  data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
  tessdata_dir="${INIR_TESSDATA_DIR:-$data_home/inir/tessdata}"

  mkdir -p "$tessdata_dir" || {
    log_warning "Could not create OCR model directory: $tessdata_dir"
    return 1
  }

  for lang in "$@"; do
    expected_sha="${VOID_OCR_MODEL_SHA256[$lang]:-}"
    if [[ -z "$expected_sha" ]]; then
      log_warning "No verified Void OCR fallback is defined for $lang"
      return 1
    fi

    target="$tessdata_dir/$lang.traineddata"
    if [[ -s "$target" ]] \
        && printf '%s  %s\n' "$expected_sha" "$target" | sha256sum -c - >/dev/null 2>&1; then
      continue
    fi

    tmp="$target.part.$$"
    url="https://raw.githubusercontent.com/tesseract-ocr/tessdata_fast/${TESSDATA_FAST_COMMIT}/${lang}.traineddata"
    if ! curl -fsSL --max-time 90 -o "$tmp" "$url" \
        || ! printf '%s  %s\n' "$expected_sha" "$tmp" | sha256sum -c - >/dev/null 2>&1 \
        || ! mv -f "$tmp" "$target"; then
      rm -f "$tmp"
      log_warning "Could not provision verified OCR model: $lang"
      return 1
    fi
  done

  log_success "Void OCR language models are ready"
}

configure_void_tesseract_command() {
  local wrapper_dir wrapper_path wrapper

  if command -v tesseract >/dev/null 2>&1; then
    return 0
  fi
  if ! command -v tesseract-ocr >/dev/null 2>&1; then
    log_warning "Void Tesseract binary is unavailable"
    return 1
  fi

  wrapper_dir="${XDG_BIN_HOME:-$HOME/.local/bin}"
  wrapper_path="$wrapper_dir/tesseract"
  wrapper="$(mktemp)" || return 1
  printf '%s\n' '#!/bin/sh' 'exec tesseract-ocr "$@"' > "$wrapper"
  if ! install -Dm755 "$wrapper" "$wrapper_path"; then
    rm -f "$wrapper"
    log_warning "Could not install the Void Tesseract command adapter"
    return 1
  fi
  rm -f "$wrapper"

  if [[ ":$PATH:" != *":${wrapper_dir}:"* ]]; then
    export PATH="$wrapper_dir:$PATH"
  fi
  command -v tesseract >/dev/null 2>&1 || return 1
}

install_void_adw_gtk3() {
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

install_void_whitesur_icons() {
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

install_void_capitaine_cursors() {
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

install_void_visual_providers() {
  install_void_adw_gtk3 || return 1
  install_void_whitesur_icons || return 1
  install_void_capitaine_cursors || return 1
  log_success "Void visual theme providers are ready"
}

install_void_verified_font_file() {
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

install_void_roboto_flex() {
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
      || ! python3 - "$archive" "$extracted" <<'PY'
import sys
import zipfile

archive, target = sys.argv[1:]
with zipfile.ZipFile(archive) as bundle:
    name = next(
        entry for entry in bundle.namelist()
        if "/variable/" in entry and entry.endswith(".ttf")
    )
    with open(target, "wb") as output:
        output.write(bundle.read(name))
PY
  then
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

install_void_font_providers() {
  local data_home config_home font_dir fontconfig_dir alias_file alias_tmp
  data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
  config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
  font_dir="$data_home/fonts"
  fontconfig_dir="$config_home/fontconfig/conf.d"
  alias_file="$fontconfig_dir/60-inir-void-font-aliases.conf"
  mkdir -p "$font_dir"

  install_void_verified_font_file \
    "Material Symbols Rounded" \
    "https://raw.githubusercontent.com/google/material-design-icons/${MATERIAL_SYMBOLS_COMMIT}/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf" \
    "$MATERIAL_SYMBOLS_SHA256" \
    "$font_dir/MaterialSymbolsRounded.ttf" || return 1
  install_void_roboto_flex || return 1
  install_void_verified_font_file \
    "Gabarito" \
    "https://raw.githubusercontent.com/google/fonts/${GOOGLE_FONTS_COMMIT}/ofl/gabarito/Gabarito%5Bwght%5D.ttf" \
    "$GABARITO_SHA256" \
    "$font_dir/Gabarito.ttf" || return 1
  install_void_verified_font_file \
    "Oxanium" \
    "https://raw.githubusercontent.com/google/fonts/${GOOGLE_FONTS_COMMIT}/ofl/oxanium/Oxanium%5Bwght%5D.ttf" \
    "$OXANIUM_SHA256" \
    "$font_dir/Oxanium.ttf" || return 1
  install_void_verified_font_file \
    "Rubik" \
    "https://raw.githubusercontent.com/google/fonts/${GOOGLE_FONTS_COMMIT}/ofl/rubik/Rubik%5Bwght%5D.ttf" \
    "$RUBIK_SHA256" \
    "$font_dir/Rubik.ttf" || return 1
  install_void_verified_font_file \
    "Rubik Italic" \
    "https://raw.githubusercontent.com/google/fonts/${GOOGLE_FONTS_COMMIT}/ofl/rubik/Rubik-Italic%5Bwght%5D.ttf" \
    "$RUBIK_ITALIC_SHA256" \
    "$font_dir/Rubik-Italic.ttf" || return 1

  mkdir -p "$fontconfig_dir"
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
  log_success "Void required font providers are ready"
}

void_darkly_plugin_path() {
  local plugin_dir
  plugin_dir=""
  if command -v qtpaths6 >/dev/null 2>&1; then
    plugin_dir="$(qtpaths6 --plugin-dir 2>/dev/null || true)"
  elif command -v qtpaths >/dev/null 2>&1; then
    plugin_dir="$(qtpaths --plugin-dir 2>/dev/null || true)"
  fi
  for plugin_dir in \
      "$plugin_dir" \
      /usr/lib64/qt6/plugins \
      /usr/lib/qt6/plugins \
      /usr/lib/x86_64-linux-gnu/qt6/plugins; do
    [[ -n "$plugin_dir" && -d "$plugin_dir/styles" ]] || continue
    find "$plugin_dir/styles" -maxdepth 1 -type f -iname '*darkly*.so' -print -quit 2>/dev/null
  done | head -n1
}

void_darkly_kcm_path() {
  local plugin_dir
  plugin_dir=""
  if command -v qtpaths6 >/dev/null 2>&1; then
    plugin_dir="$(qtpaths6 --plugin-dir 2>/dev/null || true)"
  elif command -v qtpaths >/dev/null 2>&1; then
    plugin_dir="$(qtpaths --plugin-dir 2>/dev/null || true)"
  fi
  for plugin_dir in \
      "$plugin_dir" \
      /usr/lib64/qt6/plugins \
      /usr/lib/qt6/plugins \
      /usr/lib/x86_64-linux-gnu/qt6/plugins; do
    [[ -n "$plugin_dir" && -d "$plugin_dir/org.kde.kdecoration3.kcm" ]] || continue
    find "$plugin_dir/org.kde.kdecoration3.kcm" -maxdepth 1 -type f \
      -name 'kcm_darklydecoration.so' -print -quit 2>/dev/null
  done | head -n1
}

install_void_darkly() {
  local data_home marker_dir marker plugin kcm temp_dir archive source_dir build_dir jobs verify_output
  data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
  marker_dir="$data_home/inir/providers"
  marker="$marker_dir/darkly"
  plugin="$(void_darkly_plugin_path || true)"
  kcm="$(void_darkly_kcm_path || true)"

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
  if ! python3 - "$source_dir/CMakeLists.txt" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
old = 'find_package(Qt6 ${QT_MIN_VERSION} REQUIRED CONFIG COMPONENTS Widgets DBus)'
new = 'find_package(Qt6 ${QT_MIN_VERSION} REQUIRED CONFIG COMPONENTS Widgets DBus OpenGL)'
if text.count(old) != 1:
    raise SystemExit('Darkly Qt6 find_package shape changed')
path.write_text(text.replace(old, new, 1))
PY
  then
    rm -rf "$temp_dir"
    log_warning "Darkly v${DARKLY_VERSION} Qt6 build patch no longer applies"
    return 1
  fi

  jobs="$(nproc)"
  (( jobs > 2 )) && jobs=2
  if ! cmake -S "$source_dir" -B "$build_dir" \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=/usr \
      -DKDE_INSTALL_USE_QT_SYS_PATHS=ON \
      -DBUILD_QT5=OFF \
      -DBUILD_QT6=ON \
      -DWITH_DECORATIONS=ON \
      -DBUILD_TESTING=OFF \
      || ! cmake --build "$build_dir" -j"$jobs" \
      || ! pkg_sudo cmake --install "$build_dir"; then
    rm -rf "$temp_dir"
    log_warning "Darkly v${DARKLY_VERSION} Qt6 build/install failed"
    return 1
  fi
  rm -rf "$temp_dir"

  plugin="$(void_darkly_plugin_path || true)"
  kcm="$(void_darkly_kcm_path || true)"
  if [[ -z "$plugin" ]] || ldd "$plugin" 2>/dev/null | grep -Fq 'not found'; then
    log_warning "Darkly Qt6 plugin was not installed with usable runtime dependencies"
    return 1
  fi
  if [[ -z "$kcm" ]] || ldd "$kcm" 2>/dev/null | grep -Fq 'not found'; then
    log_warning "Darkly settings KCM was not installed with usable runtime dependencies"
    return 1
  fi
  verify_output="$(timeout 3 env QT_QPA_PLATFORM=offscreen QT_STYLE_OVERRIDE=Darkly qt6ct 2>&1 || true)"
  if grep -Fq "invalid style override 'Darkly'" <<<"$verify_output"; then
    log_warning "Qt6 rejected the installed Darkly style"
    return 1
  fi

  mkdir -p "$marker_dir"
  printf '%s\n' "${DARKLY_VERSION}:${DARKLY_SOURCE_SHA256}" > "$marker"
  log_success "Darkly v${DARKLY_VERSION} Qt6 style and settings KCM installed"
}

install_void_missioncenter() {
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
    log_warning "Mission Center requires Flatpak on Void"
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

install_void_ydotool() {
  local installed_version
  installed_version="$(ydotoold --version 2>/dev/null || true)"
  if command -v ydotool >/dev/null 2>&1 && [[ "$installed_version" == "v${YDOTOOL_VERSION}" ]]; then
    log_success "ydotool v${YDOTOOL_VERSION} already installed"
    return 0
  fi

  tui_info "Installing ydotool v${YDOTOOL_VERSION} from verified upstream source..."
  local temp_dir archive source_dir build_dir
  temp_dir="$(mktemp -d)" || return 1
  archive="$temp_dir/ydotool.tar.gz"
  source_dir="$temp_dir/ydotool-${YDOTOOL_VERSION}"
  build_dir="$temp_dir/build"

  if ! curl -fsSL --max-time 90 -o "$archive" \
      "https://github.com/ReimuNotMoe/ydotool/archive/refs/tags/v${YDOTOOL_VERSION}.tar.gz" \
      || ! printf '%s  %s\n' "$YDOTOOL_SOURCE_SHA256" "$archive" | sha256sum -c - >/dev/null \
      || ! tar -xzf "$archive" -C "$temp_dir" \
      || ! (cd "$source_dir" && cmake -S . -B "$build_dir" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        "-DCMAKE_C_FLAGS=-DVERSION=\\\"v${YDOTOOL_VERSION}\\\"" \
        && cmake --build "$build_dir" --target ydotool ydotoold -j"$(nproc)") \
      || ! pkg_sudo install -Dm755 "$build_dir/ydotool" "$build_dir/ydotoold" /usr/local/bin/; then
    rm -rf "$temp_dir"
    log_warning "ydotool v${YDOTOOL_VERSION} source installation failed"
    return 1
  fi

  rm -rf "$temp_dir"
  log_success "ydotool v${YDOTOOL_VERSION} installed"
}

# deps.toml recipe names.
provider_missioncenter() { install_void_missioncenter "$@"; }
provider_ydotool() { install_void_ydotool "$@"; }
provider_ocr-vertical-models() { install_void_ocr_models "$@"; }
provider_darkly() { install_void_darkly "$@"; }
provider_themes-download() { install_void_visual_providers "$@"; }
