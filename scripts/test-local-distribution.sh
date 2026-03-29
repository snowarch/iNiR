#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
runtime_root="$(cd -- "$script_dir/.." && pwd)"
launcher="${INIR_LAUNCHER_PATH:-$runtime_root/scripts/inir}"

run_runtime=false
if [[ "${1:-}" == "--with-runtime" ]]; then
    run_runtime=true
fi

step() {
    printf '\n== %s ==\n' "$1"
}

step "shell syntax"
bash -n \
    "$runtime_root/setup" \
    "$runtime_root/scripts/inir" \
    "$runtime_root/sdata/lib/versioning.sh" \
    "$runtime_root/sdata/lib/doctor.sh" \
    "$runtime_root/sdata/lib/package-installers.sh"

step "runtime payload manifests"
while IFS= read -r runtime_file; do
    [[ -n "$runtime_file" ]] || continue
    [[ -f "$runtime_root/$runtime_file" ]]
done < "$runtime_root/sdata/runtime-root-files.txt"

while IFS= read -r runtime_dir; do
    [[ -n "$runtime_dir" ]] || continue
    [[ -d "$runtime_root/$runtime_dir" ]]
done < "$runtime_root/sdata/runtime-payload-dirs.txt"

if [[ -f "$runtime_root/Makefile" ]]; then
    step "make install dry run"
    make -n install PREFIX=/tmp/inir-stage-test -C "$runtime_root" >/dev/null
fi

if [[ -d "$runtime_root/distro/arch" ]]; then
    step "pkgbuild syntax"
    bash -n \
        "$runtime_root/distro/arch/inir-shell/PKGBUILD" \
        "$runtime_root/distro/arch/inir-shell-git/PKGBUILD" \
        "$runtime_root/distro/arch/inir-meta/PKGBUILD"
fi

step "launcher resolution"
bash "$launcher" path >/dev/null
bash "$launcher" status >/dev/null

if [[ "$run_runtime" == true ]]; then
    step "runtime restart"
    bash scripts/inir kill >/dev/null 2>&1 || true
    sleep 1
    bash scripts/inir run >/tmp/inir-test-local-runtime.log 2>&1 &
    sleep 3

    step "runtime logs"
    bash scripts/inir logs

    step "runtime filtered errors"
    bash "$launcher" logs --full | grep -iE 'error|ReferenceError|TypeError|binding loop' | tail -80 || true

    step "launcher ipc"
    bash "$launcher" ipc shellUpdate diagnose >/dev/null
fi

printf '\nAll local distribution checks passed.\n'
