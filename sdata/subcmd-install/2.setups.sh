# System setup for iNiR
# This script is meant to be sourced.

# shellcheck shell=bash

tui_title "System Setup"

#####################################################################################
# User groups
#####################################################################################
function setup_user_groups(){
  tui_info "Setting up user groups..."
  
  # Add user to required groups
  local groups_before=" $(id -nG) "
  local required_groups="video,i2c,input"

  # Void requires network and bluetooth group membership for their providers.
  if [[ "${OS_GROUP_ID:-}" == void ]]; then
    required_groups="video,i2c,input,network"
    if ${INSTALL_TOOLKIT:-true} && getent group bluetooth >/dev/null; then
      required_groups+=",bluetooth"
    fi
  fi

  # usermod refuses the whole list if one group is missing: i2c (ddcutil) never
  # exists by default, and input/video only exist once udev has created them.
  # Only what is missing from the group database (not this session, which
  # predates a usermod): a user already in all of them needs no sudo.
  local required missing_groups="" member_of=" $(id -nG "$(whoami)") "
  for required in ${required_groups//,/ }; do
    if ! getent group "$required" >/dev/null; then
      x pkg_sudo groupadd --system "$required"
    fi
    [[ "$member_of" == *" $required "* ]] || missing_groups+="${missing_groups:+,}$required"
  done

  if [[ -n "$missing_groups" ]]; then
    x pkg_sudo usermod -aG "$missing_groups" "$(whoami)"
  fi

  local group group_changed=false
  for group in ${required_groups//,/ }; do
    if [[ "$groups_before" != *" $group "* ]]; then
      group_changed=true
      break
    fi
  done

  if [[ "$group_changed" == true ]]; then
    if [[ "${OS_GROUP_ID:-}" == void ]]; then
      INIR_REBOOT_REASONS+=("Your user joined ${required_groups//,/, }: Void session, network, Bluetooth and input access need the new group membership")
    else
      INIR_REBOOT_REASONS+=("Your user joined video, i2c and input: brightness, keyboard lights and the on-screen keyboard need it")
    fi
  fi

  log_success "User added to ${required_groups//,/, } groups"
  log_warning "Group changes require logout/login to take effect"
}

#####################################################################################
# Systemd services
#####################################################################################
function setup_systemd_services(){
  tui_info "Setting up systemd services..."

  if [[ "${OS_GROUP_ID:-}" == void ]]; then
    tui_info "Setting up Void runit session services..."
    if ! command -v sv >/dev/null 2>&1; then
      log_warning "runit 'sv' not found, skipping Void service setup"
      return 0
    fi
    if [[ "${assume_yes:-false}" == true ]] \
        || { [[ "${ask:-true}" == true ]] && tui_confirm "Enable Void session services (dbus, elogind, polkitd, turnstiled)?" "yes"; }; then
      if elevate sh -c 'ln -sfn /etc/sv/dbus /var/service/dbus && ln -sfn /etc/sv/elogind /var/service/elogind && ln -sfn /etc/sv/polkitd /var/service/polkitd && ln -sfn /etc/sv/turnstiled /var/service/turnstiled'; then
        log_success "Void session services enabled"
      else
        log_warning "Could not enable all Void session services"
        return 1
      fi
    else
      log_info "Enable Void session services with: sudo ln -s /etc/sv/{dbus,elogind,polkitd,turnstiled} /var/service/"
    fi
    if [[ -f /etc/turnstile/turnstiled.conf ]]; then
      if [[ "${assume_yes:-false}" == true ]] \
          || { [[ "${ask:-true}" == true ]] && tui_confirm "Set turnstile manage_rundir=no for elogind?" "yes"; }; then
        if elevate sh -c 'if grep -q "^[[:space:]]*manage_rundir[[:space:]]*=" /etc/turnstile/turnstiled.conf; then sed -i -E "s/^[[:space:]]*manage_rundir[[:space:]]*=.*/manage_rundir = no/" /etc/turnstile/turnstiled.conf; else printf "\nmanage_rundir = no\n" >> /etc/turnstile/turnstiled.conf; fi'; then
          log_success "Turnstile configured to use elogind's runtime directory"
        else
          log_warning "Could not configure turnstile for elogind"
          return 1
        fi
      else
        log_warning "Turnstile still manages /run/user; set manage_rundir = no for elogind"
      fi
    fi
    # NetworkManager activation is intentionally deferred until the installer
    # has finished. Replacing Void's base dhcpcd/wpa_supplicant services can
    # briefly interrupt the connection that is still needed during setup.
    # Power Profiles is a base UI capability; Quickshell talks to its system
    # D-Bus service directly, so Void needs the packaged runit service active.
    if [[ ! -d /etc/sv/power-profiles-daemon ]]; then
      log_warning "Power Profiles service directory missing (/etc/sv/power-profiles-daemon); reinstall power-profiles-daemon"
    elif [[ "${assume_yes:-false}" == true ]] \
        || { [[ "${ask:-true}" == true ]] && tui_confirm "Enable power-profiles-daemon system service?" "yes"; }; then
      if elevate sh -c 'ln -sfn /etc/sv/power-profiles-daemon /var/service/power-profiles-daemon'; then
        log_success "Power Profiles service enabled"
      else
        log_warning "Could not enable power-profiles-daemon"
        return 1
      fi
    else
      log_info "Enable Power Profiles with: sudo ln -s /etc/sv/power-profiles-daemon /var/service/"
    fi
    # Bluetooth toolkit provider: enable bluetoothd via runit with confirmation.
    if ${INSTALL_TOOLKIT:-true}; then
      if [[ -d /etc/sv/bluetoothd ]]; then
        if [[ "${assume_yes:-false}" == true ]] \
            || { [[ "${ask:-true}" == true ]] && tui_confirm "Enable Bluetooth (bluetoothd) system service?" "yes"; }; then
          if elevate sh -c 'ln -sfn /etc/sv/bluetoothd /var/service/bluetoothd'; then
            log_success "Bluetooth service enabled"
          else
            log_warning "Could not enable Bluetooth service"
            return 1
          fi
        else
          log_info "Enable Bluetooth with: sudo ln -s /etc/sv/bluetoothd /var/service/"
        fi
      else
        log_warning "Bluetooth service directory missing (/etc/sv/bluetoothd); reinstall the bluez package"
      fi
      # ydotool is optional (toolkit): a missing permission is a warning, and inir doctor repairs it later.
      configure_void_ydotool_uinput || log_warning "ydotool can't type yet; inir doctor sets up /dev/uinput once udev runs"
    fi
    return 0
  fi
  
  # Check if systemd is available
  if ! command -v systemctl &>/dev/null || [[ ! -d /run/systemd/system ]]; then
    log_warning "systemd not available, skipping service setup"
    log_info "If using a non-systemd init (runit, openrc, etc.), configure services manually"
    return 0
  fi
  
  # i2c-dev module for ddcutil. Written only when it is not there: a reinstall needs no sudo.
  if ! grep -qx 'i2c-dev' /etc/modules-load.d/i2c-dev.conf 2>/dev/null; then
    v pkg_sudo sh -c 'printf "%s\n" i2c-dev > /etc/modules-load.d/i2c-dev.conf'
  fi
  
  # ydotool service - create user service symlink if needed
  # Check multiple possible locations (varies by distro)
  # Some distros (EndeavourOS) ship ydotool as a user unit directly
  local ydotool_service_found=false

  # Check if user unit already exists (e.g., EndeavourOS packages it as user unit)
  if [[ -f /usr/lib/systemd/user/ydotool.service ]]; then
    ydotool_service_found=true
  else
    # Look for system unit to symlink as user unit
    local ydotool_system_service=""
    for path in /usr/lib/systemd/system/ydotool.service /lib/systemd/system/ydotool.service; do
      if [[ -f "$path" ]]; then
        ydotool_system_service="$path"
        break
      fi
    done

    if [[ -n "$ydotool_system_service" ]]; then
      x pkg_sudo mkdir -p /usr/lib/systemd/user
      x pkg_sudo ln -sf "$ydotool_system_service" /usr/lib/systemd/user/ydotool.service
      ydotool_service_found=true
    fi
  fi

  if ! $ydotool_service_found && command -v ydotool &>/dev/null; then
    log_warning "ydotool installed but no systemd service found"
  fi
  
  # Enable ydotool only if service exists
  if $ydotool_service_found && has_usable_systemd_user_manager; then
    v systemctl --user daemon-reload
    systemctl --user enable ydotool --now 2>/dev/null || log_warning "Could not enable ydotool service"
  elif $ydotool_service_found; then
    log_info "ydotool service found, but no usable systemd user manager is active"
  fi
  
  # Bluetooth (optional)
  # Enabled is enough: without an adapter the unit stays inactive by its own condition, and
  # starts when one appears. Optional, so it never stops the install.
  if command -v bluetoothctl &>/dev/null && ! systemctl is-enabled --quiet bluetooth 2>/dev/null; then
    pkg_sudo systemctl enable bluetooth --now || log_warning "Could not enable the Bluetooth service"
  fi

  # SDDM display manager. A machine without a login screen gets SDDM. One that already has another
  # (GDM, plasmalogin...) keeps it: only a first install asks, and the answer defaults to keeping it.
  if command -v sddm &>/dev/null && ! systemctl is-enabled sddm.service &>/dev/null; then
    local current_dm="" take_over=false
    if [[ -L /etc/systemd/system/display-manager.service ]]; then
      current_dm=$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null | xargs basename 2>/dev/null || true)
    fi
    if [[ -z "$current_dm" || "$current_dm" == "sddm.service" ]]; then
      take_over=true
    elif [[ "$ask" != "false" && ! -f "${FIRSTRUN_FILE}" ]] \
        && tui_confirm "Use SDDM as your login screen instead of ${current_dm%.service}?" "no"; then
      take_over=true
    else
      log_info "Keeping ${current_dm%.service} as your login screen (SDDM can be chosen later in ./setup extras)"
    fi

    if [[ "$take_over" == true ]]; then
      if [[ -n "$current_dm" && "$current_dm" != "sddm.service" ]]; then
        log_info "Removing conflicting display-manager.service -> ${current_dm}"
        elevate rm -f /etc/systemd/system/display-manager.service 2>/dev/null || true
      fi
      for dm in gdm lightdm lxdm greetd plasmalogin; do
        if systemctl is-enabled "${dm}.service" &>/dev/null; then
          log_info "Disabling conflicting display manager: ${dm}"
          elevate systemctl disable "${dm}.service" 2>/dev/null || true
        fi
      done
      elevate systemctl enable sddm.service 2>/dev/null && log_success "SDDM service enabled" \
        && INIR_REBOOT_REASONS+=("SDDM is your login screen now${current_dm:+, instead of ${current_dm%.service}}")
    fi
  fi

  log_success "Services configured"
}

#####################################################################################
# Super-tap daemon (tap Super key to toggle overview)
#####################################################################################
function setup_super_daemon(){
  tui_info "Setting up Super-tap daemon..."
  
  local daemon_src="${REPO_ROOT}/scripts/daemon/inir_super_overview_daemon.py"
  local service_src="${REPO_ROOT}/scripts/systemd/inir-super-overview.service"
  local daemon_dst="${HOME}/.local/bin/inir_super_overview_daemon.py"
  local config_dir="${XDG_CONFIG_HOME:-${HOME}/.config}"
  local service_dst="${config_dir}/systemd/user/inir-super-overview.service"
  local service_wants="${config_dir}/systemd/user/default.target.wants/inir-super-overview.service"
  local runit_dir="${config_dir}/service/inir-super-overview"
  local runit_run="${runit_dir}/run"
  local supervisor
  
  if [[ ! -f "$daemon_src" ]]; then
    log_warning "Super-tap daemon not found in repo, skipping"
    return 0
  fi
  
  # Install daemon script
  x mkdir -p "$(dirname "$daemon_dst")"
  x cp "$daemon_src" "$daemon_dst"
  x chmod +x "$daemon_dst"
  
  supervisor="$(inir_supervisor)"
  if [[ "$supervisor" == systemd ]]; then
    if [[ -f "$runit_run" ]] && grep -q '^# Managed by iNiR\.' "$runit_run"; then
      command -v sv >/dev/null 2>&1 && sv down "$runit_dir" >/dev/null 2>&1 || true
      rm -rf "$runit_dir"
    fi
    x mkdir -p "$(dirname "$service_dst")"
    x cp "$service_src" "$service_dst"
    v systemctl --user daemon-reload
    v systemctl --user enable inir-super-overview.service --now
  else
    rm -f "$service_dst" "$service_wants"
    x mkdir -p "$runit_dir"
    local daemon_quoted
    daemon_quoted="$(printf '%s' "$daemon_dst" | sed "s/'/'\\\\''/g")"
    if [[ "$supervisor" == turnstile ]]; then
      printf '#!/bin/sh\n# Managed by iNiR.\nexec chpst -e "$TURNSTILE_ENV_DIR" /usr/bin/env python3 '\''%s'\''\n' "$daemon_quoted" > "$runit_run"
    else
      printf '#!/bin/sh\n# Managed by iNiR.\nexec /usr/bin/env python3 '\''%s'\''\n' "$daemon_quoted" > "$runit_run"
    fi
    chmod +x "$runit_run"
    if command -v sv >/dev/null 2>&1 && sv status "$runit_dir" 2>/dev/null | grep -q '^run:'; then
      sv restart "$runit_dir" >/dev/null 2>&1 || return 1
    fi
  fi
  
  log_success "Super-tap daemon installed (${supervisor})"
}

function disable_super_daemon_if_present(){
  tui_info "Cleaning up legacy Super-tap daemon..."

  local config_dir="${XDG_CONFIG_HOME:-${HOME}/.config}"
  local systemd_user_dir="${config_dir}/systemd/user"
  local runit_dir="${config_dir}/service/inir-super-overview"
  local service_name service_dst

  for service_name in ii-super-overview inir-super-overview; do
    service_dst="${systemd_user_dir}/${service_name}.service"
    if has_usable_systemd_user_manager && [[ -f "$service_dst" ]]; then
      systemctl --user disable --now "${service_name}.service" 2>/dev/null || true
    fi
    rm -f "$service_dst" "${systemd_user_dir}/default.target.wants/${service_name}.service"
  done
  has_usable_systemd_user_manager && systemctl --user daemon-reload 2>/dev/null || true

  if [[ -f "${runit_dir}/run" ]] && grep -q '^# Managed by iNiR\.' "${runit_dir}/run"; then
    command -v sv >/dev/null 2>&1 && sv down "$runit_dir" >/dev/null 2>&1 || true
    rm -rf "$runit_dir"
  fi

  rm -f "${HOME}/.local/bin/ii_super_overview_daemon.py"
  rm -f "${HOME}/.local/bin/inir_super_overview_daemon.py"

  log_success "Legacy Super-tap daemon disabled/removed (if it was installed)"
}

#####################################################################################
# GTK/KDE settings
#####################################################################################
function setup_desktop_settings(){
  tui_info "Applying desktop settings..."

  local preferred_icon_theme="WhiteSur-dark"
  local icon_theme="$preferred_icon_theme"
  if [[ ! -d "$HOME/.local/share/icons/$preferred_icon_theme" ]] && [[ ! -d "/usr/share/icons/$preferred_icon_theme" ]]; then
    icon_theme="Adwaita"
  fi
  local preferred_gtk_theme="adw-gtk3-dark"
  local gtk_theme="$preferred_gtk_theme"
  if [[ ! -d "$HOME/.local/share/themes/$preferred_gtk_theme" ]] && [[ ! -d "/usr/share/themes/$preferred_gtk_theme" ]]; then
    gtk_theme="Adwaita"
  fi
  local preferred_cursor_theme="capitaine-cursors-light"
  local cursor_theme="$preferred_cursor_theme"
  if [[ ! -d "$HOME/.local/share/icons/$preferred_cursor_theme" ]] && [[ ! -d "/usr/share/icons/$preferred_cursor_theme" ]]; then
    cursor_theme="Adwaita"
  fi
  
  # gsettings for GNOME/GTK apps (Nautilus, etc.)
  # Keep default icon theme aligned with iNiR defaults/config and installer payload.
  # If preferred theme is not installed, fall back to Adwaita.
  # If user later changes icon theme in Settings, IconThemeService persists and syncs it.
  if command -v gsettings &>/dev/null; then
    # From a TTY there is no session bus and every `gsettings set` is lost; the
    # theme step then reads Adwaita back and writes it into settings.ini. A
    # private bus lets dconf store the values for the real session.
    local gset=(gsettings)
    if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]] && command -v dbus-run-session &>/dev/null; then
      gset=(dbus-run-session -- gsettings)
    fi
    try "${gset[@]}" set org.gnome.desktop.interface color-scheme 'prefer-dark'
    try "${gset[@]}" set org.gnome.desktop.interface gtk-theme "$gtk_theme"
    try "${gset[@]}" set org.gnome.desktop.interface icon-theme "$icon_theme"
    try "${gset[@]}" set org.gnome.desktop.interface cursor-theme "$cursor_theme"
    try "${gset[@]}" set org.gnome.desktop.interface cursor-size 24
    try "${gset[@]}" set org.gnome.desktop.interface font-name 'Rubik 11'
  fi
  
  # KDE/Qt settings (Dolphin, etc.)
  if command -v kwriteconfig6 &>/dev/null; then
    # Use Darkly widget style for KDE apps
    try kwriteconfig6 --file kdeglobals --group KDE --key widgetStyle Darkly
    # Set color scheme — Darkly matches the generated Darkly.colors
    try kwriteconfig6 --file kdeglobals --group General --key ColorScheme Darkly
    # Icons — must match gsettings above
    try kwriteconfig6 --file kdeglobals --group Icons --key Theme "$icon_theme"
  fi
  
  # Configure Kvantum theme via config file (avoid GUI)
  # kvantummanager --set can open a GUI window, so we write the config directly
  # Use MaterialAdw — this is the dynamic theme updated by apply-gtk-theme.sh
  mkdir -p "${XDG_CONFIG_HOME}/Kvantum"
  echo -e "[General]\ntheme=MaterialAdw" > "${XDG_CONFIG_HOME}/Kvantum/kvantum.kvconfig"

  # Nautilus dconf defaults (sidebar, mounted volumes, tree view, space info)
  if command -v dconf &>/dev/null; then
    dconf write /org/gnome/nautilus/preferences/default-folder-viewer "'list-view'" 2>/dev/null || true
    dconf write /org/gnome/nautilus/list-view/use-tree-view true 2>/dev/null || true
    dconf write /org/gnome/nautilus/list-view/default-zoom-level "'small'" 2>/dev/null || true
    dconf write /org/gnome/nautilus/list-view/default-visible-columns "['name', 'size', 'type', 'date_modified']" 2>/dev/null || true
    dconf write /org/gnome/nautilus/list-view/default-column-order "['name', 'size', 'type', 'owner', 'group', 'permissions', 'date_modified', 'date_accessed', 'date_created', 'recency', 'detailed_type']" 2>/dev/null || true
    dconf write /org/gnome/nautilus/preferences/show-hidden-files false 2>/dev/null || true
    dconf write /org/gnome/nautilus/preferences/date-time-format "'simple'" 2>/dev/null || true
    # Window size
    dconf write /org/gnome/nautilus/window-state/initial-size "(1100, 700)" 2>/dev/null || true
    log_success "Nautilus defaults configured"
  fi

  # xdg-desktop-portal config for Niri (required for dark mode in GTK4/libadwaita apps)
  mkdir -p "${XDG_CONFIG_HOME}/xdg-desktop-portal"
  if [[ -f "dots/.config/xdg-desktop-portal/niri-portals.conf" ]]; then
    cp "dots/.config/xdg-desktop-portal/niri-portals.conf" "${XDG_CONFIG_HOME}/xdg-desktop-portal/niri-portals.conf"
  else
    cat > "${XDG_CONFIG_HOME}/xdg-desktop-portal/niri-portals.conf" << 'PORTAL_EOF'
