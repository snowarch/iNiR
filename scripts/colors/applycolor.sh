#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/module-runtime.sh"

main() {
  ensure_generated_dirs

  local modules=()
  while IFS= read -r module_path; do
    [[ -n "$module_path" ]] || continue
    modules+=("$module_path")
  done < <(list_declared_theming_modules)

  if [[ ${#modules[@]} -eq 0 ]]; then
    while IFS= read -r module_path; do
      [[ -n "$module_path" ]] || continue
      modules+=("$module_path")
    done < <(list_theming_modules)
  fi

  if [[ ${#modules[@]} -eq 0 ]]; then
    printf 'No theming modules found in %s\n' "$SCRIPT_DIR/modules" >&2
    exit 1
  fi

  local pids=()
  for module_path in "${modules[@]}"; do
    bash "$module_path" &
    pids+=("$!")
  done

  local failed=0
  for pid in "${pids[@]}"; do
    if ! wait "$pid"; then
      failed=1
    fi
  done

  exit "$failed"
}

main "$@"
