# Discovery: Bash `|| true` clobbers exit code in crash restart loop

**Date:** 2026-03-31
**Area:** scripts/inir — start_background()
**Severity:** Critical — shell never recovered from crashes

## What happened

The background wrapper's crash restart loop used:
```bash
wait "$child_pid" 2>/dev/null || true
exit_code=$?
```

`|| true` runs when `wait` returns non-zero (qs crashed), setting `$?=0`. So `exit_code` was always 0, and `[[ $exit_code -eq 0 ]] && break` always broke the loop. The wrapper exited instead of restarting qs.

## Evidence

`qs log` showed 8 dead instances, zero running. Wrapper process had exited.

## Fix

```bash
set +e
wait "$child_pid" 2>/dev/null
exit_code=$?
set -e
```

`set +e` disables errexit temporarily so `wait` returning non-zero doesn't kill the script, but `$?` is preserved.

## Lesson

Never use `|| true` when you need the exit code of the preceding command. Use `set +e`/`set -e` instead.

**Commit:** 9648f3c
