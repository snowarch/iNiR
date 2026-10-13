<div align="center">
  <h1>iNiR NixOS</h1>
  <p><b>Unified, modular NixOS flake and modules for iNiR Desktop Shell + Niri Compositor</b></p>
  <p><i>Material You dynamic theming, snappy animations, and complete Flake support</i></p>

  <p>
    <a href="https://github.com/LATAR-web/inir-nixos/actions"><img src="https://github.com/LATAR-web/inir-nixos/actions/workflows/ci.yml/badge.svg" alt="CI Status"></a>
    <a href="https://github.com/LATAR-web/inir-nixos/releases"><img src="https://img.shields.io/github/v/release/LATAR-web/inir-nixos?color=7aa2f7&label=release" alt="Latest release"></a>
    <a href="https://nixos.org"><img src="https://img.shields.io/badge/NixOS-unstable-5277C3.svg?logo=nixos&logoColor=white" alt="NixOS"></a>
  </p>

  [Documentación en Español](README.es.md) · [Kira Mascot](modules/mascot.nix) · [SDDM Theme](https://github.com/LATAR-web/inir-sddm-nixos)
</div>

---

## Highlights

- **100% Declarative:** Clean, fully declarative configuration via NixOS and Home Manager modules.
- **Dynamic Material You Theming:** Native Material You color system integrated with the desktop shell.
- **Snappy Animations:** Original fast and fluid physics-based animations matching upstream iNiR.
- **Continuous Synchronization:** Tracks upstream iNiR and synchronizes every 2 hours via GitHub Actions and on `repository_dispatch`.
- **Idempotent Adaptations:** Regex-based build adaptations for NixOS without brittle context patches.


---

## Getting Started

### Using Flakes (Recommended)

In `/etc/nixos/flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    inir = {
      url = "github:snowarch/inir";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, inir, ... }: {
    nixosConfigurations.<your_hostname> = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hardware-configuration.nix
        ./configuration.nix
        inir.nixosModules.default
      ];
    };
  };
}
```

In `/etc/nixos/configuration.nix`:

```nix
{ pkgs, ... }:
{
  programs.inir = {
    enable = true;
    colorSync.enable = true;         # Real-time Material You palette sync
    screenRecording.enable = true;   # Hardware-accelerated record-screen with audio
    hardware.brightnessControl = true; # DDC/CI monitor brightness control
    niri = {
      enable = true;
      autoDeployConfig = true;       # Auto-deploy ~/.config/niri/config.d
    };
    audio.enable = true;
    desktop = {
      enable = true;
      displayManager = "gdm";        # "gdm", "greetd", or "sddm"
    };
  };

  # Choose and install your preferred terminal emulator:
  environment.systemPackages = with pkgs; [
    kitty # or ghostty, foot, wezterm, etc.
  ];

  nixpkgs.config.allowUnfree = true;
  users.users.<your_username>.extraGroups = [ "wheel" "networkmanager" "video" "i2c" ];
}
```

---

### Deployment

1. **Rebuild your system**:
   ```bash
   sudo nixos-rebuild switch --flake /etc/nixos#<your_hostname>
   ```

2. **Initialize user state and symlinks**:
   ```bash
   systemd-tmpfiles --user --create
   ```

3. **Log in**:
   Select the **Niri** session on your display manager. Run `verify-setup` to verify all components are green.

---

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| <kbd>Mod</kbd> + <kbd>Enter</kbd> / <kbd>T</kbd> | Terminal (`inir terminal` launches your installed terminal) |
| <kbd>Mod</kbd> + <kbd>Space</kbd> / <kbd>Tab</kbd> | Overview mode |
| <kbd>Mod</kbd> + <kbd>G</kbd> | Desktop overlay (crosshair) |
| <kbd>Mod</kbd> + <kbd>V</kbd> | Clipboard history |
| <kbd>Mod</kbd> + <kbd>,</kbd> | iNiR Settings |
| <kbd>Mod</kbd> + <kbd>/</kbd> | Shortcuts cheatsheet |
| <kbd>Mod</kbd> + <kbd>Shift</kbd> + <kbd>S</kbd> | Region snip menu |
| <kbd>Mod</kbd> + <kbd>Shift</kbd> + <kbd>X</kbd> | Region OCR (extract text) |
| <kbd>Mod</kbd> + <kbd>Shift</kbd> + <kbd>A</kbd> | Region search (Google Lens) |
| <kbd>Mod</kbd> + <kbd>Alt</kbd> + <kbd>R</kbd> / <kbd>S</kbd> | Record region / Stop recording |
| <kbd>Mod</kbd> + <kbd>Alt</kbd> + <kbd>L</kbd> | Toggle light / dark mode (`inir colorMode set toggle`) |
| <kbd>Ctrl</kbd> + <kbd>Alt</kbd> + <kbd>T</kbd> | Wallpaper picker (Material You) |
| <kbd>Mod</kbd> + <kbd>Shift</kbd> + <kbd>W</kbd> | Cycle panel family (animated) |
| <kbd>Super</kbd> + <kbd>E</kbd> | File manager (Nautilus) |
| <kbd>Mod</kbd> + <kbd>B</kbd> / <kbd>Super</kbd> + <kbd>W</kbd> | Browser |
| <kbd>Mod</kbd> + <kbd>Q</kbd> / <kbd>Shift</kbd> + <kbd>Q</kbd> | Close window / Session dialog |
| <kbd>Mod</kbd> + <kbd>Shift</kbd> + <kbd>E</kbd> | Quit session |
| <kbd>Mod</kbd> + <kbd>1</kbd>–<kbd>9</kbd> | Go to workspace 1–9 |

---

## iNiR CLI Commands

### Color & Themes
```bash
# Set or toggle color schemes on the fly
inir colorMode set dark       # Dark mode
inir colorMode set light      # Light mode
inir colorMode set toggle     # Toggle between dark and light

# Get current scheme information in JSON
inir colorMode get

# Screen color picker
inir colorpicker

# Inspect available theming targets
inir theme list-targets

# Manually trigger theming for an external target
inir theme apply <target>

# Run or watch color sync daemon
niri-sync-colors              # One-shot sync
niri-sync-colors --watch      # Persistent watcher
```

### Runtime & Diagnostics
```bash
inir run                      # Start the shell
inir restart                  # Safely restart the shell
inir status                   # Inspect status of components
inir doctor                   # Diagnostic dependency and health check
inir doctor --perf            # Media and graphics benchmark snapshot
inir logs                     # Live runtime logs (-n 50, --full, --issues)
inir settings                 # Toggle settings dialog
inir terminal                 # Open your configured or installed terminal
inir browser                  # Open default browser
```

### Kira Companion Mascot
```bash
inir mascot poke              # Interactive companion reaction
inir mascot romp              # Chaos / playtime mode
inir mascot chase             # Start chase game
inir mascot hideSeek          # Hide and seek game
inir mascot hide              # Temporarily hide Kira
```

### System & Synchronization Tools
```bash
inir-sync                     # Check sync status with upstream iNiR & runtime state
inir-sync --update            # Pull latest upstream iNiR commits and check flake integrity
inir-sync --colors            # Immediate one-shot Material You palette & terminal sync
inir-sync --seed-niri         # Deploy missing modular Niri config files (~/.config/niri/config.d)
inir-sync --doctor            # Run verify-setup diagnostics
record-screen                 # Hardware-accelerated Wayland screen recorder with audio
verify-setup                  # Automated diagnostic health check
```

---

## Synchronization Architecture

### 1. Upstream iNiR Sync
- **Automated Continuous Sync**: GitHub Actions runs every 2 hours (and reacts to repository dispatch events) to check if upstream [snowarch/iNiR](https://github.com/snowarch/iNiR) has new commits. If an update is detected, it validates the flake with `nix flake check --no-build` and commits the lockfile diff.
- **Manual CLI Sync**:
  ```bash
  # Check synchronization status against remote upstream
  inir-sync -s

  # Pull and lock the latest upstream commits
  inir-sync -u
  ```

### 2. Live Runtime & Terminal Color Sync
- **Palette Pipeline**: Changing wallpapers or running `inir colorMode set dark/light` triggers Matugen to generate Material You palettes in `~/.local/state/quickshell/user/generated/colors.json`.
- **Sync Daemon (`niri-sync-colors`)**: Runs in the background under systemd user services, listens for file changes, and instantly updates:
  - Niri active and inactive focus-ring borders.
  - Terminal configs for **Kitty** (`SIGUSR1`), **Foot** (`SIGUSR1`), **Ghostty** (`ii-auto`), **WezTerm** (`colors.lua`), and **Alacritty** (`theme.toml`).
  - Active interactive shells via OSC escape sequences broadcast across `/dev/pts/*`.
  - GNOME / GTK accent colors and dark/light preference via `gsettings`.

### 3. Updating your NixOS Host System
```bash
# Update the inir-nixos flake input on your system
nix flake lock --update-input inir-nixos /etc/nixos
sudo nixos-rebuild switch --flake /etc/nixos#<your_hostname>
```

---

<div align="center">
  <i>Made for NixOS and Niri</i>
</div>

