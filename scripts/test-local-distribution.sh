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
        || ! grep -qx 'Before=graphical-session.target' "$service_unit" \
        || grep -qx 'After=graphical-session.target' "$service_unit" \
        || grep -qx 'Requisite=graphical-session.target' "$service_unit"; then
    printf 'FAIL: inir.service does not gate XDG autostart on the tray watcher\n' >&2
    exit 1
fi
if ! grep -Fq 'property var _trayService: TrayService' "$runtime_root/shell.qml"; then
    printf 'FAIL: shell startup does not instantiate the StatusNotifier watcher\n' >&2
    exit 1
fi

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

checks = {
    "settings rail": config["settingsUi"]["overlayStyle"] == "rail",
    "balanced profile": config["welcomeWizard"]["profile"] == "balanced",
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
}
failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit("FAIL: fresh-install defaults: " + ", ".join(failed))

schema_checks = {
    "schema settings rail": 'property string overlayStyle: "rail"' in schema,
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
    "schema wallhaven tab": "property JsonObject wallhaven: JsonObject {\n                    // Enable/disable the Wallpapers tab in the left sidebar\n                    property bool enable: true" in schema,
    "schema news tab": "property JsonObject news: JsonObject {\n                    property bool enable: true" in schema,
    "wizard applies initial profile": "root.applyProfile(root.selectedProfile)" in wizard,
    "wizard dock pinned": '"dock.pinnedOnStartup": true' in wizard,
    "wizard dock not hover-only": '"dock.hoverToReveal": false' in wizard,
    "wizard right sidebar full height": '"sidebar.collapseEmptyNotifications": false' in wizard,
    "wizard left sidebar full height": '"sidebar.collapseWidgetsTab": false' in wizard,
    "wizard preserves Waffle configuration": '"waffles.' not in wizard.split(
        "readonly property var profileEssentials", 1)[1].split(
        "// ─── Entry/exit animation state", 1)[0],
}
failed = [name for name, passed in schema_checks.items() if not passed]
if failed:
    raise SystemExit("FAIL: schema/wizard defaults: " + ", ".join(failed))

binds = (root / "defaults/niri/config.d/70-binds.kdl").read_text(encoding="utf-8")
if 'Alt+Tab { next-window; }' not in binds or 'Alt+Shift+Tab { previous-window; }' not in binds:
    raise SystemExit("FAIL: native Niri Alt+Tab bindings are missing")
if 'spawn "inir" "altSwitcher"' in binds:
    raise SystemExit("FAIL: fresh-install Alt+Tab invokes the iNiR switcher")
PY

arch_installer="$runtime_root/sdata/dist-arch/install-deps.sh"
if ! grep -Fq 'pacman -T "${depends[@]}"' "$arch_installer" \
        || ! grep -Fq 'pacman -S $installflags "${missing_deps[@]}"' "$arch_installer"; then
    printf 'FAIL: Arch PKGBUILD dependencies are not filtered through the local package database\n' >&2
    exit 1
fi
if grep -Fq 'pacman -S $installflags "${depends[@]}"' "$arch_installer"; then
    printf 'FAIL: Arch installer can still reinstall or downgrade satisfied PKGBUILD dependencies\n' >&2
    exit 1
fi

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
if grep -q -- "--exclude='assets/images/mascot/manifest.json'" "$runtime_root/sdata/lib/functions.sh"; then
    printf 'FAIL: repo-copy sync excludes the mascot runtime manifest\n' >&2
    exit 1
fi
# Payload directories are copied one at a time, so these are relative to
# assets/ — an 'assets/…' prefix here never matches and the art ships.
for local_mascot_path in \
    "images/mascot/*.png" \
    "images/mascot/*.gif" \
    "images/mascot/frames/" \
    "images/mascot/PROMPTS.md"; do
    if ! grep -Fq -- "--exclude='$local_mascot_path'" "$runtime_root/sdata/lib/functions.sh"; then
        printf 'FAIL: repo-copy sync can leak local mascot artifact: %s\n' "$local_mascot_path" >&2
        exit 1
    fi
