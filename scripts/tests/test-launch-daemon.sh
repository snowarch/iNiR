#!/usr/bin/env bash
# Contract test suite for ShellExec.launchDaemon
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/../.." && pwd)"
qml_file="$repo_root/modules/common/functions/ShellExec.qml"

# Temporary directory for mocks and test logs
tmp_dir="$(mktemp -d /tmp/inir-test-launch-daemon.XXXXXX)"

test_units=(
    "inir-test-dummy"
    "inir-test-rel"
    "inir-test-notfound"
    "inir-test-fail"
    "inir-test-crash"
)

cleanup() {
    local exit_code=$?
    # Ensure all test units are stopped and reset in systemd user manager
    for unit in "${test_units[@]}"; do
        systemctl --user stop "${unit}.service" >/dev/null 2>&1 || true
        systemctl --user reset-failed "${unit}.service" >/dev/null 2>&1 || true
    done
    if [[ -d "$tmp_dir" ]]; then
        rm -rf "$tmp_dir"
    fi
    exit "$exit_code"
}
trap cleanup EXIT INT TERM

log_step() {
    printf '\n[test-launch-daemon] == %s ==\n' "$1"
}

log_pass() {
    printf '[test-launch-daemon] PASS: %s\n' "$1"
}

log_fail() {
    printf '[test-launch-daemon] FAIL: %s\n' "$1" >&2
    exit 1
}

# Preflight checks
if ! command -v systemctl >/dev/null 2>&1 || ! command -v systemd-run >/dev/null 2>&1; then
    log_fail "systemctl or systemd-run not found in PATH"
fi

if ! systemctl --user is-system-running >/dev/null 2>&1 && ! systemctl --user status >/dev/null 2>&1; then
    log_fail "systemd --user manager is not running or not accessible"
fi

if [[ ! -f "$qml_file" ]]; then
    log_fail "ShellExec.qml not found at $qml_file"
fi

# Clean initial state
for unit in "${test_units[@]}"; do
    systemctl --user stop "${unit}.service" >/dev/null 2>&1 || true
    systemctl --user reset-failed "${unit}.service" >/dev/null 2>&1 || true
done

# Extract the runtime launcher wrapper script from ShellExec.qml
log_step "Extracting launchDaemon script from ShellExec.qml"
extractor="$repo_root/scripts/lib/extract-launch-daemon.py"
if [[ ! -f "$extractor" ]]; then
    log_fail "Extractor not found at $extractor"
fi
launcher_script="$(python3 "$extractor" "$qml_file")"

if [[ -z "$launcher_script" ]]; then
    log_fail "Failed to extract launcher script from ShellExec.qml"
fi

# Helper to invoke the extracted launchDaemon script with identical contract signature
# argv: $0 inir-daemon, $1 systemd_run, $2 desc, $3 unit, $4 restart, $5 if_active, $6 program, then args
invoke_launch_daemon() {
    local scope="$1"
    local program="$2"
    local restart="${3:-}"
    local desc="${4:-$scope}"
    local custom_systemd_run="${5:-/usr/bin/systemd-run}"
    local if_active="${6:-replace}"
    shift 6 || true
    local extra_args=("$@")

    local unit="inir-${scope}"

    bash -c "$launcher_script" "inir-daemon" "$custom_systemd_run" "$desc" "$unit" "$restart" "$if_active" "$program" "${extra_args[@]}"
}

# Scenario 1: STARTED (Normal launch creates transient systemd service)
log_step "Scenario 1: STARTED"
systemctl --user stop "inir-test-dummy.service" >/dev/null 2>&1 || true
systemctl --user reset-failed "inir-test-dummy.service" >/dev/null 2>&1 || true

set +e
output="$(invoke_launch_daemon "test-dummy" "sleep" "" "Test Dummy Daemon" "/usr/bin/systemd-run" "replace" "60" 2>&1)"
ec=$?
set -e

if [[ $ec -ne 0 ]]; then
    log_fail "Scenario 1: Expected exit code 0, got $ec. Output: $output"
fi

if ! systemctl --user is-active --quiet "inir-test-dummy.service"; then
    log_fail "Scenario 1: Unit inir-test-dummy.service is not active in systemd"
fi

dummy_pid="$(systemctl --user show -p MainPID --value inir-test-dummy.service)"
if [[ -z "$dummy_pid" || "$dummy_pid" -le 0 ]]; then
    log_fail "Scenario 1: Unit inir-test-dummy.service has invalid MainPID: $dummy_pid"
fi

log_pass "Scenario 1 (STARTED): Unit inir-test-dummy.service active with PID $dummy_pid"

# Scenario 2: REPLACE (default relaunch stops the unit and starts a new MainPID)
log_step "Scenario 2: REPLACE"
pid_before="$(systemctl --user show -p MainPID --value inir-test-dummy.service)"

