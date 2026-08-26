#!/usr/bin/env bash
# Contract test: unlock.sh must not pkill before secret-tool / already-unlocked guards.
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/../.." && pwd)"
src_unlock="$repo_root/scripts/keyring/unlock.sh"

log_pass() { printf '[test-keyring-unlock] PASS: %s\n' "$1"; }
log_fail() { printf '[test-keyring-unlock] FAIL: %s\n' "$1" >&2; exit 1; }

if [[ ! -f "$src_unlock" ]]; then
    log_fail "unlock.sh not found"
fi

tmp_dir="$(mktemp -d /tmp/inir-test-keyring-unlock.XXXXXX)"
cleanup() { rm -rf "$tmp_dir"; }
trap cleanup EXIT INT TERM

cp "$src_unlock" "$tmp_dir/unlock.sh"
chmod +x "$tmp_dir/unlock.sh"

stub_bin="$tmp_dir/bin"
mkdir -p "$stub_bin"
pkill_log="$tmp_dir/pkill.log"

cat > "$stub_bin/pkill" <<EOF
#!/usr/bin/env bash
printf 'pkill:%s\n' "\$*" >> "$pkill_log"
exit 0
EOF
chmod +x "$stub_bin/pkill"

cat > "$stub_bin/systemctl" <<EOF
#!/usr/bin/env bash
printf 'systemctl:%s\n' "\$*" >> "$tmp_dir/systemctl.log"
exit 0
EOF
chmod +x "$stub_bin/systemctl"

cat > "$stub_bin/sleep" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$stub_bin/sleep"

for needed in bash sh env cat printf whoami seq dirname pwd rm mkdir; do
    resolved="$(command -v "$needed" 2>/dev/null || true)"
    if [[ -n "$resolved" && -x "$resolved" ]]; then
        ln -sf "$resolved" "$stub_bin/$needed"
    fi
done
isolated_path="$stub_bin"

# Case 1: already unlocked — never pkill
cat > "$tmp_dir/is_unlocked.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$tmp_dir/is_unlocked.sh"
rm -f "$pkill_log"
set +e
output="$(PATH="$isolated_path" "$tmp_dir/unlock.sh" 2>&1)"
ec=$?
set -e
if [[ $ec -ne 0 ]]; then
    log_fail "already unlocked should exit 0, got $ec. Output: $output"
fi
if [[ -f "$pkill_log" ]]; then
    log_fail "already unlocked must never pkill: $(cat "$pkill_log")"
fi
log_pass "already unlocked exits 0 without pkill"

# Case 2: locked + missing secret-tool — exit 1, never pkill
cat > "$tmp_dir/is_unlocked.sh" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "$tmp_dir/is_unlocked.sh"
rm -f "$pkill_log"
set +e
output="$(PATH="$isolated_path" "$tmp_dir/unlock.sh" 2>&1)"
ec=$?
set -e
if [[ $ec -ne 1 ]]; then
    log_fail "missing secret-tool should exit 1, got $ec. Output: $output"
fi
if [[ -f "$pkill_log" ]]; then
    log_fail "missing secret-tool must never pkill: $(cat "$pkill_log")"
fi
log_pass "missing secret-tool exits 1 without pkill"
printf '[test-keyring-unlock] All scenarios passed\n'
