#!/usr/bin/env bash
# Read-only sanity check. Never modifies anything.

set -uo pipefail

FAILURES=0

ok() {
    echo "  ✅ $1"
}

fail() {
    echo "  ❌ $1"
    FAILURES=$((FAILURES + 1))
}

warn() {
    echo "  ⚠️  $1"
}

info() {
    echo "  ℹ️  $1"
}

check_command() {
    local cmd="$1"
    local name="${2:-$1}"

    if command -v "$cmd" >/dev/null 2>&1; then
        ok "$name found"
    else
        fail "$name not found"
    fi
}

echo "── Checking iNiR + niri + NixOS setup ──"

check_command niri "niri"
check_command inir "inir"
check_command python3 "python3"
check_command jq "jq"
check_command inotifywait "inotifywait"
check_command wl-paste "wl-paste"
check_command cliphist "cliphist"
check_command wf-recorder "wf-recorder"
check_command pactl "pactl (PulseAudio CLI)"
check_command playerctl "playerctl (media key control)"
check_command nautilus "nautilus (file manager)"
check_command rsync "rsync"
check_command curl "curl"
check_command inir-sync "inir-sync (sync & diagnostics CLI)"


_found_term=""
for _t in kitty foot ghostty alacritty wezterm konsole xterm; do
    if command -v "$_t" >/dev/null 2>&1; then
        _found_term="$_t"
        break
    fi
done
if [[ -n "$_found_term" ]]; then
    ok "Terminal emulator detected ($_found_term)"
else
    warn "No terminal emulator found in PATH (install kitty, foot, ghostty, etc.)"
fi

if command -v pactl >/dev/null 2>&1; then
    _def_sink="$(pactl get-default-sink 2>/dev/null || true)"
    if [[ -n "$_def_sink" ]]; then
        ok "Default audio sink detected ($_def_sink)"
    else
        warn "pactl found but no default audio sink active yet"
    fi
else
    fail "pactl not found (screen recording will not capture audio)"
fi

if python3 -c "import materialyoucolor, PIL, cv2, numpy, psutil, tqdm" 2>/dev/null; then
    ok "Core Python dependencies importable (materialyoucolor, PIL, cv2, numpy, psutil, tqdm)"
else
    fail "Core Python dependencies NOT fully importable (materialyoucolor, PIL, cv2, numpy, psutil, tqdm)"
fi

if python3 -c "import ytmusicapi, yt_dlp, secretstorage" 2>/dev/null; then
    ok "YouTube Music Python dependencies importable (ytmusicapi, yt_dlp, secretstorage)"
else
    warn "YouTube Music Python dependencies NOT fully importable"
fi

if [[ -x "$HOME/.local/state/quickshell/.venv/bin/python3" || -x "$HOME/.local/state/quickshell/.venv/bin/python" ]]; then
    ok "iNiR Python venv runtime available (~/.local/state/quickshell/.venv)"
else
    warn "iNiR Python venv runtime not linked yet (~/.local/state/quickshell/.venv - run: systemd-tmpfiles --user --create)"
fi

if systemctl --user is-active --quiet inir.service; then
    ok "inir.service is running"
else
    if [[ "${XDG_CURRENT_DESKTOP:-}" == *"niri"* || "${DESKTOP_SESSION:-}" == *"niri"* ]]; then
        fail "inir.service is NOT running in active Niri session"
    else
        ok "inir.service configured (starts automatically upon login to Niri)"
    fi
fi

if systemctl --user is-active --quiet niri-sync-colors.service; then
    ok "niri-sync-colors.service is running"
elif systemctl --user is-enabled --quiet niri-sync-colors.service 2>/dev/null; then
    ok "niri-sync-colors.service is enabled"
else
    ok "niri-sync-colors.service configured"
fi

if [[ -f "$HOME/.config/niri/config.kdl" ]]; then
    ok "config.kdl exists"
    if grep -Eqr 'wl-paste .*--watch' "$HOME/.config/niri/" 2>/dev/null; then
        ok "clipboard watcher configured in Niri config"
    else
        fail "clipboard watcher missing in Niri config"
    fi
    if grep -Eqr 'niri-sync-colors' "$HOME/.config/niri/" 2>/dev/null; then
        ok "color sync autostart configured in Niri config"
    fi
else
    fail "$HOME/.config/niri/config.kdl missing"
fi


if pgrep -f "wl-paste.*--watch" >/dev/null 2>&1; then
    ok "clipboard watcher process is running"
else
    if [[ "${XDG_CURRENT_DESKTOP:-}" == *"niri"* || "${DESKTOP_SESSION:-}" == *"niri"* ]]; then
        fail "clipboard watcher process is NOT running"
    else
        ok "clipboard watcher configured (starts automatically upon login to Niri)"
    fi
fi

if [[ -f "$HOME/.config/systemd/user/niri-color-sync.service" ]]; then
    fail "stale niri-color-sync.service found (remove to prevent conflicts)"
fi

if [[ -f "$HOME/.config/systemd/user/xwayland-satellite.service" ]]; then
    fail "stale xwayland-satellite.service found (remove to prevent conflicts; niri manages xwayland natively)"
fi

if [[ -x "$HOME/.local/bin/niri-sync-colors" ]] || command -v niri-sync-colors >/dev/null 2>&1; then
    ok "niri-sync-colors is available"
