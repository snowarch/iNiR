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
    "$runtime_root/sdata/lib/"*.sh \
    "$runtime_root/sdata/subcmd-install/"*.sh \
    "$runtime_root/sdata/migrations/"*.sh

step "session tray ordering"
service_unit="$runtime_root/assets/systemd/inir.service"
if ! grep -qx 'Type=dbus' "$service_unit" \
        || ! grep -qx 'BusName=org.kde.StatusNotifierWatcher' "$service_unit" \
        || ! grep -qx 'PartOf=niri.service' "$service_unit" \
        || ! grep -qx 'Requisite=niri.service' "$service_unit" \
        || ! grep -qx 'After=niri.service' "$service_unit" \
        || ! grep -qx 'Before=xdg-desktop-autostart.target' "$service_unit"; then
    printf 'FAIL: inir.service is not ordered behind Niri and ahead of XDG autostart\n' >&2
    exit 1
fi
if grep -Fq '/tmp/.X11-unix/X' "$runtime_root/scripts/inir" \
        || grep -Fq '/tmp/.X11-unix/X' "$runtime_root/modules/common/functions/ShellExec.qml" \
        || grep -Fq 'niri.wayland-*.sock' "$runtime_root/scripts/inir"; then
    printf 'FAIL: iNiR still guesses compositor-owned DISPLAY/NIRI_SOCKET from filesystem sockets\n' >&2
    exit 1
fi
session_helper="$runtime_root/scripts/lib/niri-session-env.sh"
if [[ ! -f "$session_helper" ]] \
        || ! grep -Fq 'MainPID --value niri.service' "$session_helper" \
        || ! grep -Fq 'inir_resolve_niri_service_environment' "$runtime_root/scripts/inir" \
        || ! grep -Fq 'inir_resolve_niri_service_environment' "$runtime_root/sdata/lib/doctor.sh" \
        || ! grep -Fq '"040-niri-session-environment-lifecycle"' "$runtime_root/sdata/lib/migrations.sh"; then
    printf 'FAIL: Niri session recovery is not owned by launcher/Doctor with the legacy migration retired\n' >&2
    exit 1
fi

session_env_root="$(mktemp -d)"
mkdir -p "$session_env_root/bin" "$session_env_root/runtime"
python3 - "$session_env_root/runtime" <<'PYSESSION'
import pathlib
import socket
import sys
root = pathlib.Path(sys.argv[1])
for name in ("wayland-7", "niri.wayland-7.4242.sock"):
    sock = socket.socket(socket.AF_UNIX)
    sock.bind(str(root / name))
    sock.close()
PYSESSION
cat > "$session_env_root/bin/systemctl" <<'SH'
#!/usr/bin/env bash
if [[ "$*" == "--user is-active --quiet niri.service" ]]; then exit 0; fi
if [[ "$*" == "--user show -p MainPID --value niri.service" ]]; then printf '%s\n' "${INIR_TEST_NIRI_PID:-4242}"; exit 0; fi
exit 1
SH
chmod +x "$session_env_root/bin/systemctl"
if ! PATH="$session_env_root/bin:$PATH" XDG_RUNTIME_DIR="$session_env_root/runtime" SESSION_HELPER="$session_helper" bash -c '
    source "$SESSION_HELPER"
    inir_resolve_niri_service_environment
    [[ "$INIR_RESOLVED_NIRI_SOCKET" == "$XDG_RUNTIME_DIR/niri.wayland-7.4242.sock" ]]
    [[ "$INIR_RESOLVED_WAYLAND_DISPLAY" == "wayland-7" ]]
'; then
    rm -rf "$session_env_root"
    printf 'FAIL: Niri service-scoped environment recovery cannot resolve the service-owned sockets\n' >&2
    exit 1
fi
if PATH="$session_env_root/bin:$PATH" XDG_RUNTIME_DIR="$session_env_root/runtime" INIR_TEST_NIRI_PID=9999 SESSION_HELPER="$session_helper" bash -c '
    source "$SESSION_HELPER"
    inir_resolve_niri_service_environment
'; then
    rm -rf "$session_env_root"
    printf 'FAIL: Niri environment recovery accepts a socket not owned by niri.service MainPID\n' >&2
    exit 1
fi
rm -rf "$session_env_root"
if ! grep -Fq 'property var _trayService: TrayService' "$runtime_root/shell.qml"; then
    printf 'FAIL: shell startup does not instantiate the StatusNotifier watcher\n' >&2
    exit 1
fi
if grep -q '^Environment=MALLOC_' "$service_unit" \
        || grep -Eq '^[[:space:]]*export[[:space:]]+MALLOC_' "$runtime_root/scripts/inir" \
        || grep -Eq '^[[:space:]]*export[[:space:]]+MALLOC_' "$runtime_root/scripts/quickshell-env.sh"; then
    printf 'FAIL: iNiR still overrides the glibc allocator at runtime\n' >&2
    exit 1
fi

step "suspend lock handshake"
lock_owner="$runtime_root/modules/lock/Lock.qml"
idle_owner="$runtime_root/services/Idle.qml"
if ! grep -Fq 'function prepareSleep(): string' "$lock_owner" \
        || ! grep -Fq 'return lock.secure ? "secure" : "locking";' "$lock_owner"; then
    printf 'FAIL: lock before-sleep path does not expose compositor-confirmed secure state\n' >&2
    exit 1
fi
if ! grep -Fq 'inir-session-lock.state' "$lock_owner" \
        || ! grep -Fq 'Recovering interrupted Niri session lock' "$lock_owner" \
        || ! grep -Fq 'previousSocket === _niriSocket' "$lock_owner"; then
    printf 'FAIL: Niri lock recovery state does not survive a Quickshell restart safely\n' >&2
    exit 1
fi
if ! grep -Fq 'lock prepareSleep' "$idle_owner" \
        || grep -Eq 'before-sleep.*lock activate' "$idle_owner"; then
    printf 'FAIL: swayidle before-sleep does not wait for the secure lock handshake\n' >&2
    exit 1
fi
if ! grep -Fq 'Lock did not become secure before sleep' "$runtime_root/scripts/inir"; then
    printf 'FAIL: launcher does not wait for WlSessionLock secure before returning to swayidle\n' >&2
    exit 1
fi
if ! grep -Fq 'Lock IPC was unavailable before sleep and no fallback could secure the session' "$runtime_root/scripts/inir" \
        || ! grep -Fq '"$swaylock_bin" -f -c 1a1a2e' "$runtime_root/scripts/inir"; then
    printf 'FAIL: before-sleep does not fail closed when the Quickshell lock target is unavailable\n' >&2
    exit 1
fi
for lock_surface in \
        "$runtime_root/modules/lock/LockSurface.qml" \
        "$runtime_root/modules/waffle/lock/WaffleLockSurface.qml" \
        "$runtime_root/modules/waffle/lock/WaffleLockSurfaceSafe.qml"; do
    if grep -Fq 'readonly property int imgStatus: avatarImage.status' "$lock_surface"; then
        printf 'FAIL: lock avatar retry still mutates its source from a synchronous status binding: %s\n' "$lock_surface" >&2
        exit 1
    fi
done

step "service mask handling"
service_mask_root="$(mktemp -d)"
mkdir -p "$service_mask_root/systemd/user" "$service_mask_root/bin"
cat > "$service_mask_root/bin/systemctl" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "${INIR_TEST_SYSTEMCTL_STATE:-disabled}"
SH
chmod +x "$service_mask_root/bin/systemctl"
ln -s /dev/null "$service_mask_root/systemd/user/inir.service"
if ! (
    export XDG_CONFIG_HOME="$service_mask_root"
    export PATH="$service_mask_root/bin:$PATH"
    source "$runtime_root/sdata/lib/functions.sh"
    inir_user_service_is_masked
); then
    printf 'FAIL: user service mask is not detected\n' >&2
    rm -rf "$service_mask_root"
    exit 1
fi
rm -f "$service_mask_root/systemd/user/inir.service"
printf '[Unit]\nDescription=test\n' > "$service_mask_root/systemd/user/inir.service"
if (
    export XDG_CONFIG_HOME="$service_mask_root"
    export PATH="$service_mask_root/bin:$PATH"
    source "$runtime_root/sdata/lib/functions.sh"
    inir_user_service_is_masked
); then
    printf 'FAIL: regular user service is classified as masked\n' >&2
    rm -rf "$service_mask_root"
    exit 1
fi
if ! (
    export XDG_CONFIG_HOME="$service_mask_root"
    export PATH="$service_mask_root/bin:$PATH"
    export INIR_TEST_SYSTEMCTL_STATE=masked-runtime
    source "$runtime_root/sdata/lib/functions.sh"
    inir_user_service_is_masked
); then
    printf 'FAIL: runtime user service mask is not detected\n' >&2
    rm -rf "$service_mask_root"
    exit 1
fi
service_wiring_function="$(sed -n '/^ensure_user_inir_service_enabled() {/,/^}/p' "$runtime_root/setup")"
mkdir -p "$service_mask_root/systemd/user/graphical-session.target.wants"
ln -sf "$service_mask_root/systemd/user/inir.service" "$service_mask_root/systemd/user/graphical-session.target.wants/inir.service"
if ! (
    export XDG_CONFIG_HOME="$service_mask_root"
    export PATH="$service_mask_root/bin:$PATH"
    export INIR_TEST_SYSTEMCTL_STATE=disabled
    source "$runtime_root/sdata/lib/functions.sh"
    eval "$service_wiring_function"
    ensure_user_inir_service_enabled
    [[ "$INIR_SERVICE_WIRING_CHANGED" -eq 1 ]]
    [[ ! -e "$service_mask_root/systemd/user/graphical-session.target.wants/inir.service" ]]
    [[ -L "$service_mask_root/systemd/user/niri.service.wants/inir.service" ]]
    ensure_user_inir_service_enabled
    [[ "$INIR_SERVICE_WIRING_CHANGED" -eq 0 ]]
); then
    printf 'FAIL: service wiring does not remove legacy wants links and converge idempotently\n' >&2
    rm -rf "$service_mask_root"
    exit 1
fi
rm -rf "$service_mask_root"

package_service_root="$(mktemp -d)"
mkdir -p "$package_service_root/xdg/systemd/user" "$package_service_root/bin" "$package_service_root/pkg"
printf '[Unit]\nDescription=iNiR package fixture\n' > "$package_service_root/pkg/inir.service"
cat > "$package_service_root/bin/systemctl" <<'SH'
#!/usr/bin/env bash
case "$*" in
    "--user is-enabled inir.service") printf 'disabled\n' ;;
    "--user cat niri.service") printf '[Unit]\nDescription=Niri fixture\n' ;;
    "--user show -p FragmentPath --value inir.service") printf '%s\n' "$INIR_TEST_PACKAGE_UNIT" ;;
    "--user show -p KillMode inir.service") printf 'KillMode=process\n' ;;
    "--user daemon-reload") : ;;
    *) exit 1 ;;
esac
SH
chmod +x "$package_service_root/bin/systemctl"
if ! (
    export XDG_CONFIG_HOME="$package_service_root/xdg"
    export PATH="$package_service_root/bin:$PATH"
    export INIR_TEST_PACKAGE_UNIT="$package_service_root/pkg/inir.service"
    source "$runtime_root/sdata/lib/functions.sh"
    get_installed_update_strategy() { printf 'package-manager\n'; }
    eval "$service_wiring_function"
    ensure_user_inir_service_enabled
    [[ "$INIR_SERVICE_WIRING_CHANGED" -eq 1 ]]
    [[ ! -e "$XDG_CONFIG_HOME/systemd/user/inir.service" ]]
    [[ "$(readlink -f "$XDG_CONFIG_HOME/systemd/user/niri.service.wants/inir.service")" == "$INIR_TEST_PACKAGE_UNIT" ]]
); then
    printf 'FAIL: package-managed service wiring creates or depends on a stale user unit copy\n' >&2
    rm -rf "$package_service_root"
    exit 1
fi

mkdir -p "$package_service_root/home/.config" "$package_service_root/runtime"
cat > "$package_service_root/runtime/version.json" <<'EOF'
{"installMode":"package-managed","updateStrategy":"package-manager"}
EOF
if ! HOME="$package_service_root/home" XDG_CONFIG_HOME="$package_service_root/home/.config" \
        PATH="$package_service_root/bin:$PATH" INIR_TEST_PACKAGE_UNIT="$package_service_root/pkg/inir.service" \
        INIR_FALLBACK_SYSTEM_RUNTIME_DIR="$package_service_root/runtime" \
        "$runtime_root/scripts/inir" service enable >/dev/null; then
    printf 'FAIL: packaged launcher cannot enable the Niri service from packaged version metadata\n' >&2
    rm -rf "$package_service_root"
    exit 1
fi
if [[ -e "$package_service_root/home/.config/systemd/user/inir.service" ]] \
        || [[ "$(readlink -f "$package_service_root/home/.config/systemd/user/niri.service.wants/inir.service")" != "$package_service_root/pkg/inir.service" ]]; then
    printf 'FAIL: packaged launcher shadows the package-owned service with a user copy\n' >&2
    rm -rf "$package_service_root"
    exit 1
fi
rm -rf "$package_service_root"
if ! grep -Fq 'inir_user_service_is_masked && return 2' "$runtime_root/setup" \
        || ! grep -Fq 'User inir.service is masked; leaving it unchanged' "$runtime_root/setup" \
        || ! grep -Fq 'Shell restart skipped: inir.service is masked' "$runtime_root/setup" \
        || ! grep -Fq 'User inir.service is masked' "$runtime_root/sdata/lib/doctor.sh" \
        || ! grep -Fq 'systemctl --user unmask inir.service' "$runtime_root/sdata/subcmd-install/3.files.sh" \
        || ! grep -Fq 'systemctl --user unmask --runtime inir.service' "$runtime_root/scripts/inir"; then
    printf 'FAIL: install/update/doctor do not preserve the service mask contract\n' >&2
    exit 1
fi
if ! grep -Fq '[[ "$qs_cgroup" == *"/inir.service"* ]] || continue' "$runtime_root/scripts/inir"; then
    printf 'FAIL: cleanup-orphans can terminate Quickshell processes outside inir.service\n' >&2
    exit 1
fi
if ! grep -Fq 'ActiveState --value inir.service' "$runtime_root/sdata/lib/doctor.sh" \
        || ! grep -Fq 'Result --value inir.service' "$runtime_root/sdata/lib/doctor.sh" \
        || ! grep -Fq 'service_result" == "start-limit-hit"' "$runtime_root/sdata/lib/doctor.sh"; then
    printf 'FAIL: Doctor does not surface failed/start-limit-hit inir.service state\n' >&2
    exit 1
fi

step "maintenance help is non-destructive"
setup_update_help="$($runtime_root/setup update --help)"
inir_update_help="$($runtime_root/scripts/inir update --help)"
if ! grep -Fq -- '--realign' <<< "$setup_update_help" \
        || ! grep -Fq -- '--realign' <<< "$inir_update_help" \
        || grep -Fq 'Checking for updates' <<< "$setup_update_help" \
        || grep -Fq 'Checking for updates' <<< "$inir_update_help"; then
    printf 'FAIL: update --help can enter the maintenance workflow or hides recovery options\n' >&2
    exit 1
fi

step "legacy allocator repair"
allocator_root="$(mktemp -d)"
mkdir -p "$allocator_root/xdg/environment.d" "$allocator_root/bin"
cat > "$allocator_root/bin/systemctl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-} ${2:-}" in
    "--user show-environment")
        cat "${INIR_TEST_MANAGER_ENV:?}"
        ;;
    "--user unset-environment")
        key="${3:?}"
        grep -v "^${key}=" "${INIR_TEST_MANAGER_ENV:?}" > "${INIR_TEST_MANAGER_ENV}.tmp" || true
        mv "${INIR_TEST_MANAGER_ENV}.tmp" "${INIR_TEST_MANAGER_ENV}"
        ;;
    *) exit 1 ;;
