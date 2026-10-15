#!/usr/bin/env bash
# Void XBPS UI XBPS UI checks for Void package-management surfaces.
set -u

failures=0
temp_root=""
cleanup() {
  [[ -z "$temp_root" ]] || rm -rf "$temp_root"
}
trap cleanup EXIT
check() {
  if "$@"; then
    printf 'PASS: %s\n' "$*"
  else
    printf 'FAIL: %s\n' "$*" >&2
    failures=$((failures + 1))
  fi
}

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
expected_branch="${INIR_EXPECTED_BRANCH:-feat/void-xbps-ui}"
expected_commit="${INIR_EXPECTED_COMMIT:-}"
actual_branch="$(git -C "$repo_root" branch --show-current 2>/dev/null || true)"
actual_commit="$(git -C "$repo_root" rev-parse HEAD 2>/dev/null || true)"

check test "$actual_branch" = "$expected_branch"
if [[ -n "$expected_commit" ]]; then
  check test "$actual_commit" = "$expected_commit"
else
  printf 'INFO: commit=%s (not pinned; set INIR_EXPECTED_COMMIT to pin it)\n' "$actual_commit"
fi
if [[ "${INIR_ALLOW_DIRTY:-false}" != true ]]; then
  check test -z "$(git -C "$repo_root" status --porcelain 2>/dev/null)"
fi

updates="$repo_root/services/Updates.qml"
search="$repo_root/services/deferred/PackageSearch.qml"
catalog="$repo_root/services/AppCatalog.qml"
catalog_json="$repo_root/defaults/app-catalog.json"
software_view="$repo_root/modules/ii/sidebarLeft/SoftwareView.qml"

for needle in \
  'xbps-install", "-nu"' \
  'root._backend === "xbps"'; do
  check grep -Fq "$needle" "$updates"
done
check grep -Fq 'case "xbps": return AppCatalog.hasFlatpak ? "xbps + flatpak" : "xbps"' "$software_view"

for needle in \
  '_xbpsSearchPipeline("-Rs", 200)' \
  '_xbpsSearchPipeline("-s", 100)' \
  'xbps-uhelper getpkgname' \
  'sudo xbps-install -S --' \
  'sudo xbps-remove -R --' \
  'sudo xbps-install -Su'; do
  check grep -Fq "$needle" "$search"
done

for needle in \
  'pm=xbps' \
  'case "xbps":' \
  'targets.xbps' \
  'sudo xbps-install -S -- "$1"' \
  'sudo xbps-remove -R -- "$1"'; do
  check grep -Fq "$needle" "$catalog"
done

check python3 - "$catalog_json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as fh:
    catalog = json.load(fh)

expected = {
    "firefox": "firefox",
    "chromium": "chromium",
    "kitty": "kitty",
    "signal": "Signal-Desktop",
    "gowall": "gowall",
    "mangohud": "MangoHud",
    "thunar": "Thunar",
}
by_id = {entry["id"]: entry for entry in catalog}
for app_id, package in expected.items():
    actual = by_id.get(app_id, {}).get("targets", {}).get("xbps")
    if actual != package:
        raise SystemExit(f"{app_id}: expected xbps target {package!r}, got {actual!r}")
PY

if [[ "${INIR_STATIC_ONLY:-false}" == true ]]; then
  if ((failures > 0)); then
    printf '%d Void XBPS UI static check(s) failed\n' "$failures" >&2
    exit 1
  fi
  printf 'All Void XBPS UI static checks passed\n'
  exit 0
fi

check command -v xbps-query
check command -v xbps-install
check command -v xbps-remove
check command -v xbps-uhelper
check xbps-install -nu

search_result="$(xbps-query -Rs firefox 2>/dev/null || true)"
check grep -Eq '^\[[*+-]\][[:space:]]+firefox-[^[:space:]]+' <<<"$search_result"

installed_result="$(xbps-query -s firefox 2>/dev/null || true)"
if xbps-query -p pkgver firefox >/dev/null 2>&1; then
  check grep -Eq '^\[\*\][[:space:]]+firefox-[^[:space:]]+' <<<"$installed_result"
fi

catalog_targets="$(
  python3 - "$catalog_json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as fh:
    catalog = json.load(fh)
for entry in catalog:
    target = entry.get("targets", {}).get("xbps")
    if target:
        print(target)
PY
)"
while IFS= read -r package; do
  [[ -n "$package" ]] || continue
  check xbps-query -R -p pkgver "$package"
done <<<"$catalog_targets"

test_package=""
for candidate in sl figlet cowsay; do
  if xbps-query -R -p pkgver "$candidate" >/dev/null 2>&1 \
      && ! xbps-query -p pkgver "$candidate" >/dev/null 2>&1; then
    test_package="$candidate"
    break
  fi
done

if [[ -z "$test_package" ]]; then
  printf 'FAIL: no disposable XBPS test package is available and uninstalled\n' >&2
  failures=$((failures + 1))
elif sudo -n true >/dev/null 2>&1; then
  check sudo -n xbps-install -S -y -- "$test_package"
  check xbps-query -p pkgver "$test_package"
  check sudo -n xbps-remove -R -y -- "$test_package"
  if xbps-query -p pkgver "$test_package" >/dev/null 2>&1; then
    printf 'FAIL: disposable package remained installed after remove: %s\n' "$test_package" >&2
    failures=$((failures + 1))
  else
    printf 'PASS: disposable package removed cleanly from system root: %s\n' "$test_package"
  fi
else
  printf 'INFO: sudo -n unavailable; validating a real XBPS transaction in an isolated user-owned root\n'
  temp_root="$(mktemp -d /tmp/inir-pr6-xbps.XXXXXX)"
  repo_url="$(xbps-query -L 2>/dev/null | awk 'NR == 1 {print $2}')"
  arch="$(xbps-uhelper arch 2>/dev/null || true)"
  if [[ -z "$repo_url" || -z "$arch" ]]; then
    printf 'FAIL: could not resolve XBPS repository or architecture for isolated validation\n' >&2
    failures=$((failures + 1))
  else
    mkdir -p "$temp_root/var/db/xbps/keys" "$temp_root/etc/xbps.d"
    cp -a /var/db/xbps/keys/. "$temp_root/var/db/xbps/keys/"
    check env XBPS_ARCH="$arch" xbps-install -r "$temp_root" -R "$repo_url" -S -y -- "$test_package"
    check xbps-query -r "$temp_root" -p pkgver "$test_package"
    check xbps-remove -r "$temp_root" -Rn -- "$test_package"
    check xbps-remove -r "$temp_root" -R -y -- "$test_package"
    if xbps-query -r "$temp_root" -p pkgver "$test_package" >/dev/null 2>&1; then
      printf 'FAIL: disposable package remained installed in isolated root: %s\n' "$test_package" >&2
      failures=$((failures + 1))
    else
      printf 'PASS: isolated XBPS install/remove transaction completed: %s\n' "$test_package"
    fi
  fi
  rm -rf "$temp_root"
  temp_root=""
fi

if ((failures > 0)); then
  printf '%d Void XBPS UI check(s) failed\n' "$failures" >&2
  exit 1
fi
printf 'All Void XBPS UI checks passed\n'