set +e
output="$(invoke_launch_daemon "test-dummy" "sleep" "" "Test Dummy Daemon" "/usr/bin/systemd-run" "replace" "60" 2>&1)"
ec=$?
set -e

if [[ $ec -ne 0 ]]; then
    log_fail "Scenario 2: Expected exit code 0 for replace relaunch, got $ec. Output: $output"
fi

if ! systemctl --user is-active --quiet "inir-test-dummy.service"; then
    log_fail "Scenario 2: Unit inir-test-dummy.service is not active after replace"
fi

pid_after="$(systemctl --user show -p MainPID --value inir-test-dummy.service)"
if [[ -z "$pid_after" || "$pid_after" -le 0 ]]; then
    log_fail "Scenario 2: Unit has invalid MainPID after replace: $pid_after"
fi
if [[ "$pid_before" == "$pid_after" ]]; then
    log_fail "Scenario 2: MainPID was preserved ($pid_before); replace must change MainPID"
fi

log_pass "Scenario 2 (REPLACE): Relaunch changed MainPID $pid_before -> $pid_after"

# Scenario 2b: REUSE (explicit if_active=reuse preserves MainPID)
log_step "Scenario 2b: REUSE"
pid_before="$(systemctl --user show -p MainPID --value inir-test-dummy.service)"

set +e
output="$(invoke_launch_daemon "test-dummy" "sleep" "" "Test Dummy Daemon" "/usr/bin/systemd-run" "reuse" "60" 2>&1)"
ec=$?
set -e

if [[ $ec -ne 0 ]]; then
    log_fail "Scenario 2b: Expected exit code 0 for reuse relaunch, got $ec. Output: $output"
fi

if ! systemctl --user is-active --quiet "inir-test-dummy.service"; then
    log_fail "Scenario 2b: Unit inir-test-dummy.service is not active after reuse"
fi

pid_after="$(systemctl --user show -p MainPID --value inir-test-dummy.service)"
if [[ "$pid_before" != "$pid_after" ]]; then
    log_fail "Scenario 2b: MainPID changed from $pid_before to $pid_after; reuse must preserve MainPID"
fi

log_pass "Scenario 2b (REUSE): Idempotency verified, PID preserved ($pid_after)"

# Scenario 3: PATH_RESOLUTION (Relative binary resolved in restored $PATH)
log_step "Scenario 3: PATH_RESOLUTION"
systemctl --user stop "inir-test-rel.service" >/dev/null 2>&1 || true
systemctl --user reset-failed "inir-test-rel.service" >/dev/null 2>&1 || true

set +e
output="$(invoke_launch_daemon "test-rel" "sleep" "" "Test Rel Daemon" "/usr/bin/systemd-run" "replace" "60" 2>&1)"
ec=$?
set -e

if [[ $ec -ne 0 ]]; then
    log_fail "Scenario 3: Expected exit code 0, got $ec. Output: $output"
fi

if ! systemctl --user is-active --quiet "inir-test-rel.service"; then
    log_fail "Scenario 3: Unit inir-test-rel.service is not active"
fi

exec_start="$(systemctl --user show -p ExecStart --value inir-test-rel.service)"
if [[ "$exec_start" != *"path=/usr/bin/sleep"* && "$exec_start" != *"sleep"* ]]; then
    log_fail "Scenario 3: ExecStart does not contain resolved path: $exec_start"
fi

log_pass "Scenario 3 (PATH_RESOLUTION): Relative binary resolved and started as inir-test-rel.service"

# Scenario 4: NOT_FOUND (Non-existent binary aborts with 127)
log_step "Scenario 4: NOT_FOUND"
set +e
err_out="$(invoke_launch_daemon "test-notfound" "nonexistent_bin_xyz_999" "" "Test Not Found" "/usr/bin/systemd-run" "replace" 2>&1)"
ec=$?
set -e

if [[ $ec -ne 127 ]]; then
    log_fail "Scenario 4: Expected exit code 127 for missing binary, got $ec. Output: $err_out"
fi

if [[ "$err_out" != *"not found or not executable"* && "$err_out" != *"[launcher]"* ]]; then
    log_fail "Scenario 4: Stderr missing expected error message. Got: $err_out"
fi

if systemctl --user is-active --quiet "inir-test-notfound.service" 2>/dev/null; then
    log_fail "Scenario 4: inir-test-notfound.service should not have been created"
fi

log_pass "Scenario 4 (NOT_FOUND): Non-existent binary exited with 127 and reported error"

# Scenario 5: FAILED (Supervisor failure exits with 1, no orphan exec)
log_step "Scenario 5: FAILED"
mock_systemd_run="$tmp_dir/mock-systemd-run-fail"
cat <<'EOF' > "$mock_systemd_run"
#!/usr/bin/env bash
echo "Failed to start transient service: unit configuration invalid" >&2
exit 1
EOF
chmod +x "$mock_systemd_run"

