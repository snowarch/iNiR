# Global Actions

Global actions are keyboard-driven commands you can trigger from the Overview search bar or bind to keys. They're the shell's equivalent of a command palette.

## Using actions

Open Overview (`Super+Space`) and start typing. Actions appear alongside app results. They're prefixed with their category:

- `>` for shell actions (toggle sidebar, switch family, open settings)
- `=` for calculator (evaluates math expressions via qalc)
- `$` for system actions (lock, logout, reboot)

You can also bind any action directly to a keybind through Niri's config.

## Built-in actions

### Shell

| Action | What it does |
|--------|-------------|
| Toggle sidebar left | Open/close the left sidebar |
| Toggle sidebar right | Open/close the right sidebar |
| Toggle overview | Open/close workspace overview |
| Switch panel family | Swap between ii and waffle |
| Open settings | Launch the settings UI |
| Reload shell | Hot-reload the shell |

### System

| Action | What it does |
|--------|-------------|
| Lock | Lock the session |
| Logout | Show session screen |
| Reboot | Reboot (with confirmation) |
| Shutdown | Shutdown (with confirmation) |
| Suspend | Suspend the system |

### Tools

| Action | What it does |
|--------|-------------|
| Screenshot region | Select a region to screenshot |
| Screen record | Start/stop screen recording |
| OCR region | Select a region for text recognition |
| Color picker | Pick a color from screen |
| Clipboard history | Open clipboard manager |

### Setup recipes

Type `/setup` in the launcher to see every available installer. Each entry runs a dedicated, distro-aware script in your terminal and pushes progress notifications to the desktop.

| Action | What it does |
|--------|-------------|
| `/setup-spotify` | Installs Spotify (AUR on Arch, Flatpak elsewhere) and configures Spicetify with the Marketplace plugin |
| `/setup-discord` | Installs Discord and applies the Vencord client mod |

Recipes live under `scripts/setup/` and are **auto-discovered** — adding one is a pure filesystem operation, no QML edits and no shell reload required. The full maintainer guide is in [`scripts/setup/README.md`](../scripts/setup/README.md). The short version:

1. `cp scripts/setup/_template.sh.example scripts/setup/<slug>.sh` and fill in the `@meta` header + body.
2. `chmod +x scripts/setup/<slug>.sh`.

The action id (`/setup-<slug>`), display name, icon, keywords, terminal launching and the in-place progress notifications are all derived automatically. A `FolderListModel` + a single `awk` subprocess handle discovery; only the affected setup action recomputes when a recipe is added/changed.

You can disable the whole category by setting `search.globalActions.enableSetup` to `false` in your config.

## Custom actions

You can add your own actions by creating scripts in:

```
~/.config/illogical-impulse/actions/
```

Each script becomes an action that appears in Overview search. The filename becomes the action name (without extension).

Example: create `~/.config/illogical-impulse/actions/deploy.sh`:

```bash
#!/bin/bash
cd ~/myproject && make deploy
notify-send "Deployed" "Project deployed successfully"
```

The action "deploy" will now appear when you search for it in Overview.

## IPC

```bash
inir globalActions list              # list all available actions
inir globalActions search "screen"   # search actions by name
inir globalActions execute <id>      # execute an action by ID
```
