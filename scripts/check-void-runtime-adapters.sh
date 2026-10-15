#!/usr/bin/env bash
# Read-only Void runtime adapters checks for a live Void session.
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
expected_branch="${INIR_EXPECTED_BRANCH:-feat/void-optional-systemd-adapters}"
expected_commit="${INIR_EXPECTED_COMMIT:-}"

actual_branch="$(git -C "$repo_root" branch --show-current 2>/dev/null || true)"
actual_commit="$(git -C "$repo_root" rev-parse HEAD 2>/dev/null || true)"
check test "$actual_branch" = "$expected_branch"
if [[ -n "$expected_commit" ]]; then
  check test "$actual_commit" = "$expected_commit"
else
  printf 'INFO: commit=%s (not pinned; set INIR_EXPECTED_COMMIT to pin it)\n' "$actual_commit"
fi
check test -z "$(git -C "$repo_root" status --porcelain 2>/dev/null)"

for package in awww jq pipewire; do
  check xbps-query -p pkgver "$package"
done
check command -v awww
check command -v awww-daemon
check command -v jq
check command -v pactl

for adapter in \
  "$repo_root/services/AwwwBackend.qml" \
  "$repo_root/scripts/capture-windows.sh" \
  "$repo_root/scripts/clipboard-copy.sh" \
  "$repo_root/scripts/thumbnails/thumbgen-venv.sh"; do
  if grep -Fq 'systemd/private' "$adapter" &&
     grep -Fq 'systemctl --user show-environment' "$adapter"; then
    printf 'PASS: systemd user-manager predicate: %s\n' "${adapter#"$repo_root/"}"
  else
    printf 'FAIL: systemd user-manager predicate: %s\n' "${adapter#"$repo_root/"}" >&2
    failures=$((failures + 1))
  fi
done

if [[ -S "${XDG_RUNTIME_DIR:-}/systemd/private" ]] &&
   timeout 3s systemctl --user show-environment >/dev/null 2>&1; then
  printf 'FAIL: usable systemd user manager detected; Void fallback is not active\n' >&2
  failures=$((failures + 1))
else
  printf 'PASS: usable systemd user manager predicate is false\n'
fi

if grep -Fq 'command -v discover-overlay' "$repo_root/services/GameMode.qml"; then
  printf 'PASS: discover-overlay control runs only where it is installed\n'
else
  printf 'FAIL: discover-overlay control is not gated on the overlay being installed\n' >&2
  failures=$((failures + 1))
fi

for warp_toggle in \
  "$repo_root/modules/common/models/quickToggles/CloudflareWarpToggle.qml" \
  "$repo_root/modules/ii/sidebarRight/quickToggles/androidStyle/AndroidCloudflareWarpToggle.qml" \
  "$repo_root/modules/ii/sidebarRight/quickToggles/classicStyle/CloudflareWarp.qml"; do
  if ! grep -Fq 'systemctl start warp-svc' "$warp_toggle" \
      && ! grep -Fq 'registration", "new' "$warp_toggle"; then
    printf 'PASS: WARP avoids privileged auto-start and registration: %s\n' "${warp_toggle#"$repo_root/"}"
  else
    printf 'FAIL: WARP auto-start or registration remains: %s\n' "${warp_toggle#"$repo_root/"}" >&2
    failures=$((failures + 1))
  fi
done

service_root="${XDG_CONFIG_HOME:-$HOME/.config}/service"
for audio_svc in pipewire wireplumber pipewire-pulse; do
  if [[ -x "$service_root/$audio_svc/run" ]] &&
     grep -q '^# Managed by iNiR\.' "$service_root/$audio_svc/run"; then
    printf 'PASS: audio user service owned: %s\n' "$audio_svc"
  else
    printf 'FAIL: audio user service missing: %s\n' "$audio_svc" >&2
    failures=$((failures + 1))
  fi
done
check sv status "$service_root/pipewire"
check sv status "$service_root/wireplumber"
check sv status "$service_root/pipewire-pulse"
check pactl info

if ((failures > 0)); then
  printf '%d Void runtime adapters check(s) failed\n' "$failures" >&2
  exit 1
fi
printf 'All Void runtime adapters checks passed\n'
