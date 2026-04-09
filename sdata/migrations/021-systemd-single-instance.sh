#!/usr/bin/env bash

MIGRATION_ID="021-systemd-single-instance"
MIGRATION_TITLE="Move iNiR shell startup to a single systemd owner"
MIGRATION_DESCRIPTION="Removes compositor startup of inir, installs/enables the user inir.service, and keeps shell startup owned by a single systemd user unit."
MIGRATION_TARGET_FILE="~/.config/systemd/user/inir.service + ~/.config/niri/config.d/50-startup.kdl"
MIGRATION_REQUIRED=true

migration_check() {
  local xdg_config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
  local startup_cfg="${xdg_config_home}/niri/config.d/50-startup.kdl"
  local monolithic_cfg="${xdg_config_home}/niri/config.kdl"
  local service_file="${xdg_config_home}/systemd/user/inir.service"
  local startup_pattern='spawn-at-startup.*(inir([^[:alnum:]_-]|$)|\.local/bin/inir|config/quickshell/inir/scripts/inir)'

  if [[ ! -f "$service_file" ]]; then
    return 0
  fi

  if [[ -f "$startup_cfg" ]] && grep -Eq "$startup_pattern" "$startup_cfg" 2>/dev/null; then
    return 0
  fi

  if [[ -f "$monolithic_cfg" ]] && grep -Eq "$startup_pattern" "$monolithic_cfg" 2>/dev/null; then
    return 0
  fi

  if command -v systemctl >/dev/null 2>&1; then
    if ! systemctl --user is-enabled --quiet inir.service >/dev/null 2>&1; then
      return 0
    fi
  fi

  return 1
}

migration_preview() {
  echo -e "${STY_RED}- spawn-at-startup \"inir\" \"start\"${STY_RST}"
  echo -e "${STY_GREEN}+ systemd user service owns iNiR startup${STY_RST}"
  echo -e "${STY_GREEN}+ ~/.config/systemd/user/inir.service enabled${STY_RST}"
}

migration_apply() {
  local xdg_config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
  local startup_cfg="${xdg_config_home}/niri/config.d/50-startup.kdl"
  local monolithic_cfg="${xdg_config_home}/niri/config.kdl"
  local service_file="${xdg_config_home}/systemd/user/inir.service"
  local launcher_path="${XDG_BIN_HOME:-$HOME/.local/bin}/inir"
  local service_asset
  local tmp_file

  _remove_inir_startup_lines() {
    local file="$1"
    [[ -f "$file" ]] || return 0

    python3 - "$file" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
text = path.read_text()
pattern = re.compile(r'.*spawn-at-startup.*(?:inir(?![A-Za-z0-9_-])|\.local/bin/inir|config/quickshell/inir/scripts/inir).*\n?', re.MULTILINE)
new_text = pattern.sub('', text)
if new_text != text:
    path.write_text(new_text)
PY
  }

  if [[ ! -f "$service_file" ]]; then
    service_asset="${REPO_ROOT}/assets/systemd/inir.service"
    if [[ -f "$service_asset" ]]; then
      mkdir -p "${xdg_config_home}/systemd/user"
      mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}"
      tmp_file="${XDG_CACHE_HOME:-$HOME/.cache}/inir.service.migration.$$"
      sed "s|^ExecStart=.*|ExecStart=${launcher_path//&/\\&} run --session|" "$service_asset" > "$tmp_file"
      cp -f "$tmp_file" "$service_file"
      rm -f "$tmp_file"
    fi
  fi

  if [[ -f "$startup_cfg" ]]; then
    _remove_inir_startup_lines "$startup_cfg"
  fi

  if [[ -f "$monolithic_cfg" ]]; then
    _remove_inir_startup_lines "$monolithic_cfg"
  fi

  if command -v systemctl >/dev/null 2>&1 && [[ -f "$service_file" ]]; then
    systemctl --user daemon-reload >/dev/null 2>&1 || true
    systemctl --user enable inir.service >/dev/null 2>&1 || true
    if [[ -n "${NIRI_SOCKET:-}" || -n "${WAYLAND_DISPLAY:-}" ]]; then
      systemctl --user reset-failed inir.service >/dev/null 2>&1 || true
      systemctl --user start inir.service >/dev/null 2>&1 || true
    fi
  fi
}
