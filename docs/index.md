# iNiR

**A complete desktop shell environment for Wayland compositors.**

iNiR is a single-runtime shell built on [Quickshell](https://quickshell.outfoxxed.me/) with full system integration — panels, services, theming, and compositor IPC — running inside the QML runtime with no separate backend daemon.

---

## Quick navigation

<div class="grid cards" markdown>

- :material-download: **Getting Started**

  ---

  Install iNiR, run the setup wizard, and get up and running.

  [:octicons-arrow-right-24: Installation](INSTALL.md)

- :material-cog: **Setup & Update**

  ---

  Post-install configuration, updates, migrations, and rollback.

  [:octicons-arrow-right-24: Setup guide](SETUP.md)

- :material-console: **IPC Reference**

  ---

  All targets and functions you can call from keybinds or scripts.

  [:octicons-arrow-right-24: IPC targets](IPC.md)

- :material-palette: **Theming**

  ---

  Wallpaper-based color pipeline and how theming modules work.

  [:octicons-arrow-right-24: Architecture](THEMING_ARCHITECTURE.md)

</div>

---

## What iNiR is

iNiR has three integrated layers:

| Layer                     | What it is                                                                        |
| ------------------------- | --------------------------------------------------------------------------------- |
| **QML Runtime Shell**     | Quickshell + QML singletons — both the UI and system integration (~760 QML files) |
| **Bash Control Plane**    | `scripts/inir` — launcher, service lifecycle, IPC routing, diagnostics            |
| **Python / Go Toolchain** | Color pipeline, Niri config generation, external app theme generators             |

**Primary compositor:** Niri. Secondary Hyprland support exists from the fork origin.

**Panel families:** `ii` (Material Design, 5 style variants) and `waffle` (Windows 11 Fluent).

---

## Panel families at a glance

|               | **ii** — Material Design             | **waffle** — Windows 11       |
| ------------- | ------------------------------------ | ----------------------------- |
| Design tokens | `Appearance.*`                       | `Looks.*`                     |
| Bar position  | Top / vertical                       | Bottom taskbar                |
| Launcher      | Overview (`Super+Space`)             | Start Menu                    |
| Action center | Sidebar right                        | Action center                 |
| Styles        | material, cards, aurora, inir, angel | Fluent                        |
| Switch to it  | `inir panelFamily set ii`            | `inir panelFamily set waffle` |

Switch between families at runtime with `Super+Shift+W`.

---

## Common commands

```bash
inir run            # Start the shell (foreground)
inir restart        # Restart running instance
inir settings       # Open settings UI
inir logs           # View runtime logs
inir doctor         # Health checks and diagnostics
inir status         # Shell status info
inir theme apply all  # Re-apply all wallpaper theming targets
```

---

## Key directories

| Path                   | What lives here                                                |
| ---------------------- | -------------------------------------------------------------- |
| `shell.qml`            | Entry point — singleton init, panel family dispatch, IPC       |
| `services/`            | 70 system integration singletons (audio, network, Niri IPC, …) |
| `modules/`             | 676 QML files — all UI panels and components                   |
| `modules/common/`      | Config singleton, Appearance tokens, 130 shared widgets        |
| `defaults/config.json` | Shipped default configuration (~1300 lines)                    |
| `scripts/inir`         | CLI launcher and IPC router (~2000 lines)                      |
| `scripts/colors/`      | Wallpaper → color token pipeline                               |

---

## Version

This documentation reflects the state of the **`main`** branch.
See [`ARCHITECTURE.md`](https://github.com/snowarch/inir/blob/main/ARCHITECTURE.md) in the repository root for the high-level system diagram.
