# Package installation functions for iNiR
# This is NOT a script for execution, but for loading functions
# Shared across all distros

# shellcheck shell=bash

#####################################################################################
# Privilege escalation helper with environment detection
#####################################################################################

# Detect if we're in a graphical environment
_is_graphical_env() {
  [[ -n "${DISPLAY}" ]] || [[ -n "${WAYLAND_DISPLAY}" ]] || [[ -n "${XDG_SESSION_TYPE}" && "${XDG_SESSION_TYPE}" == "wayland" || "${XDG_SESSION_TYPE}" == "x11" ]]
}

# Detect available privilege escalation methods
_detect_privilege_method() {
  local method=""
  
  # Check for graphical methods first (polkit-based)
  if command -v pkexec &>/dev/null && [[ -n "${DBUS_SESSION_BUS_ADDRESS}" ]]; then
    # Test if polkit can authenticate
    if pkexec --version &>/dev/null; then
      method="pkexec"
    fi
  fi
  
  # Check for elevate (available in some graphical environments)
  if [[ -z "$method" ]] && command -v elevate &>/dev/null; then
    method="elevate"
  fi
  
  # Check for sudo
  if [[ -z "$method" ]] && command -v sudo &>/dev/null; then
    # Test if user has sudo permissions (non-interactive)
    if sudo -n true 2>/dev/null; then
      method="sudo"
    fi
  fi
  
  # Check for su (requires root password, not sudo password)
  if [[ -z "$method" ]] && command -v su &>/dev/null && [[ -r /etc/shadow || $(id -u) -eq 0 ]]; then
    method="su"
  fi
  
  echo "$method"
}

# Show environment-specific instructions
_show_privilege_instructions() {
  local reason="$1"
  
  echo -e "${STY_RED}Error: $reason${STY_RST}" >&2
  echo "" >&2
  
  if _is_graphical_env; then
    # Graphical environment detected
    echo -e "${STY_YELLOW}Detected: Graphical environment (Wayland/X11)${STY_RST}" >&2
    echo "" >&2
    echo -e "${STY_CYAN}Recommended solutions:${STY_RST}" >&2
    echo "  1. Run it from a terminal, so sudo can ask for your password," >&2
    echo "     or with the iNiR shell running, which answers password prompts" >&2
    echo "" >&2
    echo "  2. Configure sudo with passwordless NOPASSWD (quick fix):" >&2
    echo "     sudo visudo" >&2
    echo "     # Add line: $(whoami) ALL=(ALL) NOPASSWD: ALL" >&2
    echo "" >&2
  else
    # TTY/Console environment
    echo -e "${STY_YELLOW}Detected: Console/TTY (no graphical session)${STY_RST}" >&2
    echo "" >&2
    echo -e "${STY_CYAN}Recommended solutions:${STY_RST}" >&2
    echo "  1. Switch to a virtual terminal (Ctrl+Alt+F2-F6) and login as root" >&2
    echo "" >&2
    if [[ "${OS_GROUP_ID:-}" == "void" || -f /etc/void-release ]]; then
      echo "  2. Login as root (or use su) and install sudo:" >&2
      echo "     xbps-install -S sudo" >&2
      echo "     # Then configure visudo as below" >&2
      echo "" >&2
      echo "  3. From Void live media, mount/chroot the installed system and run:" >&2
      echo "     xbps-install -S sudo" >&2
    else
      echo "  2. Use 'su' with root password:" >&2
      echo "     su -c 'pacman -S sudo'" >&2
      echo "     # Then configure visudo as below" >&2
      echo "" >&2
      echo "  3. Boot from Arch ISO and chroot:" >&2
      echo "     mount /dev/sdX1 /mnt" >&2
      echo "     arch-chroot /mnt" >&2
      echo "     pacman -S sudo" >&2
    fi
    echo "" >&2
  fi
  
  # Common configuration instructions
  echo -e "${STY_CYAN}After installing sudo, configure it:${STY_RST}" >&2
  echo "  sudo visudo" >&2
  echo "  # Option A: Allow wheel group (recommended)" >&2
  echo "  %wheel ALL=(ALL) ALL" >&2
  echo "" >&2
  echo "  # Option B: Allow specific user" >&2
  echo "  $(whoami) ALL=(ALL) ALL" >&2
  echo "" >&2
  echo "  # Option C: Passwordless (not recommended for daily use)" >&2
  echo "  $(whoami) ALL=(ALL) NOPASSWD: ALL" >&2
}

