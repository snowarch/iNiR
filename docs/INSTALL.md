# Installation

> **Arch Linux only.** The installer only supports Arch-based distros. If you're on something else, you're on your own - check the manual section below and figure out the equivalent packages for your distro. No support provided, no complaints accepted.

---

## The Easy Way (Arch)

```bash
git clone https://github.com/snowarch/quickshell-ii-niri.git
cd quickshell-ii-niri
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
| `quickshell-git` | The shell runtime. **Must be the AUR version**, not the one in Arch repos. See note below. |
| `wl-clipboard` | Copy/paste. |
| `cliphist` | Clipboard history. |
| `pipewire` + `wireplumber` | Audio. |
| `grim` + `slurp` | Screenshots. |
| `matugen` | Material You colors from wallpaper. |

For everything else, check [PACKAGES.md](PACKAGES.md). It's organized by category so you can skip what you don't need.

> **Note on quickshell-git:** The AUR package may not include all optional modules. If you see errors about missing modules (like `Quickshell.Services.Polkit`), ii-niri will still work - those features will just be disabled. For full functionality, you can rebuild quickshell with all service modules enabled.

### 2. Clone the repo

```bash
git clone https://github.com/snowarch/quickshell-ii-niri.git ~/.config/quickshell/ii
```

### 3. Copy the configs

```bash
cp -r dots/.config/* ~/.config/
```

This gives you:
- Niri config with ii keybindings
- Matugen templates for theming
- GTK settings
- Fuzzel config

### 4. Tell Niri to start ii

Add this to `~/.config/niri/config.kdl`:

```kdl
spawn-at-startup "qs" "-c" "ii"
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
qs log -c ii
```

If everything went well, you should see:
- Bar at the top (the thing with the clock)
- Background/wallpaper (hopefully not a black screen)
- `Mod+Tab` opens the Niri overview (native)
- `Mod+Space` (`Super+Space`) toggles the ii overview
- `Alt+Tab` cycles windows using ii's switcher
- `Super+V` opens the clipboard panel
- `Super+Shift+S` takes a region screenshot

If something's broken, the logs will probably tell you which package is missing. Probably.

---

## Partial Install

Don't want everything? The setup script has options:

```bash
./setup install-deps    # just packages, no config files
./setup install-setups  # just services (ydotool, groups)
./setup install-files   # just config files
```

---

## What now?

- [KEYBINDS.md](KEYBINDS.md) - Learn the shortcuts
- [IPC.md](IPC.md) - Make your own keybindings
- [SETUP.md](SETUP.md) - Updating, uninstalling, how configs are handled
- [PACKAGES.md](PACKAGES.md) - Full package list if something's missing
