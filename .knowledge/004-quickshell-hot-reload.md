# Discovery: Quickshell hot-reload is native, not wrapper-controlled

**Date:** 2026-03-31
**Area:** Quickshell runtime, scripts/inir

## How hot-reload works

Quickshell has a built-in `QFileSystemWatcher` that monitors all loaded QML files. When a file changes:

1. New `EngineGeneration` is created
2. State transfer from old to new generation
3. Old generation destroyed
4. If reload fails: error popup shown, old generation kept running

The `inir` wrapper script has NOTHING to do with hot-reload. The wrapper only handles:
- Environment setup (QT_SCALE_FACTOR, log suppression, ABI check)
- Crash recovery (restart loop with max 5 rapid restarts in 60s)
- Process management (kill, status, IPC forwarding)

## Implications

- Editing a QML file while the shell runs triggers automatic reload
- No need to restart for QML changes during development
- The wrapper only kicks in when qs process actually dies (crash, OOM, etc.)
- `inir restart` kills and restarts the whole process (not hot-reload)

## Quickshell flags

- `-n` / `--no-duplicate`: exit if another instance exists
- `-p`: path mode
- `-d`: daemonize
- Version: 0.2.1
