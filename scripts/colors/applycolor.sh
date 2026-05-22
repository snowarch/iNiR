#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/module-runtime.sh"

main() {
  ensure_generated_dirs

  local manifests=()
  while IFS= read -r manifest_path; do
    [[ -n "$manifest_path" ]] || continue
    manifests+=("$manifest_path")
  done < <(list_theming_target_manifests)

  local modules=()
  local enabled_targets=0
  local manifest_path target_id module_path
  for manifest_path in "${manifests[@]}"; do
    target_manifest_enabled "$manifest_path" || continue
    enabled_targets=$((enabled_targets + 1))
    target_id="$(basename "$manifest_path" .json)"
    module_path="$(resolve_target_module_path "$target_id" || true)"
    [[ -n "$module_path" ]] || continue
    modules+=("$module_path")
  done

  if [[ ${#modules[@]} -eq 0 && ${#manifests[@]} -eq 0 ]]; then
    while IFS= read -r module_path; do
      [[ -n "$module_path" ]] || continue
      modules+=("$module_path")
    done < <(list_theming_modules)
  fi

  if [[ ${#modules[@]} -eq 0 && ${#manifests[@]} -gt 0 && "$enabled_targets" -eq 0 ]]; then
    printf 'No enabled theming targets found in %s\n' "$SCRIPT_DIR/targets" >&2
    exit 0
  fi

  if [[ ${#modules[@]} -eq 0 ]]; then
    printf 'No theming modules found for enabled targets in %s\n' "$SCRIPT_DIR/modules" >&2
    exit 1
  fi

  local cpu_count max_jobs running failed
  cpu_count="$(nproc 2>/dev/null || printf '4')"
  max_jobs="${INIR_THEME_MAX_JOBS:-$((cpu_count / 2))}"
  [[ "$max_jobs" =~ ^[0-9]+$ ]] || max_jobs=2
  (( max_jobs < 2 )) && max_jobs=2
  (( max_jobs > 4 )) && max_jobs=4

  run_one_module() {
    local module_path="$1"
    if command -v ionice >/dev/null 2>&1; then
      ionice -c 3 nice -n 10 bash "$module_path"
    else
      nice -n 10 bash "$module_path"
    fi
  }

  running=0
  failed=0
  for module_path in "${modules[@]}"; do
    run_one_module "$module_path" &
    running=$((running + 1))
    if (( running >= max_jobs )); then
      if ! wait -n; then
        failed=1
      fi
      running=$((running - 1))
    fi
  done

  while (( running > 0 )); do
    if ! wait -n; then
      failed=1
    fi
    running=$((running - 1))
  done

  exit "$failed"
}

main "$@"