esac
SH
chmod +x "$allocator_root/bin/systemctl"
cat > "$allocator_root/xdg/environment.d/quickshell-mem.conf" <<'EOF'
# Quickshell/iNiR memory optimization
# Prevents glibc malloc arenas from retaining freed wallpaper textures.
# See: scripts/quickshell-env.sh for details.
MALLOC_ARENA_MAX=2
MALLOC_MMAP_THRESHOLD_=131072
EOF
printf 'MALLOC_ARENA_MAX=2\nMALLOC_MMAP_THRESHOLD_=131072\n' > "$allocator_root/manager-env"
if ! (
    export XDG_CONFIG_HOME="$allocator_root/xdg"
    export PATH="$allocator_root/bin:$PATH"
    export INIR_TEST_MANAGER_ENV="$allocator_root/manager-env"
    export MALLOC_ARENA_MAX=2 MALLOC_MMAP_THRESHOLD_=131072
    source "$runtime_root/sdata/lib/functions.sh"
    repair_legacy_quickshell_malloc_environment
    [[ ! -e "$allocator_root/xdg/environment.d/quickshell-mem.conf" ]]
    [[ -z "${MALLOC_ARENA_MAX:-}" && -z "${MALLOC_MMAP_THRESHOLD_:-}" ]]
    [[ ! -s "$allocator_root/manager-env" ]]
    [[ "${INIR_LEGACY_MALLOC_ENV_REPAIRED:-0}" -ge 5 ]]
); then
    printf 'FAIL: legacy Quickshell allocator repair does not clean file, process and user-manager state\n' >&2
    rm -rf "$allocator_root"
    exit 1
fi
cat > "$allocator_root/xdg/environment.d/quickshell-mem.conf" <<'EOF'
MALLOC_ARENA_MAX=8
MALLOC_MMAP_THRESHOLD_=262144
EOF
cp "$allocator_root/xdg/environment.d/quickshell-mem.conf" "$allocator_root/manager-env"
allocator_before="$(sha256sum "$allocator_root/xdg/environment.d/quickshell-mem.conf" | cut -d' ' -f1)"
if ! (
    export XDG_CONFIG_HOME="$allocator_root/xdg"
    export PATH="$allocator_root/bin:$PATH"
    export INIR_TEST_MANAGER_ENV="$allocator_root/manager-env"
    export MALLOC_ARENA_MAX=8 MALLOC_MMAP_THRESHOLD_=262144
    source "$runtime_root/sdata/lib/functions.sh"
    repair_legacy_quickshell_malloc_environment
    [[ "${INIR_LEGACY_MALLOC_ENV_REPAIRED:-0}" -eq 0 ]]
    [[ "${MALLOC_ARENA_MAX:-}" == 8 && "${MALLOC_MMAP_THRESHOLD_:-}" == 262144 ]]
); then
    printf 'FAIL: allocator repair modified custom user allocator values\n' >&2
    rm -rf "$allocator_root"
    exit 1
fi
allocator_after="$(sha256sum "$allocator_root/xdg/environment.d/quickshell-mem.conf" | cut -d' ' -f1)"
if [[ "$allocator_before" != "$allocator_after" ]]; then
    printf 'FAIL: allocator repair rewrote custom environment.d values\n' >&2
    rm -rf "$allocator_root"
    exit 1
fi
rm -rf "$allocator_root"

step "update status path ownership"
if ! grep -Fq '_write_update_status() {' "$runtime_root/setup" \
        || ! grep -Fq 'mkdir -p "$status_dir"' "$runtime_root/setup" \
        || grep -Fq 'echo "success" > "$_update_status_file"' "$runtime_root/setup"; then
    printf 'FAIL: setup update status writes can fail before the shell creates its state directory\n' >&2
    exit 1
fi

step "rewritten remote recovery"
rewrite_root="$(mktemp -d)"
remote_repo="$rewrite_root/origin.git"
seed_repo="$rewrite_root/seed"
clean_repo="$rewrite_root/clean"
local_repo="$rewrite_root/local"
git -c init.defaultBranch=main init --bare -q "$remote_repo"
git -c init.defaultBranch=main init -q "$seed_repo"
git -C "$seed_repo" config user.email test@inir.invalid
git -C "$seed_repo" config user.name 'iNiR test'
printf 'A\n' > "$seed_repo/history.txt"
git -C "$seed_repo" add history.txt
git -C "$seed_repo" commit -qm A
git -C "$seed_repo" remote add origin "$remote_repo"
git -C "$seed_repo" push -qu origin main
printf 'B\n' >> "$seed_repo/history.txt"
git -C "$seed_repo" commit -qam B
old_published_tip="$(git -C "$seed_repo" rev-parse HEAD)"
git -C "$seed_repo" push -qu origin main
git clone -q "$remote_repo" "$clean_repo"
git clone -q "$remote_repo" "$local_repo"
git -C "$local_repo" config user.email test@inir.invalid
git -C "$local_repo" config user.name 'iNiR test'
printf 'local\n' >> "$local_repo/history.txt"
git -C "$local_repo" commit -qam local
local_tip="$(git -C "$local_repo" rev-parse HEAD)"
git -C "$seed_repo" reset -q --hard HEAD~1
printf 'C\n' >> "$seed_repo/history.txt"
git -C "$seed_repo" commit -qam C
git -C "$seed_repo" push -q --force origin main
git -C "$clean_repo" fetch -q origin
git -C "$local_repo" fetch -q origin
if ! (
    export XDG_CONFIG_HOME="$rewrite_root/xdg-clean"
    export XDG_STATE_HOME="$rewrite_root/state-clean"
    REPO_ROOT="$clean_repo"
    source "$runtime_root/sdata/lib/snapshots.sh"
    is_upstream_rewrite_divergence main
    realign_repo_to_remote main
    [[ "$(git -C "$clean_repo" rev-parse HEAD)" == "$(git -C "$clean_repo" rev-parse origin/main)" ]]
    [[ -n "${INIR_REPO_RECOVERY_REF:-}" ]]
    [[ "$(git -C "$clean_repo" rev-parse "$INIR_REPO_RECOVERY_REF")" == "$old_published_tip" ]]
); then
    printf 'FAIL: clean checkout cannot recover safely from a recorded upstream rewrite\n' >&2
    rm -rf "$rewrite_root"
    exit 1
fi
if (
    export XDG_CONFIG_HOME="$rewrite_root/xdg-local"
    export XDG_STATE_HOME="$rewrite_root/state-local"
    REPO_ROOT="$local_repo"
    source "$runtime_root/sdata/lib/snapshots.sh"
    realign_repo_to_remote main
); then
    printf 'FAIL: --realign can reset a clean checkout containing local commits\n' >&2
    rm -rf "$rewrite_root"
    exit 1
fi
if [[ "$(git -C "$local_repo" rev-parse HEAD)" != "$local_tip" ]]; then
    printf 'FAIL: rejected --realign changed the local-commit checkout\n' >&2
    rm -rf "$rewrite_root"
    exit 1
fi
printf 'dirty\n' >> "$clean_repo/history.txt"
if (
    export XDG_CONFIG_HOME="$rewrite_root/xdg-dirty"
    export XDG_STATE_HOME="$rewrite_root/state-dirty"
    REPO_ROOT="$clean_repo"
    source "$runtime_root/sdata/lib/snapshots.sh"
    realign_repo_to_remote main
); then
    printf 'FAIL: --realign can reset a dirty checkout\n' >&2
    rm -rf "$rewrite_root"
    exit 1
fi
rm -rf "$rewrite_root"

step "fresh install defaults"
python3 - "$runtime_root" <<'PY'
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
with (root / "defaults/config.json").open(encoding="utf-8") as handle:
    config = json.load(handle)
schema = (root / "modules/common/Config.qml").read_text(encoding="utf-8")
wizard = (root / "welcome.qml").read_text(encoding="utf-8")
iris_background = (root / "modules/iris/background/IrisBackground.qml").read_text(encoding="utf-8")
iris_panels = (root / "modules/iris/ShellIrisPanelsImpl.qml").read_text(encoding="utf-8")
bar_settings = (root / "modules/settings/BarConfig.qml").read_text(encoding="utf-8")
right_sidebar_button = (root / "modules/barM3/RightSidebarButton.qml").read_text(encoding="utf-8")
m3_bar_content = (root / "modules/barM3/BarContent.qml").read_text(encoding="utf-8")

checks = {
    "settings rail": config["settingsUi"]["overlayStyle"] == "rail",
    "legacy profile marker preserved": config["welcomeWizard"]["profile"] == "balanced",
    "fresh Material experience": config["welcomeWizard"]["stylePreset"] == "material",
    "fresh balanced graphics budget": config["welcomeWizard"]["performancePreset"] == "balanced",
    "fresh contextual motion": config["appearance"]["iiMotionProfile"] == "contextual",
    "fresh M3 bar": config["bar"]["appearanceStyle"] == "m3",
    "fresh M3 dock": config["dock"]["style"] == "m3",
    "iNiR Alt+Tab opt-in": config["modules"]["altSwitcher"] is False,
    "dock enabled": config["dock"]["enable"] is True,
    "dock pinned": config["dock"]["pinnedOnStartup"] is True,
    "dock not hover-only": config["dock"]["hoverToReveal"] is False,
    "right sidebar full height": config["sidebar"]["collapseEmptyNotifications"] is False,
    "left sidebar full height": config["sidebar"]["collapseWidgetsTab"] is False,
    "wallhaven tab": config["sidebar"]["wallhaven"]["enable"] is True,
    "news tab": config["sidebar"]["news"]["enable"] is True,
    "controls widget": config["sidebar"]["widgets"]["controls"] is True,
    "status widget": config["sidebar"]["widgets"]["status"] is True,
    "media controls surface defaults": all([
        config["background"]["widgets"]["mediaControls"]["showBackground"] is True,
        config["background"]["widgets"]["mediaControls"]["showBorder"] is True,
        config["background"]["widgets"]["mediaControls"]["backgroundOpacity"] == 0.16,
        config["background"]["widgets"]["mediaControls"]["borderWidth"] == 1,
    ]),
}
failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit("FAIL: fresh-install defaults: " + ", ".join(failed))

schema_checks = {
    "schema settings rail": 'property string overlayStyle: "rail"' in schema,
    "schema contextual motion": 'property string iiMotionProfile: "contextual"' in schema,
    "schema M3 bar": 'property string appearanceStyle: "m3"' in schema,
    "schema M3 dock": 'property string style: "m3"' in schema.split(
        "property JsonObject dock: JsonObject {", 1)[1].split(
        "property JsonObject controlPanel: JsonObject {", 1)[0],
    "schema M3 joined pills default": 'property string borderless: "pills"' in schema.split(
        "property JsonObject m3: JsonObject {", 1)[1].split(
        "property JsonObject layouts: JsonObject {", 1)[0],
    "schema fresh Flow uses discoverable compact M3": all(fragment in schema for fragment in [
        'property string layoutMode: "compact"',
        'property list<string> leftLayout: ["leftSidebarButton", "media", "workspaces"]',
        'property list<string> middleLayout: ["docktoPanel"]',
        'property list<string> rightLayout: ["utilButtons", "weatherBar", "clockWidget", "systemIcons", "rightSidebarButton"]'
    ]),
    "M3 right sidebar entry is a real runtime button": all(fragment in right_sidebar_button for fragment in [
        'ShellLayoutController.sidebarOpenAtSlot("right", screenName)',
        'ShellLayoutController.toggleSidebarAtSlot("right", screenName)',
        'text: root.toggled ? "right_panel_close" : "right_panel_open"'
    ]) and 'id: "rightSidebarButton"' in bar_settings
        and '"leftSidebarButton", "rightSidebarButton", "activeWindow"' in m3_bar_content,
    "schema fresh Material experience": 'property string stylePreset: "material"' in schema,
    "schema fresh graphics budget": 'property string performancePreset: "balanced"' in schema,
    "schema iNiR Alt+Tab opt-in": "property bool altSwitcher: false" in schema.split(
        "property JsonObject modules: JsonObject {", 1)[1].split(
        "property JsonObject appearance: JsonObject {", 1)[0],
    "schema dock enabled": "property bool enable: true" in schema.split(
        "property JsonObject dock: JsonObject {", 1)[1].split(
        "property JsonObject controlPanel: JsonObject {", 1)[0],
    "schema dock pinned": "property bool pinnedOnStartup: true" in schema,
    "schema dock not hover-only": "property bool hoverToReveal: false" in schema,
    "schema right sidebar full height": "property bool collapseEmptyNotifications: false" in schema,
    "schema left sidebar full height": "property bool collapseWidgetsTab: false" in schema,
    # `wallhaven` is the compatibility key; the UI is now the generic
    # Wallpapers tab. Assert the schema contract instead of a stale comment.
    "schema wallhaven compatibility": "property JsonObject wallhaven: JsonObject {" in schema
        and "property bool enable: true" in schema[schema.index("property JsonObject wallhaven: JsonObject {"):],
    "schema news tab": "property JsonObject news: JsonObject {\n                    property bool enable: true" in schema,
    "schema media controls surface contract": all(fragment in schema.split(
        "property JsonObject mediaControls: JsonObject {", 1)[1].split(
        "property JsonObject visualizer: JsonObject {", 1)[0] for fragment in [
            "property bool showBackground: true",
            "property bool showBorder: true",
            "property real backgroundOpacity: 0.16",
            "property real borderWidth: 1",
        ]),
    "wizard applies initial balanced profile only outside iRiS": all(fragment in wizard for fragment in [
        "if (!root.irisFamily && !root.initialProfileApplied)",
        "root.applyProfile(root.selectedProfile)"
    ]),
    "wizard applies initial graphics budget": "root.applyPerformancePreset(root.selectedPerformancePreset)" in wizard,
    "wizard does not auto-apply a style on page entry": 'if (root.currentStep === 2' not in wizard,
    "wizard iRiS starting layouts use real iRiS owners": all(fragment in wizard for fragment in [
        'id: "signature"', 'id: "floating"', 'id: "full"',
        '"iris.bar.layout": "island"', '"iris.bar.layout": "full"',
        '"iris.bar.notch": true', '"iris.surround.enable": true',
        '"iris.dock.position": "auto"'
    ]) and 'id: "minimal"' not in wizard,
    "wizard iRiS appearance uses curated Themes": all(fragment in wizard for fragment in [
        "irisWelcomeThemeIds", "IrisThemes.curated.filter", "IrisThemes.apply(theme)",
        "IrisThemes.activeId", "IrisScreenPreview"
    ]),
    "wizard iRiS placement writes iRiS geometry": all(fragment in wizard for fragment in [
        'Config.setNestedValue("iris.bar.position", value)',
        'Config.setNestedValue("iris.bar.layout", value)',
        'Config.setNestedValue("iris.dock.position", value)',
        'Config.setNestedValue("iris.bar.notch", value === "on")',
        'Config.setNestedValue("iris.modules.desktopWidgets", value === "on")'
    ]),
    "iRiS lightweight background retains bare-desktop menu": all(fragment in iris_background for fragment in [
        "IrisDesktopMenu {", "acceptedButtons: Qt.RightButton | Qt.LeftButton", "IrisDesktopActions.menu("
    ]) and 'Config.setNestedValue("iris.modules.desktopWidgets", true)' in (root / "modules/iris/background/IrisDesktopActions.qml").read_text(encoding="utf-8") and 'component: IrisBackground {}' in (root / "modules/iris/critical/ShellIrisCriticalPanels.qml").read_text(encoding="utf-8")
        and 'component: Background {}' in iris_panels,
    "wizard style catalog covers all ii global styles": all(preset in wizard for preset in [
        'id: "material"', 'id: "cards"', 'id: "aurora"', 'id: "inir"',
        'id: "angel"', 'id: "regalia"', 'id: "zzz"', 'id: "cookie"',
        'id: "editorial"'
    ]),
    "wizard styles cover all ii bar chassis": all(fragment in wizard for fragment in [
        '"bar.appearanceStyle": "classic"', '"bar.appearanceStyle": "islands"',
        '"bar.appearanceStyle": "scenic"', '"bar.appearanceStyle": "frame"',
        '"bar.appearanceStyle": "m3"', '"bar.appearanceStyle": "pill"'
    ]),
    "wizard styles cover all dock chassis": all(fragment in wizard for fragment in [
        '"dock.style": "panel"', '"dock.style": "pill"', '"dock.style": "macos"',
        '"dock.style": "island"', '"dock.style": "m3"'
    ]),
    "wizard Material stays on compact M3": all(fragment in wizard for fragment in [
        '"bar.appearanceStyle": "m3"', '"bar.m3.layoutMode": "compact"',
        '"bar.m3.borderless": "pills"', '"dock.style": "m3"',
        '["leftSidebarButton", "media", "workspaces"]',
        '["utilButtons", "weatherBar", "clockWidget", "systemIcons", "rightSidebarButton"]'
    ]) and '"bar.m3.layoutMode": "showcase"' not in wizard,
    "wizard Pill preset keeps visualizer opt-in": all(fragment in wizard for fragment in [
        '"bar.appearanceStyle": "pill"', '"bar.pill.musicViz": false',
        '"bar.pill.soul.enable": true', '"bar.pill.soul.style": "orb"'
    ]),
    "wizard balanced sidebars remain useful without provider bloat": all(fragment in wizard for fragment in [
        '"sidebar.news.enable": true', '"sidebar.wallhaven.enable": true',
        '"sidebar.tools.enable": false', '"sidebar.software.enable": false',
        '"sidebar.widgets.controls": true', '"sidebar.widgets.status": true',
        '"sidebar.right.enabledWidgets": [\n                "calendar", "events", "todo", "notepad", "weather"\n            ]'
    ]),
    "wizard balanced quick toggles match maintained baseline": all(fragment in wizard for fragment in [
        '{ "size": 1, "type": "network" }', '{ "size": 1, "type": "bluetooth" }',
        '{ "size": 1, "type": "audio" }', '{ "size": 1, "type": "mic" }',
        '{ "size": 1, "type": "nightLight" }', '{ "size": 1, "type": "screenSnip" }',
        '{ "size": 1, "type": "colorPicker" }', '{ "size": 1, "type": "idleInhibitor" }'
    ]),
    "wizard fresh desktop stays sparse and zoned": all(fragment in wizard for fragment in [
        '"background.widgets.clock.enable": true',
        '"background.widgets.clock.placementStrategy": "topRight"',
        '"background.widgets.visualizer.enable": false',
        '"background.widgets.mediaControls.enable": false'
    ]),
    "wizard Full avoids demo-only clutter": all(fragment in wizard for fragment in [
        '"background.widgets.systemMonitor.enable": true',
        '"background.widgets.systemMonitor.placementStrategy": "bottomRight"',
        '"mascot.enable": false'
    ]) and '"background.widgets.visualizer.enable": true' not in wizard,
    "wizard uses one real curated style selector": wizard.count('ThemeService.setGlobalStyle(') == 1
        and 'ThemeService.setGlobalStyle(newValue)' not in wizard,
    "wizard preserves independent Waffle family selection": all(fragment in wizard for fragment in [
        'title: "Waffle"',
        'onClicked: root.chooseFamily("waffle")'
    ]),
    "wizard exposes independent iRiS family selection": all(fragment in wizard for fragment in [
        'title: "iRiS"',
        'onClicked: root.chooseFamily("iris")'
    ]),
    "wizard graphics catalog": all(preset in wizard for preset in [
        'id: "minimum"', 'id: "efficient"', 'id: "balanced"'
    ]),
    "wizard graphics labels stay outcome-oriented": all(label in wizard for label in [
        'id: "minimum", name: Translation.tr("Save power")',
        'id: "efficient", name: Translation.tr("Fewer effects")',
        'id: "balanced", name: Translation.tr("Full style")'
    ]),
    "wizard graphics budgets preserve style-default blur policy": (
        wizard.split("readonly property var performancePresets:", 1)[1]
            .split("function presetById", 1)[0]
            .count('"performance.blurBackend": "auto"') == 3
        and '"performance.blurBackend": "off"' not in wizard.split(
            "readonly property var performancePresets:", 1)[1].split("function presetById", 1)[0]
    ),
    "wizard low-end tiers keep distinct master/compositor policy": all(fragment in wizard for fragment in [
        '"performance.lowPower": true',
        '"performance.compositorBlur": false',
        '"performance.compositorBlur": true'
    ]),
    "wizard dock pinned": '"dock.pinnedOnStartup": true' in wizard,
    "wizard dock not hover-only": '"dock.hoverToReveal": false' in wizard,
    "wizard right sidebar full height": '"sidebar.collapseEmptyNotifications": false' in wizard,
    "wizard left sidebar full height": '"sidebar.collapseWidgetsTab": false' in wizard,
    "wizard ii layout refinements mark the profile custom": all(fragment in wizard for fragment in [
        'root.setProfileFeature("bar.bottom", value === "bottom")',
        'root.setProfileFeature("dock.position", value)'
    ]),
    "wizard family selection goes through the runtime family owner": all(fragment in wizard for fragment in [
        'function chooseFamily(id: string): void',
        '"panelFamily", "set", id',
        'root.chooseFamily("ii")',
        'root.chooseFamily("waffle")',
        'root.chooseFamily("iris")'
    ]),
    "wizard responsive grids collapse on narrow widths": all(fragment in wizard for fragment in [
        'columns: welcomeFlickable.width < 720 ? 1 : 2',
        'columns: layoutFlickable.width < 760 ? 1 : 2',
        'columns: featuresFlickable.width < 760 ? 1 : 2',
        'columns: themeFlickable.width < 760 ? 1 : 2'
    ]),
}
failed = [name for name, passed in schema_checks.items() if not passed]
if failed:
    raise SystemExit("FAIL: schema/wizard defaults: " + ", ".join(failed))

