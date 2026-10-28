# How iNiR fits together

iNiR is a few parts that each do one job. You install one thing and `inir update` keeps all of them current, so none of
this needs your attention. It is here for the curious, and for anyone who wants to change a part.

<!-- preview parts -->

## The short version

- **Niri** puts your windows on screen. iNiR doesn't replace it; it draws everything around the windows.
- **The base** (this repo) is the shell's engine: services, Settings, the welcome wizard, setup and updates. It has no
  look of its own.
- **Families** are the looks. Material, Waffle and iRiS are plugins from the Hub, and so are themes, widgets and web
  apps.
- **The runtime** draws the shell. **qs-rs** does it, and Quickshell stays as the fallback.
- **inir-accel** does the heavy work the shell asks for: colours from the wallpaper, editor themes (VSCode, OpenCode, Zed),
  thumbnails, region tools.
- **The `inir` command** is what you type: `inir update`, `inir doctor`, `inir hub`, `inir bind`.
- **inir.space** is where your machine fetches all of it: the Hub catalogue, the releases and these docs.

## The parts

| Part | What it does | Repo |
| --- | --- | --- |
| The base | Services, config, the Settings core, IPC, setup, update, the welcome wizard, the plugin host | [snowarch/iNiR](https://github.com/snowarch/iNiR) |
| Families and plugins | Material, Waffle, iRiS, colour themes, iRiS themes, widgets, web apps | [snowarch/inir-hub](https://github.com/snowarch/inir-hub) |
| qs-rs | The runtime that loads the shell and draws it, Quickshell written again in Rust | [snowarch/qs-rs](https://github.com/snowarch/qs-rs) |
| inir-accel | Native helpers: wallpaper colours, editor themes, thumbnails, image work | [snowarch/inir-accel](https://github.com/snowarch/inir-accel) |
| inir-cli | The `inir` command | [snowarch/inir-cli](https://github.com/snowarch/inir-cli) |
| inir.space | The site, these docs, the Hub catalogue and the release list | [snowarch/inir-site](https://github.com/snowarch/inir-site) |

## Where each one lives on your machine

| Path | What |
| --- | --- |
| The folder you cloned, usually `~/inir` | The base. `inir update` pulls new versions into it |
| `~/.config/quickshell/inir/` | The shell that runs: the base copied from your clone, with your families linked in |
| `~/.local/share/inir/plugins/` | Installed families and other plugins from the Hub |
| `~/.local/share/inir/runtime/<version>/` | qs-rs, with the Qt it was built against. `current` points at the one in use |
| `~/.local/share/inir/accel/<version>/` | inir-accel. `current` points at the one in use |
| `~/.local/bin/inir` | What runs when you type `inir`: it starts the shell and hands every other command on |
| `~/.local/share/inir/cli/inir` | The `inir` command itself |
| `~/.config/inir/` | Your settings (`config.json`), your widgets, themes and web apps |
| `~/.config/niri/config.d/` | Niri's settings, one file per area. Yours: `90-user-extra.kdl` |
| `~/.local/state/quickshell/` | What the shell remembers: generated colours, notifications, update snapshots |

Binaries arrive prebuilt (qs-rs for x86_64, inir-accel for x86_64 and aarch64) and checked against the release's checksums; nothing compiles on your machine. The
previous runtime and helpers stay beside the new ones, so a bad update can go back. When qs-rs can't start on a system,
the shell runs on Quickshell and the next update tries again.

## How an update goes

1. `inir update`, or the update notification, fetches the new base.
2. It fetches the families you use, the runtime, inir-accel and the `inir` command, and checks each download before it
   changes anything. A missing piece stops the update with your shell untouched.
3. It copies the new shell, links your families back in and sets right what an older version left in your config. Your settings and
   your own files stay.
4. It restarts the shell and checks it loads. If it doesn't, the update goes back to the shell you had and says so.

Plugins move on their own: a new version of a family or a widget reaches you on the next `inir update`, or from
**Hub** in Settings.

## Changing a part

- A family, theme, widget or web app: [inir-hub](https://github.com/snowarch/inir-hub), with its contributing guide.
- The base: this repo. [Architecture](ARCHITECTURE_OVERVIEW.md) and [Runtime](RUNTIME.md) are the map.
- Commands the shell answers: [IPC](IPC.md).