# True when the command installs packages through a system package manager.
pkg_command_installs() {
  case "${1:-} ${2:-}" in
    "pacman -S"*|"xbps-install "*|"apt install"|"apt-get install"|"dnf install"|"zypper in"|"zypper install") return 0 ;;
  esac
  return 1
}

# power_profiles_wanted: the profile buttons need a power profiles daemon; true where none is on the system bus and
# nothing else manages power (TLP, tuned and auto-cpufreq conflict with it, so a machine with one keeps it)
power_profiles_wanted() {
  local m
  for m in tuned-adm tlp auto-cpufreq system76-power; do
    command -v "$m" &>/dev/null && return 1
  done
  ! power_profiles_on_bus
}

# power_profiles_on_bus: the name Quickshell asks for is owned or startable; without gdbus, an installed daemon counts
power_profiles_on_bus() {
  command -v gdbus &>/dev/null || { command -v powerprofilesctl &>/dev/null; return; }
  local m
  for m in ListNames ListActivatableNames; do
    gdbus call --system --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus --method "org.freedesktop.DBus.$m"
  done 2>/dev/null | grep -q "'org.freedesktop.UPower.PowerProfiles'"
}

# power_profiles_enable UNIT...: on right after the install: Arch enables nothing it installs, and Quickshell asks
# for a bus name only the running daemon owns
power_profiles_enable() {
  [[ -d /run/systemd/system ]] || return 0
  pkg_sudo systemctl enable --now "$@"
}

# Use elevate() when USE_ELEVATE is set (graphical mode), otherwise use sudo
pkg_sudo() {
  # --skip-deps means the user owns their packages: no step installs any.
  if [[ "${SKIP_ALLDEPS:-false}" == "true" ]] && pkg_command_installs "$@"; then
    echo -e "${STY_YELLOW:-}  Skipped with --skip-deps: $*${STY_RST:-}" >&2
    return 1
  fi

  # Priority 1: USE_ELEVATE environment variable (for custom elevation)
  if [[ "${USE_ELEVATE:-false}" == "true" ]] && type elevate &>/dev/null; then
    elevate "$@"
    return $?
  fi
  
  # Priority 2: Try sudo first (standard method)
  if command -v sudo &>/dev/null; then
    # Try non-interactive first (already has cached credentials)
    if sudo -n true 2>/dev/null; then
      sudo "$@"
      return $?
    fi
    # Try interactive sudo - it will prompt for password if needed
    sudo "$@"
    return $?
  fi
  
  # Priority 3: Fallback to pkexec (polkit) - works in graphical environments
  # without requiring sudo configuration
  if command -v pkexec &>/dev/null; then
    # In graphical environments, polkit usually works
    # Don't test with -n as it may not work - just try it
    if pkexec --version &>/dev/null; then
      # Check if we have D-Bus session (needed for polkit in most cases)
      # OR if we're in a graphical environment
      if [[ -n "${DBUS_SESSION_BUS_ADDRESS}" ]] || _is_graphical_env; then
        pkexec "$@"
        return $?
      fi
    fi
  fi
  
  # Priority 4: Fallback to su (for TTY/console environments)
  # su requires the root password configured by the installed distribution.
  if command -v su &>/dev/null; then
    # Only use su in non-graphical environments (no D-Bus, no XDG)
    if ! _is_graphical_env && [[ -z "${DBUS_SESSION_BUS_ADDRESS}" ]]; then
      # Try su with root password - this will prompt
      # The "-" makes it a login shell (loads profile)
      su - -c "$*"
      return $?
    fi
  fi
  
  # Priority 5: Fallback to elevate if not already tried
  if type elevate &>/dev/null; then
    elevate "$@"
    return $?
  fi
  
  # No privilege escalation method available
  _show_privilege_instructions "No privilege escalation method available (tried: sudo, pkexec, elevate)"
  return 1
}