binds = (root / "defaults/niri/config.d/70-binds.kdl").read_text(encoding="utf-8")
if 'Alt+Tab { next-window; }' not in binds or 'Alt+Shift+Tab { previous-window; }' not in binds:
    raise SystemExit("FAIL: native Niri Alt+Tab bindings are missing")
if 'spawn "inir" "altSwitcher"' in binds:
    raise SystemExit("FAIL: fresh-install Alt+Tab invokes the iNiR switcher")
if 'Ctrl+Alt+F { spawn "inir" "equalizer" "toggle"; }' not in binds:
    raise SystemExit("FAIL: fresh-install EasyEffects Equalizer binding is missing")
if 'Ctrl+Alt+E { spawn "inir" "equalizer" "toggle"; }' in binds:
    raise SystemExit("FAIL: fresh-install Equalizer binding regressed to the old Ctrl+Alt+E chord")
PY

equalizer_helper="$runtime_root/scripts/audio/easyeffects-eq.sh"
equalizer_service="$runtime_root/services/deferred/EasyEffects.qml"
equalizer_owner="$runtime_root/modules/ii/ShellIiPanelsImpl.qml"
if grep -Fq 'equalizer:0:' "$equalizer_helper" \
        || grep -Fq 'get_last_loaded_preset:output' "$equalizer_helper" \
        || ! grep -Fq 'find_equalizer_instance()' "$equalizer_helper" \
        || ! grep -Fq 'output_pipeline_is_empty()' "$equalizer_helper" \
        || ! grep -Fq "load_preset:output:iNiR Equalizer" "$equalizer_helper" \
        || ! grep -Fq '"instanceId":%s' "$equalizer_helper" \
        || ! grep -Fq 'property int equalizerInstanceId: -1' "$equalizer_service" \
        || ! grep -Fq 'Component.onCompleted: EasyEffects.ensureEqualizer()' "$equalizer_owner"; then
    printf 'FAIL: EasyEffects Equalizer can regress to instance #0, unsafe preset restore, or lose fresh-pipeline bootstrap\n' >&2
    exit 1
fi

arch_installer="$runtime_root/sdata/dist-arch/install-deps.sh"
if ! grep -Fq 'pacman -T "${_all_official[@]}"' "$arch_installer" \
        || ! grep -Fq 'pacman -S $installflags "${_repo_installable[@]}"' "$arch_installer"; then
    printf 'FAIL: Arch package plan is not filtered through the local package database before the batched install\n' >&2
    exit 1
fi
if grep -Fq 'pacman -S $installflags "${_all_official[@]}"' "$arch_installer"; then
    printf 'FAIL: Arch installer can still reinstall or downgrade satisfied dependencies\n' >&2
    exit 1
fi
if ! grep -Fq 'OS_SPECIFIC_ID:-}" == "cachyos"' "$arch_installer" \
        || ! grep -Fq 'pacman -Si niri-focused-booster' "$arch_installer" \
        || ! grep -Fq 'OFFICIAL_PACKAGES+=(niri-focused-booster)' "$arch_installer"; then
    printf 'FAIL: CachyOS fresh installs no longer provision the Niri DMEM focus booster from configured repos\n' >&2
    exit 1
fi
if ! grep -Fq 'ID="?cachyos"?' "$runtime_root/sdata/lib/dist-determine.sh"; then
    printf 'FAIL: CachyOS detection ignores /etc/os-release ID=cachyos\n' >&2
    exit 1
fi
files_installer="$runtime_root/sdata/subcmd-install/3.files.sh"
if ! grep -Fq 'INSTALL_FIRSTRUN}" == true && "${OS_SPECIFIC_ID:-}" == "cachyos"' "$files_installer" \
        || ! grep -Fq 'command -v niri-focused-booster >/dev/null 2>&1' "$files_installer" \
        || ! grep -Fq '[ -r /sys/fs/cgroup/dmem.capacity ] && exec niri-focused-booster' "$files_installer"; then
    printf 'FAIL: fresh CachyOS installs do not conditionally wire the Niri DMEM focus booster\n' >&2
    exit 1
fi
if grep -Fq 'niri-focused-booster' "$runtime_root/defaults/niri/config.d/50-startup.kdl"; then
    printf 'FAIL: generic Niri defaults contain CachyOS-only DMEM integration\n' >&2
    exit 1
fi

fedora_installer="$runtime_root/sdata/dist-fedora/install-deps.sh"
if ! grep -Fq 'fedora_quickshell_compatible' "$fedora_installer" \
        || ! grep -Fq 'FEDORA_REPO_PKGS=' "$fedora_installer" \
        || ! grep -Eq '^[[:space:]]+sddm$' "$fedora_installer"; then
    printf 'FAIL: Fedora installer lost repository-first/version-aware package planning or SDDM\n' >&2
    exit 1
fi
if grep -Fq 'rpmfusion-nonfree-release' "$fedora_installer"; then
    printf 'FAIL: Fedora installer enables RPM Fusion Nonfree without an iNiR dependency requiring it\n' >&2
    exit 1
fi
setups_script="$runtime_root/sdata/subcmd-install/2.setups.sh"
# Install keeps a login screen the machine already has: SDDM takes over only when there is none or the
# person says so on a first install (#279). Disabling GDM & co. outside that decision put hybrid laptops
# on a black screen after every reinstall.
if ! grep -Fq 'take_over=false' "$setups_script" \
        || ! grep -Fq 'if [[ "$take_over" == true ]]; then' "$setups_script" \
        || ! grep -Fq 'extras_install_sddm_theme "yes" no' "$runtime_root/sdata/subcmd-install/3.files.sh"; then
    printf 'FAIL: install can switch an existing display manager to SDDM without asking\n' >&2
    exit 1
fi
sddm_installer="$runtime_root/scripts/sddm/install-pixel-sddm.sh"
# The theme drop-in holds only the theme; a display server is set only by the separate, chosen greeter
# drop-in (98-inir-greeter.conf, Wayland with Niri), and InputMethod never.
sddm_theme_conf="$(awk '/^desired_conf="/,/"$/' "$sddm_installer")"
if grep -Eq 'DisplayServer=|InputMethod=' <<<"$sddm_theme_conf" \
        || grep -Eq '^[[:space:]]*InputMethod=' "$sddm_installer" \
        || [[ "$(grep -c 'DisplayServer=' "$sddm_installer")" != "1" ]] \
        || ! grep -Fq 'GREETER_MODE="${INIR_SDDM_GREETER:-keep}"' "$sddm_installer"; then
    printf 'FAIL: ii-pixel theme installer overrides distro-owned SDDM greeter backend/input policy\n' >&2
    exit 1
fi
if ! grep -Fq 'Current=${THEME_NAME}' "$sddm_installer"; then
    printf 'FAIL: ii-pixel theme installer no longer configures the SDDM theme\n' >&2
    exit 1
fi
if grep -Fq '${cmd_to_pkg[$cmd]:-$cmd}' "$fedora_installer"; then
    printf 'FAIL: Fedora Doctor repair can still pass unknown command IDs directly to dnf\n' >&2
    exit 1
fi
for required in \
    '[qalc]="qalculate"' \
    '[nm-connection-editor]="nm-connection-editor"' \
    'install_awww_fedora' \
    'install_gowall_fedora' \
    'install_missioncenter_fedora' \
    'install_songrec_fedora'; do
    if ! grep -Fq "$required" "$fedora_installer"; then
        printf 'FAIL: Fedora dependency repair lost required route: %s\n' "$required" >&2
        exit 1
    fi
done
if ! grep -Fq 'dnf copr enable -y scottames/awww' "$fedora_installer" \
        || ! grep -Fq 'dnf copr enable -y achno/gowall' "$fedora_installer"; then
    printf 'FAIL: Fedora awww/Gowall no longer prefer their focused COPR packages before source fallbacks\n' >&2
    exit 1
fi
if ! grep -Fq '[[ "${OS_GROUP_ID:-unknown}" == "arch" ]]' "$runtime_root/sdata/lib/doctor.sh"; then
    printf 'FAIL: Doctor no longer scopes checkupdates to Arch\n' >&2
    exit 1
fi
if ! grep -Fq 'ocr-jpn:OCR Japanese data' "$runtime_root/sdata/lib/doctor.sh" \
        || ! grep -Fq '[ocr-jpn]="tesseract-data-jpn"' "$arch_installer" \
        || ! grep -Fq '[ocr-jpn]="tesseract-langpack-jpn"' "$fedora_installer"; then
    printf 'FAIL: Doctor/installers no longer repair missing OCR language data\n' >&2
    exit 1
fi

debian_installer="$runtime_root/sdata/dist-debian/install-deps.sh"
if ! grep -Fq 'ensure_debian_backports' "$debian_installer" \
        || ! grep -Fq 'ensure_debian_component "contrib"' "$debian_installer" \
        || ! grep -Fq 'polkitd' "$debian_installer"; then
    printf 'FAIL: Debian installer lost backports/contrib/Trixie compatibility handling\n' >&2
    exit 1
fi
# The shell is the only polkit agent: nothing installs or starts another one.
if grep -rnE --exclude-dir=pkg --exclude-dir=src --exclude='*.pkg.tar*' \
        'polkit-gnome|polkit-kde|policykit-1-gnome|mate-polkit|lxpolkit|lxqt-policykit' \
        "$runtime_root/sdata/dist-arch" "$runtime_root/sdata/dist-fedora" "$runtime_root/sdata/dist-debian" \
        "$runtime_root/sdata/dist-generic" "$runtime_root/sdata/lib/deps-map.sh" "$runtime_root/sdata/subcmd-install" \
        "$runtime_root/defaults/niri" "$runtime_root/dots/.config/niri" "$runtime_root/distro/arch" "$runtime_root/nix" >&2; then
    printf 'FAIL: an external polkit agent is installed or started beside the shell'"'"'s own\n' >&2
    exit 1
fi
if ! grep -Fq 'libpolkit-agent-1-dev' "$debian_installer" || ! grep -Fq -- '-DSERVICE_POLKIT=ON' "$debian_installer"; then
    printf 'FAIL: Debian builds Quickshell without its Polkit module\n' >&2
    exit 1
fi
if grep -Fq 'tui_info "Setting up Rust toolchain..."' "$debian_installer"; then
    printf 'FAIL: Debian installer installs Rust unconditionally instead of only for source fallbacks\n' >&2
    exit 1
fi
if ! grep -Fq '[ocr-jpn]="tesseract-ocr-jpn"' "$debian_installer"; then
    printf 'FAIL: Debian Doctor repair lost Japanese OCR language mapping\n' >&2
    exit 1
fi

# Super+Shift+S is the remembered unified snip entry point; Print remains direct.
if ! grep -Fq 'Mod+Shift+S { spawn "inir" "region" "menu"; }' "$runtime_root/defaults/niri/config.d/70-binds.kdl" \
        || [[ ! -x "$runtime_root/sdata/migrations/037-remembered-super-shift-s.sh" ]]; then
    printf 'FAIL: remembered Super+Shift+S snip flow is incomplete\n' >&2
    exit 1
fi
if grep -Fq '${cmd_to_pkg[$cmd]:-$cmd}' "$debian_installer"; then
    printf 'FAIL: Debian Doctor repair can still pass unknown command IDs directly to apt\n' >&2
    exit 1
fi
for required in \
    '[qalc]="qalc"' \
    '[nm-connection-editor]="network-manager-gnome"' \
    'io.missioncenter.MissionCenter' \
    'golang-go' \
    'cargo install --root "$SONGREC_ROOT" songrec'; do
    if ! grep -Fq "$required" "$debian_installer"; then
        printf 'FAIL: Debian dependency repair/provider route missing: %s\n' "$required" >&2
        exit 1
    fi
done

ocr_runner="$runtime_root/scripts/ocr-runner.sh"
region_selector="$runtime_root/modules/regionSelector/RegionSelection.qml"
if [[ ! -x "$ocr_runner" ]] \
        || ! grep -Fq 'property string ocrLanguage: "auto"' "$runtime_root/modules/common/Config.qml" \
        || ! grep -Fq 'scripts/ocr-runner.sh' "$region_selector"; then
    printf 'FAIL: multilingual OCR runtime/config wiring is incomplete\n' >&2
    exit 1
