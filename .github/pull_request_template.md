## Summary

Brief description of what this pull request changes.

## Motivation

Why is this change needed? What problem does it solve?

## Testing

Steps to verify this works:

1. 
2. 
3. 

## Checklist

- [ ] Tested on Niri (or Hyprland if applicable)
- [ ] Tested both inir and waffle families for UI changes
- [ ] Tested material, aurora, and inir styles for inir changes
- [ ] No hardcoded values (colors, fonts, durations use design tokens)
- [ ] Config changes synced in Config.qml and defaults/config.json
- [ ] Config access uses optional chaining: Config.options?.section?.option ?? default
- [ ] IPC functions have explicit return types (: void, : string, etc.)
- [ ] Shell restarted after changes: qs kill -c inir; qs -c inir
- [ ] Logs checked for errors: qs log -c inir | tail -50
- [ ] Lazy-loaded components tested (Settings, overlays)
- [ ] No console errors or warnings

## Related

Closes #
Fixes #