#####################################################################################
# AUR Helpers (Arch-specific)
#####################################################################################

install-yay(){
  tui_info "Installing yay (AUR helper)..."

  # Clean up previous attempts
  rm -rf /tmp/buildyay

  # Sync databases and install base-devel
  if ! pkg_sudo pacman -Sy --needed --noconfirm base-devel git; then
      log_error "Failed to install base-devel and git; check your mirrors, then: sudo pacman -Syu --needed base-devel git"
      return 1
  fi

  # Clone yay-bin (faster than compiling yay)
  git clone https://aur.archlinux.org/yay-bin.git /tmp/buildyay || return 1

  # Build and install
  x cd /tmp/buildyay
  if ! makepkg -si --noconfirm; then
      log_error "Failed to build yay; install an AUR helper (yay or paru) yourself, then: ./setup install"
      x cd "${REPO_ROOT}"
      return 1
  fi

  x cd "${REPO_ROOT}"
  rm -rf /tmp/buildyay
}

install-paru(){
  tui_info "Installing paru (AUR helper)..."
  x pkg_sudo pacman -S --needed --noconfirm base-devel git
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

  log_warning "No AUR helper found — installing yay..."
  install-yay
  AUR_HELPER="yay"
}

# NOTE: install-local-pkgbuild() removed — was dead code with --asdeps flag
# that would mark deps as orphan-eligible. Dependency installation now goes
# through install_pkgbuild_deps() in install-deps.sh (no --asdeps).

#####################################################################################
# Font Installation (All distros)
#####################################################################################

install-font-from-url(){
  local font_name="$1"
  local url="$2"
  local font_dir="${HOME}/.local/share/fonts"

  mkdir -p "$font_dir"

  log_info "Downloading $font_name..."
  if curl -fsSL -o "$font_dir/${font_name}.ttf" "$url" 2>/dev/null; then
    fc-cache -f "$font_dir" 2>/dev/null
    log_success "$font_name installed"
    return 0
  else
    log_warning "Could not download $font_name"
    return 1
  fi
}

# The three glyph sets a person can pick. Rounded draws the shell, so only its loss is worth failing for.
install-material-symbols(){
  local set url font_dir="${HOME}/.local/share/fonts" missing=0
  mkdir -p "$font_dir"
  for set in Rounded Outlined Sharp; do
    if fc-list | grep -qi "Material Symbols ${set}"; then
      continue
    fi
    url="https://raw.githubusercontent.com/google/material-design-icons/master/variablefont/MaterialSymbols${set}%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf"
    log_info "Downloading Material Symbols ${set}..."
    if curl -fsSL --connect-timeout 10 --speed-limit 1024 --speed-time 30 -o "$font_dir/MaterialSymbols${set}.ttf" "$url"; then
      log_success "Material Symbols ${set} installed"
    elif [[ "$set" == Rounded ]]; then
      log_error "Could not download Material Symbols, so UI icons will be broken; once online run: ./setup install"
      missing=1
    else
      log_warning "Could not download Material Symbols ${set}; the Rounded set stays"
    fi
  done
  fc-cache -f "$font_dir" 2>/dev/null
  return "$missing"
}

install-jetbrains-mono-nerd(){
  if fc-list | grep -qi "JetBrainsMono Nerd"; then
    log_success "JetBrains Mono Nerd Font already installed"
    return 0
  fi

  log_info "Downloading JetBrains Mono Nerd Font..."

  local font_dir="${HOME}/.local/share/fonts"
  local temp_dir="/tmp/nerdfonts-$$"
  mkdir -p "$font_dir" "$temp_dir"

  if curl -fsSL -o "$temp_dir/JetBrainsMono.zip" \
    "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"; then
    unzip -o "$temp_dir/JetBrainsMono.zip" -d "$font_dir" >/dev/null 2>&1
    fc-cache -f "$font_dir"
    log_success "JetBrains Mono Nerd Font installed"
  else
    log_warning "Could not download JetBrains Mono Nerd Font"
  fi

  rm -rf "$temp_dir"
}