fi
if grep -Fq 'tesseract --list-langs |' "$region_selector"; then
    printf 'FAIL: region OCR still combines every installed Tesseract language\n' >&2
    exit 1
fi
if ! grep -Fq 'tessdata_fast/main/$lang.traineddata' "$ocr_runner" \
        || ! grep -Fq 'cdn.jsdelivr.net/gh/tesseract-ocr/tessdata_fast' "$ocr_runner" \
        || ! grep -Fq 'INIR_TESSDATA_DIR' "$ocr_runner"; then
    printf 'FAIL: OCR runtime lost user-space language provisioning fallback\n' >&2
    exit 1
fi
if grep -F 'japaneseOcrProc.command' "$region_selector" | grep -Fq 'wl-copy'; then
    printf 'FAIL: Japanese OCR stdout is still consumed by clipboard plumbing before lookup\n' >&2
    exit 1
fi
clipboard_helper="$runtime_root/scripts/clipboard-copy.sh"
if [[ ! -x "$clipboard_helper" ]] \
        || ! grep -Fq 'systemd-run --user' "$clipboard_helper" \
        || grep -R -Fq '/usr/bin/wl-copy' "$runtime_root/modules/regionSelector" \
        || grep -R -Fq 'execDetached(["wl-copy"' "$runtime_root/modules/japaneseLookup"; then
    printf 'FAIL: snipping clipboard ownership can leak wl-copy into inir.service\n' >&2
    exit 1
fi
if grep -A30 -F 'Enable AnkiConnect button' "$runtime_root/modules/settings/ToolsConfig.qml" | grep -Fq 'GridLayout {'; then
    printf 'FAIL: Anki settings reintroduced the MaterialTextField/GridLayout implicitWidth binding loop\n' >&2
    exit 1
fi
if ! grep -Fq 'anki-status' "$runtime_root/services/JapaneseDictionary.qml" \
        || ! grep -Fq 'Anki Desktop not detected' "$runtime_root/services/JapaneseDictionary.qml" \
        || ! grep -Fq 'Open Anki' "$runtime_root/modules/japaneseLookup/JapaneseLookup.qml" \
        || ! grep -Fq 'cardContent.implicitHeight + 28' "$runtime_root/modules/japaneseLookup/JapaneseLookup.qml"; then
    printf 'FAIL: Japanese lookup Anki health/footer sizing regression\n' >&2
    exit 1
fi
if ! grep -Fq 'showAdvancedOcr' "$runtime_root/modules/settings/ToolsConfig.qml" \
        || ! grep -Fq 'showAdvancedAnki' "$runtime_root/modules/settings/ToolsConfig.qml" \
        || ! grep -Fq 'Japanese study assistant' "$runtime_root/modules/settings/ToolsConfig.qml"; then
    printf 'FAIL: OCR/Japanese Settings onboarding regressed into technical-first controls\n' >&2
    exit 1
fi
sidebar_group="$runtime_root/modules/sidebarRight/BottomWidgetGroup.qml"
if grep -A90 -F '// Navigation rail' "$sidebar_group" | grep -Fq 'open_in_full' \
        || ! grep -Fq 'onRequestExpand: root.requestExpand("calendar")' "$sidebar_group" \
        || ! grep -Fq 'onRequestExpand: root.requestExpand("events")' "$sidebar_group" \
        || ! grep -Fq 'onRequestExpand: root.requestExpand("todo")' "$sidebar_group"; then
    printf 'FAIL: right-sidebar organizer expansion leaked back into the navigation rail\n' >&2
    exit 1
fi
for widget in calendar/CalendarWidget.qml events/EventsWidget.qml todo/TodoWidget.qml; do
    grep -Fq 'signal requestExpand()' "$runtime_root/modules/sidebarRight/$widget" || {
        printf 'FAIL: right-sidebar organizer widget lacks contextual expand action: %s\n' "$widget" >&2
        exit 1
    }
done

if ! grep -Fq 'japaneseLookupExpanded' "$runtime_root/modules/japaneseLookup/JapaneseLookup.qml" \
        || ! grep -Fq 'translateCurrent' "$runtime_root/modules/japaneseLookup/JapaneseLookup.qml" \
        || [[ ! -x "$runtime_root/scripts/translate-ocr.sh" ]] \
        || [[ ! -x "$runtime_root/scripts/study-decks.py" ]]; then
    printf 'FAIL: expandable Japanese lookup translation/study tools are incomplete\n' >&2
    exit 1
fi
if ! grep -Fq -- '--psm "$psm"' "$ocr_runner" \
        || ! grep -Fq 'resize 200%' "$ocr_runner"; then
    printf 'FAIL: OCR selection-aware segmentation/preprocessing regressed\n' >&2
    exit 1
fi
python3 "$runtime_root/scripts/study-decks.py" list | grep -Fq '"kaishi"' || {
    printf 'FAIL: study deck catalog is unavailable\n' >&2
    exit 1
}
for pkg in tesseract-data-rus tesseract-data-jpn tesseract-data-jpn_vert tesseract-data-chi_sim tesseract-data-chi_tra; do
    grep -Fq "$pkg" "$runtime_root/sdata/dist-arch/inir-screencapture/PKGBUILD" || {
        printf 'FAIL: Arch screencapture bundle is missing OCR language package %s\n' "$pkg" >&2
        exit 1
    }
done
for pkg in tesseract-langpack-rus tesseract-langpack-jpn tesseract-langpack-jpn_vert tesseract-langpack-chi_sim tesseract-langpack-chi_tra; do
    grep -Fq "$pkg" "$fedora_installer" || {
        printf 'FAIL: Fedora installer is missing OCR language package %s\n' "$pkg" >&2
        exit 1
    }
done
for pkg in tesseract-ocr-rus tesseract-ocr-jpn tesseract-ocr-jpn-vert tesseract-ocr-chi-sim tesseract-ocr-chi-tra; do
    grep -Fq "$pkg" "$debian_installer" || {
        printf 'FAIL: Debian installer is missing OCR language package %s\n' "$pkg" >&2
        exit 1
    }
done

jp_dictionary="$runtime_root/scripts/japanese-dictionary.py"
if [[ ! -x "$jp_dictionary" ]]; then
    printf 'FAIL: Japanese dictionary backend is missing or not executable\n' >&2
    exit 1
fi
if ! grep -Fq 'singleton JapaneseDictionary 1.0 JapaneseDictionary.qml' "$runtime_root/services/qmldir" \
        || ! grep -Fq 'modules/japaneseLookup/JapaneseLookup.qml' "$runtime_root/shell.qml" \
        || ! grep -Fq 'JapaneseDictionary.lookupText' "$runtime_root/modules/regionSelector/RegionSelection.qml" \
        || ! grep -Fq 'Install Japanese dictionary (~37 MB)' "$runtime_root/modules/settings/ToolsConfig.qml"; then
    printf 'FAIL: Japanese OCR dictionary UI/runtime wiring is incomplete\n' >&2
    exit 1
fi
jp_installer="$runtime_root/scripts/install-japanese-dictionary.sh"
if [[ ! -x "$jp_installer" ]] \
        || ! grep -Fq 'releases/latest/download/jitendex-yomitan.zip' "$jp_installer" \
        || ! grep -Fq 'JapaneseDictionary.installRecommended()' "$runtime_root/modules/japaneseLookup/JapaneseLookup.qml"; then
    printf 'FAIL: one-click Jitendex onboarding is incomplete\n' >&2
    exit 1
fi
python3 - "$jp_dictionary" <<'PYTEST'
import json, subprocess, sys, tempfile, zipfile
from pathlib import Path

script = Path(sys.argv[1])
with tempfile.TemporaryDirectory() as td:
    root = Path(td)
    archive = root / "test.zip"
    db = root / "dictionary.sqlite3"
    with zipfile.ZipFile(archive, "w") as z:
        z.writestr("index.json", json.dumps({"title": "iNiR Test", "revision": "1", "format": 3}))
        z.writestr("term_bank_1.json", json.dumps([
            ["食べる", "たべる", "v1", "v1", 10, ["to eat"], 1, "common"],
            ["高い", "たかい", "adj-i", "adj-i", 8, [{"type":"structured-content","content":{"tag":"ul","data":{"content":"glossary"},"content":{"tag":"li","content":"high; expensive"}}}], 2, "common"],
            ["またね", "またね", "", "", 200, ["bye; see you later"], 3, "common"],
            ["ま", "ま", "", "", 97, ["just; now"], 4, ""],
            ["幾ら", "いくら", "", "", 200, ["how much"], 5, "common"],
            ["いくら", "いくら", "", "", 99, ["salted salmon roe"], 6, ""],
            ["何処", "どこ", "", "", 200, ["where"], 7, "common"]
        ], ensure_ascii=False))
        z.writestr("term_meta_bank_1.json", json.dumps([["食べる", "pitch", {"reading": "たべる", "pitches": [{"position": 2}]}]], ensure_ascii=False))
        z.writestr("kanji_bank_1.json", json.dumps([["食", "ショク", "た.べる", "", ["eat"], {}]], ensure_ascii=False))
    def run(*args):
        proc = subprocess.run([sys.executable, str(script), "--db", str(db), *args], check=True, text=True, capture_output=True)
        return json.loads(proc.stdout)
    assert run("import", str(archive))["terms"] == 7
    scanned = run("scan", "食べる猫")
    assert scanned["matched"] == "食べる"
    assert scanned["metadata"]["pitch"][0]["data"]["pitches"][0]["position"] == 2
    polite = run("scan-smart", "食べました")
    assert polite["matched"] == "食べる" and polite["surface"] == "食べました"
    assert polite["reading"] == "たべる" and polite["romaji"] == "taberu"
    adjective = run("scan-smart", "高かった")
    assert adjective["matched"] == "高い"
    assert adjective["terms"][0]["displayDefinitions"] == ["high; expensive"]
    phrase = run("scan-smart", "• またね (Mata ne) — See you later")
    assert phrase["surface"] == "またね" and phrase["terms"][0]["displayDefinitions"][0].startswith("bye")
    spaced_phrase = run("scan-smart", "• ま た ね (Mata ne) — See you later")
    assert spaced_phrase["surface"] == "またね"
    price = run("scan-smart", "いくらですか (Ikura desu ka)")
    assert price["surface"] == "いくら" and price["terms"][0]["expression"] == "幾ら"
    where = run("scan-smart", "どこですか")
    assert where["surface"] == "どこ" and where["terms"][0]["expression"] == "何処"
    assert run("kanji", "食")["kanji"][0]["meanings"] == ["eat"]
PYTEST

python_setup_owners=$(grep -l 'v install-python-packages' \
    "$runtime_root"/sdata/dist-*/install-deps.sh \
    "$runtime_root/sdata/subcmd-install/3.files.sh" 2>/dev/null || true)
if [[ "$python_setup_owners" != "$runtime_root/sdata/subcmd-install/3.files.sh" ]]; then
    printf 'FAIL: Python environment setup has more than one install owner:\n%s\n' "$python_setup_owners" >&2
    exit 1
fi

step "YT Music distribution contract"
for requirements in "$runtime_root/sdata/uv/requirements.in" "$runtime_root/sdata/uv/requirements.txt"; do
    grep -Fq 'ytmusicapi>=1.12.0' "$requirements" || {
        printf 'FAIL: managed Python runtime does not own ytmusicapi in %s\n' "$requirements" >&2
        exit 1
    }
    grep -Fq 'yt-dlp[default,secretstorage]' "$requirements" || {
        printf 'FAIL: managed Python runtime lacks Chromium cookie-loader support in %s\n' "$requirements" >&2
        exit 1
    }
done

grep -Fq 'v ensure-ytmusic-js-runtime' "$runtime_root/sdata/subcmd-install/3.files.sh" || {
    printf 'FAIL: fresh install does not provision the YT Music JS runtime\n' >&2
    exit 1
}
grep -Fq 'ensure-ytmusic-js-runtime' "$runtime_root/setup" || {
    printf 'FAIL: update path does not repair the YT Music JS runtime\n' >&2
    exit 1
}
grep -Fq 'YT Music JS runtime unavailable' "$runtime_root/sdata/lib/doctor.sh" || {
    printf 'FAIL: doctor does not validate/repair the YT Music JS runtime\n' >&2
    exit 1
}

if grep -Fq 'python3-ytmusicapi' "$runtime_root/sdata/dist-fedora/install-deps.sh" \
        || grep -Fq 'python3-ytmusicapi' "$runtime_root/sdata/dist-debian/install-deps.sh"; then
    printf 'FAIL: setup-managed Fedora/Debian still depend on a distro ytmusicapi package\n' >&2
    exit 1
fi
for dependency in deno yt-dlp-ejs; do
    grep -Eq "^[[:space:]]*${dependency}[[:space:]]*$" "$runtime_root/sdata/dist-arch/inir-audio/PKGBUILD" || {
        printf 'FAIL: Arch audio bundle lacks %s\n' "$dependency" >&2
        exit 1
    }
done
for dependency in deno python-ytmusicapi yt-dlp yt-dlp-ejs; do
    grep -Eq "^[[:space:]]*depends = ${dependency}$" "$runtime_root/distro/arch/inir-meta/.SRCINFO" || {
        printf 'FAIL: packaged Arch meta lacks %s\n' "$dependency" >&2
        exit 1
    }
done
if ! grep -Fq 'ps.ytmusicapi' "$runtime_root/nix/package.nix" \
        || ! grep -Fq 'ps.yt-dlp' "$runtime_root/nix/package.nix" \
        || ! grep -Fq 'ps.secretstorage' "$runtime_root/nix/package.nix" \
        || ! grep -Eq '^[[:space:]]+deno$' "$runtime_root/nix/package.nix" \
        || ! grep -Eq '^[[:space:]]+yt-dlp$' "$runtime_root/nix/package.nix"; then
    printf 'FAIL: Nix runtime does not provide the complete YT Music runtime\n' >&2
    exit 1
fi

ytmusic_service="$runtime_root/services/YtMusic.qml"
if grep -Eq '/usr/bin/(yt-dlp|mpv)|js-runtimes=node' "$ytmusic_service" \
        || ! grep -Fq '"--js-runtimes", "deno"' "$ytmusic_service" \
        || ! grep -Fq 'command -v deno' "$ytmusic_service"; then
    printf 'FAIL: YT Music runtime still assumes Arch paths or the obsolete Node JS contract\n' >&2
    exit 1
fi
grep -Fq 'pkg="${pkg%%[*}"' "$runtime_root/sdata/lib/doctor.sh" || {
    printf 'FAIL: doctor does not normalize Python requirement extras\n' >&2
    exit 1
}
grep -Fq 'yt-dlp-runtime.sh' "$ytmusic_service" || {
    printf 'FAIL: YT Music does not select the managed yt-dlp runtime\n' >&2
    exit 1
}
if grep -Fq 'Install python-ytmusicapi' "$runtime_root/modules/sidebarLeft/innertune/InnerTuneHome.qml" \
        || grep -Fq 'Reconnect account on launch' "$runtime_root/modules/settings/SidebarsConfig.qml"; then
    printf 'FAIL: YT Music UI still exposes manual Python install or implicit browser reconnect\n' >&2
    exit 1
fi

python3 - "$runtime_root/scripts/ytmusic_auth.py" <<'PYTEST'
import hashlib
import importlib.util
import pathlib
import sqlite3
import sys
import tempfile
import os

script = pathlib.Path(sys.argv[1])
spec = importlib.util.spec_from_file_location("inir_ytmusic_auth_test", script)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

assert "~/.config/mozilla/firefox" in module.FIREFOX_FORKS["firefox"]

with tempfile.TemporaryDirectory(prefix="inir-yt-cookie-fixture-") as tmp:
    profile = pathlib.Path(tmp) / "profile"
    profile.mkdir()
    database = profile / "cookies.sqlite"
    con = sqlite3.connect(database)
    con.execute(
        "CREATE TABLE moz_cookies (host TEXT, path TEXT, isSecure INTEGER, expiry INTEGER, "
        "name TEXT, value TEXT, originAttributes TEXT)"
    )
    con.executemany(
        "INSERT INTO moz_cookies VALUES (?, ?, ?, ?, ?, ?, ?)",
        [
            (".youtube.com", "/", 1, 4102444800, "SAPISID", "fixture-sapisid", ""),
            (".youtube.com", "/", 1, 4102444800, "LOGIN_INFO", "fixture-login", ""),
            (".youtube.com", "/", 1, 4102444800, "__Secure-3PSID", "fixture-psid", ""),
        ],
    )
    con.commit()
    con.close()

    before = hashlib.sha256(database.read_bytes()).hexdigest()
    output = pathlib.Path(tmp) / "yt-cookies.txt"
    ok, error = module.extract_firefox_direct(str(profile), str(output))
    after = hashlib.sha256(database.read_bytes()).hexdigest()
    assert ok, error
    assert before == after, "browser cookie DB was modified"
    exported = output.read_text()
    assert "SAPISID" in exported and "LOGIN_INFO" in exported
    assert output.stat().st_mode & 0o777 == 0o600

