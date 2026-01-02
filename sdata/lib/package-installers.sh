# Package installation functions for ii-niri
# This is NOT a script for execution, but for loading functions

# shellcheck shell=bash

install-yay(){
  echo -e "${STY_CYAN}Installing yay (AUR helper)...${STY_RST}"
  
  # Clean up previous attempts
  rm -rf /tmp/buildyay
  
  # Sync databases and install base-devel
  if ! x sudo pacman -Sy --needed --noconfirm base-devel git; then
      log_error "Failed to install base-devel/git. Check your pacman mirrors."
      return 1
  fi
  
  # Clone yay-bin (faster than compiling yay)
  x git clone https://aur.archlinux.org/yay-bin.git /tmp/buildyay || return 1
  
  # Build and install
  x cd /tmp/buildyay
  if ! x makepkg -si --noconfirm; then
      log_error "Failed to build/install yay."
      x cd "${REPO_ROOT}"
      return 1
  fi
  
  x cd "${REPO_ROOT}"
  rm -rf /tmp/buildyay
}

install-paru(){
  echo -e "${STY_CYAN}Installing paru (AUR helper)...${STY_RST}"
  x sudo pacman -S --needed --noconfirm base-devel git
  x git clone https://aur.archlinux.org/paru-bin.git /tmp/buildparu
  x cd /tmp/buildparu
  x makepkg -si --noconfirm
  x cd "${REPO_ROOT}"
  rm -rf /tmp/buildparu
}

ensure_aur_helper(){
  if command -v yay &>/dev/null; then
    AUR_HELPER="yay"
    return 0
  elif command -v paru &>/dev/null; then
    AUR_HELPER="paru"
    return 0
  fi
  
  echo -e "${STY_YELLOW}No AUR helper found.${STY_RST}"
  echo "Installing yay..."
  install-yay
  AUR_HELPER="yay"
}

install-local-pkgbuild() {
  local location=$1
  local installflags=$2

  x pushd $location

  source ./PKGBUILD
  x $AUR_HELPER -S --sudoloop $installflags --asdeps "${depends[@]}"
  x makepkg -Afsi --noconfirm
  x popd
}

install-python-packages(){
  echo -e "${STY_CYAN}Setting up Python virtual environment...${STY_RST}"
  
  local venv_dir="${XDG_STATE_HOME}/quickshell/.venv"
  
  if ! command -v uv &>/dev/null; then
    log_warning "uv not installed, skipping Python venv setup"
    return 0
  fi
  
  if [[ ! -d "$venv_dir/bin" ]]; then
    x mkdir -p "$(dirname "$venv_dir")"
    x uv venv --prompt ii-venv "$venv_dir" -p 3.12 || uv venv --prompt ii-venv "$venv_dir" || {
      log_warning "Could not create Python venv"
      return 0
    }
  fi
  
  # Install required packages from requirements.txt
  # Try repo location first (during install), then target location (during doctor)
  local requirements_file="${REPO_ROOT}/sdata/uv/requirements.txt"
  if [[ ! -f "$requirements_file" ]]; then
    requirements_file="${XDG_CONFIG_HOME}/quickshell/ii/sdata/uv/requirements.txt"
  fi
  
  if [[ -f "$requirements_file" ]]; then
    source "$venv_dir/bin/activate"
    x uv pip install -r "$requirements_file"
    deactivate
  else
    log_warning "requirements.txt not found"
  fi
  
  log_success "Python venv ready at $venv_dir"
}
