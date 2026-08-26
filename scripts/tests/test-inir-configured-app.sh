#!/usr/bin/env bash
# Contract test: app slot reader uses inir_config_file, not payload config.json.
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/../.." && pwd)"
config_path_helper="$repo_root/scripts/lib/config-path.sh"
inir_script="$repo_root/scripts/inir"

log_pass() { printf '[test-inir-configured-app] PASS: %s\n' "$1"; }
log_fail() { printf '[test-inir-configured-app] FAIL: %s\n' "$1" >&2; exit 1; }

if [[ ! -f "$config_path_helper" ]]; then
    log_fail "config-path.sh not found"
fi
if [[ ! -f "$inir_script" ]]; then
    log_fail "scripts/inir not found"
fi

tmp_dir="$(mktemp -d /tmp/inir-test-configured-app.XXXXXX)"
cleanup() { rm -rf "$tmp_dir"; }
trap cleanup EXIT INT TERM

export HOME="$tmp_dir/home"
export XDG_CONFIG_HOME="$HOME/.config"
unset XDG_RUNTIME_DIR
export XDG_RUNTIME_DIR="$tmp_dir/runtime"
mkdir -p "$XDG_CONFIG_HOME/inir" "$XDG_RUNTIME_DIR" "$HOME"

user_config="$XDG_CONFIG_HOME/inir/config.json"
cat > "$user_config" <<'EOF'
{
  "apps": {
    "files": "inir-test-fm-xyz",
    "browser": "inir-test-browser-xyz"
  }
}
EOF

# Decoy payload-next-to-shell.qml config.json must be ignored for app slots.
payload_dir="$tmp_dir/payload"
mkdir -p "$payload_dir"
touch "$payload_dir/shell.qml"
cat > "$payload_dir/config.json" <<'EOF'
{
  "apps": {
    "files": "wrong-fm",
    "browser": "wrong-browser"
  }
}
EOF
export INIR_RUNTIME_DIR="$payload_dir"

# shellcheck source=/dev/null
source "$config_path_helper"

if ! declare -F _read_apps_slot >/dev/null 2>&1; then
    log_fail "_read_apps_slot is not defined after sourcing config-path.sh"
fi

files_slot="$(_read_apps_slot files)"
if [[ "$files_slot" != "inir-test-fm-xyz" ]]; then
    log_fail "_read_apps_slot files expected inir-test-fm-xyz, got '$files_slot'"
fi
browser_slot="$(_read_apps_slot browser)"
if [[ "$browser_slot" != "inir-test-browser-xyz" ]]; then
    log_fail "_read_apps_slot browser expected inir-test-browser-xyz, got '$browser_slot'"
fi
log_pass "_read_apps_slot uses inir_config_file (user config.json)"

if ! grep -q '_read_apps_slot files' "$inir_script"; then
    log_fail "launch_configured_files does not call _read_apps_slot"
fi
if ! grep -q '_read_apps_slot browser' "$inir_script"; then
    log_fail "launch_configured_browser does not call _read_apps_slot"
fi
if awk '/^launch_configured_files\(\)/,/^}/ { print }' "$inir_script" | grep -q 'resolve_config_dir'; then
    log_fail "launch_configured_files still calls resolve_config_dir"
fi
log_pass "both launchers share _read_apps_slot"

stub_bin="$tmp_dir/bin"
mkdir -p "$stub_bin"
call_log="$tmp_dir/call.log"

cat > "$stub_bin/inir-test-fm-xyz" <<EOF
#!/usr/bin/env bash
printf 'FM:%s\n' "\$*" > "$call_log"
EOF
chmod +x "$stub_bin/inir-test-fm-xyz"

export PATH="$stub_bin:/usr/bin:/bin"
rm -f "$call_log"
set +e
output="$("$inir_script" files /tmp/some-folder 2>&1)"
ec=$?
set -e
if [[ $ec -ne 0 ]]; then
    log_fail "inir files exited $ec. Output: $output"
fi
if [[ ! -f "$call_log" ]]; then
    log_fail "inir files did not exec the configured file manager. Output: $output"
fi
if ! grep -q 'FM:/tmp/some-folder' "$call_log"; then
    log_fail "configured file manager argv mismatch: $(cat "$call_log")"
fi
log_pass "inir files execs user-configured command, ignores payload config.json"
printf '[test-inir-configured-app] All scenarios passed\n'