with tempfile.TemporaryDirectory(prefix="inir-chromium-profile-fixture-") as tmp:
    previous_home = os.environ.get("HOME")
    os.environ["HOME"] = tmp
    try:
        base = pathlib.Path(tmp) / ".config/google-chrome"
        profile = base / "Profile 7"
        profile.mkdir(parents=True)
        (profile / "Cookies").touch()
        (base / "Local State").write_text('{"profile":{"last_used":"Profile 7"}}')
        assert module.find_chrome_profile("chrome") == str(profile)
    finally:
        if previous_home is None:
            os.environ.pop("HOME", None)
        else:
            os.environ["HOME"] = previous_home
PYTEST

python3 - "$runtime_root/scripts/innertube.py" <<'PYTEST'
import importlib.util
import pathlib
import tempfile
import sys

script = pathlib.Path(sys.argv[1])
spec = importlib.util.spec_from_file_location("inir_innertube_transaction_test", script)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

with tempfile.TemporaryDirectory(prefix="inir-yt-transaction-fixture-") as tmp:
    module._CFG_DIR = tmp
    module.YTCOOKIE_PATH = str(pathlib.Path(tmp) / "yt-cookies.txt")
    canonical = pathlib.Path(module.YTCOOKIE_PATH)
    canonical.write_text("previous-valid-session")
    canonical.chmod(0o600)

    probe_called = False
    module._run_auth_helper = lambda args, candidate: False
    def should_not_probe(*args, **kwargs):
        nonlocal_probe[0] = True
        return True, "wrong", ""
    nonlocal_probe = [False]
    module._account_probe = should_not_probe
    assert module._extract_and_probe("signed-out", attempts=1) == (False, "", "")
    assert not nonlocal_probe[0]
    assert canonical.read_text() == "previous-valid-session"

    def extract_candidate(args, candidate):
        pathlib.Path(candidate).write_text("candidate-session")
        pathlib.Path(candidate).chmod(0o600)
        return True
    def probe_candidate(path, allow_oauth=True):
        assert path != module.YTCOOKIE_PATH
        assert allow_oauth is False
        assert pathlib.Path(path).read_text() == "candidate-session"
        return True, "Fixture account", ""
    module._run_auth_helper = extract_candidate
    module._account_probe = probe_candidate
    assert module._extract_and_probe("signed-in", attempts=1)[0]
    assert canonical.read_text() == "candidate-session"
    assert canonical.stat().st_mode & 0o777 == 0o600
PYTEST

step "runtime payload manifests"
while IFS= read -r runtime_file; do
    [[ -n "$runtime_file" ]] || continue
    [[ -f "$runtime_root/$runtime_file" ]]
done < "$runtime_root/sdata/runtime-root-files.txt"

while IFS= read -r runtime_dir; do
    [[ -n "$runtime_dir" ]] || continue
    [[ -d "$runtime_root/$runtime_dir" ]]
done < "$runtime_root/sdata/runtime-payload-dirs.txt"

snapshot_lib="$runtime_root/sdata/lib/snapshots.sh"
if ! grep -Fq 'quickshell/user/desktop-items.json' "$snapshot_lib" \
        || ! grep -Fq 'desktop-items.json' "$snapshot_lib"; then
    printf 'FAIL: managed desktop items are absent from update snapshots\n' >&2
    exit 1
fi

step "mascot runtime manifest"
mascot_manifest="$runtime_root/assets/images/mascot/manifest.json"
if [[ ! -f "$mascot_manifest" ]]; then
    printf 'FAIL: mascot runtime manifest is missing: %s\n' "$mascot_manifest" >&2
    exit 1
fi
python3 -m json.tool "$mascot_manifest" >/dev/null
if ! grep -qx 'assets' "$runtime_root/sdata/runtime-payload-dirs.txt"; then
    printf 'FAIL: assets is absent from runtime-payload-dirs.txt\n' >&2
    exit 1
fi
step "mascot pack install and repair"
bash "$runtime_root/scripts/test-mascot-pack-flow.sh"

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

    step "version consistency"
    version="$(cat "$runtime_root/VERSION")"
    for pkg in inir-shell inir-meta; do
        pkg_ver="$(grep -m1 '^pkgver=' "$runtime_root/distro/arch/$pkg/PKGBUILD" | cut -d= -f2)"
        if [[ "$pkg_ver" != "$version" ]]; then
            printf 'FAIL: %s pkgver=%s != VERSION=%s\n' "$pkg" "$pkg_ver" "$version" >&2
            exit 1
        fi
        srcinfo_ver="$(awk '/^[[:space:]]*pkgver = / {print $3; exit}' "$runtime_root/distro/arch/$pkg/.SRCINFO")"
        if [[ "$srcinfo_ver" != "$version" ]]; then
            printf 'FAIL: %s .SRCINFO pkgver=%s != VERSION=%s\n' "$pkg" "$srcinfo_ver" "$version" >&2
            exit 1
        fi
    done

    deps_ver="$(grep -m1 '^pkgver=' "$runtime_root/sdata/dist-arch/inir-deps/PKGBUILD" | cut -d= -f2)"
    if [[ "$deps_ver" != "$version" ]]; then
        printf 'FAIL: inir-deps pkgver=%s != VERSION=%s\n' "$deps_ver" "$version" >&2
        exit 1
    fi

    if ! grep -Fq "iNiR/${version} (https://github.com/snowarch/inir)" "$runtime_root/scripts/lyrics/lyrics.py"; then
        printf 'FAIL: lyrics User-Agent does not match VERSION=%s\n' "$version" >&2
        exit 1
    fi

    if ! grep -Fq "version-${version}-blue" "$runtime_root/README.md"; then
        printf 'FAIL: README release badge does not match VERSION=%s\n' "$version" >&2
        exit 1
    fi
fi

step "release polish guards"
config_qml="$runtime_root/modules/common/Config.qml"
game_mode_qml="$runtime_root/services/GameMode.qml"
niri_service_qml="$runtime_root/services/NiriService.qml"
screen_corners_qml="$runtime_root/modules/screenCorners/ScreenCorners.qml"
dock_apps_qml="$runtime_root/modules/dock/DockApps.qml"
dock_app_button_qml="$runtime_root/modules/dock/DockAppButton.qml"
dock_context_menu_qml="$runtime_root/modules/dock/DockContextMenu.qml"
dock_preview_qml="$runtime_root/modules/dock/DockPreview.qml"
dock_window_preview_qml="$runtime_root/modules/dock/DockWindowPreview.qml"
cava_wrapper="$runtime_root/modules/common/widgets/CavaProcess.qml"
visualizer_layer="$runtime_root/modules/common/widgets/AudioVisualizerLayer.qml"
pill_music_bars="$runtime_root/modules/pill/MusicBars.qml"
quick_config="$runtime_root/modules/settings/QuickConfig.qml"
waffle_general="$runtime_root/modules/waffle/settings/pages/WGeneralPage.qml"

