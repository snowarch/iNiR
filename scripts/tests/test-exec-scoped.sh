#!/usr/bin/env bash
# Contract test: inir_exec_scoped skips nested systemd-run when already in a unit.
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/../.." && pwd)"
helper="$repo_root/scripts/lib/exec-scoped.sh"
inir_script="$repo_root/scripts/inir"
term_script="$repo_root/scripts/launch-terminal.sh"

log_pass() { printf '[test-exec-scoped] PASS: %s\n' "$1"; }
log_fail() { printf '[test-exec-scoped] FAIL: %s\n' "$1" >&2; exit 1; }

if [[ ! -f "$helper" ]]; then
    log_fail "scripts/lib/exec-scoped.sh not found"
fi

# shellcheck source=/dev/null
source "$helper"
if ! declare -F inir_exec_scoped >/dev/null 2>&1; then
    log_fail "inir_exec_scoped is not defined"
fi

tmp_dir="$(mktemp -d /tmp/inir-test-exec-scoped.XXXXXX)"
cleanup() { rm -rf "$tmp_dir"; }
trap cleanup EXIT INT TERM

marker="$tmp_dir/ran"
systemd_log="$tmp_dir/systemd-run.log"
stub_bin="$tmp_dir/bin"
mkdir -p "$stub_bin" "$tmp_dir/runtime/systemd"

cat > "$stub_bin/payload" <<EOF
#!/usr/bin/env bash
printf 'payload:%s\n' "\$*" > "$marker"
EOF
chmod +x "$stub_bin/payload"

cat > "$stub_bin/systemd-run" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" > "$systemd_log"
while [[ \$# -gt 0 ]]; do
    if [[ "\$1" == "--" ]]; then
        shift
        exec "\$@"
    fi
    shift
done
exit 1
EOF
chmod +x "$stub_bin/systemd-run"

export PATH="$stub_bin:/usr/bin:/bin"
export XDG_RUNTIME_DIR="$tmp_dir/runtime"

run_scoped() {
    # inir_exec_scoped execs, so run in a subshell
    (inir_exec_scoped "$@")
}

# Already inside a unit: never wrap.
rm -f "$marker" "$systemd_log"
INVOCATION_ID="test-unit" run_scoped "inir-app" payload /tmp/x
if [[ ! -f "$marker" ]]; then
    log_fail "INVOCATION_ID path did not exec payload"
fi
if [[ -f "$systemd_log" ]]; then
    log_fail "INVOCATION_ID path must not call systemd-run"
fi
log_pass "INVOCATION_ID skips systemd-run"

# No private socket: exec directly.
unset INVOCATION_ID
rm -f "$marker" "$systemd_log"
run_scoped "inir-app" payload /tmp/y
if [[ ! -f "$marker" ]]; then
    log_fail "no-socket path did not exec payload"
fi
if [[ -f "$systemd_log" ]]; then
    log_fail "no-socket path must not call systemd-run"
fi
log_pass "missing systemd private socket execs directly"

# Socket + systemd-run: wrap with expected flags.
rm -f "$marker" "$systemd_log" "$tmp_dir/runtime/systemd/private"
python3 - "$tmp_dir/runtime/systemd/private" <<'PY'
import os, socket, sys
path = sys.argv[1]
if os.path.exists(path):
    os.remove(path)
sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
sock.bind(path)
sock.close()
PY
if [[ ! -S "$tmp_dir/runtime/systemd/private" ]]; then
    log_fail "failed to create fake systemd private socket"
fi
run_scoped "inir-terminal" payload /tmp/z
if [[ ! -f "$marker" ]]; then
    log_fail "wrap path did not exec payload"
fi
if [[ ! -f "$systemd_log" ]]; then
    log_fail "wrap path did not call systemd-run"
fi
flags="$(cat "$systemd_log")"
for needed in --user --quiet --collect --same-dir --scope --unit=inir-terminal-; do
    if [[ "$flags" != *"$needed"* ]]; then
        log_fail "systemd-run flags missing '$needed': $flags"
    fi
done
if [[ "$flags" != *"-- payload /tmp/z"* && "$flags" != *" -- payload /tmp/z" ]]; then
    # allow either spacing; require payload after --
    if [[ "$flags" != *" -- "* || "$flags" != *"payload /tmp/z"* ]]; then
        log_fail "systemd-run did not exec payload after --: $flags"
    fi
fi
log_pass "systemd-run wraps with --user --quiet --collect --same-dir --scope --unit=<prefix>-PID"

if ! grep -q 'exec-scoped.sh' "$inir_script" && ! grep -q 'inir_exec_scoped' "$inir_script"; then
    log_fail "scripts/inir does not use inir_exec_scoped"
fi
if ! grep -q 'exec-scoped.sh' "$term_script" && ! grep -q 'inir_exec_scoped' "$term_script"; then
    log_fail "scripts/launch-terminal.sh does not use inir_exec_scoped"
fi
log_pass "inir and launch-terminal.sh share inir_exec_scoped"

# systemd ExecStart uses ~/.local/bin/inir → repo script. dirname(BASH_SOURCE)
# is the symlink directory, which has no lib/exec-scoped.sh. help/run must
# still work; the helper is only required when exec_scoped runs.
link_bin="$tmp_dir/link-bin"
mkdir -p "$link_bin"
ln -s "$inir_script" "$link_bin/inir"
set +e
help_out="$("$link_bin/inir" help 2>&1)"
help_ec=$?
set -e
if [[ "$help_out" == *"Unable to locate exec-scoped helper"* ]]; then
    log_fail "symlink inir help must not require exec-scoped.sh at parse time. Output: $help_out"
fi
if [[ $help_ec -ne 0 ]]; then
    log_fail "symlink inir help exited $help_ec. Output: $help_out"
fi
log_pass "symlink inir help does not require exec-scoped.sh at parse time"

# Payload copy without the new helper (stale ~/.config/quickshell/inir).
orphan_dir="$tmp_dir/orphan-scripts"
mkdir -p "$orphan_dir"
cp "$inir_script" "$orphan_dir/inir"
chmod +x "$orphan_dir/inir"
set +e
orphan_out="$("$orphan_dir/inir" help 2>&1)"
orphan_ec=$?
set -e
if [[ "$orphan_out" == *"Unable to locate exec-scoped helper"* ]]; then
    log_fail "inir help must work when exec-scoped.sh is absent. Output: $orphan_out"
fi
if [[ $orphan_ec -ne 0 ]]; then
    log_fail "orphan inir help exited $orphan_ec. Output: $orphan_out"
fi
log_pass "inir help works when exec-scoped.sh is not installed"
printf '[test-exec-scoped] All scenarios passed\n'
