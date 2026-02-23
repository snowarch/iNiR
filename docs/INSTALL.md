# Installation

> **Arch Linux only.** The installer only supports Arch-based distros. If you're on something else, you're on your own - check the manual section below and figure out the equivalent packages for your distro. No support provided, no complaints accepted.

---

## The Easy Way (Arch)

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup install
```

Add `-y` if you don't want to answer questions:

```bash
./setup install -y
```

When it's done:

```bash
niri msg action load-config-file
```

Log out and back in, or just restart Niri. Done.

---

## The Hard Way (Manual)

For when you're not on Arch, or you enjoy pain.

### 1. Get dependencies

The bare minimum to not crash immediately:

| Package | Why |
|---------|-----|
| `niri` | The compositor. Obviously. |
| `quickshell` | The shell runtime (official repos). Chosen intentionally for faster and more reliable installs. |
| `syntax-highlighting` | Provides QML module `org.kde.syntaxhighlighting` (required by AiChat code blocks). |
| `kirigami` | KDE QML components used by shell modules. |
| `kdialog` | KDE runtime helper used by some dialogs/integrations. |
| `wl-clipboard` | Copy/paste. |
| `cliphist` | Clipboard history. |
| `pipewire` + `wireplumber` | Audio. |
| `grim` + `slurp` | Screenshots. |
| `matugen` | Material You colors from wallpaper. |
| `plasma-integration` | KDE platform theme plugin (reads kdeglobals for Qt app colors). |
| `darkly-bin` (AUR) | Darkly Qt style (Material You widget rendering). |

For everything else, check [PACKAGES.md](PACKAGES.md). It's organized by category so you can skip what you don't need.

> **Note on quickshell package:** iNiR intentionally uses `quickshell` from official repos to avoid long AUR compile times and update-time build failures.
>
> **Runtime extras used by features:**
> - `socat` for YTMusic IPC fallback control
> - `fprintd` for fingerprint lockscreen support
>
> **Important for minimal installs (Arch base / netinstall):**
> If shell startup fails with `module "org.kde.syntaxhighlighting" is not installed`, install:
> `syntax-highlighting kirigami kdialog`

### 2. Clone the repo

```bash
git clone https://github.com/snowarch/inir.git ~/.config/quickshell/inir
```

### 3. Copy the configs

```bash
cp -r dots/.config/* ~/.config/
```

This gives you:
- Niri config with inir keybindings
- Matugen templates for theming
- GTK settings
- Fuzzel config

### 4. Tell Niri to start inir

Add this to `~/.config/niri/config.kdl`:

```kdl
spawn-at-startup "qs" "-c" "inir"
```

### 5. Restart Niri

```bash
niri msg action load-config-file
```

Or log out and back in.

---

## Did it work?

Check the logs:

```bash
qs log -c inir
```

If everything went well, you should see:
- Bar at the top (the thing with the clock)
- Background/wallpaper (hopefully not a black screen)
- `Mod+Tab` opens the Niri overview (native)
- `Mod+Space` (`Super+Space`) toggles the inir overview
- `Alt+Tab` cycles windows using inir's switcher
- `Super+V` opens the clipboard panel
- `Super+Shift+S` takes a region screenshot

If something's broken, the logs will probably tell you which package is missing. Probably.

---

## What now?

- [KEYBINDS.md](KEYBINDS.md) - Learn the shortcuts
- [IPC.md](IPC.md) - Make your own keybindings
- [SETUP.md](SETUP.md) - Updating, uninstalling, how configs are handled
- [PACKAGES.md](PACKAGES.md) - Full package list if something's missing