mascot_pack_nix="$runtime_root/nix/mascot-pack.nix"
mascot_package_nix="$runtime_root/nix/mascot-package.nix"
mascot_tag="$(sed -n 's#.*releases/download/\(v[0-9][^/]*\)/inir-mascot-pack\.tar\.gz.*#\1#p' "$mascot_pack_nix" | head -n1)"
mascot_version="$(sed -n 's/^[[:space:]]*version = "\([^"]*\)";.*/\1/p' "$mascot_package_nix" | head -n1)"
if [[ -z "$mascot_tag" || -z "$mascot_version" || "$mascot_tag" != "v${mascot_version}" ]]; then
    printf 'FAIL: Nix mascot package version (%s) does not match pinned release tag (%s)\n' "$mascot_version" "$mascot_tag" >&2
    exit 1
fi
if grep -Eq '354 poses|354 poses/animations|~32 MiB' "$runtime_root/setup" "$runtime_root/sdata/lib/extras.sh" "$runtime_root/docs/INSTALL.md" "$mascot_package_nix"; then
    printf 'FAIL: mascot install UX contains a stale hard-coded pack size/count\n' >&2
    exit 1
fi
if ! grep -Fq 'property bool disableVisualizers: true' "$config_qml" \
        || ! grep -Fq 'readonly property bool disableVisualizers:' "$game_mode_qml" \
        || ! grep -Fq 'readonly property bool visualizersSuppressed: active && disableVisualizers' "$game_mode_qml" \
        || ! grep -Fq '!GameMode.visualizersSuppressed' "$cava_wrapper" \
        || ! grep -Fq '!GameMode.visualizersSuppressed' "$visualizer_layer" \
        || ! grep -Fq 'CavaProcess {' "$pill_music_bars" \
        || ! grep -Fq 'gameMode.disableVisualizers' "$quick_config" \
        || ! grep -Fq 'gameMode.disableVisualizers' "$waffle_general"; then
    printf 'FAIL: Game Mode does not suppress shared Cava/render consumers through Settings policy\n' >&2
    exit 1
fi
if ! grep -Fq 'readonly property var liveWindows: _windowsDirty ? _pendingWindows : windows' "$niri_service_qml" \
        || ! grep -Fq 'const windows = NiriService.liveWindows' "$game_mode_qml" \
        || ! grep -Fq 'WlrLayershell.layer: WlrLayer.Top' "$screen_corners_qml" \
        || ! grep -Fq 'return GameMode.manuallyActivated' "$screen_corners_qml" \
        || ! grep -Fq 'cornerPanelWindow.orbitHotCornerBlocked()' "$screen_corners_qml"; then
    printf 'FAIL: Orbit hot corner can regress above fullscreen or manual Game Mode\n' >&2
    exit 1
fi
if ! grep -Fq 'readonly property bool contextMenuOpen: contextMenuPending || dockContextMenu.active' "$dock_apps_qml" \
        || ! grep -Fq 'hoverPreview === false || contextMenuOpen || dragActive' "$dock_apps_qml" \
        || ! grep -Fq 'Qt.callLater(() => root._openPendingContextMenu())' "$dock_apps_qml" \
        || ! grep -Fq 'property Item contextMenuSourceButton: null' "$dock_apps_qml" \
        || ! grep -Fq 'root.appListRoot.requestContextMenu(root, root.buildContextMenuModel())' "$dock_app_button_qml" \
        || grep -Fq 'closeAllContextMenus' "$dock_apps_qml" "$dock_app_button_qml" \
        || ! grep -Fq 'closeOnHoverLost: true' "$dock_context_menu_qml" \
        || ! grep -Fq 'closeOnHoverLostAfterEntered: true' "$dock_context_menu_qml" \
        || ! grep -Fq 'closeOnHoverLostDelay: 650' "$dock_context_menu_qml" \
        || ! grep -Fq 'revealDistance: 8' "$dock_context_menu_qml" \
        || ! grep -Fq 'grabFocus: false' "$dock_preview_qml" \
        || grep -Fq 'anchor.window: root.parentWindow' "$dock_apps_qml" \
        || ! grep -Fq 'WindowPreviewService.initialize()' "$dock_preview_qml" \
        || ! grep -Fq 'retainWhileLoading: true' "$dock_window_preview_qml" \
        || grep -Fq 'id: fallbackIcon' "$dock_window_preview_qml"; then
    printf 'FAIL: dock popup ownership, preview handoff, or thumbnail continuity regressed\n' >&2
    exit 1
fi
if grep -RIl 'CavaService\.subscribe' "$runtime_root/modules" \
        | grep -Fv '/modules/common/widgets/CavaProcess.qml' >/dev/null; then
    printf 'FAIL: a visualizer bypasses the Game Mode-aware shared CavaProcess owner\n' >&2
    exit 1
fi
if ! grep -Fq 'property var _pendingMutations: ({})' "$config_qml" \
        || ! grep -Fq 'property bool _rebasingExternalChange: false' "$config_qml" \
        || ! grep -Fq 'root._reapplyPendingMutations();' "$config_qml" \
        || ! sed -n '/function flushWrites()/,/^    }/p' "$config_qml" | grep -Fq 'root._pendingMutations = ({})' \
        || ! grep -Fq 'fileWriteTimer.running || Object.keys(root._pendingMutations ?? {}).length > 0' "$config_qml"; then
    printf 'FAIL: cross-process Config writes can regress to stale full-file mirror overwrites\n' >&2
    exit 1
fi
if ! grep -Fq 'property list<string> blockedApps: []' "$config_qml" \
        || grep -Fq 'property list<string> allowedApps:' "$config_qml" \
        || ! grep -Fq 'cfgBlockedAppsJson' "$runtime_root/services/deferred/CavaService.qml" \
        || ! grep -Fq -- '--blocked-apps-json' "$runtime_root/scripts/cava/resolve_audio_source.py" \
        || grep -Fq -- '--allowed-apps-json' "$runtime_root/scripts/cava/resolve_audio_source.py" \
        || [[ ! -x "$runtime_root/sdata/migrations/041-visualizer-app-filter-semantics.sh" ]]; then
    printf 'FAIL: visualizer App Filters can regress from exclusion semantics back to an allowlist\n' >&2
    exit 1
fi
if ! grep -Fq 'message="$(_tui_expand_newlines "${3:-}")"' "$runtime_root/sdata/lib/tui.sh"; then
    printf 'FAIL: TUI alerts can regress to rendering literal \n sequences\n' >&2
    exit 1
fi
pixel_clock="$runtime_root/modules/background/widgets/clock/PixelClock.qml"
if grep -Eq 'OpacityMask|maskEnabled|maskSource|StyledDropShadow' "$pixel_clock" \
        || ! grep -Fq 'renderType: Text.QtRendering' "$pixel_clock" \
        || ! grep -Fq 'style: root.showShadow ? Text.Raised : Text.Normal' "$pixel_clock" \
        || ! grep -Fq 'root.width * 0.46' "$pixel_clock" \
        || ! grep -Fq 'Compose interlocking digits directly' "$pixel_clock"; then
    printf 'FAIL: Pixel Clock can regress to masked/resampled chromatic edges or shifted geometry\n' >&2
    exit 1
fi

media_overlay="$runtime_root/modules/mediaControls/components/MediaVisualizerOverlay.qml"
media_edge="$runtime_root/modules/mediaControls/components/MediaOrganicEdgeAura.qml"
audio_layer="$runtime_root/modules/common/widgets/AudioVisualizerLayer.qml"
media_widget="$runtime_root/modules/background/widgets/mediaControls/MediaControlsWidget.qml"
if ! grep -Fq 'barsOrigin: root.visualizerPosition === "top" ? "top"' "$media_overlay" \
        || ! grep -Fq 'root.visualizerPosition === "fill" ? "mirror" : "bottom"' "$media_overlay" \
        || ! grep -Fq 'visible: root.visualizerPosition !== "none" && !root.organic' "$media_overlay" \
        || grep -Fq 'organicPresentationMode' "$media_overlay" \
        || [[ ! -f "$media_edge" ]] \
        || ! grep -Fq 'organicPresentationMode: 2.0' "$media_edge" \
        || ! grep -Fq 'organicEdgeDirections: Qt.vector4d(1, 1, 1, 1)' "$media_edge" \
        || grep -Fq 'organicDirection' "$media_edge" \
        || ! grep -Fq 'MediaOrganicEdgeAura {' "$media_widget" \
        || ! grep -Fq 'z: -1' "$media_widget" \
        || ! grep -Fq 'StyledRectangularShadow {' "$media_widget" \
        || ! grep -Fq 'z: -2' "$media_widget" \
        || grep -Fq 'maxVisualizerValue: 1000' "$runtime_root/modules/mediaControls/presets/FullPlayer.qml"; then
    printf 'FAIL: Media Player visualizers can regress to floating Wave/legacy normalization or in-card Organic\n' >&2
    exit 1
fi
if [[ "$(grep -Fc 'property bool organicStretchToHost' "$audio_layer")" -ne 1 ]] \
        || [[ "$(grep -Fc 'property real organicHollowAmount' "$audio_layer")" -ne 1 ]] \
        || ! grep -Fq 'presentationMode: root.organicPresentationMode' "$audio_layer"; then
    printf 'FAIL: shared audio visualizer properties are duplicated or missing\n' >&2
    exit 1
fi
for media_preset in Full Compact Minimal AlbumArt Visualizer Classic Lyrics LyricsSplit ExpandingLyrics; do
    preset_file="$runtime_root/modules/mediaControls/presets/${media_preset}Player.qml"
    if ! grep -Fq 'MediaVisualizerOverlay {' "$preset_file" \
            || ! grep -Fq 'root.vizType === "organic" && root.vizPosition !== "none"' "$preset_file" \
            || grep -Fq 'maxVisualizerValue: 1000' "$preset_file"; then
        printf 'FAIL: media preset %s is not on the shared adaptive visualizer path\n' "$media_preset" >&2
        exit 1
    fi
done

organic_shader="$runtime_root/modules/common/widgets/OrganicAudioBlob.frag"
organic_blob="$runtime_root/modules/common/widgets/OrganicAudioBlob.qml"
visualizer_widget="$runtime_root/modules/background/widgets/visualizer/VisualizerWidget.qml"
visualizer_settings="$runtime_root/modules/settings/DesktopWidgetsConfig.qml"
bar_content="$runtime_root/modules/bar/BarContent.qml"
bar_group="$runtime_root/modules/bar/BarGroup.qml"
m3_bar_content="$runtime_root/modules/barM3/BarContent.qml"
pill_spectrum="$runtime_root/modules/pill/PillSpectrumWings.qml"
vertical_bar_content="$runtime_root/modules/verticalBar/VerticalBarContent.qml"
if ! grep -Fq 'bool cardEdgeMode = ubuf.presentationMode > 1.5 && ubuf.presentationMode < 2.5' "$organic_shader" \
        || ! grep -Fq 'bool screenEdgeMode = ubuf.presentationMode >= 2.5' "$organic_shader" \
        || ! grep -Fq 'bool edgeMode = cardEdgeMode || screenEdgeMode' "$organic_shader" \
        || ! grep -Fq '} else if (screenEdgeMode) {' "$organic_shader" \
        || ! grep -Fq 'float edge = clamp(ubuf.screenEdge, 0.0, 3.0)' "$organic_shader" \
        || ! grep -Fq 'edgeDirections' "$organic_shader" \
        || ! grep -Fq 'edgeReachHalf' "$organic_shader" \
        || ! grep -Fq 'float edgeDistanceNormalized' "$organic_shader" \
        || ! grep -Fq 'float edgeRadialSpan = max(0.18, 0.94 - ubuf.edgeBaseRadius)' "$organic_shader" \
        || ! grep -Fq 'float edgeCornerRadius;' "$organic_shader" \
        || ! grep -Fq 'float baseRadius;' "$organic_shader" \
        || ! grep -Fq 'ubuf.baseRadius + breath + pulsePush' "$organic_shader" \
        || ! grep -Fq 'vec2 perimeterDirection = vec2(' "$organic_shader" \
        || grep -Fq 'bool verticalSide = dx < dy' "$organic_shader" \
        || grep -Fq 'float perimeterPhase' "$organic_shader" \
        || ! grep -Fq 'float r = edgeMode' "$organic_shader" \
        || ! grep -Fq 'presentationMask * sourceAlpha' "$organic_shader" \
        || ! grep -Fq 'outsideMask = smoothstep(-perimeterAA, perimeterAA, cardDistance)' "$organic_shader" \
        || [[ "$(grep -Fc 'fragColor = vec4' "$organic_shader")" -ne 1 ]] \
        || grep -Fq 'smoothstep(-0.012' "$organic_shader" \
        || grep -Fq 'float edgeExtent' "$organic_shader" \
        || grep -Fq 'float extrusion' "$organic_shader" \
        || ! grep -Fq 'geometryMargin: root.reach * 1.08' "$media_edge" \
        || ! grep -Fq 'renderMargin: root.geometryMargin + root.renderPadding' "$media_edge" \
        || ! grep -Fq 'organicOverscan: 1.0' "$media_edge" \
        || ! grep -Fq 'organicEdgeReachHalf:' "$media_edge" \
        || ! grep -Fq 'organicEdgeCornerRadius: root.cardRadius * 2' "$media_edge" \
        || ! grep -Fq 'root.width + root.geometryMargin * 2' "$media_edge" \
        || ! grep -Fq 'root.audioActive ? root.visualizerPoints : root.silentPoints' "$media_edge" \
        || ! grep -Fq 'root.paletteMode === "player"' "$media_edge" \
        || ! grep -Fq 'root.paletteMode === "accent"' "$media_edge" \
        || ! grep -Fq 'root.albumPalette.length > 0' "$media_edge" \
        || ! grep -Fq 'background.widgets.mediaControls.organicSensitivity' "$media_edge" \
        || ! grep -Fq 'background.widgets.mediaControls.organicMotionSpeed' "$media_edge" \
        || ! grep -Fq 'background.widgets.mediaControls.organicGlow' "$media_edge" \
        || ! grep -Fq 'background.widgets.mediaControls.organicRange' "$media_edge" \
        || grep -Fq 'background.widgets.mediaControls.visualizerRange' "$media_edge" \
        || grep -Fq 'background.widgets.visualizer.' "$media_edge" \
        || grep -Fq 'background.widgets.visualizer.organic' "$media_widget" \
        || ! grep -Fq 'property bool organicEdgeAura: false' "$audio_layer" \
        || ! grep -Fq 'component EdgeOrganicField: Item' "$audio_layer" \
        || ! grep -Fq 'presentationMode: 2.0' "$audio_layer" \
        || ! grep -Fq 'root.clipSegments?.length' "$audio_layer" \
        || ! grep -Fq 'Math.min(64.0, width / Math.max(1, height))' "$organic_blob" \
        || ! grep -Fq 'organicEdgeAura: root.barSpectrumOrganicEdgeAura' "$bar_content" \
        || ! grep -Fq 'organicEdgeAura: root.spectrumOrganicEdgeAura' "$bar_group" \
        || ! grep -Fq 'organicEdgeAura: root.spectrumOrganicEdgeAura' "$m3_bar_content" \
        || ! grep -Fq 'id: organicPillAura' "$pill_spectrum" \
        || ! grep -Fq 'organicEdgeAura: root.barSpectrumOrganicEdgeAura' "$vertical_bar_content" \
        || ! grep -Fq 'organicAuraAllowance' "$runtime_root/modules/bar/Bar.qml" \
        || ! grep -Fq 'organicAuraAllowance' "$runtime_root/modules/barM3/M3Bar.qml" \
        || ! grep -Fq 'organicAuraAllowance' "$runtime_root/modules/verticalBar/VerticalBar.qml" \
        || grep -Fq 'bool lineMode' "$organic_shader" \
        || grep -Fq 'float linearSpectrum(' "$organic_shader" \
        || ! grep -Fq 'background.widgets.mediaControls.organicSensitivity' "$visualizer_settings" \
        || ! grep -Fq 'background.widgets.mediaControls.organicPulse' "$visualizer_settings" \
        || ! grep -Fq 'background.widgets.mediaControls.organicGlow' "$visualizer_settings" \
        || ! grep -Fq 'background.widgets.mediaControls.organicRange' "$visualizer_settings" \
        || ! grep -Fq 'component VizSlider: WidgetQuickSlider' "$media_widget" \
        || ! grep -Fq 'key: "visualizerOpacity"' "$media_widget" \
        || ! grep -Fq 'key: "visualizerRange"' "$media_widget" \
        || ! grep -Fq 'key: "visualizerSmoothing"' "$media_widget" \
        || ! grep -Fq 'key: "visualizerBarCount"' "$media_widget" \
        || ! grep -Fq 'vizPath + "visualizerFrequencyProfile"' "$media_widget" \
        || ! grep -Fq 'key: "visualizerAccentStrength"' "$media_widget" \
        || ! grep -Fq 'organicCoverUnderlap' "$visualizer_widget" \
        || grep -Fq 'organicInnerGap' "$visualizer_widget" \
        || ! grep -Fq 'background.widgets.visualizer.organicCoverSize' "$visualizer_widget" \
        || ! grep -Fq 'background.widgets.visualizer.organicRange' "$visualizer_widget" \
        || ! grep -Fq 'organicBaseRadius: root.organicBaseRadius' "$visualizer_widget" \
        || ! grep -Fq 'root.organicCoverSize / root.organicRenderOverscan + 0.078' "$visualizer_widget" \
        || ! grep -Fq '_organicArtIdentity' "$visualizer_widget" \
        || ! grep -Fq '?inir_art=' "$visualizer_widget" \
        || ! grep -Fq '_organicSilentPoints' "$visualizer_widget" \
        || ! grep -Fq '? root._organicPresent' "$visualizer_widget" \
        || ! grep -Fq 'root.paletteMode === "album"' "$visualizer_widget" \
        || ! grep -Fq 'id: albumArtworkQuantizer' "$visualizer_widget" \
        || ! grep -Fq 'organicSensitivitySetting <= 0.4' "$visualizer_widget" \
        || ! grep -Fq 'title: Translation.tr("Smoothing"); key: "smoothing"' "$visualizer_widget" \
        || ! grep -Fq 'background.widgets.visualizer.smoothing' "$visualizer_widget" \
        || grep -Fq 'background.widgets.mediaControls.' "$visualizer_widget" \
        || ! grep -Fq 'Idle motion' "$visualizer_settings"; then
    printf 'FAIL: Organic visualizer can regress to in-card media geometry or lose cover/motion controls\n' >&2
    exit 1
fi

nightlight_service="$runtime_root/services/Hyprsunset.qml"
if ! grep -Fq 'inir-wlsunset.service' "$nightlight_service" \
        || grep -Fq 'Quickshell.execDetached(["/usr/bin/wlsunset"' "$nightlight_service"; then
    printf 'FAIL: Niri night light can regress to leaking wlsunset inside inir.service\n' >&2
    exit 1
fi

audio_layer="$runtime_root/modules/common/widgets/AudioVisualizerLayer.qml"
media_layer="$runtime_root/modules/mediaControls/components/MediaVisualizerOverlay.qml"
if [[ ! -f "$audio_layer" || ! -f "$media_layer" ]] \
        || ! grep -Fq 'CavaTheme.visualizerColors' "$audio_layer" \
        || ! grep -Fq 'CavaService.normalizationCeiling' "$media_layer" \
        || ! grep -Fq 'visualizerType: root.visualizerType' "$media_layer" \
        || grep -R -Eq 'WaveVisualizer|CavaVisualizer|maxVisualizerValue: 1000' \
            "$runtime_root/modules/mediaControls/presets"; then
    printf 'FAIL: desktop media visualizers are no longer sharing the Cava/Organic renderer contract\n' >&2
    exit 1
fi
organic_qsb="$runtime_root/modules/common/widgets/OrganicAudioBlob.frag.qsb"
if [[ ! -s "$organic_qsb" ]] \
        || ! grep -Fq 'property real pulseStrength' "$runtime_root/modules/common/widgets/OrganicAudioBlob.qml" \
        || ! grep -Fq 'ubuf.spin / TAU' "$runtime_root/modules/common/widgets/OrganicAudioBlob.frag" \
        || grep -Fq 'ubuf.phase * 0.035' "$runtime_root/modules/common/widgets/OrganicAudioBlob.frag"; then
    printf 'FAIL: Organic visualizer pulse renderer/shader asset is missing\n' >&2
    exit 1
fi
qsb_tool="$(command -v qsb 2>/dev/null || true)"
if [[ -z "$qsb_tool" ]]; then
    for candidate in /usr/lib/qt6/bin/qsb /usr/lib64/qt6/bin/qsb; do
        if [[ -x "$candidate" ]]; then
            qsb_tool="$candidate"
            break
        fi
    done
fi
if [[ -n "$qsb_tool" ]]; then
    qsb_dump="$($qsb_tool -d "$organic_qsb" 2>/dev/null || true)"
    if ! grep -Fq 'GLSL 120 [Standard]' <<<"$qsb_dump" \
            || ! grep -Fq 'GLSL 150 [Standard]' <<<"$qsb_dump"; then
        printf 'FAIL: Organic visualizer shader pack is missing desktop GLSL targets\n' >&2
        exit 1
    fi
fi

organic_edge_qsb="$runtime_root/modules/common/widgets/OrganicScreenEdge.frag.qsb"
organic_edge_shader="$runtime_root/modules/common/widgets/OrganicScreenEdge.frag"
organic_edge_qml="$runtime_root/modules/common/widgets/OrganicScreenEdge.qml"
organic_edge_settings="$runtime_root/modules/settings/OrganicEdgeSettings.qml"
organic_motion="$runtime_root/modules/common/widgets/OrganicAudioMotion.qml"
organic_edge_config="$runtime_root/modules/background/widgets/OrganicEdgeConfig.js"
organic_edge_host="$runtime_root/modules/background/widgets/OrganicEdgeWidget.qml"
if [[ ! -s "$organic_edge_qsb" || ! -f "$organic_edge_shader" \
        || ! -f "$organic_edge_qml" || ! -f "$organic_edge_settings" \
        || ! -f "$organic_motion" || ! -f "$organic_edge_config" \
        || ! -f "$organic_edge_host" ]] \
        || ! grep -Fq 'float smoothMinField(' "$organic_edge_shader" \
        || ! grep -Fq 'void edgeInterval(' "$organic_edge_shader" \
        || ! grep -Fq 'bool cornerJoined(' "$organic_edge_shader" \
        || ! grep -Fq 'float edgeEndpointMask(' "$organic_edge_shader" \
        || ! grep -Fq 'float centeredLevel = level - u.activity.x * 0.62' "$organic_edge_shader" \
        || ! grep -Fq 'float bassEnergy =' "$organic_edge_shader" \
        || ! grep -Fq 'float haloDecay = unifiedPath' "$organic_edge_shader" \
        || ! grep -Fq '? mix(12.0, 3.5, u.appearance.z)' "$organic_edge_shader" \
        || ! grep -Fq ': mix(54.0, 14.0, u.appearance.z) * max(reach, 0.025)' "$organic_edge_shader" \
        || ! grep -Fq 'property vector4d appearance:' "$organic_edge_qml" \
        || ! grep -Fq 'property vector4d response:' "$organic_edge_qml" \
        || ! grep -Fq 'property real beatGlow: 0.65' "$organic_edge_qml" \
        || ! grep -Fq 'property vector4d peaksA: root._peakA' "$organic_edge_qml" \
        || ! grep -Fq 'property real attackScale: 1.0' "$organic_motion" \
        || ! grep -Fq 'property real releaseScale: 1.0' "$organic_motion" \
        || ! grep -Fq 'property real _effectiveMotionSpeed' "$organic_motion" \
        || ! grep -Fq 'root._effectiveMotionSpeed = follow' "$organic_motion" \
        || ! grep -Fq 'property vector4d topology:' "$organic_edge_qml" \
        || ! grep -Fq 'property real cornerBlend: 0.55' "$organic_edge_qml" \
        || ! grep -Fq 'property real flowDirection: 1' "$organic_edge_qml" \
        || ! grep -Fq 'shapeMode:' "$organic_edge_host" \
        || ! grep -Fq 'joinConnected:' "$organic_edge_host" \
        || ! grep -Fq 'restPresence:' "$organic_edge_host" \
        || ! grep -Fq 'audioPresence:' "$organic_edge_host" \
        || ! grep -Fq 'AdaptedMaterialScheme {' "$organic_edge_host" \
        || ! grep -Fq 'Appearance.wallpaperDominantColor' "$organic_edge_host" \
        || ! grep -Fq 'name: "Wallpaper Tide"' "$organic_edge_config" \
        || ! grep -Fq 'name: "Afterglow Frame"' "$organic_edge_config" \
        || ! grep -Fq 'value: "filament"' "$organic_edge_config" \
        || ! grep -Fq 'value: "caustic"' "$organic_edge_config" \
        || ! grep -Fq 'value: "afterglow"' "$organic_edge_config" \
        || ! grep -Fq 'float contourReach(' "$organic_edge_shader" \
        || ! grep -Fq 'bool unifiedPath = joinTR || joinBR || joinBL || joinTL' "$organic_edge_shader" \
        || ! grep -Fq 'if (!unifiedPath) {' "$organic_edge_shader" \
        || ! grep -Fq 'if (edgeT < intervalStart || edgeT > intervalEnd)' "$organic_edge_shader" \
        || ! grep -Fq 'if (dot(reachable, vec4(1)) < 0.5)' "$organic_edge_shader" \
        || ! grep -Fq 'float bassEnergy = max(max(u.bandsA.x, u.bandsA.y), u.bandsA.z)' "$organic_edge_shader" \
        || ! grep -Fq 'bool nearHorizontalCorner = p.x < radius || p.x > size.x - radius' "$organic_edge_shader" \
        || ! grep -Fq 'float flowDirection = u.topology.y < 0.0 ? -1.0 : 1.0' "$organic_edge_shader" \
        || ! grep -Fq 'float cornerBlend = clamp(u.topology.z, 0.0, 1.0)' "$organic_edge_shader" \
        || ! grep -Fq 'float connectedFieldRatio = 1e9' "$organic_edge_shader" \
        || ! grep -Fq 'vec2 connectedPhase = vec2(0.0)' "$organic_edge_shader" \
        || ! grep -Fq 'connectedFieldRatio = smoothMinField(' "$organic_edge_shader" \
        || ! grep -Fq 'connectedLocal = atan(connectedPhase.y, connectedPhase.x) / TAU' "$organic_edge_shader" \
        || ! grep -Fq 'float effectiveSideDepth = u.depths[side]' "$organic_edge_shader" \
        || ! grep -Fq 'float sharedDepth = min(' "$organic_edge_shader" \
        || ! grep -Fq 'float fieldRatio = unifiedPath ? connectedFieldRatio' "$organic_edge_shader" \
        || ! grep -Fq 'float fieldClip = unifiedPath' "$organic_edge_shader" \
        || ! grep -Fq 'if (unifiedPath && iteration > 0) continue' "$organic_edge_shader" \
        || grep -Fq 'cornerOwner' "$organic_edge_shader" \
        || grep -Fq 'cornerReach' "$organic_edge_shader" \
        || grep -Fq 'pathOwner' "$organic_edge_shader" \
        || grep -Fq 'sampleConnectedPath' "$organic_edge_shader" \
        || ! grep -Fq 'float p = fract(position) * 12.0' "$organic_edge_shader" \
        || ! grep -Fq 'u.topology.x > 0.5 ? max(alpha, weight)' "$organic_edge_shader" \
        || ! grep -Fq 'toggled: root.presetMatches(modelData)' "$organic_edge_settings" \
        || ! grep -Fq 'model: EdgeConfig.responsePresets' "$organic_edge_settings" \
        || ! grep -Fq 'options: EdgeConfig.shapes.map' "$organic_edge_settings" \
        || ! grep -Fq 'Join connected edges' "$organic_edge_settings" \
        || ! grep -Fq 'entries: EdgeConfig.materialBody' "$organic_edge_settings" \
        || ! grep -Fq 'entries: EdgeConfig.materialLight' "$organic_edge_settings" \
        || ! grep -Fq 'entries: EdgeConfig.audioDynamics' "$organic_edge_settings" \
        || ! grep -Fq 'entries: EdgeConfig.audioTone' "$organic_edge_settings" \
        || ! grep -Fq 'onMoved: root.setValue(metric.modelData.key' "$organic_edge_settings" \
        || ! grep -Fq 'model: EdgeConfig.scenePresets' "$organic_edge_settings" \
        || ! grep -Fq 'model: EdgeConfig.compositionPresets' "$organic_edge_settings" \
        || ! grep -Fq 'model: EdgeConfig.materialPresets' "$organic_edge_settings" \
        || ! grep -Fq 'component ResetButton:' "$organic_edge_settings" \
        || ! grep -Fq 'component SelectionBlock:' "$organic_edge_settings" \
        || ! grep -Fq 'check_circle' "$organic_edge_settings" \
        || ! grep -Fq 'EdgeConfig.colorModes' "$organic_edge_settings" \
        || ! grep -Fq 'EdgeConfig.effects' "$organic_edge_settings" \
        || ! grep -Fq 'Behavior on _primaryColor' "$organic_edge_qml" \
        || ! grep -Fq 'TuneBehavior on _effectStrength' "$organic_edge_qml" \
        || ! grep -Fq 'property vector4d effects:' "$organic_edge_qml" \
        || ! grep -Fq 'paletteColors:' "$runtime_root/modules/background/widgets/OrganicEdgeWidget.qml" \
        || ! grep -Fq 'albumColorCount:' "$runtime_root/modules/background/widgets/OrganicEdgeWidget.qml" \
        || ! grep -Fq 'palette === "album"' "$runtime_root/modules/background/widgets/OrganicEdgeWidget.qml" \
        || ! grep -Fq 'name: "Album Aura"' "$runtime_root/modules/background/widgets/OrganicEdgeConfig.js" \
        || ! grep -Fq 'name: "Club Pulse"' "$runtime_root/modules/background/widgets/OrganicEdgeConfig.js" \
        || ! grep -Fq 'name: "Quiet Horizon"' "$runtime_root/modules/background/widgets/OrganicEdgeConfig.js" \
        || ! grep -Fq 'var presets = legacyPresets.concat(scenePresets.filter' "$runtime_root/modules/background/widgets/OrganicEdgeConfig.js" \
        || ! grep -Fq 'name: "Full Frame"' "$runtime_root/modules/background/widgets/OrganicEdgeConfig.js"; then
    printf 'FAIL: Organic edge renderer/settings contract is incomplete\n' >&2
    exit 1
fi
if [[ -n "$qsb_tool" ]]; then
    edge_qsb_dump="$($qsb_tool -d "$organic_edge_qsb" 2>/dev/null || true)"
    if ! grep -Fq 'GLSL 120 [Standard]' <<<"$edge_qsb_dump" \
            || ! grep -Fq 'GLSL 150 [Standard]' <<<"$edge_qsb_dump"; then
        printf 'FAIL: Organic edge shader pack is missing desktop GLSL targets\n' >&2
        exit 1
    fi
fi

step "visualizer app filter semantics"
python3 - "$runtime_root/scripts/cava/resolve_audio_source.py" <<'PY'
import importlib.util
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
spec = importlib.util.spec_from_file_location("inir_resolve_audio_source_test", path)
module = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = module
spec.loader.exec_module(module)

def node(name, app_name, app_id, binary, sink_id="58"):
    return module.SinkInput(1, "", name, "", "", app_name, app_id, binary, False, sink_id)

checks = [
    ("firefox blocks firefox", node("Firefox", "Firefox", "org.mozilla.firefox", "firefox"), ["firefox"], True),
    ("firefox does not block zen", node("zen", "Zen", "app.zen-browser.zen", "zen"), ["firefox"], False),
    ("chromium does not block generic electron", node("SomeElectron", "Some App", "com.example.app", "electron"), ["chromium"], False),
    ("desktop id blocks firefox", node("Firefox", "Firefox", "", "firefox"), ["org.mozilla.firefox"], True),
    ("chrome desktop id blocks chrome", node("Google Chrome", "Google Chrome", "", "google-chrome-stable"), ["com.google.Chrome"], True),
]

failed = [name for name, stream, blocked, expected in checks
          if module._matches_blocked(stream, blocked) is not expected]
if failed:
    raise SystemExit("visualizer blocklist matcher failed: " + ", ".join(failed))

sink_inputs = module._parse_sink_inputs("""Sink Input #23
\tClient: 7
\tSink: 58
\tCorked: no
\tProperties:
\t\tnode.name = \"Firefox\"
\t\tapplication.name = \"Firefox\"
\t\tapplication.process.binary = \"firefox\"
\t\tobject.serial = \"28174\"
""", {})
sink_monitors = module._parse_sink_monitors("""Sink #58
\tName: alsa_output.test
\tMonitor Source: alsa_output.test.monitor
""")
if len(sink_inputs) != 1 or sink_inputs[0].sink_id != "58":
    raise SystemExit("visualizer source resolver lost the playback sink id")
if module._stream_monitor(sink_inputs[0], sink_monitors) != "alsa_output.test.monitor":
    raise SystemExit("visualizer source resolver does not route through the playback sink monitor")
if module._stream_monitor(sink_inputs[0], sink_monitors) == "28174":
    raise SystemExit("visualizer source resolver can regress to a playback stream serial and capture the microphone")

def fake_run(command):
    if command == ["pactl", "info"]:
        return "Server Name: PulseAudio (on PipeWire 1.6.8)"
    if command == ["pactl", "list", "clients"]:
        return ""
    if command == ["pactl", "list", "sink-inputs"]:
        return """Sink Input #23
\tSink: 58
\tCorked: no
\tProperties:
\t\tnode.name = \"Firefox\"
\t\tapplication.name = \"Firefox\"
\t\tapplication.process.binary = \"firefox\"
\t\tobject.serial = \"28174\"
"""
    if command == ["pactl", "list", "sinks"]:
        return """Sink #58
\tName: alsa_output.test
\tMonitor Source: alsa_output.test.monitor
"""
    if command == ["pactl", "get-default-sink"]:
        return "alsa_output.test"
    return ""

real_run = module._run
module._run = fake_run
try:
    resolved = module.resolve_source("firefox", [])
finally:
    module._run = real_run
if resolved != "alsa_output.test.monitor":
    raise SystemExit("visualizer source resolver must target the playback monitor, got: " + resolved)
PY

step "launcher resolution"
bash "$launcher" path >/dev/null
bash "$launcher" status >/dev/null

# A repo-copy update must replace an inherited/stale symlink with a real file;
# `cp -f source symlink` follows the link and only overwrites its old target.
# Conversely repo-link must always converge back to the live repo symlink.
launcher_sync_root="$(mktemp -d)"
mkdir -p "$launcher_sync_root/home/.local/bin" "$launcher_sync_root/old"
printf '#!/bin/sh\nprintf OLD\\n\n' > "$launcher_sync_root/old/inir"
chmod +x "$launcher_sync_root/old/inir"
ln -s "$launcher_sync_root/old/inir" "$launcher_sync_root/home/.local/bin/inir"
launcher_sync_function="$(sed -n '/^sync_launcher_from_repo() {/,/^}/p' "$runtime_root/setup")"
if ! TEST_HOME="$launcher_sync_root/home" TEST_REPO="$runtime_root" \
        TEST_FUNCTION="$launcher_sync_function" bash -c '
    set -e
    export HOME="$TEST_HOME"
    export XDG_BIN_HOME="$HOME/.local/bin"
    export REPO_ROOT="$TEST_REPO"
    get_installed_install_mode() { printf repo-copy; }
    get_install_mode() { printf repo-copy; }
    ensure_launcher_path_in_shells() { :; }
    eval "$TEST_FUNCTION"
    sync_launcher_from_repo >/dev/null
    [[ ! -L "$XDG_BIN_HOME/inir" ]]
    cmp -s "$REPO_ROOT/scripts/inir" "$XDG_BIN_HOME/inir"
    grep -Fq OLD "$TEST_HOME/../old/inir"

    printf stale-copy > "$XDG_BIN_HOME/inir"
    get_installed_install_mode() { printf repo-link; }
    get_install_mode() { printf repo-link; }
    sync_launcher_from_repo >/dev/null
    [[ -L "$XDG_BIN_HOME/inir" ]]
    [[ "$(readlink -f "$XDG_BIN_HOME/inir")" == "$(readlink -f "$REPO_ROOT/scripts/inir")" ]]
'; then
    rm -rf "$launcher_sync_root"
    printf 'FAIL: setup launcher sync does not converge repo-copy/repo-link topology\n' >&2
    exit 1
fi
rm -rf "$launcher_sync_root"

step "application launch environment"
# Niri owns DISPLAY/WAYLAND_DISPLAY/NIRI_SOCKET. App launches may refresh from
# the live user-manager snapshot, but must never infer compositor sockets.
shell_exec="$runtime_root/modules/common/functions/ShellExec.qml"
inir_launcher="$runtime_root/scripts/inir"
if ! grep -Fq 'systemctl --user show-environment' "$shell_exec" \
        || ! grep -Fq 'for _var in DISPLAY WAYLAND_DISPLAY NIRI_SOCKET' "$shell_exec" \
        || ! grep -Fq 'QT_QPA_PLATFORM QT_QPA_PLATFORMTHEME QT_STYLE_OVERRIDE' "$shell_exec" \
        || ! grep -Fq 'apply_niri_app_environment' "$inir_launcher" \
        || ! grep -Fq 'config.d/40-environment.kdl' "$inir_launcher" \
        || grep -Fq '/tmp/.X11-unix/X' "$shell_exec" \
        || grep -Fq 'valid_display()' "$shell_exec"; then
    printf 'FAIL: application launches do not preserve Niri-owned graphical session environment\n' >&2
    exit 1
fi

# The supervised shell starts from systemd rather than as a direct Niri child.
# Exercise the launcher-side KDL mirror with no user-manager Qt variables so
# app policy still comes from Niri's effective environment config.
niri_env_root="$(mktemp -d)"
mkdir -p "$niri_env_root/niri/config.d"
cat > "$niri_env_root/niri/config.kdl" <<'EOF'
include "config.d/40-environment.kdl"
EOF
cat > "$niri_env_root/niri/config.d/40-environment.kdl" <<'EOF'
environment {
    XDG_MENU_PREFIX "plasma-"
    QT_QPA_PLATFORM "wayland"
    QT_QPA_PLATFORMTHEME "kde"
    QT_STYLE_OVERRIDE "Darkly"
    ELECTRON_OZONE_PLATFORM_HINT "auto"
}
EOF
niri_env_functions="$({
    sed -n '/^_niri_app_environment_file() {/,/^}/p' "$inir_launcher"
    sed -n '/^_niri_app_environment_value() {/,/^}/p' "$inir_launcher"
    sed -n '/^apply_niri_app_environment() {/,/^}/p' "$inir_launcher"
})"
if ! TEST_XDG_CONFIG_HOME="$niri_env_root" TEST_FUNCTIONS="$niri_env_functions" bash -c '
    set -e
    export XDG_CONFIG_HOME="$TEST_XDG_CONFIG_HOME"
    unset QT_QPA_PLATFORM QT_QPA_PLATFORMTHEME QT_STYLE_OVERRIDE ELECTRON_OZONE_PLATFORM_HINT XDG_MENU_PREFIX
    eval "$TEST_FUNCTIONS"
    apply_niri_app_environment
    [[ "$QT_QPA_PLATFORM" == wayland ]]
    [[ "$QT_QPA_PLATFORMTHEME" == kde ]]
    [[ "$QT_STYLE_OVERRIDE" == Darkly ]]
    [[ "$ELECTRON_OZONE_PLATFORM_HINT" == auto ]]
    [[ "$XDG_MENU_PREFIX" == plasma- ]]
