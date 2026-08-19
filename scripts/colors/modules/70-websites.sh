#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/module-runtime.sh"
COLOR_MODULE_ID="websites"

main() {
  local ext_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/matuflow-extension"
  local bridge_path="$ext_dir/website-extension-bridge.py"
  local server_path="$ext_dir/website-extension-server.py"

  # Auto-install extension if needed
  if [[ ! -d "$ext_dir/node_modules" ]]; then
    log_module "Installing matuflow extension dependencies..."
    (cd "$ext_dir" && npm install)
  fi

  if [[ ! -d "$ext_dir/extension/dashboard" ]]; then
    log_module "Building matuflow extension..."
    (cd "$ext_dir" && npm run build)
  fi

  # Auto-load extension into browsers
  ensure_extension_loaded() {
    local ext_path="$ext_dir/extension"
    local ext_id
    ext_id=$(python3 -c "import hashlib; h=hashlib.sha256('$ext_path'.encode()).hexdigest()[:32]; print(''.join(chr(int(c,16)+ord('a')) for c in h))")
    
    local browsers=(
      "google-chrome|$HOME/.config/google-chrome"
      "google-chrome-stable|$HOME/.config/google-chrome"
      "chromium|$HOME/.config/chromium"
      "brave|$HOME/.config/BraveSoftware/Brave-Browser"
      "brave-browser|$HOME/.config/BraveSoftware/Brave-Browser"
    )

    for entry in "${browsers[@]}"; do
      IFS='|' read -r bin prefs_dir <<< "$entry"
      if command -v "$bin" &>/dev/null && [[ -d "$prefs_dir" ]]; then
        local ext_dir_path="$prefs_dir/External Extensions"
        mkdir -p "$ext_dir_path"
        local json_file="$ext_dir_path/$ext_id.json"
        
        if [[ ! -f "$json_file" ]]; then
          log_module "Loading extension into $bin ($ext_id)..."
          printf '{\n  "external_path": "%s",\n  "external_version": "1.0"\n}\n' "$ext_path" > "$json_file"
        fi
      fi
    done
  }
  ensure_extension_loaded

  log_module "generating stylus theme for websites"
  
  local in_dir="$HOME/.local/state/quickshell/user/generated"
  local palette_file="$in_dir/palette.json"
  local out_file="$in_dir/palette.css"
  
  if [[ ! -f "$palette_file" ]]; then
    log_module "Palette file not found at $palette_file"
    return 1
  fi
  
  jq -r '"/* ==UserStyle==
@name           matugen global styles
@namespace      github.com/openstyles/stylus
@version        1.2.5
@description    mine, --not yours--, and now yours
@author         bhimio
==/UserStyle== */

:root {
    /* Primary Colors */
    --primary: \(.primary);
    --on-primary: \(.on_primary);
    --primary-container: \(.primary_container);
    --on-primary-container: \(.on_primary_container);
    --inverse-primary: \(.inverse_primary);
    --primary-fixed: \(.primary_fixed);
    --primary-fixed-dim: \(.primary_fixed_dim);
    --on-primary-fixed: \(.on_primary_fixed);
    --on-primary-fixed-variant: \(.on_primary_fixed_variant);

    /* Secondary Colors */
    --secondary: \(.secondary);
    --on-secondary: \(.on_secondary);
    --secondary-container: \(.secondary_container);
    --on-secondary-container: \(.on_secondary_container);
    --secondary-fixed: \(.secondary_fixed);
    --secondary-fixed-dim: \(.secondary_fixed_dim);
    --on-secondary-fixed: \(.on_secondary_fixed);
    --on-secondary-fixed-variant: \(.on_secondary_fixed_variant);

    /* Tertiary Colors */
    --tertiary: \(.tertiary);
    --on-tertiary: \(.on_tertiary);
    --tertiary-container: \(.tertiary_container);
    --on-tertiary-container: \(.on_tertiary_container);
    --tertiary-fixed: \(.tertiary_fixed);
    --tertiary-fixed-dim: \(.tertiary_fixed_dim);
    --on-tertiary-fixed: \(.on_tertiary_fixed);
    --on-tertiary-fixed-variant: \(.on_tertiary_fixed_variant);

    /* Surface & Background */
    --background: \(.background);
    --on-background: \(.on_background);
    --surface: \(.surface);
    --on-surface: \(.on_surface);
    --surface-variant: \(.surface_variant);
    --on-surface-variant: \(.on_surface_variant);
    --surface-dim: \(.surface_dim);
    --surface-bright: \(.surface_bright);
    --surface-container-lowest: \(.surface_container_lowest);
    --surface-container-low: \(.surface_container_low);
    --surface-container: \(.surface_container);
    --surface-container-high: \(.surface_container_high);
    --surface-container-highest: \(.surface_container_highest);
    --inverse-surface: \(.inverse_surface);
    --inverse-on-surface: \(.inverse_on_surface);
    --surface-tint: \(.surface_tint);

    /* Error Colors */
    --error: \(.error);
    --on-error: \(.on_error);
    --error-container: \(.error_container);
    --on-error-container: \(.on_error_container);

    /* Success Colors */
    --success: \(.success);
    --on-success: \(.on_success);
    --success-container: \(.success_container);
    --on-success-container: \(.on_success_container);

    /* Outline & Misc */
    --outline: \(.outline);
    --outline-variant: \(.outline_variant);
    --shadow: \(.shadow);
    --scrim: \(.scrim);
}"' "$palette_file" > "$out_file"

  
  local service_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
  mkdir -p "$service_dir"
  local service_path="$service_dir/matuflow.service"
  
  # Create matuflow.service if not exists
  if [[ ! -f "$service_path" ]]; then
    log_module "Creating matuflow.service (user)..."
    cat > "$service_path" << EOF
[Unit]
Description=MatuFlow Website Bridge Service
Wants=network.target
After=network.target

[Service]
Type=simple
ExecStart=$(which python3) "${server_path}"
Restart=always
RestartSec=5
Environment="PATH=/usr/bin:$HOME/.local/bin"

[Install]
WantedBy=default.target
EOF
    systemctl --user daemon-reload
  fi
  
  # Check if matuflow service is active
  if systemctl --user is-active --quiet matuflow.service; then
    log_module "matuflow.service is active, reloading theme..."
    python3 "$bridge_path" --reload
  else
    log_module "matuflow.service is not active, starting user service..."
    systemctl --user start matuflow.service
    sleep 2
    python3 "$bridge_path" --reload
  fi
}

main "$@"