done
if ! grep -q "inir-mascot-.*\\.png" "$runtime_root/Makefile" \
        || ! grep -q "inir-mascot-.*\\.gif" "$runtime_root/Makefile" \
        || ! grep -q 'PROMPTS.md' "$runtime_root/Makefile" \
        || ! grep -q 'assets/images/mascot/frames' "$runtime_root/Makefile"; then
    printf 'FAIL: make install does not strip local mascot art/tooling\n' >&2
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
    done
fi

step "launcher resolution"
bash "$launcher" path >/dev/null
bash "$launcher" status >/dev/null

step "application launch environment"
# XWayland is not guaranteed to own :0. Preserve live DISPLAY discovery and validation.
shell_exec="$runtime_root/modules/common/functions/ShellExec.qml"
inir_launcher="$runtime_root/scripts/inir"
if ! grep -Fq 'systemctl --user show-environment' "$shell_exec" \
        || ! grep -Fq '_manager_display="$(manager_value DISPLAY)"' "$shell_exec" \
        || ! grep -Fq 'valid_display "$DISPLAY"' "$shell_exec" \
        || ! grep -Fq 'for _x in /tmp/.X11-unix/X*' "$shell_exec"; then
    printf 'FAIL: application launches do not recover the live XWayland DISPLAY environment\n' >&2
    exit 1
fi
if ! grep -Fq 'vars_to_import+=("DISPLAY=$DISPLAY")' "$inir_launcher" \
        || ! grep -Fq 'for _xsock in /tmp/.X11-unix/X*' "$inir_launcher" \
        || ! grep -Fq 'systemctl --user set-environment "${vars_to_import[@]}"' "$inir_launcher"; then
    printf 'FAIL: session environment does not publish the XWayland DISPLAY to the user manager\n' >&2
    exit 1
fi

if command -v python3 &>/dev/null && [[ -f "$runtime_root/scripts/lib/generate-ipc-registry.py" ]]; then
    step "IPC registry freshness"
    python3 "$runtime_root/scripts/lib/generate-ipc-registry.py" --check
fi

if command -v python3 &>/dev/null && [[ -f "$runtime_root/scripts/lib/check-launch-policy.py" ]]; then
    step "launch policy scan"
    # set -euo pipefail at the top makes a scanner violation fatal.
    python3 "$runtime_root/scripts/lib/check-launch-policy.py"
fi

if [[ -f "$runtime_root/scripts/tests/test-launch-daemon.sh" ]]; then
    step "launch daemon contract suite"
    bash "$runtime_root/scripts/tests/test-launch-daemon.sh"
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

step "agent artifact leak guard"
# The source tree legitimately has AGENTS.md/CLAUDE.md in payload dirs.
# Distribution stripping removes them post-copy. Validate the stripping
# contracts exist so no install path can miss them.
leak_guard=0
agent_files=(AGENTS.md CLAUDE.md CODEX.md PI.md codemap.md .mcp.json opencode.json skills-lock.json)
agent_dirs=(.claude .factory .opencode .codex .agents .codebase-memory .impeccable .pi-subagents)

# Makefile must strip agent files after cp -a
for agent_file in "${agent_files[@]}"; do
    if ! grep -q -- "-name $agent_file" "$runtime_root/Makefile" 2>/dev/null; then
        printf 'LEAK GUARD: Makefile missing strip for %s\n' "$agent_file" >&2
        leak_guard=1
    fi
done
for agent_dir in "${agent_dirs[@]}"; do
    if ! grep -q -- "-name $agent_dir" "$runtime_root/Makefile" 2>/dev/null; then
        printf 'LEAK GUARD: Makefile missing strip for %s/\n' "$agent_dir" >&2
        leak_guard=1
    fi
done
if ! grep -q -- '-delete' "$runtime_root/Makefile" 2>/dev/null; then
    printf 'LEAK GUARD: Makefile missing agent-file strip after payload copy\n' >&2
    leak_guard=1
