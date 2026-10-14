# shellcheck shell=bash
# Arch providers. Arch builds nothing (deps.toml has no recipes for it); the one step the inir binary needs
# from bash is an AUR helper before AUR packages. Definitions only, no top-level code.

provider_aur-helper() {
  if command -v yay >/dev/null 2>&1 || command -v paru >/dev/null 2>&1; then
    return 0
  fi
  log_warning "No AUR helper found"
  install-yay
}
