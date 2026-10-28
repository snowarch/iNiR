# Setup, updates and rollback

These commands keep an installed iNiR healthy. Run them in a terminal. `inir update` works from anywhere. `./setup` commands need the folder you cloned iNiR into.

## Update

```bash
inir update
```

The update checks for new changes, takes a snapshot so you can roll back, pulls the changes, copies the new shell files and restarts the shell. Your settings are not overwritten. It also installs what the shell needs and is missing, such as plasma-integration, a colour emoji font and the shell's fonts, unless you installed with `--skip-deps`. When a release needs a change to your config, the update migrates it and keeps a backup. Required migrations run on their own. Optional ones are offered to you.

If iNiR came from your distro's package manager, update the shell through that package manager instead.

### The runtime and the helpers

On x86_64, setup and `inir update` also download two parts built for you: **qs-rs**, which draws the shell, with its
own Qt, and **inir-accel**, the native helpers. Each download is checked against the checksum the release pins, and
nothing compiles on your machine.

- A download that fails stops the update before anything changes. On a fresh install the shell runs on Quickshell
  instead, and the next `inir update` gets them.
- If qs-rs doesn't start on your system, the update moves the shell to Quickshell and says so; `inir doctor` does the
  same if it stops starting later. The next `inir update` tries qs-rs again.
- The version before stays beside the new one, so a rollback brings both back.
- `INIR_PREBUILT=0 inir update` skips the downloads and keeps the shell on Quickshell.
- While Material's Web Apps tab is on, setup and the update also get **Qt WebEngine** for qs-rs (about 110 MB, once,
  always the one for the qs-rs you have). `inir webengine` gets it at any time and restarts the shell. On Quickshell
  it comes from your distribution's Qt 6 WebEngine package instead.

## Migrations

```bash
./setup migrate
```

Lists the changes that are pending. You pick which optional ones to apply. Each one shows what it will change and makes a backup first.

## Repair

```bash
inir doctor
```

Checks the install and fixes what it can: missing folders, script permissions, Python packages and version tracking.
It also checks that qs-rs starts on its own Qt (if it doesn't, the shell moves to Quickshell until the next update),
that password prompts get answered (by the shell, or by your own agent), and that inir-accel's helpers match what is installed.
It checks plasma-integration, a colour emoji font, `niri-session` (not on Void) and the fonts the shell and each installed family use, and tries to install the missing ones. With the Web Apps tab
on, it gets Qt WebEngine if it is missing.

If you also want a restart and a check of the logs, run `inir repair`.

## Rollback

```bash
./setup rollback
```

Lists the snapshots taken before each update, by date. Pick one to restore it.

## My changes

```bash
./setup my-changes
```

Shows the files you changed from the defaults. You can look at the differences, restore the originals, or keep your changes.

## Uninstall

```bash
./setup uninstall
```

Removes iNiR and asks before each shared file, such as your Niri config, GTK and Kvantum settings. Your iNiR settings are removed too, so copy them first if you want to keep them. Before it removes anything, it backs them up to `~/.local/share/inir-uninstall-backup-` followed by the date and time.

The runtime, the helpers and the `inir` command that iNiR downloaded go too, and so does the `inir` launcher.

Packages are not removed. The command prints the commands to remove them, so you can run those yourself.

Use `./setup uninstall -y` to take the recommended answer to every question.

## Backups

- Before a first install, your existing configs are backed up to `~/inir-backup/`.
- Update backups go to `~/.local/state/quickshell/backups/`.
