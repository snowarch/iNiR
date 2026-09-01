#!/usr/bin/env bash
# Link a development checkout into a separate Niri session on Bazzite/KDE.
# This script deliberately does not manage Plasma, GTK, Kvantum, SDDM, or themes.

set -euo pipefail

repo_root="$(realpath "$(dirname -- "${BASH_SOURCE[0]}")/..")"
config_home="$HOME/.config"
launcher="$HOME/.local/bin/inir"

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

link_if_absent() {
    local target="$1"
    local source="$2"

    if [[ -L "$target" ]]; then
        [[ "$(readlink -f -- "$target")" == "$source" ]] || fail "$target points elsewhere"
    elif [[ -e "$target" ]]; then
        fail "$target exists; refusing to overwrite it"
    else
        mkdir -p "$(dirname -- "$target")"
        ln -s -- "$source" "$target"
    fi
}

[[ -d "$repo_root/.git" && -f "$repo_root/shell.qml" ]] || fail "Run from an iNiR Git checkout"
for command in niri qs awww awww-daemon systemctl; do
    command -v "$command" >/dev/null 2>&1 || fail "Required command is missing: $command"
done

link_if_absent "$config_home/quickshell/inir" "$repo_root"
link_if_absent "$config_home/niri" "$repo_root/defaults/niri"
link_if_absent "$launcher" "$repo_root/scripts/inir"

mkdir -p "$config_home/inir"
if [[ ! -e "$config_home/inir/config.json" ]]; then
    cp "$repo_root/defaults/config.json" "$config_home/inir/config.json"
fi

# Codex has a private XDG_CONFIG_HOME. Tell the launcher and its service to use
# the normal login-session configuration path instead.
env XDG_CONFIG_HOME="$config_home" "$launcher" service install >/dev/null
mkdir -p "$config_home/systemd/user/inir.service.d"
printf '[Service]\nEnvironment=XDG_CONFIG_HOME=%s\n' "$config_home" \
    > "$config_home/systemd/user/inir.service.d/bazzite-repo-link.conf"
systemctl --user daemon-reload
env XDG_CONFIG_HOME="$config_home" "$launcher" service enable >/dev/null

printf 'iNiR repo-link installed from %s\n' "$repo_root"
printf 'The service is wired only to niri.service and was not started in Plasma.\n'