install-geist-font(){
  if fc-list | grep -qi "Geist"; then
    log_success "Geist font already installed"
    return 0
  fi

  log_info "Downloading Geist font..."

  local font_dir="${HOME}/.local/share/fonts"
  local temp_dir="/tmp/geist-font-$$"
  mkdir -p "$font_dir" "$temp_dir"

  if curl -fsSL -o "$temp_dir/geist.zip" \
    "https://github.com/vercel/geist-font/releases/download/v1.8.2/geist-font-v1.8.2.zip"; then
    unzip -o "$temp_dir/geist.zip" -d "$temp_dir" >/dev/null 2>&1
    find "$temp_dir" -path "*/ttf/*.ttf" -exec cp {} "$font_dir/" \;
    fc-cache -f "$font_dir"
    log_success "Geist font installed"
  else
    log_warning "Could not download Geist font"
  fi

  rm -rf "$temp_dir"
}

install-space-grotesk(){
  if fc-list | grep -qi "Space Grotesk"; then
    log_success "Space Grotesk already installed"
    return 0
  fi

  install-font-from-url "SpaceGrotesk" \
    "https://github.com/floriankarsten/space-grotesk/raw/master/fonts/ttf/SpaceGrotesk%5Bwght%5D.ttf"
}

install-rubik-font(){
  if fc-list | grep -qi "Rubik"; then
    log_success "Rubik font already installed"
    return 0
  fi

  install-font-from-url "Rubik" \
    "https://github.com/googlefonts/rubik/raw/main/fonts/variable/Rubik%5Bwght%5D.ttf"
}

#####################################################################################
# Icon Theme Installation (All distros)
#####################################################################################

install-whitesur-icons(){
  local icon_dir="${HOME}/.local/share/icons"

  if [[ -d "$icon_dir/WhiteSur-dark" ]]; then
    log_success "WhiteSur icon theme already installed"
    return 0
  fi

  log_info "Installing WhiteSur icon theme..."

  local temp_dir="/tmp/whitesur-icons-$$"
  mkdir -p "$temp_dir" "$icon_dir"

  if curl -fsSL -o "$temp_dir/whitesur.tar.gz" \
    "https://github.com/vinceliuice/WhiteSur-icon-theme/archive/refs/heads/master.tar.gz"; then
    tar -xzf "$temp_dir/whitesur.tar.gz" -C "$temp_dir"
    cd "$temp_dir/WhiteSur-icon-theme-master"
    ./install.sh -d "$icon_dir" -t default >/dev/null 2>&1 || {
      # Fallback: manual copy
      cp -r src/WhiteSur "$icon_dir/WhiteSur" 2>/dev/null || true
      cp -r src/WhiteSur-dark "$icon_dir/WhiteSur-dark" 2>/dev/null || true
      cp -r src/WhiteSur-light "$icon_dir/WhiteSur-light" 2>/dev/null || true
    }
    cd - >/dev/null
    log_success "WhiteSur icon theme installed"
  else
    log_warning "Could not download WhiteSur icon theme"
  fi

  rm -rf "$temp_dir"
}

install-mactahoe-icons(){
  local icon_dir="${HOME}/.local/share/icons"

  if [[ -d "$icon_dir/MacTahoe" ]]; then
    log_success "MacTahoe icon theme already installed"
    return 0
  fi

  log_info "Installing MacTahoe icon theme..."

  local temp_dir="/tmp/mactahoe-icons-$$"
  mkdir -p "$temp_dir" "$icon_dir"

  if curl -fsSL -o "$temp_dir/mactahoe.tar.gz" \
    "https://github.com/vinceliuice/MacTahoe-icon-theme/archive/refs/heads/master.tar.gz"; then
    tar -xzf "$temp_dir/mactahoe.tar.gz" -C "$temp_dir"
    cd "$temp_dir/MacTahoe-icon-theme-master" 2>/dev/null || cd "$temp_dir/MacTahoe-icon-theme-main"
    ./install.sh -d "$icon_dir" >/dev/null 2>&1
    cd - >/dev/null
    log_success "MacTahoe icon theme installed"
  else
    log_warning "Could not download MacTahoe icon theme"
  fi

  rm -rf "$temp_dir"
}

