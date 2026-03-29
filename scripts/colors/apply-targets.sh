#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/module-runtime.sh"

usage() {
  cat <<'EOF'
Usage: apply-targets.sh [target-id ...]

Examples:
  apply-targets.sh terminals
  apply-targets.sh gtk-kde editors chrome
  apply-targets.sh all
EOF
}

main() {
  ensure_generated_dirs

  if [[ $# -eq 0 ]]; then
    usage >&2
    exit 1
  fi

  local targets=()
  if [[ "$1" == "all" ]]; then
    while IFS= read -r manifest; do
      [[ -n "$manifest" ]] || continue
      targets+=("$(basename "$manifest" .json)")
    done < <(list_theming_target_manifests)
  else
    targets=("$@")
  fi

  local failed=0
  local target_id module_path
  for target_id in "${targets[@]}"; do
    module_path="$(resolve_target_module_path "$target_id" || true)"
    if [[ -z "$module_path" ]]; then
      echo "Unknown theming target: $target_id" >&2
      failed=1
      continue
    fi

    COLOR_MODULE_ID="$target_id" log_module "running target via $(basename "$module_path")"
    if ! COLOR_MODULE_ID="$target_id" bash "$module_path"; then
      COLOR_MODULE_ID="$target_id" log_module "target failed"
      failed=1
    fi
  done

  exit "$failed"
}

main "$@"