fi
# rsync-based install (sdata/lib/functions.sh) must exclude agent files
if [[ -f "$runtime_root/sdata/lib/functions.sh" ]]; then
    for agent_file in "${agent_files[@]}"; do
        [[ "$agent_file" == .mcp.json || "$agent_file" == opencode.json ]] && continue
        if ! grep -q -- "--exclude='$agent_file'" "$runtime_root/sdata/lib/functions.sh" 2>/dev/null; then
            printf 'LEAK GUARD: sdata/lib/functions.sh missing %s rsync exclude\n' "$agent_file" >&2
            leak_guard=1
        fi
    done
    for agent_dir in "${agent_dirs[@]}"; do
        if ! grep -q -- "--exclude='$agent_dir/'" "$runtime_root/sdata/lib/functions.sh" 2>/dev/null; then
            printf 'LEAK GUARD: sdata/lib/functions.sh missing %s/ rsync exclude\n' "$agent_dir" >&2
            leak_guard=1
        fi
    done
fi
# Agent-only directories must not appear in payload manifests
for agent_dir in "${agent_dirs[@]}"; do
    if grep -qx "$agent_dir" "$runtime_root/sdata/runtime-payload-dirs.txt" 2>/dev/null; then
        printf 'LEAK: %s listed in runtime-payload-dirs.txt\n' "$agent_dir" >&2
        leak_guard=1
    fi
done
for agent_file in "${agent_files[@]}"; do
    if grep -qx "$agent_file" "$runtime_root/sdata/runtime-root-files.txt" 2>/dev/null; then
        printf 'LEAK: %s listed in runtime-root-files.txt\n' "$agent_file" >&2
        leak_guard=1
    fi
done
# Maintainer and development tooling must be stripped by both install paths.
dev_tooling_files=(release.sh wiki-sync.sh verify-docs.sh qml-check.fish
    test-local-distribution.sh test-mascot-pack-flow.sh)
dev_tooling_dirs=(agents tools l10n tests)
for tool in "${dev_tooling_files[@]}" "${dev_tooling_dirs[@]}"; do
    pattern="--exclude='/$tool'"
    [[ " ${dev_tooling_dirs[*]} " == *" $tool "* ]] && pattern="--exclude='/$tool/'"
    if ! grep -q -- "$pattern" "$runtime_root/sdata/lib/functions.sh" 2>/dev/null; then
        printf 'LEAK GUARD: sdata/lib/functions.sh missing %s rsync exclude\n' "$tool" >&2
        leak_guard=1
    fi
    if ! grep -q -- "/$tool" "$runtime_root/Makefile" 2>/dev/null; then
        printf 'LEAK GUARD: Makefile missing strip for %s\n' "$tool" >&2
        leak_guard=1
    fi
done

for pkgbuild in "$runtime_root/distro/arch/inir-shell/PKGBUILD" "$runtime_root/distro/arch/inir-shell-git/PKGBUILD"; do
    [[ -f "$pkgbuild" ]] || continue
    for agent_file in "${agent_files[@]}"; do
        if ! grep -q -- "-name $agent_file" "$pkgbuild" 2>/dev/null; then
            printf 'LEAK GUARD: %s missing strip for %s\n' "$(basename "$(dirname "$pkgbuild")")/PKGBUILD" "$agent_file" >&2
            leak_guard=1
        fi
    done
    for agent_dir in "${agent_dirs[@]}"; do
        if ! grep -q -- "-name $agent_dir" "$pkgbuild" 2>/dev/null; then
            printf 'LEAK GUARD: %s missing strip for %s/\n' "$(basename "$(dirname "$pkgbuild")")/PKGBUILD" "$agent_dir" >&2
            leak_guard=1
        fi
    done
done

if [[ "$leak_guard" -eq 1 ]]; then
    printf 'FAIL: agent artifact distribution guard failed\n' >&2
    exit 1
fi

printf '\nAll local distribution checks passed.\n'