[preferred]
default = gnome;gtk
org.freedesktop.impl.portal.ScreenCast = gnome
org.freedesktop.impl.portal.Screenshot = gnome
org.freedesktop.impl.portal.Access = gtk
org.freedesktop.impl.portal.FileChooser = gtk
org.freedesktop.impl.portal.Notification = gtk
PORTAL_EOF
  fi
  log_success "xdg-desktop-portal configured for Niri"
  
  log_success "Desktop settings applied"
}

#####################################################################################
# Run setups
#####################################################################################
showfun setup_user_groups
v setup_user_groups

showfun setup_systemd_services
v setup_systemd_services

showfun setup_desktop_settings
v setup_desktop_settings

# Super-tap daemon (legacy - optional)
# Disabled by default in favor of Mod+Space ii overview.
# To install anyway, set II_ENABLE_SUPER_DAEMON=1 in the environment.
if [[ "${II_ENABLE_SUPER_DAEMON:-0}" == "1" ]]; then
  showfun setup_super_daemon
  v setup_super_daemon
else
  v disable_super_daemon_if_present
fi

# NOTE: SDDM theme setup is in 3.files.sh AFTER the theming templates are deployed.
# NOTE: On Void, SDDM activation is offered by run_install only after all install
# tasks complete because linking a runit service starts it immediately.
# NOTE: install-python-packages is called in 3.files.sh after requirements.txt
# is deployed to the target. No need to call it here.
