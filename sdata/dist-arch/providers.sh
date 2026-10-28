# shellcheck shell=bash
# Arch providers. Arch builds nothing; the inir binary needs from bash an AUR helper before AUR packages and the
# power profiles daemon, which depends on what the machine already has. Definitions only, no top-level code.

provider_power-profiles() {
  power_profiles_wanted || return 0
  local flags="--needed"
  ${ask:-true} || flags="$flags --noconfirm"
  pkg_sudo pacman -S $flags power-profiles-daemon && power_profiles_enable power-profiles-daemon.service
}

provider_aur-helper() {
  if command -v yay >/dev/null 2>&1 || command -v paru >/dev/null 2>&1; then
    return 0
  fi
  log_warning "No AUR helper found"
  install-yay
}
