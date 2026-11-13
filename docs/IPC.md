# IPC Reference

iNiR exposes IPC targets you can call from Niri keybinds, scripts, or your terminal.

> **Quick discovery:** `inir help` lists all targets, `inir <target> --help` shows available functions.
> Tab completion knows every target, function and the values each one takes: `inir completions install`.

From terminal (for testing, or showing off):

```bash
inir <target> <function> [values…]
```

As a Niri keybind, let `inir bind` write it for you. It checks the call, tells you if the keys already do something, and saves the bind to your own block in `~/.config/niri/config.d/90-user-extra.kdl`:

```bash
inir bind Mod+O orbit toggle          # shows the line and what those keys do now
inir bind --add Mod+O orbit toggle    # saves it; Niri picks it up right away
inir bind --examples                  # ready binds for your panel family
inir bind --list                      # the binds you added
inir bind --remove Mod+O
```

Or by hand, as a line inside the `binds { }` block of your Niri config:

```kdl
binds {
    Mod+O repeat=false { spawn "inir" "orbit" "toggle"; }
}
```

The examples further down are lines for that block.

For low-level debugging, `inir ipc <target> <function>` still works.

## Every target

Every target and function the shell answers, and what each one does. The list is built from the shell's code, so it never falls behind; `inir help` and tab completion read the same list.

<!-- ipc reference -->
The full list is on [inir.space/docs/ipc](https://inir.space/docs/ipc/), or run `inir help` on your machine.
<!-- /ipc reference -->

## Standalone Commands

These are top-level `inir` commands that work directly, without going through IPC.

### colorpicker

Take a colour from anywhere on the screen: every screen stands still under a loupe, a click copies that pixel's hex
to the clipboard (Esc or a right click cancels). Same as `inir colorPicker pick`.

```kdl
Super+Shift+C { spawn "inir" "colorpicker"; }
```
