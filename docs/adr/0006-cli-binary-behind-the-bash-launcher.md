# ADR-0006: The inir binary sits behind the bash launcher

`inir` reaches people through paths nobody should have to change: the copy or
link at `~/.local/bin/inir` that setup keeps in sync with `scripts/inir`,
`/usr/bin/inir` in the Arch packages (a copy) and Nix (a wrapper), the
`ExecStart` of `inir.service`, niri binds that `spawn "inir"`, and more than a
hundred `shellPath("scripts/inir")` calls from the QML. Doctor also checks that
the launcher on `PATH` has the same content as `scripts/inir`.

So the binary does not replace any of them. It is installed next to them, and
`scripts/inir` hands over to it on its first lines:

- The launcher looks for the binary at `$INIR_CLI`,
  `${XDG_DATA_HOME:-~/.local/share}/inir/cli/inir`, `/usr/local/lib/inir/inir`
  and `/usr/lib/inir/inir`, and execs the first one that is executable. If the
  exec fails (`execfail`), or there is none, it carries on as before.
- It exports `INIR_BASH_LAUNCHER`, its own path as it was called. The binary
  does what it knows (IPC calls to a running shell, completions, doctor) and
  execs that same file back for everything else, with `INIR_CLI_DELEGATED=1`.
  The launcher unsets the marker right after reading it, so the shell it starts
  and the calls it makes go through the binary again.
- `INIR_NO_CLI=1` turns the hand-over off.
- `setup doctor` with no arguments, or only `-y`, goes to the binary too, with
  `INIR_SETUP_DIR` set to its checkout. The binary checks in Go and asks
  `setup doctor --only=N --report=FILE` for each step to repair, with the marker
  set, so the repairs are the bash ones. Any other `setup doctor` flags stay in
  bash, so a flag the binary does not know cannot bounce between them.

Nothing an old `setup` needs moves, and removing the binary puts everyone back
on bash with no step in between. The cost of the extra hop is about 10 ms on an
IPC call, which drops from about 210 ms to 70 ms on the same machine.

How the binary gets there is separate from the hand-over, and every one of
these needs the `snowarch/inir-cli` repo with tagged releases first:

1. A system package can put it at `/usr/local/lib/inir/inir` or
   `/usr/lib/inir/inir`; the launcher looks there too.
2. `setup install` and `setup update` fetch the release for the machine's
   architecture into `~/.local/share/inir/cli/inir`, check its sha256 against
   the release's checksums file and keep the old one if anything fails.
   `INIR_FETCH_CLI=0` skips it.
3. `uninstall` removes the user copy.

A test holds the hand-over to these rules, and
`inir-cli`'s `test/parity.sh` checks that every call gives the same output and
exit code through the bash launcher alone, through the binary, and through the
launcher with the binary installed.

Status: accepted; setup and update fetch the binary from its releases.
