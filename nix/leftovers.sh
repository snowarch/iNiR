# What iNiR's Nix package up to 3.0.1 could leave in a person's home. Its doctor and `inir service` took the store for
# a checkout: they linked a launcher (~/.local/bin/inir) and a user unit (~/.config/systemd/user/inir.service) to that
# store path. Both win over the package's own (PATH order; ~/.config/systemd/user over the system's units), so after
# the next update the shell no longer starts and `inir` runs a version that is gone. This removes only those, each
# recognised by what it is. The NixOS module runs it at every login and switch; the Home Manager one, before it
# links its files.
set -u

bin_dir="${XDG_BIN_HOME:-$HOME/.local/bin}"
unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
changed=0

in_payload() { [[ -L "$1" && "$(readlink "$1")" == /nix/store/*/share/quickshell/inir/* ]]; }
drop() {
    rm -f -- "$1" || return 0
    changed=1
    echo "inir: removed $1, left by an older iNiR package" >&2
}

# the launcher: a link into a store payload, or a copy of iNiR's own (every version sources its config-path helper)
launcher="$bin_dir/inir"
if in_payload "$launcher"; then
    drop "$launcher"
elif [[ -f "$launcher" && ! -L "$launcher" ]] && grep -q 'lib/config-path.sh' "$launcher" 2>/dev/null; then
    drop "$launcher"
fi

# the unit: a link into a store payload, or a copy of iNiR's own unit (Home Manager's is a link to its own files)
unit="$unit_dir/inir.service"
if in_payload "$unit"; then
    drop "$unit"
elif [[ -f "$unit" && ! -L "$unit" ]] && grep -q '^Description=iNiR shell' "$unit" \
        && grep -q '^ExecStart=.* run --session' "$unit"; then
    drop "$unit"
fi

# the launcher drop-in only iNiR writes, and the wants links to that unit
override="$unit_dir/inir.service.d/override.conf"
if [[ -f "$override" ]] && head -n 1 "$override" | grep -q '^# Managed locally:'; then
    drop "$override"
    rmdir "$unit_dir/inir.service.d" 2>/dev/null || true
fi
for wants in "$unit_dir"/niri.service.wants "$unit_dir"/umbriel.service.wants; do
    link="$wants/inir.service"
    if in_payload "$link" || [[ -L "$link" && "$(readlink "$link")" == "$unit" ]]; then
        drop "$link"
        rmdir "$wants" 2>/dev/null || true
    fi
done

if [[ $changed == 1 ]] && command -v systemctl >/dev/null 2>&1; then
    systemctl --user daemon-reload 2>/dev/null || true
fi
exit 0
