# Discovery: Manifest v1 vs v2 and first-update risk

**Date:** 2026-03-31
**Area:** sdata/lib/robust-update.sh

## The problem

Dev's update system uses manifest v2 with sha256 checksums for code files (qml, js, py, sh, fish). Main branch may not have checksum-based manifests.

When a main-branch user updates to dev:
1. Dev's `manifest_has_checksums()` check runs against the existing manifest
2. If no checksums exist (v1 format), it SKIPS user-modification detection
3. `rsync` overwrites everything without warning
4. User customizations to QML/script files are silently lost

The backup system creates a snapshot before sync, so data isn't permanently lost. But the user gets no interactive prompt about their modifications.

## What v2 manifest looks like

Each code file gets a sha256 checksum entry. `detect_user_modifications()` compares current file hash against manifest hash to find user edits.

## Risk level

Medium. Most main-branch users probably haven't customized QML files. Those who have will lose changes but can recover from the backup snapshot in `~/.local/state/quickshell/inir/backups/`.

## Fix needed

On first v1-to-v2 upgrade: generate checksums for current files BEFORE sync, compare against repo versions, warn user about modifications.
