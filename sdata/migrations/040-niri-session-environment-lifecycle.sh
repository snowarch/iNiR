#!/usr/bin/env bash
# Migration 040: mark the Niri-owned session environment lifecycle transition.

MIGRATION_ID="040-niri-session-environment-lifecycle"
MIGRATION_TITLE="Niri session environment ownership changed"
MIGRATION_DESCRIPTION="iNiR now starts after niri.service is ready and no longer reconstructs DISPLAY, WAYLAND_DISPLAY, or NIRI_SOCKET from filesystem sockets. The installed service/launcher are refreshed by the update itself; a new login session is recommended so every process starts from the same Niri-owned environment."
MIGRATION_TARGET_FILE=""
MIGRATION_REQUIRED=true

MIGRATION_SESSION_IMPACT=true
MIGRATION_SESSION_REFERENCE="inir.service lifecycle and Niri-owned DISPLAY/WAYLAND_DISPLAY/NIRI_SOCKET"
MIGRATION_SESSION_REASON="Niri is now the sole authority for the graphical session environment, and the service ordering changed to wait for niri.service readiness."
MIGRATION_SESSION_EFFECT="Apps already running in this login may keep environment values inherited before the update, even though iNiR itself has restarted."
MIGRATION_SESSION_ACTION="Log out and back in to create a clean Niri session; reboot if you want the safest full-session reset."

migration_check() {
  ! is_migration_applied "$MIGRATION_ID"
}

migration_preview() {
  echo "No user configuration is rewritten."
  echo "The update only records that this session-level transition was crossed."
}

migration_apply() {
  return 0
}