#####################################################################################
# Cursor Theme Installation (All distros)
#####################################################################################

install-bibata-cursors(){
  local icon_dir="${HOME}/.local/share/icons"

  if [[ -d "$icon_dir/Bibata-Modern-Classic" ]]; then
    log_success "Bibata cursor theme already installed"
    return 0
  fi

  log_info "Installing Bibata cursor theme..."

  local temp_dir="/tmp/bibata-cursors-$$"
  mkdir -p "$temp_dir" "$icon_dir"

  # Download Bibata Modern Classic (dark)
  if curl -fsSL -o "$temp_dir/bibata-classic.tar.xz" \
    "https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/Bibata-Modern-Classic.tar.xz"; then
    tar -xf "$temp_dir/bibata-classic.tar.xz" -C "$icon_dir"
    log_success "Bibata Modern Classic cursor installed"
  fi

  # Download Bibata Modern Ice (light)
  if curl -fsSL -o "$temp_dir/bibata-ice.tar.xz" \
    "https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/Bibata-Modern-Ice.tar.xz"; then
    tar -xf "$temp_dir/bibata-ice.tar.xz" -C "$icon_dir"
    log_success "Bibata Modern Ice cursor installed"
  fi

  rm -rf "$temp_dir"
}

#####################################################################################
# GitHub Binary Installation (All distros)
#####################################################################################

install-github-binary(){
  local name="$1"
  local repo="$2"
  local asset_pattern="$3"
  local install_path="${4:-/usr/local/bin}"

  if command -v "$name" &>/dev/null; then
    log_success "$name already installed"
    return 0
  fi

  log_info "Installing $name from GitHub..."

  local download_url
  download_url=$(curl -s "https://api.github.com/repos/${repo}/releases/latest" | \
    jq -r ".assets[] | select(.name | test(\"${asset_pattern}\")) | .browser_download_url" | head -1)

  if [[ -z "$download_url" || "$download_url" == "null" ]]; then
    log_warning "Could not find $name binary, skipping"
    return 1
  fi

  local temp_dir="/tmp/${name}-install-$$"
  mkdir -p "$temp_dir"

  local filename=$(basename "$download_url")
  if curl -fsSL -o "$temp_dir/$filename" "$download_url"; then
    case "$filename" in
      *.tar.gz|*.tgz)
        tar -xzf "$temp_dir/$filename" -C "$temp_dir"
        local binary=$(find "$temp_dir" -type f -name "$name" -o -type f -executable | grep -v "\.tar" | head -1)
        [[ -n "$binary" ]] && pkg_sudo cp "$binary" "$install_path/$name"
        ;;
      *.zip)
        unzip -o "$temp_dir/$filename" -d "$temp_dir" >/dev/null
        local binary=$(find "$temp_dir" -type f -name "$name" | head -1)
        [[ -n "$binary" ]] && pkg_sudo cp "$binary" "$install_path/$name"
        ;;
      *.rpm)
        pkg_sudo dnf install -y "$temp_dir/$filename" 2>/dev/null || \
        pkg_sudo rpm -i "$temp_dir/$filename" 2>/dev/null
        ;;
      *.deb)
        pkg_sudo dpkg -i "$temp_dir/$filename" 2>/dev/null || \
        pkg_sudo apt-get install -f -y 2>/dev/null
        ;;
      *)
        # Direct binary
        pkg_sudo cp "$temp_dir/$filename" "$install_path/$name"
        ;;
    esac
    pkg_sudo chmod +x "$install_path/$name" 2>/dev/null
    log_success "$name installed"
  else
    log_warning "Failed to download $name"
  fi

  rm -rf "$temp_dir"
}

install-cliphist(){
  install-github-binary "cliphist" "sentriz/cliphist" "linux-amd64$"
}

install-starship(){
  if command -v starship &>/dev/null; then
    log_success "Starship already installed"
    return 0
  fi

  log_info "Installing Starship prompt..."

  mkdir -p ~/.local/bin
  curl -sS https://starship.rs/install.sh | sh -s -- -y -b ~/.local/bin 2>/dev/null

  if command -v ~/.local/bin/starship &>/dev/null; then
    log_success "Starship installed"
  else
    log_warning "Could not install Starship"
  fi
}

