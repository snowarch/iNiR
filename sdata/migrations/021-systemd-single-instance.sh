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
  local startup_pattern='spawn-at-startup.*([^[:alnum:]_-]inir([^[:alnum:]_/-]|$)|\.local/bin/inir([^[:alnum:]_/-]|$)|config/quickshell/inir/scripts/inir([^[:alnum:]_/-]|$))'

  if [[ ! -f "$service_file" ]]; then
    return 0
  fi

  if [[ -f "$startup_cfg" ]] && grep -vE '^[[:space:]]*//' "$startup_cfg" 2>/dev/null | grep -Eq "$startup_pattern"; then
    return 0
  fi

  if [[ -f "$monolithic_cfg" ]] && grep -vE '^[[:space:]]*//' "$monolithic_cfg" 2>/dev/null | grep -Eq "$startup_pattern"; then
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
  local systemd_user_dir="${xdg_config_home}/systemd/user"
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
pattern = re.compile(r'^(?![ \t]*//).*spawn-at-startup.*(?:[^A-Za-z0-9_-]inir(?![A-Za-z0-9_/-])|\.local/bin/inir(?![A-Za-z0-9_/-])|config/quickshell/inir/scripts/inir(?![A-Za-z0-9_/-])).*\n?', re.MULTILINE)
new_text = pattern.sub('', text)
if new_text != text:
    path.write_text(new_text)
PY
  }

  if [[ ! -f "$service_file" ]]; then
    service_asset="${REPO_ROOT}/assets/systemd/inir.service"
    if [[ -f "$service_asset" ]]; then
      mkdir -p "$systemd_user_dir" || return 1
      mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}" || return 1
      tmp_file="${XDG_CACHE_HOME:-$HOME/.cache}/inir.service.migration.$$"
      sed "s|^ExecStart=.*|ExecStart=${launcher_path//&/\\&} run --session|" "$service_asset" > "$tmp_file" \
        || { rm -f "$tmp_file"; return 1; }
      cp -f "$tmp_file" "$service_file" || { rm -f "$tmp_file"; return 1; }
      rm -f "$tmp_file"
    else
      return 1
    fi
  fi

  if [[ -f "$startup_cfg" ]]; then
    _remove_inir_startup_lines "$startup_cfg" || return 1
  fi

  if [[ -f "$monolithic_cfg" ]]; then
    _remove_inir_startup_lines "$monolithic_cfg" || return 1
  fi

  if command -v systemctl >/dev/null 2>&1 && [[ -f "$service_file" ]]; then
    systemctl --user daemon-reload >/dev/null 2>&1 || return 1
    if ! systemctl --user is-enabled --quiet inir.service >/dev/null 2>&1; then
      # Unit has no [Install] section: ownership is a compositor wants link.
      local compositor_unit=""
      if systemctl --user cat niri.service >/dev/null 2>&1; then
        compositor_unit="niri.service"
      elif systemctl --user cat 'wayland-wm@Hyprland.service' >/dev/null 2>&1; then
        compositor_unit="wayland-wm@Hyprland.service"
      fi
      [[ -n "$compositor_unit" ]] || return 1
      mkdir -p "$systemd_user_dir/${compositor_unit}.wants" || return 1
      ln -sf "$service_file" "$systemd_user_dir/${compositor_unit}.wants/inir.service" || return 1
      systemctl --user daemon-reload >/dev/null 2>&1 || return 1
      systemctl --user is-enabled --quiet inir.service >/dev/null 2>&1 || return 1
    fi
    if [[ -n "${NIRI_SOCKET:-}" || -n "${WAYLAND_DISPLAY:-}" ]]; then
      systemctl --user reset-failed inir.service >/dev/null 2>&1 || return 1
      systemctl --user start inir.service >/dev/null 2>&1 || return 1
    fi
  fi

  return 0
}
