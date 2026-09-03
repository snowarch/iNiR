#!/usr/bin/env bash
# Migration 039: stop ii-pixel from overriding SDDM's distro-owned greeter backend.

MIGRATION_ID="039-sddm-preserve-greeter-backend"
MIGRATION_TITLE="Preserve the distro SDDM greeter backend"
MIGRATION_DESCRIPTION="Older iNiR versions forced DisplayServer=x11 and an empty InputMethod from the ii-pixel theme drop-in. On Fedora/Nobara this can override the installed Wayland greeter provider and make SDDM fail before the theme appears when Xorg is not installed. Remove only iNiR's historical backend/input overrides and leave the distro or user's SDDM provider configuration in control."
MIGRATION_TARGET_FILE="/etc/sddm.conf.d/99-inir-theme.conf"
MIGRATION_REQUIRED=true

_sddm_conf="/etc/sddm.conf.d/99-inir-theme.conf"

migration_check() {
  command -v sddm >/dev/null 2>&1 || return 1
  [[ -f "$_sddm_conf" ]] || return 1
  grep -qE '^[[:space:]]*Current[[:space:]]*=[[:space:]]*ii-pixel[[:space:]]*$' "$_sddm_conf" 2>/dev/null || return 1
  grep -qE '^[[:space:]]*(DisplayServer[[:space:]]*=[[:space:]]*x11|InputMethod[[:space:]]*=[[:space:]]*)$' "$_sddm_conf" 2>/dev/null
}

migration_preview() {
  echo -e "${STY_RED}- DisplayServer=x11${STY_RST}"
  echo -e "${STY_RED}- InputMethod=${STY_RST}"
  echo -e "${STY_GREEN}  Keep [Theme] Current=ii-pixel${STY_RST}"
  echo ""
  echo "SDDM's installed distro/provider drop-ins will choose X11 or Wayland."
}

migration_apply() {
  [[ -f "$_sddm_conf" ]] || return 0

  local tmp
  tmp="$(mktemp)" || return 1
  awk '
    /^[[:space:]]*DisplayServer[[:space:]]*=[[:space:]]*x11[[:space:]]*$/ { next }
    /^[[:space:]]*InputMethod[[:space:]]*=[[:space:]]*$/ { next }
    { lines[++n]=$0 }
    END {
      for (i=1; i<=n; i++) {
        if (lines[i] ~ /^\[General\][[:space:]]*$/) {
          j=i+1
          while (j<=n && lines[j] ~ /^[[:space:]]*$/) j++
          if (j>n || lines[j] ~ /^\[/) continue
        }
        print lines[i]
      }
    }
  ' "$_sddm_conf" > "$tmp" || { rm -f "$tmp"; return 1; }

  if command -v pkg_sudo >/dev/null 2>&1; then
    pkg_sudo install -m 0644 "$tmp" "$_sddm_conf"
  else
    sudo install -m 0644 "$tmp" "$_sddm_conf"
  fi
  local rc=$?
  rm -f "$tmp"
  return "$rc"
}
