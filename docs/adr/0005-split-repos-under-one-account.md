# ADR-0005: Split the project into repos by release pace, under one account

Everything lives in one repo today: the QML shell, a 5k-line bash CLI, a bash
installer with one dependency script per distro, Python helpers with their own
venv, and Go that gets compiled on the user's machine at runtime. Nothing tested
an install before a release; install and update bugs reached users first.

The split follows what changes together and who consumes it, not code areas:

- `snowarch/iNiR` stays the shell and the front page: QML, assets,
  translations, defaults and the scripts the QML calls. Every existing clone
  updates from here, so the shell does not move.
- `snowarch/inir-cli` will hold one Go binary (CLI, install, update, doctor,
  migration runner, Hub client, heavy helpers) plus packaging and the
  per-distro CI.
- `snowarch/inir-hub` holds the catalogue the Hub client already reads.

The three panel families stay in one repo. They share the engine, the services
and some panels, so separate repos would turn every engine change into several
coordinated PRs. `dev/tests/test-family-isolation.py` keeps them from importing
each other beyond the crossings that exist today.

Contracts between repos are files with tests: `scripts/lib/ipc.json` (the IPC
surface, generated with `ipc-registry.sh`), `VERSION`, `version.json` and the
install layout.

Until a release has moved users to the binary, the files an old `setup` needs
before pulling stay at the repo root: `setup`, `shell.qml`, `sdata/lib/`,
`sdata/runtime-*.txt`, `scripts/inir` and `VERSION`.

`dev/lifecycle/run.sh` runs install, reinstall, update and uninstall in a clean
container per distro (Arch, Fedora, Debian, Ubuntu, Void) and is what CI runs.

Status: accepted. The bench and the contracts exist; the CLI and Hub repos do not yet.
