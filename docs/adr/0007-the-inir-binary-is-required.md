# ADR-0007: The inir binary is required

ADR-0006 put the inir binary behind the bash launcher as an option: `setup` fetched it with `|| true`, and
everything still ran through `scripts/inir` without it. That kept bash in every call the shell made: more than a
hundred `Quickshell.shellPath("scripts/inir")` calls in the base and the families, most of them the shell asking
one of its own IPC handlers to do something, each a bash start, the binary, a `qs ipc call` process and a socket
round trip back into the same process.

iNiR now runs on Go and Rust and nothing it runs is bash (owner's decision, 2026-11-28). The binary is part of
iNiR, not an option on top of it:

- `setup install` and `setup update` fail when no binary that runs is there after the fetch (`require_inir_cli_binary`
  in `sdata/lib/cli-binary.sh`). A failed download keeps a copy that runs; with none, nothing changes and the
  update says why. A package ships its own and names it (`INIR_CLI`, `INIR_FETCH_CLI=0`): Nix does.
- `setup doctor` (bash, so it runs only when the binary does not) installs a missing binary or fails step 6.
- The launcher that starts the shell names the binary in its environment (`INIR_CLI`) and the tree's own launcher
  the binary hands unported commands back to (`INIR_BASH_LAUNCHER`). A dev nest does the same.
- The shell has one owner for its own commands, `ShellExec` (`modules/common/functions`), over one path,
  `Directories.inir`:
  - `ShellExec.ipc(target, fn, args)` runs an IpcHandler of this shell in process (qs-rs `Ipc.call`): no process
    and no socket. A standalone window (Settings, the welcome; `INIR_STANDALONE_WINDOW=1`) holds copies of some
    services and their handlers, so there, and on a runtime without `Ipc.call`, the binary makes the call as
    `inir ipc TARGET FN ARGS`, the form no command name (`settings`, `hub`) shadows.
  - `ShellExec.inir(args)` runs a command of the binary (`settings-window`, `hub`, `service`, `kill-dialog`).
  - A command line another program runs (swayidle, inir-accel's family switch) takes `Directories.inir`.
- `Directories.inir` falls back to `scripts/inir` only for a shell started without the launcher's environment,
  which then hands over to the binary as before.

Each command the binary takes over deletes its bash; none stays as a fallback. `scripts/inir` remains the entry
for what is not ported yet (the shell start, the colour pipeline, setup).

Status: accepted; replaces ADR-0006's "the binary is optional". ADR-0006's hand-over rules stand for the commands
still in bash.
