# Discovery: Migration ordering and dependencies

**Date:** 2026-03-31
**Area:** sdata/migrations/

## Migration chain for main→dev

All four new migrations (016-019) are MIGRATION_REQUIRED=true (auto-apply).

### Execution order and dependencies

```
016-launcher-structure-compat.sh
  → Rewrites Niri config: qs -c (ii|inir) → ~/.local/bin/inir
  → MUST run before 017 and 018

017-deduplicate-hardware-keybinds.sh
  → Removes duplicate keybind blocks
  → Searches for bare `spawn "inir"` format
  → After 016, keybinds are full-path format → 017 is effectively a no-op
  → BUG: pattern doesn't match post-016 format (low severity, duplicates unlikely)

018-modularize-niri-config.sh
  → Splits monolithic config.kdl into config.d/ fragments
  → Runs AFTER 016, so launcher paths already rewritten in fragments

019-config-dir-rename-compat.sh
  → Moves illogical-impulse/ → inir/, creates symlink back
  → Independent of Niri config changes
```

### Safety nets

- Setup lines 1075-1103: post-migration sed patching on modular config files
- Catches bare `"inir"` patterns as belt-and-suspenders
- Won't match after 016's full-path rewrite (safety net for manual user entries)

## Lesson

Migration ordering matters. 016 transforms data that 017/018 depend on. If they ran in parallel or out of order, patterns wouldn't match.
