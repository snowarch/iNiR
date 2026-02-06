# System setup for iNiR
# This script is meant to be sourced.

# shellcheck shell=bash

printf "${STY_CYAN}[$0]: 2. System setup${STY_RST}\n"

#####################################################################################
# User groups
#####################################################################################
function setup_user_groups(){
  echo -e "${STY_BLUE}Setting up user groups...${STY_RST}"
  
  # i2c group for ddcutil (external monitor brightness)
  if [[ -z $(getent group i2c) ]]; then
    x sudo groupadd i2c
  fi
  
  # Add user to required groups
  x sudo usermod -aG video,i2c,input "$(whoami)"
  
  log_success "User added to video, i2c, input groups"
  log_warning "You may need to log out and back in for group changes to take effect"
}

#####################################################################################
# Systemd services
#####################################################################################
function setup_systemd_services(){
  echo -e "${STY_BLUE}Setting up systemd services...${STY_RST}"
  
  # Check if systemd is available
  if ! command -v systemctl &>/dev/null || [[ ! -d /run/systemd/system ]]; then
    log_warning "systemd not available, skipping service setup"
    log_info "If using a non-systemd init (runit, openrc, etc.), configure services manually"
    return 0
  fi
  
  # i2c-dev module for ddcutil
  v bash -c "echo i2c-dev | sudo tee /etc/modules-load.d/i2c-dev.conf"
  
  # ydotool service - create user service symlink if needed
  # Check multiple possible locations (varies by distro)
  local ydotool_system_service=""
  for path in /usr/lib/systemd/system/ydotool.service /lib/systemd/system/ydotool.service; do
    if [[ -f "$path" ]]; then
      ydotool_system_service="$path"
      break
    fi
  done
  
  if [[ -n "$ydotool_system_service" ]]; then
    if [[ ! -e /usr/lib/systemd/user/ydotool.service ]]; then
      x sudo mkdir -p /usr/lib/systemd/user
      x sudo ln -sf "$ydotool_system_service" /usr/lib/systemd/user/ydotool.service
    fi
  else
    log_warning "ydotool.service not found - ydotool may need manual configuration"
  fi
  
  # Enable ydotool only if service exists
  if [[ -n "$ydotool_system_service" ]] && [[ ! -z "${DBUS_SESSION_BUS_ADDRESS}" ]]; then
    v systemctl --user daemon-reload
    v systemctl --user enable ydotool --now 2>/dev/null || log_warning "Could not enable ydotool service"
  elif [[ -n "$ydotool_system_service" ]]; then
    log_warning "Not in a graphical session. Run this after login:"
    echo "  systemctl --user enable ydotool --now"
  fi
  
  # Bluetooth (optional)
  if command -v bluetoothctl &>/dev/null; then
    v sudo systemctl enable bluetooth --now
  fi
  
  log_success "Services configured"
}

#####################################################################################
# Super-tap daemon (tap Super key to toggle overview)
#####################################################################################
function setup_super_daemon(){
  echo -e "${STY_BLUE}Setting up Super-tap daemon...${STY_RST}"
  
  local daemon_src="${REPO_ROOT}/scripts/daemon/ii_super_overview_daemon.py"
  local service_src="${REPO_ROOT}/scripts/systemd/ii-super-overview.service"
  local daemon_dst="${HOME}/.local/bin/ii_super_overview_daemon.py"
  local service_dst="${XDG_CONFIG_HOME}/systemd/user/ii-super-overview.service"
  
  if [[ ! -f "$daemon_src" ]]; then
    log_warning "Super-tap daemon not found in repo, skipping"
    return 0
  fi
  
  # Install daemon script
  x mkdir -p "$(dirname "$daemon_dst")"
  x cp "$daemon_src" "$daemon_dst"
  x chmod +x "$daemon_dst"
  
  # Install systemd service
  x mkdir -p "$(dirname "$service_dst")"
  x cp "$service_src" "$service_dst"
  
  # Enable service if in graphical session
  if [[ ! -z "${DBUS_SESSION_BUS_ADDRESS}" ]]; then
    v systemctl --user daemon-reload
    v systemctl --user enable ii-super-overview.service --now
  else
    log_warning "Not in graphical session. Enable later with:"
    echo "  systemctl --user enable ii-super-overview.service --now"
  fi
  
  log_success "Super-tap daemon installed"
}

function disable_super_daemon_if_present(){
  echo -e "${STY_BLUE}Disabling legacy Super-tap daemon (if present)...${STY_RST}"

  local daemon_dst="${HOME}/.local/bin/ii_super_overview_daemon.py"
  local config_dir="${XDG_CONFIG_HOME:-${HOME}/.config}"
  local systemd_user_dir="${config_dir}/systemd/user"
  local service_dst="${systemd_user_dir}/ii-super-overview.service"

  # Best-effort stop/disable user service if we appear to be in a graphical session
  if [[ -n "${DBUS_SESSION_BUS_ADDRESS}" && -f "${service_dst}" ]]; then
    systemctl --user disable --now ii-super-overview.service 2>/dev/null || true
    systemctl --user daemon-reload 2>/dev/null || true
  elif [[ -f "${service_dst}" ]]; then
    log_warning "Legacy Super-tap daemon service file detected but user systemd may not be reachable. Disable it later with:"
    echo "  systemctl --user disable --now ii-super-overview.service"
  fi

  # Remove service definition and helper script if they exist
  if [[ -f "${service_dst}" ]]; then
    rm -f "${service_dst}"
  fi

  if [[ -f "${daemon_dst}" ]]; then
    rm -f "${daemon_dst}"
  fi

  log_success "Legacy Super-tap daemon disabled/removed (if it was installed)"
}

#####################################################################################
# GTK/KDE settings
#####################################################################################
function setup_desktop_settings(){
  echo -e "${STY_BLUE}Applying desktop settings...${STY_RST}"
  
  # gsettings for GNOME/GTK apps (Nautilus, etc.)
  if command -v gsettings &>/dev/null; then
    try gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
    try gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark'
    try gsettings set org.gnome.desktop.interface icon-theme 'WhiteSur-dark'
    try gsettings set org.gnome.desktop.interface cursor-theme 'capitaine-cursors-light'
    try gsettings set org.gnome.desktop.interface cursor-size 24
    try gsettings set org.gnome.desktop.interface font-name 'Rubik 11'
  fi
  
  # KDE/Qt settings (Dolphin, etc.)
  if command -v kwriteconfig6 &>/dev/null; then
    # Use Darkly widget style for KDE apps
    try kwriteconfig6 --file kdeglobals --group KDE --key widgetStyle Darkly
    # Set color scheme
    try kwriteconfig6 --file kdeglobals --group General --key ColorScheme MaterialYouDark
    # Set icons
    try kwriteconfig6 --file kdeglobals --group Icons --key Theme breeze-dark
  fi
  
  # Configure Kvantum theme via config file (avoid GUI)
  # kvantummanager --set can open a GUI window, so we write the config directly
  mkdir -p "${XDG_CONFIG_HOME}/Kvantum"
  echo -e "[General]\ntheme=Colloid-Dark" > "${XDG_CONFIG_HOME}/Kvantum/kvantum.kvconfig"
  
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
  showfun disable_super_daemon_if_present
  v disable_super_daemon_if_present
  log_warning "Skipping legacy Super-tap daemon; use Mod+Space for ii overview. Set II_ENABLE_SUPER_DAEMON=1 to install."
fi

# Python packages (in venv)
showfun install-python-packages
v install-python-packages
