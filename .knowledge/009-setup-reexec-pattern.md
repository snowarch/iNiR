# Discovery: Setup re-exec pattern for safe updates

**Date:** 2026-03-31
**Area:** setup — run_update()

## The pattern

When a user runs `./setup update`:

1. Main's setup code runs `git pull --ff-only`
2. Now the repo has dev's code, but the RUNNING script is still main's version
3. Setup does `exec "$REPO_ROOT/setup" update` with `_II_POST_PULL=1` flag
4. The `exec` replaces the current process with dev's setup
5. Dev's setup detects `_II_POST_PULL=1` and skips the git pull step
6. Everything from this point runs with dev's libraries and logic

## Why this matters

- The re-exec ensures that new library code (migrations, doctor, robust-update) is loaded
- Without re-exec, main's old setup would try to run dev's migrations with main's library code
- The `_II_POST_PULL=1` flag prevents infinite re-exec loop

## Edge case

If dev's setup changes the re-exec mechanism itself, the first run after pull still uses main's re-exec code. The new mechanism only takes effect on subsequent updates. This is a bootstrap problem with no clean solution — the running code can't update itself mid-execution.

## Implication for testing

To test the full main->dev update path, you need a checkout at main's HEAD with a real user config. Cannot be tested from dev alone.