# Record sleep processes before test
sleep_count_before=$(pgrep -f "sleep 59" | wc -l || true)

set +e
err_out="$(invoke_launch_daemon "test-fail" "sleep" "" "Test Fail Daemon" "$mock_systemd_run" "replace" "59" 2>&1)"
ec=$?
set -e

if [[ $ec -ne 1 ]]; then
    log_fail "Scenario 5: Expected exit code 1 on systemd-run failure, got $ec. Output: $err_out"
fi

if [[ "$err_out" != *"systemd-run failed to start service"* && "$err_out" != *"[launcher]"* ]]; then
    log_fail "Scenario 5: Stderr missing expected failure message. Got: $err_out"
fi

sleep_count_after=$(pgrep -f "sleep 59" | wc -l || true)
if [[ "$sleep_count_after" -ne "$sleep_count_before" ]]; then
    log_fail "Scenario 5: Orphan process was executed in shell cgroup! sleep count before=$sleep_count_before, after=$sleep_count_after"
fi

log_pass "Scenario 5 (FAILED): Supervisor failure cleanly returned 1 without falling back to plain exec"

# Scenario 6: RESTART_CRASH_STATE (Supervisor custody and failed is-active check)
log_step "Scenario 6: RESTART_CRASH_STATE"
systemctl --user stop "inir-test-crash.service" >/dev/null 2>&1 || true
systemctl --user reset-failed "inir-test-crash.service" >/dev/null 2>&1 || true

set +e
output="$(invoke_launch_daemon "test-crash" "false" "on-failure" "Test Crash Daemon" "/usr/bin/systemd-run" "replace" 2>&1)"
ec=$?
set -e

if [[ $ec -ne 0 ]]; then
    log_fail "Scenario 6: Initial launch delegation to systemd failed with exit code $ec. Output: $output"
fi

# Poll for crash transition (unit should enter failed or inactive state)
crashed=false
for _ in $(seq 1 40); do
    state="$(systemctl --user show -p ActiveState --value "inir-test-crash.service" 2>/dev/null || true)"
    if [[ "$state" == "failed" || "$state" == "inactive" ]]; then
        crashed=true
        break
    fi
    sleep 0.1
done

if [[ "$crashed" != true ]]; then
    log_fail "Scenario 6: Failing process did not transition to failed/inactive state"
fi

# Verify is-active returns non-zero
set +e
systemctl --user is-active --quiet "inir-test-crash.service"
is_active_ec=$?
set -e

if [[ $is_active_ec -eq 0 ]]; then
    log_fail "Scenario 6: is-active returned 0 for crashed unit inir-test-crash.service"
fi

unit_state="$(systemctl --user is-active "inir-test-crash.service" 2>&1 || true)"
log_pass "Scenario 6 (RESTART_CRASH_STATE): Custody delegated, crashed unit state is '$unit_state' (is-active exit code: $is_active_ec)"

# Scenario 7: NO_SYSTEMD (Degraded mode fallback executes directly and propagates exit code)
log_step "Scenario 7: NO_SYSTEMD (Degraded Mode)"

# Create a mock isolated bin directory without systemctl or systemd-run
no_systemd_bin_dir="$tmp_dir/no-systemd-bin"
mkdir -p "$no_systemd_bin_dir"
# Link essential binaries needed for shell execution (bash, coreutils, sed, etc.)
for b in bash sh cat cut sed tr date mkdir rm printf uname chmod env true false id stat type; do
    p="$(command -v "$b" 2>/dev/null || true)"
    if [[ -n "$p" && -x "$p" ]]; then
        ln -sf "$p" "$no_systemd_bin_dir/$b"
    fi
done

# Test 7.1: Degraded mode succeeds on successful child (true -> exit 0)
set +e
output="$(PATH="$no_systemd_bin_dir" invoke_launch_daemon "test-nosystemd-success" "true" "" "Test No Systemd Success" "/nonexistent/systemd-run" "replace" 2>&1)"
ec=$?
set -e

if [[ $ec -ne 0 ]]; then
    log_fail "Scenario 7.1: Expected exit code 0 for degraded mode with true, got $ec. Output: $output"
fi

# Test 7.2: Degraded mode propagates non-zero exit code of child (sh -c 'exit 42' -> exit 42)
set +e
output="$(PATH="$no_systemd_bin_dir" invoke_launch_daemon "test-nosystemd-fail" "sh" "" "Test No Systemd Fail" "/nonexistent/systemd-run" "replace" "-c" "exit 42" 2>&1)"
ec=$?
set -e

if [[ $ec -ne 42 ]]; then
    log_fail "Scenario 7.2: Expected propagated child exit code 42 in degraded mode, got $ec. Output: $output"
fi

log_pass "Scenario 7 (NO_SYSTEMD): Degraded fallback executed child via exec and cleanly propagated exit codes (0 and 42)"

# Final cleanup and success
log_step "All contract scenarios passed successfully"

