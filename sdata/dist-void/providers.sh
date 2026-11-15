# shellcheck shell=bash
# Void providers: what sdata/deps.toml calls `build = "<recipe>"` for Void, as provider_<recipe>, plus the
# pinned versions and checksums they verify. Definitions only, no top-level code: install-deps.sh sources
# it, and so can the inir binary to run one provider.
YDOTOOL_VERSION="1.0.4"
YDOTOOL_SOURCE_SHA256="ba075a43aa6ead51940e892ecffa4d0b8b40c241e4e2bc4bd9bd26b61fde23bd"
TESSDATA_FAST_COMMIT="87416418657359cb625c412a48b6e1d6d41c29bd"
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
provider_missioncenter() { install_user_missioncenter "$@"; }
provider_ydotool() { install_void_ydotool "$@"; }
# The OCR packages call their program tesseract-ocr; iNiR and doctor call tesseract. Alone (setup provider),
# it installs the vertical models the install path installs.
provider_ocr-vertical-models() {
  configure_void_tesseract_command || return 1
  if (($#)); then install_void_ocr_models "$@"; else install_void_ocr_models jpn_vert chi_sim_vert chi_tra_vert; fi
}
provider_darkly() { install_darkly_source /usr "$@"; }
provider_themes-download() { install_user_visual_themes "$@"; }