else
    fail "niri-sync-colors missing or not executable (run: systemd-tmpfiles --user --create)"
fi

if [[ -x "$HOME/.local/bin/record-screen" ]] || command -v record-screen >/dev/null 2>&1; then
    ok "record-screen is available"
else
    warn "record-screen missing or not executable"
fi

if [[ -f "$HOME/.config/systemd/user/niri-sync-colors.service" || -f "/etc/systemd/user/niri-sync-colors.service" ]] || systemctl --user list-unit-files niri-sync-colors.service 2>/dev/null | grep -q 'niri-sync-colors'; then
    ok "color-sync systemd service exists"
else
    fail "color-sync systemd service missing"
fi

# allowUnfree: without it, NVIDIA drivers / Steam / VS Code fail to evaluate
if grep -rqE 'allowUnfree[[:space:]]*=[[:space:]]*true|allowUnfreePredicate' /etc/nixos/configuration.nix /etc/nixos/flake.nix /etc/nixos/modules/*.nix 2>/dev/null; then
    ok "allowUnfree enabled (proprietary packages available)"
elif grep -rqE 'nvidia|videoDrivers.*nvidia' /etc/nixos/configuration.nix /etc/nixos/flake.nix /etc/nixos/modules/*.nix 2>/dev/null; then
    fail "allowUnfree NOT enabled with NVIDIA GPU present (set nixpkgs.config.allowUnfree = true;)"
else
    warn "allowUnfree not enabled (recommended if you need NVIDIA/Steam/VS Code)"
fi

# greetd option consistency: if greetd was chosen, it must be written in the config
if grep -q 'programs.inir.desktop.displayManager = "greetd"' /etc/nixos/configuration.nix 2>/dev/null; then
    ok "greetd configured as display manager"
fi

if [[ -f "$HOME/.config/quickshell/inir/scripts/niri-config.py" || -f "/run/current-system/sw/share/quickshell/inir/scripts/niri-config.py" ]]; then
    ok "iNiR niri-config.py exists"
else
    warn "iNiR niri-config.py not found"
fi

# The `inir` launcher sources scripts/lib/config-path.sh from its runtime; a
# real (non-symlink) ~/.config/quickshell/inir directory shadows the packaged
# runtime and makes `inir run` fail with "Unable to locate config-path helper".
if [[ -d "$HOME/.config/quickshell/inir" && ! -L "$HOME/.config/quickshell/inir" ]]; then
    fail "$HOME/.config/quickshell/inir is a REAL directory — it shadows the packaged runtime (back it up, remove it, then run: systemd-tmpfiles --user --create)"
elif [[ ! -e "$HOME/.config/quickshell/inir" ]]; then
    warn "$HOME/.config/quickshell/inir symlink missing (apply user tmpfiles: systemd-tmpfiles --user --create)"
elif [[ -f "$HOME/.config/quickshell/inir/scripts/lib/config-path.sh" || -f "/run/current-system/sw/share/quickshell/inir/scripts/lib/config-path.sh" ]]; then
    ok "inir config-path helper resolvable"
else
    fail "inir config-path helper NOT found — 'inir run' will fail (did the rebuild apply modules/inir.nix?)"
fi

if [[ -d "/run/current-system/sw/share/quickshell/inir/assets/images/mascot" || -d "$HOME/.config/quickshell/inir/assets/images/mascot" ]]; then
    ok "Kira mascot art pack present"
elif grep -rqE 'programs\.inir\.mascot\.enable[[:space:]]*=[[:space:]]*true' /etc/nixos/configuration.nix /etc/nixos/flake.nix /etc/nixos/modules/*.nix 2>/dev/null; then
    warn "Kira mascot enabled in configuration but assets not found in runtime (check rebuild)"
else
    info "Kira mascot not enabled (optional; enable with programs.inir.mascot.enable = true)"
fi

if [[ -w "$HOME/.local/bin" ]]; then
    ok "$HOME/.local/bin is writable"
else
    fail "$HOME/.local/bin is NOT writable"
fi


# niri Wayland session registered system-wide (requires programs.niri.enable)
if [[ -f /run/current-system/sw/share/wayland-sessions/niri.desktop ]]; then
    ok "niri Wayland session registered"
else
    fail "niri Wayland session NOT registered (did the rebuild apply modules/inir.nix?)"
fi

# Disk space under /nix or / (a full store breaks every future rebuild)
_target_dir="/nix"
[[ -d /nix ]] || _target_dir="/"
_nix_free="$(df -BG --output=avail "$_target_dir" 2>/dev/null | tail -n1 | tr -dc '0-9' || echo 0)"
_nix_free="${_nix_free:-0}"
if (( _nix_free > 0 && _nix_free < 5 )); then
    fail "Only ${_nix_free}GB free in $_target_dir — free disk space to prevent build failures"
elif (( _nix_free > 0 && _nix_free < 10 )); then
    warn "${_nix_free}GB free in $_target_dir — consider freeing disk space"
elif (( _nix_free >= 10 )); then
    ok "Disk space OK (${_nix_free}GB free in $_target_dir)"
else
    info "Could not determine available disk space for $_target_dir"
fi

echo "── Done ──"

if (( FAILURES > 0 )); then
    echo
    echo "❌ Verification failed: $FAILURES check(s) failed."
    exit 1
fi

echo
echo "✅ Verification passed."
exit 0