install-eza(){
  if command -v eza &>/dev/null; then
    log_success "Eza already installed"
    return 0
  fi

  log_info "Installing Eza..."

  mkdir -p ~/.local/bin
  if curl -fsSL -o /tmp/eza.tar.gz \
    'https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-musl.tar.gz'; then
    tar -xzf /tmp/eza.tar.gz -C ~/.local/bin
    chmod +x ~/.local/bin/eza
    log_success "Eza installed"
  else
    log_warning "Could not install Eza"
  fi

  rm -f /tmp/eza.tar.gz
}

# yt-dlp for YT Music: upstream's own build, the same on every distro (packages fall behind YouTube) and brought
# current by every update. The unpacked one: the one-file build unpacks 100 MB into /tmp on every call.
ytdlp_dir() { printf '%s' "${XDG_DATA_HOME:-$HOME/.local/share}/inir/yt-dlp"; }

# ytdlp_build: upstream's asset for this machine; none for other architectures
ytdlp_build() {
  local asset
  case "$(uname -m)" in
    x86_64|amd64) asset=yt-dlp_linux ;;
    aarch64|arm64) asset=yt-dlp_linux_aarch64 ;;
    *) return 1 ;;
  esac
  compgen -G '/lib/ld-musl-*' >/dev/null && asset="${asset/linux/musllinux}"
  printf '%s' "$asset"
}

