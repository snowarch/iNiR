# Setup, updates and rollback

These commands keep an installed iNiR healthy. Run them in a terminal. `inir update` works from anywhere. `./setup` commands need the folder you cloned iNiR into.

## Update

```bash
inir update
```

The update checks for new changes, takes a snapshot so you can roll back, pulls the changes, copies the new shell files and restarts the shell. Your settings are not overwritten. When a release needs a change to your config, the update migrates it and keeps a backup. Required migrations run on their own. Optional ones are offered to you.

If iNiR came from your distro's package manager, update the shell through that package manager instead.

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

Packages are not removed. The command prints the commands to remove them, so you can run those yourself.

Use `./setup uninstall -y` to take the recommended answer to every question.

## Backups

- Before a first install, your existing configs are backed up to `~/inir-backup/`.
- Update backups go to `~/.local/state/quickshell/backups/`.
