# Bazzite/KDE development install

`scripts/install-bazzite-repo-link.sh` installs iNiR as a separate Niri
session directly from this checkout. It is for development forks, not the
upstream one-command installer.

It creates guarded links for:

- `~/.config/niri` to `defaults/niri`;
- `~/.config/quickshell/inir` to this repository;
- `~/.local/bin/inir` to `scripts/inir`.

It also writes iNiR's own `~/.config/inir/config.json`, then wires
`inir.service` only to `niri.service`. The service is not started under Plasma.

The installer deliberately uses `~/.config` instead of an inherited
`XDG_CONFIG_HOME`. This keeps the install visible to the actual Niri login
session when it is started from a sandboxed application such as Codex.

The path is recorded in an `inir.service` drop-in, so the service uses the
linked configuration even if systemd inherited a different XDG environment.

It never writes `kdeglobals`, GTK settings, Kvantum settings, SDDM settings,
wallpaper files, or shell startup files. If a target already exists and is not
the expected link, installation stops rather than overwriting it.

## Install

Install the runtime dependencies first, then run:

```bash
./scripts/install-bazzite-repo-link.sh
```

Log out, choose the **Niri** session in SDDM, and log in. Return to Plasma from
the same session chooser if anything needs to be adjusted.

## Update this fork

Do not use the upstream `./setup update` path: it can manage global theming.
Update the checked-out branch, then restart the service from a Niri session:

```bash
git pull --ff-only origin dell-bazzite
inir restart
```
