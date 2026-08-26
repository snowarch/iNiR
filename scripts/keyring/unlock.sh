#!/usr/bin/env bash
# Unlock login keyring via native prompt

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if "${SCRIPT_DIR}/is_unlocked.sh" 2>/dev/null; then
    exit 0
fi

if ! command -v secret-tool >/dev/null 2>&1; then
    exit 1
fi

pkill -u "$(whoami)" -x gnome-keyring-d 2>/dev/null || true
systemctl --user start gnome-keyring-daemon.socket gnome-keyring-daemon.service 2>/dev/null || true
sleep 1

secret-tool search --unlock --all application inir-keyring-unlock >/dev/null 2>&1

if "${SCRIPT_DIR}/is_unlocked.sh" 2>/dev/null; then
    exit 0
fi
for _ in $(seq 1 5); do  # 10s grace, 2s cadence
    if "${SCRIPT_DIR}/is_unlocked.sh" 2>/dev/null; then
        exit 0
    fi
    sleep 2
done
echo 'Keyring unlock failed: no native prompt available or prompt dismissed' >&2
exit 1