'; then
    rm -rf "$niri_env_root"
    printf 'FAIL: supervised launcher does not mirror Niri app environment\n' >&2
    exit 1
fi
rm -rf "$niri_env_root"

if ! grep -Fq 'for _qs_var in WAYLAND_DISPLAY NIRI_SOCKET DISPLAY' "$inir_launcher" \
        || grep -Fq '/tmp/.X11-unix/X' "$inir_launcher" \
        || grep -Fq 'niri.wayland-*.sock' "$inir_launcher" \
        || grep -Fq 'systemctl --user set-environment "${vars_to_import[@]}"' "$inir_launcher"; then
    printf 'FAIL: launcher still manufactures or republishes compositor-owned session variables\n' >&2
    exit 1
fi
if grep -Fq 'MALLOC_ARENA_MAX' "$shell_exec" \
        || grep -Fq 'MALLOC_MMAP_THRESHOLD_' "$shell_exec"; then
    printf 'FAIL: application launch policy still carries retired allocator handling\n' >&2
    exit 1
fi

# Generic distro setup must key off the platform-theme plugin itself, not the
# presence of a full Plasma desktop. Niri users commonly install
# plasma-integration standalone.
package_installers="$runtime_root/sdata/lib/package-installers.sh"
doctor_lib="$runtime_root/sdata/lib/doctor.sh"
if ! grep -Fq 'KDEPlasmaPlatformTheme6.so' "$package_installers" \
        || ! grep -Fq 'config.d/40-environment.kdl' "$doctor_lib" \
        || ! grep -Fq 'KDEPlasmaPlatformTheme6.so' "$inir_launcher"; then
    printf 'FAIL: Qt theming setup/doctor does not support standalone plasma-integration with modular Niri config\n' >&2
    exit 1
fi

orbit_stage="$runtime_root/modules/overview/OrbitOrbitalStage.qml"
orbit_stage_view="$runtime_root/modules/overview/OverviewNiriWidget.qml"
orbit_studio="$runtime_root/modules/overview/OrbitStudio.qml"
if ! grep -Fq 'z: isCore ? 100 : 20 + workspaceIndex * 0.01' "$orbit_stage" \
        || [[ "$(grep -c 'NumberAnimation { duration: root.transitionDurationMs; easing.type: root.navigationEasingType }' "$orbit_stage")" -lt 5 ]]; then
    printf 'FAIL: Orbit orbital navigation no longer tracks geometry/depth continuously\n' >&2
    exit 1
