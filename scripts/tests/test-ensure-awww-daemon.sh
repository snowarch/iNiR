#!/usr/bin/env bash
# Contract test: AwwwBackend._ensureDaemonScript waits for the daemon, then starts it.
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/../.." && pwd)"
qml_file="$repo_root/services/AwwwBackend.qml"

log_pass() { printf '[test-ensure-awww-daemon] PASS: %s\n' "$1"; }
log_fail() { printf '[test-ensure-awww-daemon] FAIL: %s\n' "$1" >&2; exit 1; }

if [[ ! -f "$qml_file" ]]; then
    log_fail "AwwwBackend.qml not found at $qml_file"
fi

ensure_script="$(python3 - "$qml_file" <<'PY'
import re, sys, pathlib
path = pathlib.Path(sys.argv[1])
content = path.read_text(encoding="utf-8")
match = re.search(r'readonly property string _ensureDaemonScript:\s*`([^`]+)`', content)
if not match:
    sys.exit("Error: _ensureDaemonScript not found")
print(re.sub(r'\\(\$|`)', r'\1', match.group(1)))
PY
)"

if [[ -z "$ensure_script" ]]; then
    log_fail "Failed to extract _ensureDaemonScript"
fi

if [[ "$ensure_script" != *"inir-awww-daemon"* ]]; then
    log_fail "Script does not wait/start inir-awww-daemon"
fi
if [[ "$ensure_script" != *"query"* ]]; then
    log_fail "Script does not poll awww query"
fi
if [[ "$ensure_script" != *"systemctl --user start"* && "$ensure_script" != *"systemctl --user start inir-awww-daemon"* ]]; then
    log_fail "Script does not start inir-awww-daemon after wait"
fi

log_pass "extracted script gates on inir-awww-daemon and awww query"

tmp_dir="$(mktemp -d /tmp/inir-test-ensure-awww.XXXXXX)"
cleanup() { rm -rf "$tmp_dir"; }
trap cleanup EXIT INT TERM

stub_bin="$tmp_dir/bin"
mkdir -p "$stub_bin"
log_file="$tmp_dir/sys.log"
query_count_file="$tmp_dir/query.count"
printf '0' > "$query_count_file"

cat > "$stub_bin/awww" <<EOF
#!/usr/bin/env bash
if [[ "\${1:-}" != "query" ]]; then
    echo "unexpected awww args: \$*" >&2
    exit 2
fi
count=\$(cat "$query_count_file")
count=\$((count + 1))
printf '%s' "\$count" > "$query_count_file"
if [[ -f "$tmp_dir/query.ok" ]]; then
    exit 0
fi
exit 1
EOF
chmod +x "$stub_bin/awww"

cat > "$stub_bin/systemctl" <<EOF
#!/usr/bin/env bash
echo "\$*" >> "$log_file"
if [[ "\$1" == "--user" && "\$2" == "is-active" ]]; then
    if [[ -f "$tmp_dir/unit.active" ]]; then
        exit 0
    fi
    exit 3
fi
if [[ "\$1" == "--user" && "\$2" == "start" ]]; then
    touch "$tmp_dir/started"
    touch "$tmp_dir/query.ok"
    exit 0
fi
exit 0
EOF
chmod +x "$stub_bin/systemctl"

# sleep stays real so the 0.1s budget can elapse
export PATH="$stub_bin:/usr/bin:/bin"

set +e
output="$(bash -c "$ensure_script" 2>&1)"
ec=$?
set -e

if [[ $ec -ne 0 ]]; then
    log_fail "ensure script exited $ec. Output: $output"
fi

if [[ ! -f "$tmp_dir/started" ]]; then
    log_fail "expected systemctl --user start when query never succeeded during wait"
fi

if ! grep -q 'is-active' "$log_file"; then
    log_fail "expected systemctl --user is-active inir-awww-daemon during wait"
fi

if ! grep -q 'start' "$log_file"; then
    log_fail "systemctl start was not recorded"
fi

query_count="$(cat "$query_count_file")"
if [[ "$query_count" -lt 5 ]]; then
    log_fail "expected multiple awww query polls, got $query_count"
fi

log_pass "wait then systemctl start when daemon is down (queries=$query_count)"

# Query already succeeding: must not start
rm -f "$tmp_dir/started" "$log_file"
touch "$tmp_dir/query.ok"
printf '0' > "$query_count_file"

set +e
output="$(bash -c "$ensure_script" 2>&1)"
ec=$?
set -e

if [[ $ec -ne 0 ]]; then
    log_fail "ready-daemon ensure script exited $ec. Output: $output"
fi
if [[ -f "$tmp_dir/started" ]]; then
    log_fail "must not systemctl start when awww query already succeeds"
fi

log_pass "no start when awww query already succeeds"
printf '[test-ensure-awww-daemon] All scenarios passed\n'
