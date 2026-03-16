#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/module-runtime.sh"
COLOR_MODULE_ID="editors"

SCSS_FILE="$STATE_DIR/user/generated/material_colors.scss"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VSCODE_THEMEGEN_BIN="$STATE_DIR/user/generated/bin/inir-vscode-themegen"

ensure_vscode_themegen() {
  command -v go &>/dev/null || return 1
  mkdir -p "$STATE_DIR/user/generated/bin"
  if [[ ! -x "$VSCODE_THEMEGEN_BIN" || "$REPO_ROOT/go.mod" -nt "$VSCODE_THEMEGEN_BIN" || "$SCRIPT_DIR/vscode_themegen/main.go" -nt "$VSCODE_THEMEGEN_BIN" ]]; then
    (cd "$REPO_ROOT" && go build -o "$VSCODE_THEMEGEN_BIN" ./scripts/colors/vscode_themegen) >/dev/null 2>&1 || return 1
  fi
  [[ -x "$VSCODE_THEMEGEN_BIN" ]]
}

apply_code_editors() {
  [[ -f "$SCSS_FILE" ]] || return 0
  local python_cmd
  python_cmd=$(venv_python)

  local enable_zed enable_vscode
  enable_zed=$(config_json 'if .appearance.wallpaperTheming | has("enableZed") then .appearance.wallpaperTheming.enableZed else true end' true)
  enable_vscode=$(config_json 'if .appearance.wallpaperTheming | has("enableVSCode") then .appearance.wallpaperTheming.enableVSCode else true end' true)

  if [[ "$enable_zed" == 'true' ]] && { command -v zed &>/dev/null || command -v zeditor &>/dev/null; }; then
    "$python_cmd" "$SCRIPT_DIR/generate_terminal_configs.py" --scss "$SCSS_FILE" --zed >> "$STATE_DIR/user/generated/code_editor_themes.log" 2>&1 || true
  fi

  if [[ "$enable_vscode" == 'true' ]]; then
    local enabled_forks=()
    if [[ -f "$CONFIG_FILE" ]] && command -v jq >/dev/null 2>&1; then
      local editors_config
      editors_config=$(jq -r '.appearance.wallpaperTheming.vscodeEditors // {}' "$CONFIG_FILE" 2>/dev/null || echo '{}')
      [[ $(echo "$editors_config" | jq -r '.code // true') == 'true' ]] && [[ -d "$HOME/.config/Code" ]] && enabled_forks+=('code')
      [[ $(echo "$editors_config" | jq -r '.codium // true') == 'true' ]] && [[ -d "$HOME/.config/VSCodium" ]] && enabled_forks+=('codium')
      [[ $(echo "$editors_config" | jq -r '.codeOss // true') == 'true' ]] && [[ -d "$HOME/.config/Code - OSS" ]] && enabled_forks+=('code-oss')
      [[ $(echo "$editors_config" | jq -r '.codeInsiders // true') == 'true' ]] && [[ -d "$HOME/.config/Code - Insiders" ]] && enabled_forks+=('code-insiders')
      [[ $(echo "$editors_config" | jq -r '.cursor // true') == 'true' ]] && [[ -d "$HOME/.config/Cursor" ]] && enabled_forks+=('cursor')
      [[ $(echo "$editors_config" | jq -r '.windsurf // true') == 'true' ]] && [[ -d "$HOME/.config/Windsurf" ]] && enabled_forks+=('windsurf')
      [[ $(echo "$editors_config" | jq -r '.windsurfNext // true') == 'true' ]] && [[ -d "$HOME/.config/Windsurf - Next" ]] && enabled_forks+=('windsurf-next')
      [[ $(echo "$editors_config" | jq -r '.qoder // true') == 'true' ]] && [[ -d "$HOME/.config/Qoder" ]] && enabled_forks+=('qoder')
      [[ $(echo "$editors_config" | jq -r '.antigravity // true') == 'true' ]] && [[ -d "$HOME/.config/Antigravity" ]] && enabled_forks+=('antigravity')
      [[ $(echo "$editors_config" | jq -r '.positron // true') == 'true' ]] && [[ -d "$HOME/.config/Positron" ]] && enabled_forks+=('positron')
      [[ $(echo "$editors_config" | jq -r '.voidEditor // true') == 'true' ]] && [[ -d "$HOME/.config/Void" ]] && enabled_forks+=('void')
      [[ $(echo "$editors_config" | jq -r '.melty // true') == 'true' ]] && [[ -d "$HOME/.config/Melty" ]] && enabled_forks+=('melty')
      [[ $(echo "$editors_config" | jq -r '.pearai // true') == 'true' ]] && [[ -d "$HOME/.config/PearAI" ]] && enabled_forks+=('pearai')
      [[ $(echo "$editors_config" | jq -r '.aide // true') == 'true' ]] && [[ -d "$HOME/.config/Aide" ]] && enabled_forks+=('aide')
    fi

    if [[ ${#enabled_forks[@]} -gt 0 ]]; then
      if ensure_vscode_themegen; then
        local vscode_cmd=("$VSCODE_THEMEGEN_BIN" "--colors" "$STATE_DIR/user/generated/colors.json" "--scss" "$SCSS_FILE")
        for fork in "${enabled_forks[@]}"; do
          vscode_cmd+=("--forks" "$fork")
        done
        "${vscode_cmd[@]}" >> "$STATE_DIR/user/generated/code_editor_themes.log" 2>&1 || true
      else
        "$python_cmd" "$SCRIPT_DIR/generate_terminal_configs.py" --scss "$SCSS_FILE" --vscode --vscode-forks "${enabled_forks[@]}" >> "$STATE_DIR/user/generated/code_editor_themes.log" 2>&1 || true
      fi
    fi
  fi

  if command -v opencode &>/dev/null; then
    local enable_opencode
    enable_opencode=$(config_bool '.appearance.wallpaperTheming.enableOpenCode' true)
    if [[ "$enable_opencode" == 'true' ]]; then
      "$python_cmd" "$SCRIPT_DIR/opencode/theme_generator.py" "$SCSS_FILE" >> "$STATE_DIR/user/generated/code_editor_themes.log" 2>&1 || true
    fi
  fi
}

main() {
  apply_code_editors
}

main "$@"