fi
if ! grep -Fq 'retainWhileLoading: true' "$orbit_stage" \
        || ! grep -Fq 'retainWhileLoading: true' "$orbit_stage_view" \
        || grep -Fq 'sourceSize.width: Math.max(1, Math.round(width * 2))' "$orbit_stage" \
        || grep -Fq 'sourceSize.width: Math.max(1, Math.round(width * 2))' "$orbit_stage_view"; then
    printf 'FAIL: Orbit preview decoding can reload during animated geometry changes\n' >&2
    exit 1
fi
pill_notifs="$runtime_root/modules/pill/PillNotifs.qml"
if ! grep -Fq 'image://qsimage/' "$pill_notifs"; then
    printf 'FAIL: Pill notification history can reuse expired Quickshell image handles\n' >&2
    exit 1
fi

preview_service="$runtime_root/services/WindowPreviewService.qml"
preview_capture="$runtime_root/scripts/capture-windows.sh"
if ! grep -Fq 'restore_saved_clipboard' "$preview_capture" \
        || ! grep -A8 -F 'screenshot-window --id "$id"' "$preview_capture" | grep -Fq 'restore_saved_clipboard'; then
    printf 'FAIL: window preview capture can leave Niri screenshot PNGs in the user clipboard\n' >&2
    exit 1
fi
preview_image_store="$runtime_root/scripts/clipboard-image-store.sh"
if [[ ! -x "$preview_image_store" ]] \
        || ! grep -Fq 'inir-window-preview-capture-' "$preview_capture" \
        || ! grep -Fq 'inir-window-preview-capture-' "$preview_image_store" \
        || ! grep -Fq 'clipboard-image-store.sh' "$runtime_root/defaults/niri/config.d/50-startup.kdl"; then
    printf 'FAIL: internal window previews can leak into cliphist image history\n' >&2
    exit 1
fi
clipboard_startup="$runtime_root/defaults/niri/config.d/50-startup.kdl"
clipboard_newline_migration="$runtime_root/sdata/migrations/042-cliphist-no-synthetic-newline.sh"
if ! grep -Fq 'wl-paste --no-newline --type text --watch ~/.config/quickshell/inir/scripts/clipboard-store.py' "$clipboard_startup" \
        || [[ ! -f "$clipboard_newline_migration" ]] \
        || ! grep -Fq 'wl-paste --no-newline ' "$clipboard_newline_migration"; then
    printf 'FAIL: clipboard text watcher can synthesize trailing newlines and bypass cliphist dedupe\n' >&2
    exit 1
fi
clipboard_restore_migration="$runtime_root/sdata/migrations/034-cliphist-text-watcher.sh"
if [[ ! -f "$clipboard_restore_migration" ]]; then
    printf 'FAIL: clipboard text-watcher repair migration is missing\n' >&2
    exit 1
fi
clipboard_migration_home="$(mktemp -d)"
mkdir -p "$clipboard_migration_home/.config/niri/config.d"
cp "$clipboard_startup" "$clipboard_migration_home/.config/niri/config.d/50-startup.kdl"
if ! HOME="$clipboard_migration_home" XDG_CONFIG_HOME="$clipboard_migration_home/.config" REPO_ROOT="$runtime_root" \
        bash -c 'source "$REPO_ROOT/sdata/lib/migrations.sh"; load_migration 034-cliphist-text-watcher; ! migration_check'; then
    rm -rf "$clipboard_migration_home"
    printf 'FAIL: current clipboard watcher is falsely reported as missing by migration 034\n' >&2
    exit 1
fi
rm -rf "$clipboard_migration_home"
if ! grep -Fq 'previewRefreshTimer' "$runtime_root/modules/dock/DockPreview.qml" \
        || ! grep -Fq 'pendingPreviewIds' "$runtime_root/modules/dock/DockPreview.qml" \
        || ! grep -Fq 'hoverDelayTimer.stop()' "$runtime_root/modules/dock/DockAppButton.qml"; then
    printf 'FAIL: dock clicks can race window-preview capture and user paste\n' >&2
    exit 1
fi
if ! grep -Fq 'windowPreviewCaptureActive' "$runtime_root/services/Notifications.qml" \
        || ! grep -Fq 'paste the image from the clipboard' "$runtime_root/services/Notifications.qml"; then
    printf 'FAIL: internal Niri preview screenshot notifications are not suppressed safely\n' >&2
    exit 1
fi
if ! grep -Fq 'requestedWindowMaxAgeMs' "$preview_service" \
        || ! grep -Fq 'markPreviewDirty(root.lastFocusedWindowId)' "$preview_service" \
        || ! grep -Fq '"-printf", "%f\\t%T@\\n"' "$preview_service" \
        || ! grep -Fq 'corePreviewFreshnessMs: 10000' "$orbit_stage" \
        || ! grep -Fq 'satellitePreviewFreshnessMs: 45000' "$orbit_stage" \
        || ! grep -Fq 'mipmap: false' "$orbit_stage" \
        || ! grep -Fq 'max_concurrent=1' "$preview_capture"; then
    printf 'FAIL: Orbit preview freshness/quality policy regressed\n' >&2
    exit 1
fi
home_nix_module="$runtime_root/nix/home-module.nix"
if ! grep -Fq 'path="$(command -v "$name" 2>/dev/null || true)"' "$preview_capture" \
        || grep -Fq '[[ ! -x "$bin" ]]' "$preview_capture" \
        || ! grep -Fq 'PATH = lib.makeBinPath ([ cfg.package ] ++ cfg.extraPackages);' "$home_nix_module"; then
    printf 'FAIL: packaged Nix preview dependencies are not resolved through the service PATH\n' >&2
    exit 1
fi
if grep -Fq 'NavigationFineControls { visible: !root.workspaceMode }' "$orbit_studio" \
        || grep -Fq 'PresentationFineControls { visible: !root.workspaceMode }' "$orbit_studio"; then
    printf 'FAIL: Orbit Studio Motion exposes advanced tuning in the primary workflow\n' >&2
    exit 1
fi

terminal_launcher="$runtime_root/scripts/launch-terminal.sh"
browser_launcher_block="$(sed -n '/^launch_configured_browser()/,/^}/p' "$inir_launcher")"
if grep -Fq 'systemd-run --user --scope' "$terminal_launcher" \
        || grep -Fq 'systemd-run --user --scope' <<< "$browser_launcher_block"; then
    printf 'FAIL: Niri terminal/browser launchers create a redundant nested systemd scope\n' >&2
    exit 1
fi

if [[ -e "$runtime_root/sdata/migrations/037-scope-quickshell-malloc-env.sh" ]]; then
    printf 'FAIL: allocator cleanup was added as a second migration instead of update/doctor repair\n' >&2
    exit 1
fi

migration_lib="$runtime_root/sdata/lib/migrations.sh"
repair_lib="$runtime_root/sdata/lib/functions.sh"
doctor_lib="$runtime_root/sdata/lib/doctor.sh"
if ! MIGRATION_LIB="$migration_lib" bash -c '
        source "$MIGRATION_LIB"
        for id in \
            001-gamemode-animation-toggle 002-backdrop-layer-rules 003-qt-theming-kde \
            004-audio-keybinds-ipc 005-dolphin-xdg-menu 006-close-confirm \
            007-brightness-keybinds 008-media-keybinds 009-quickshell-dbus-properties-logspam \
            014-malloc-arena-optimization 021-systemd-single-instance \
            022-service-compositor-wants 028-bar-modular-layout \
            040-niri-session-environment-lifecycle; do
            is_migration_retired "$id" || exit 1
        done
    ' \
        || ! grep -Fq 'is_migration_retired "$migration_id" && return 1' "$migration_lib" \
        || ! grep -Fq 'repair_legacy_quickshell_malloc_environment()' "$repair_lib" \
        || ! grep -Fq 'repair_legacy_quickshell_malloc_environment' "$runtime_root/setup" \
        || ! grep -Fq 'repair_legacy_quickshell_malloc_environment' "$doctor_lib"; then
    printf 'FAIL: retired runtime migrations are not repaired through current owners\n' >&2
    exit 1
fi
if ! grep -Fq '! -name "test-*.py"' "$doctor_lib" \
        || ! grep -Fq '! -name "test-*.py"' "$runtime_root/setup"; then
    printf 'FAIL: Doctor/update can turn non-command Python test modules executable\n' >&2
    exit 1
fi

declare -A _migration_ids_seen=()
for _migration_file in "$runtime_root"/sdata/migrations/*.sh; do
    [[ -f "$_migration_file" ]] || continue
    _migration_file_id="$(basename "$_migration_file" .sh)"
    _migration_declared_id="$(sed -n 's/^MIGRATION_ID="\([^"]*\)".*/\1/p' "$_migration_file" | head -1)"
    if [[ -z "$_migration_declared_id" || "$_migration_declared_id" != "$_migration_file_id" || -n "${_migration_ids_seen[$_migration_declared_id]:-}" ]]; then
        printf 'FAIL: migration IDs must be unique and match their filenames (%s -> %s)\n' "$_migration_file_id" "${_migration_declared_id:-missing}" >&2
        exit 1
    fi
    _migration_ids_seen["$_migration_declared_id"]=1
done

uninstall_root="$(mktemp -d)"
mkdir -p "$uninstall_root/home/.config/kitty" "$uninstall_root/home/.config/foot" \
    "$uninstall_root/home/.config/fish/conf.d" \
    "$uninstall_root/home/.local/state" "$uninstall_root/home/.local/share" \
    "$uninstall_root/home/.local/bin" "$uninstall_root/home/inir-backup/.config/kitty"
printf '# USER ORIGINAL KITTY\n' > "$uninstall_root/home/.config/kitty/kitty.conf.old"
printf '# iNiR kitty\ninclude current-theme.conf\n' > "$uninstall_root/home/.config/kitty/kitty.conf"
printf '# Auto-generated by ii wallpaper theming system\n' > "$uninstall_root/home/.config/kitty/theme.conf"
ln -s theme.conf "$uninstall_root/home/.config/kitty/current-theme.conf"
printf '# USER ORIGINAL FOOT\n' > "$uninstall_root/home/.config/foot/foot.ini.old"
printf '# iNiR foot\n' > "$uninstall_root/home/.config/foot/foot.ini"
printf '# ORIGINAL USER THEME\n' > "$uninstall_root/home/inir-backup/.config/kitty/theme.conf"
cat > "$uninstall_root/home/.bashrc" <<'EOF'
export USER_KEEP=1
# iNiR launcher PATH
export PATH="$HOME/.local/bin:$PATH"
# end iNiR launcher PATH
# iNiR environment
export INIR_VENV="$HOME/.local/state/quickshell/.venv"
# end iNiR
export USER_KEEP_TOO=1
EOF
printf 'set -gx PATH ~/.local/bin $PATH\n' > "$uninstall_root/home/.config/fish/conf.d/inir-path.fish"
printf 'set -gx INIR_VENV foo\n' > "$uninstall_root/home/.config/fish/conf.d/inir-env.fish"
if ! HOME="$uninstall_root/home" XDG_CONFIG_HOME="$uninstall_root/home/.config" \
        XDG_STATE_HOME="$uninstall_root/home/.local/state" XDG_DATA_HOME="$uninstall_root/home/.local/share" \
        XDG_CACHE_HOME="$uninstall_root/home/.cache" XDG_BIN_HOME="$uninstall_root/home/.local/bin" \
        BACKUP_DIR="$uninstall_root/home/inir-backup" REPO_ROOT="$runtime_root" bash -c '
    source "$REPO_ROOT/sdata/lib/environment-variables.sh"
    source "$REPO_ROOT/sdata/lib/functions.sh"
    source "$REPO_ROOT/sdata/lib/tui.sh"
    source "$REPO_ROOT/sdata/lib/versioning.sh"
    source "$REPO_ROOT/sdata/lib/uninstall.sh"
    backup=$(uninstall_create_backup)
    uninstall_restore_preinstall_configs >/dev/null
    uninstall_remove_shell_integration >/dev/null
    [[ "$(head -1 "$XDG_CONFIG_HOME/kitty/kitty.conf")" == "# USER ORIGINAL KITTY" ]]
    [[ "$(head -1 "$XDG_CONFIG_HOME/foot/foot.ini")" == "# USER ORIGINAL FOOT" ]]
    [[ "$(head -1 "$XDG_CONFIG_HOME/kitty/theme.conf")" == "# ORIGINAL USER THEME" ]]
    [[ "$(head -1 "$backup/shared-configs/kitty/kitty.conf")" == "# iNiR kitty" ]]
    [[ "$(head -1 "$backup/shared-configs/kitty/kitty.conf.old")" == "# USER ORIGINAL KITTY" ]]
    grep -qx "export USER_KEEP=1" "$HOME/.bashrc"
    grep -qx "export USER_KEEP_TOO=1" "$HOME/.bashrc"
    ! grep -q "iNiR launcher PATH\|iNiR environment\|INIR_VENV" "$HOME/.bashrc"
    [[ ! -e "$XDG_CONFIG_HOME/fish/conf.d/inir-path.fish" ]]
    [[ ! -e "$XDG_CONFIG_HOME/fish/conf.d/inir-env.fish" ]]
    grep -q "# iNiR environment" "$backup/shell-integration/.bashrc"
'; then
    rm -rf "$uninstall_root"
    printf 'FAIL: uninstall does not restore exact pre-iNiR configs while preserving a safety backup\n' >&2
    exit 1
fi
rm -rf "$uninstall_root"

game_mode="$runtime_root/services/GameMode.qml"
animations_default="$runtime_root/defaults/niri/config.d/60-animations.kdl"
if ! grep -Fq '[ \\t]*off$' "$game_mode" || ! grep -Eq '^[[:space:]]*//[[:space:]]+off[[:space:]]*$' "$animations_default"; then
    printf 'FAIL: GameMode cannot toggle the current spaced Niri animation marker\n' >&2
    exit 1
fi

arch_install="$runtime_root/distro/arch/inir-shell-git/inir-shell-git.install"
if grep -Fq 'systemctl --user enable --now inir.service' "$arch_install" \
        || ! grep -Fq 'inir service enable' "$arch_install" \
        || ! grep -Fq '~/.config/inir/config.json' "$arch_install"; then
    printf 'FAIL: Arch package post-install guidance contradicts the Niri-owned service/config contract\n' >&2
    exit 1
fi

if command -v python3 &>/dev/null && [[ -f "$runtime_root/scripts/lib/generate-ipc-registry.py" ]]; then
    step "IPC registry freshness"
    python3 "$runtime_root/scripts/lib/generate-ipc-registry.py" --check

    step "QML parses on Qt 6.10 and older"
    python3 "$runtime_root/scripts/test-qml-qt-compat.py"

    step "QML components that parse and fail to load"
    python3 "$runtime_root/scripts/test-qml-pitfalls.py"

    step "iRiS style tokens"
    python3 "$runtime_root/scripts/test-iris-style-tokens.py"

    step "Auto light/dark reads the wallpaper's brightness"
    python3 "$runtime_root/scripts/test-wallpaper-mode.py"

    step "App theming runs on a machine without Steam or Spotify"
    python3 "$runtime_root/scripts/test-applycolor-fingerprint.py"

    step "Terminal prose reads and nothing outshines it"
    python3 "$runtime_root/scripts/test-terminal-palette.py"

    step "iRiS defaults"
    python3 "$runtime_root/scripts/test-iris-defaults.py"

    step "iRiS anime layer"
    python3 "$runtime_root/scripts/test-iris-anime-layer.py"

    step "iRiS performance contract"
    python3 "$runtime_root/scripts/test-iris-performance-contract.py"

    step "iRiS Settings preview scenes"
    python3 "$runtime_root/scripts/test-iris-preview-scenes.py"

    step "niri config rules and flags"
    python3 "$runtime_root/scripts/test-niri-config-rules.py"

    step "niri animation presets"
    python3 "$runtime_root/scripts/test-niri-animation-presets.py"
fi

if [[ "$run_runtime" == true ]]; then
    step "runtime restart"
    bash "$runtime_root/scripts/inir" kill >/dev/null 2>&1 || true
    sleep 1
    bash "$runtime_root/scripts/inir" run >/tmp/inir-test-local-runtime.log 2>&1 &
    sleep 3

    step "runtime logs"
    bash "$runtime_root/scripts/inir" logs

    step "runtime filtered errors"
    bash "$launcher" logs --full | grep -iE 'error|ReferenceError|TypeError|binding loop' | tail -80 || true

    step "launcher ipc"
    bash "$launcher" ipc shellUpdate diagnose >/dev/null
fi

step "installed payload boundaries"
python3 "$runtime_root/scripts/test-runtime-payload.py"

printf '\nAll local distribution checks passed.\n'
