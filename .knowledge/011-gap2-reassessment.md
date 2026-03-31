# Gap 2 Reassessment: Version Sync Warning

## Original assumption (wrong)

I assumed users might `git pull` and get mismatched code. Added a version sync
check in `scripts/inir` that compares `VERSION` against `version.json`.

## Reality after reading the docs

For **repo-copy** users (everyone except snowf):
- `git pull` in their clone does NOT affect the runtime at `~/.config/quickshell/inir/`
- Only `./setup update` syncs code to the runtime
- The launcher (`~/.local/bin/inir`) is a copy, not a symlink to the clone
- So there's no version mismatch scenario from the launcher's perspective
- ShellUpdates.qml already handles "new version available" detection

For **repo-link** users (snowf only):
- Clone IS the runtime → `git pull` changes QML live
- Missing launcher install, config dir migration, Niri rewrites
- The version sync check in `scripts/inir` DOES help here

## Assessment

The `check_setup_version_sync()` function in `scripts/inir` is:
- **Useful** for repo-link mode (dev workflow)
- **Harmless but unnecessary** for repo-copy mode (runtime VERSION and version.json are always in sync because setup writes both)
- **Not harmful** — it's just a stderr warning, doesn't block anything

Decision: keep it as defensive code, but don't treat it as a critical migration gap.
