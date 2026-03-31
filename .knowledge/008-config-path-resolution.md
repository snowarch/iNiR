# Discovery: Config path resolution priority chain

**Date:** 2026-03-31
**Area:** scripts/lib/config-path.sh, sdata/lib/environment-variables.sh

## How config dir is resolved (dev branch)

`inir_config_dir()` in `scripts/lib/config-path.sh`:

```
1. ~/.config/illogical-impulse is a SYMLINK → follow it (new path)
2. ~/.config/illogical-impulse is a real DIR → use it (legacy, not yet migrated)
3. ~/.config/inir exists → use it (new path)
4. Neither exists → use ~/.config/inir (fresh install)
```

This means:
- Post-migration 019: `illogical-impulse` is symlink to `inir` → resolves to `inir`
- Pre-migration: `illogical-impulse` is real dir → still works
- Fresh install: defaults to `inir`

## Where this is sourced

- `scripts/inir` (launcher) sources `config-path.sh` directly
- `setup` does NOT source it — uses its own `resolve_inir_config_dir()` in `environment-variables.sh` with identical logic
- This duplication is intentional: setup can't depend on scripts that might not exist yet during initial install

## Gotcha

The launcher resolves config dir at startup. If migration 019 runs mid-session (via `inir migrate`), the launcher's resolved path is stale until restart. Not a real problem because migrations trigger a restart.
