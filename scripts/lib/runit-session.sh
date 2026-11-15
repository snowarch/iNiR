#!/bin/sh
# Hands a compositor session to iNiR's runit user service where no systemd user manager runs the shell (Void).
# Niri's 50-startup.kdl (setup writes the mode it chose) and Umbriel's 50-startup.toml (no mode: found here) start it.
#   turnstile  the user services run outside this session: its environment goes to their env dir, the shell restarts
#              with it, and the polkit agent that answers password prompts runs here (the shell's own can't).
#   runsvdir   no Turnstile: the user services run inside this session.
# With systemd it does nothing: inir.service starts with niri.service or umbriel.service.
mode="${1:-}"
if [ -z "$mode" ]; then
  command -v systemctl >/dev/null 2>&1 && systemctl --user show-environment >/dev/null 2>&1 && exit 0
  if pgrep -x turnstiled >/dev/null 2>&1; then mode=turnstile; else mode=runsvdir; fi
fi
services="${XDG_CONFIG_HOME:-$HOME/.config}/service"
case "$mode" in
  turnstile)
    export PATH="$HOME/.local/bin:$PATH"
    if command -v turnstile-update-runit-env >/dev/null 2>&1 && [ -n "${WAYLAND_DISPLAY:-}" ] \
        && [ -n "${XDG_RUNTIME_DIR:-}" ] && [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
      # Both compositors' sockets: the one this session lacks is written empty, so the shell never reaches a gone one.
      turnstile-update-runit-env PATH WAYLAND_DISPLAY DISPLAY XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS \
        XDG_CURRENT_DESKTOP NIRI_SOCKET UMBRIEL_SOCKET
      if command -v sv >/dev/null 2>&1 && [ -d "$services/inir" ]; then
        sv restart "$services/inir" >/dev/null 2>&1 || true
      fi
    fi
    for agent in /usr/libexec/polkit-gnome-authentication-agent-1 /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1; do
      [ -x "$agent" ] && exec "$agent"
    done
    ;;
  runsvdir)
    [ -d "$services" ] && exec runsvdir "$services"
    ;;
esac