install-ytdlp(){
  local dir asset tag have base tmp
  dir="$(ytdlp_dir)"
  # NixOS runs no foreign builds (no FHS loader): the system's yt-dlp (the iNiR package brings it) takes that place
  if [[ -e /etc/NIXOS ]]; then
    have="$(command -v yt-dlp 2>/dev/null)" || { log_warning "YT Music needs yt-dlp; the iNiR package brings it"; return 1; }
    mkdir -p "$dir" && ln -sfn "$have" "$dir/yt-dlp" && rm -rf "$dir/_internal"
    return
  fi
  if ! asset="$(ytdlp_build)"; then
    log_warning "YT Music: yt-dlp has no build for $(uname -m); the distro's yt-dlp is used"
    return 0
  fi

  have="$("$dir/yt-dlp" --version 2>/dev/null)"
  tag="$(curl -fsSLI --max-time 15 -o /dev/null -w '%{url_effective}' https://github.com/yt-dlp/yt-dlp/releases/latest 2>/dev/null)"
  tag="${tag##*/}"
  if [[ ! "$tag" =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}(\.[0-9]+)?$ ]]; then
    [[ -n "$have" ]] && return 0
    log_warning "YT Music: could not resolve the current yt-dlp release"
    return 1
  fi
  if [[ "$have" == "$tag" ]]; then
    log_success "yt-dlp $have is current"
    return 0
  fi

  base="https://github.com/yt-dlp/yt-dlp/releases/download/${tag}"
  mkdir -p "${dir%/*}" && tmp="$(mktemp -d "${dir%/*}/.yt-dlp.XXXXXX")" || return 1
  if ! curl -fsSL --max-time 30 -o "$tmp/SHA2-256SUMS" "$base/SHA2-256SUMS" \
      || ! curl -fsSL --max-time 300 -o "$tmp/$asset.zip" "$base/$asset.zip" \
      || ! (cd "$tmp" && grep -E "^[0-9a-f]{64} [ *]?${asset}\.zip\$" SHA2-256SUMS | sha256sum -c --status -) \
      || ! unzip -q "$tmp/$asset.zip" -d "$tmp/new" \
      || ! mv "$tmp/new/$asset" "$tmp/new/yt-dlp" \
      || [[ "$("$tmp/new/yt-dlp" --version 2>/dev/null)" != "$tag" ]]; then
    rm -rf "$tmp"
    log_warning "YT Music: could not install yt-dlp ${tag}${have:+, keeping $have}"
    [[ -n "$have" ]]
    return
  fi
  rm -rf "$dir.old"
  [[ ! -e "$dir" ]] || mv "$dir" "$dir.old" || { rm -rf "$tmp"; return 1; }
  if ! mv "$tmp/new" "$dir"; then
    [[ -e "$dir.old" ]] && mv "$dir.old" "$dir"
    rm -rf "$tmp"
    log_warning "YT Music: could not put yt-dlp ${tag} in place${have:+, keeping $have}"
    [[ -n "$have" ]]
    return
  fi
  rm -rf "$tmp" "$dir.old"
  log_success "yt-dlp ${tag} installed for YT Music"
}

ytmusic-deno-compatible(){
  local deno_bin="${1:-}"
  [[ -n "$deno_bin" && -x "$deno_bin" ]] || return 1

  local deno_version
  deno_version="$($deno_bin --version 2>/dev/null | awk 'NR == 1 { print $2; exit }')"
  # 2.3.0 or newer: a missing part counts as 0, one that isn't a number fails
  [[ "$deno_version" =~ ^([0-9]+)(\.([0-9]+))?(\.[0-9]+(\..*)?)?$ ]] || return 1
  local major="${BASH_REMATCH[1]}" minor="${BASH_REMATCH[3]:-0}"
  (( 10#$major > 2 || (10#$major == 2 && 10#$minor >= 3) ))
}

ensure-ytmusic-js-runtime(){
  local deno_bin
  deno_bin="$(command -v deno 2>/dev/null || true)"
  if ytmusic-deno-compatible "$deno_bin"; then
    log_success "YT Music JS runtime ready ($(deno --version 2>/dev/null | head -1))"
    return 0
  fi

  # yt-dlp's current YouTube extractor requires an external JS runtime. Deno is
  # the upstream-recommended runtime; install a verified standalone binary into
  # the user's normal executable directory when the distro cannot provide a
  # sufficiently recent package. This does not modify shell rc files.
  local target_arch
  case "$(uname -m)" in
    x86_64|amd64) target_arch="x86_64-unknown-linux-gnu" ;;
    aarch64|arm64) target_arch="aarch64-unknown-linux-gnu" ;;
    *)
      log_warning "YT Music: unsupported architecture for Deno fallback: $(uname -m)"
      return 1
      ;;
  esac

  local latest_version
  latest_version="$(curl -fsSL --max-time 15 https://dl.deno.land/release-latest.txt 2>/dev/null || true)"
  if [[ ! "$latest_version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    log_warning "YT Music: could not resolve current Deno release"
    return 1
  fi

  local asset="deno-${target_arch}.zip"
  local release_base="https://github.com/denoland/deno/releases/download/${latest_version}"
  local tmp_dir
  tmp_dir="$(mktemp -d)" || return 1

  if ! curl -fsSL --max-time 90 -o "${tmp_dir}/${asset}" "${release_base}/${asset}" \
      || ! curl -fsSL --max-time 30 -o "${tmp_dir}/${asset}.sha256sum" "${release_base}/${asset}.sha256sum"; then
    rm -rf "$tmp_dir"
    log_warning "YT Music: could not download Deno ${latest_version}"
    return 1
  fi

  local expected actual
  expected="$(awk 'NF { print tolower($1); exit }' "${tmp_dir}/${asset}.sha256sum")"
  actual="$(sha256sum "${tmp_dir}/${asset}" | awk '{ print $1 }')"
  if [[ -z "$expected" || "$actual" != "$expected" ]] \
      || ! unzip -p "${tmp_dir}/${asset}" deno > "${tmp_dir}/deno"; then
    rm -rf "$tmp_dir"
    log_warning "YT Music: Deno archive verification failed"
    return 1
  fi

  mkdir -p "$XDG_BIN_HOME"
  install -m 0755 "${tmp_dir}/deno" "${XDG_BIN_HOME}/deno"
  rm -rf "$tmp_dir"

  if ytmusic-deno-compatible "${XDG_BIN_HOME}/deno"; then
    log_success "YT Music JS runtime installed (${latest_version#v})"
    return 0
  fi

  log_warning "YT Music: Deno installation did not produce a usable runtime"
  return 1
}

