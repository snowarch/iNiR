#!/usr/bin/env bash
# Void WARP / current Void contract for the optional Cloudflare WARP provider.
# Static/provider-shape checks are always safe. Live daemon/account-adjacent checks
# only run when INIR_VERIFY_WARP_LIVE=true is explicitly requested.
set -u

failures=0
check() {
  if "$@"; then
    printf 'PASS: %s\n' "$*"
  else
    printf 'FAIL: %s\n' "$*" >&2
    failures=$((failures + 1))
  fi
}

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
expected_branch="${INIR_EXPECTED_BRANCH:-}"
expected_commit="${INIR_EXPECTED_COMMIT:-}"
actual_branch="$(git -C "$repo_root" branch --show-current 2>/dev/null || true)"
actual_commit="$(git -C "$repo_root" rev-parse HEAD 2>/dev/null || true)"

if [[ -n "$expected_branch" ]]; then
  check test "$actual_branch" = "$expected_branch"
else
  printf 'INFO: branch=%s (not pinned; set INIR_EXPECTED_BRANCH to pin it)\n' "$actual_branch"
fi
if [[ -n "$expected_commit" ]]; then
  check test "$actual_commit" = "$expected_commit"
else
  printf 'INFO: commit=%s (not pinned; set INIR_EXPECTED_COMMIT to pin it)\n' "$actual_commit"
fi
check test -z "$(git -C "$repo_root" status --porcelain 2>/dev/null)"

extras="$repo_root/sdata/lib/extras.sh"
deps="$repo_root/sdata/dist-void/install-deps.sh"
doctor="$repo_root/sdata/lib/doctor.sh"
setups="$repo_root/sdata/subcmd-install/2.setups.sh"
functions="$repo_root/sdata/lib/functions.sh"
setup="$repo_root/setup"

# WARP must remain an explicit Void Extra, not a normal toolkit/Doctor dependency.
check grep -Fq 'extras_install_void_warp()' "$extras"
check grep -Fq 'extras_refresh_void_warp_on_update()' "$extras"
check grep -Fq 'INIR_WARP_PACKAGES_URL=' "$extras"
check grep -Fq 'INIR_WARP_FALLBACK_SHA256=' "$extras"
check grep -Fq "Cloudflare WARP's official Linux binary is glibc-only" "$extras"
check grep -Fq 'Install/update Cloudflare WARP' "$setup"
check grep -Fq 'configure_void_warp_service' "$functions"
if grep -Fq 'install_void_warp' "$deps" \
    || grep -Fq 'warp-cli:cloudflare-warp' "$doctor" \
    || grep -Fq 'configure_void_warp_service || return 1' "$setups"; then
  printf 'FAIL: WARP is still wired as a mandatory Void dependency/provider\n' >&2
  failures=$((failures + 1))
else
  printf 'PASS: WARP is optional and absent from normal dependency/Doctor activation\n'
fi

check bash "$repo_root/dev/tests/test-void-warp-extra.sh"

for warp_toggle in \
  "$repo_root/modules/common/models/quickToggles/CloudflareWarpToggle.qml" \
  "$repo_root/modules/sidebarRight/quickToggles/androidStyle/AndroidCloudflareWarpToggle.qml" \
  "$repo_root/modules/sidebarRight/quickToggles/classicStyle/CloudflareWarp.qml"; do
  if ! grep -Fq 'systemctl start warp-svc' "$warp_toggle" \
      && ! grep -Fq 'registration", "new' "$warp_toggle"; then
    printf 'PASS: toggle requires explicit service/account action: %s\n' "${warp_toggle#"$repo_root/"}"
  else
    printf 'FAIL: toggle auto-starts or auto-registers: %s\n' "${warp_toggle#"$repo_root/"}" >&2
    failures=$((failures + 1))
  fi
done

if [[ "${INIR_VERIFY_WARP_LIVE:-false}" != true ]]; then
  printf 'INFO: live WARP checks skipped (set INIR_VERIFY_WARP_LIVE=true to opt in)\n'
else
  check test "$(uname -m)" = x86_64
  if ldd --version 2>&1 | grep -qi musl; then
    printf 'FAIL: live WARP verification requested on musl; provider is glibc-only\n' >&2
    failures=$((failures + 1))
  else
    printf 'PASS: live WARP host uses glibc-compatible userspace\n'
  fi

  check command -v warp-cli
  check command -v warp-svc
  check command -v nft
  check test -x /usr/local/bin/warp-cli
  check test -x /usr/local/bin/warp-svc
  check test -L /var/service/warp-svc
  check grep -Fq '# Managed by iNiR.' /etc/sv/warp-svc/run
  check test -x /etc/sv/warp-svc/log/run
  check grep -Fq '# Managed by iNiR.' /etc/sv/warp-svc/log/run
  check grep -Fq 'exec vlogger -t warp-svc -p daemon' /etc/sv/warp-svc/log/run
  if sudo -n true >/dev/null 2>&1; then
    check sudo -n sv status /var/service/warp-svc
  else
    printf 'INFO: privileged sv status skipped (sudo -n unavailable); socket/process checks remain authoritative\n'
  fi
  check test -S /run/cloudflare-warp/warp_service

  if [[ "${INIR_VERIFY_IDEMPOTENCY:-false}" == true ]]; then
    before="$(mktemp)"
    after="$(mktemp)"
    provider_snapshot() {
      for path in /usr/local/bin/warp-cli /usr/local/bin/warp-svc /etc/sv/warp-svc/run /etc/sv/warp-svc/log/run /var/service/warp-svc; do
        [[ -f "$path" ]] && sha256sum "$path"
        [[ -L "$path" ]] && readlink "$path"
      done
      [[ -f "${XDG_STATE_HOME:-$HOME/.local/state}/inir/warp-provider.json" ]] \
        && cat "${XDG_STATE_HOME:-$HOME/.local/state}/inir/warp-provider.json"
    }
    provider_snapshot > "$before"
    if (
      cd "$repo_root"
      # shellcheck source=/dev/null
      source ./sdata/lib/environment-variables.sh
      source ./sdata/lib/functions.sh
      source ./sdata/lib/tui.sh
      source ./sdata/lib/package-installers.sh
      source ./sdata/lib/dist-determine.sh
      source ./sdata/lib/extras.sh
      detect_distro
      ask=false
      extras_install_void_warp
    ); then
      printf 'PASS: optional WARP provider second run completed\n'
    else
      printf 'FAIL: optional WARP provider second run failed\n' >&2
      failures=$((failures + 1))
    fi
    provider_snapshot > "$after"
    check cmp -s "$before" "$after"
    rm -f "$before" "$after"
  else
    printf 'INFO: live idempotency skipped (also set INIR_VERIFY_IDEMPOTENCY=true)\n'
  fi
fi

if ((failures > 0)); then
  printf '%d Void WARP check(s) failed\n' "$failures" >&2
  exit 1
fi
printf 'All Void WARP optional-provider checks passed\n'
