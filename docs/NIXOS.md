# NixOS

iNiR ships a flake with a package, a NixOS module, a Home Manager module and a starter template. NixOS support is
still experimental: it gets less testing than Arch and Void.

Once it runs, everything else works as on other distros: you change things in Settings, not in Nix.

## Start a new system from the template

```bash
mkdir ~/nixos && cd ~/nixos
nix flake init -t github:snowarch/inir
cp /etc/nixos/hardware-configuration.nix .
```

Open `configuration.nix`, rename the `you` user to yours, then:

```bash
sudo nixos-rebuild switch --flake .#inir
```

Reboot and pick the Niri session on the login screen.

## Add iNiR to your own flake

```nix
inputs.inir = {
  url = "github:snowarch/inir";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Add `inir.nixosModules.default` to your system's `modules`, then:

```nix
programs.inir = {
  enable = true;
  desktop.enable = true; # leave it off if your config already sets up Niri and a login screen
};
```

## Options

| Option | Default | What it does |
|---|---|---|
| `programs.inir.enable` | `false` | Installs iNiR and its user service, started with Niri |
| `programs.inir.desktop.enable` | `false` | Niri, a login screen, PipeWire, NetworkManager and UPower |
| `programs.inir.desktop.displayManager` | `"sddm"` | `sddm`, `greetd` or `none` |
| `programs.inir.fonts.enable` | `true` | The fonts iNiR's styles use, and only those |
| `programs.inir.niriConfig.seed` | `true` | Copies iNiR's Niri config to `~/.config/niri` at login if you have none |
| `programs.inir.package` | `inir` | Use `inir-with-mascot` for Kira's art pack |
| `programs.inir.extraPackages` | `[ ]` | More programs on the shell's PATH |
| `programs.inir.service.enable` | `true` | The `inir` systemd user service |

The Niri config is copied once and is yours from then on. iNiR never overwrites it.

## Home Manager

Import `inir.homeModules.default` and set `programs.inir.enable = true;`. It installs the package and the user
service. `programs.inir.configSymlink.enable` also links the shell to `~/.config/quickshell/inir` for tools that
look there. Niri, the login screen and fonts stay with your NixOS config.

## Updates

On NixOS, iNiR updates with your flake: update the input and rebuild.

```bash
nix flake update inir
sudo nixos-rebuild switch --flake .#inir
```

## What is different here

- YouTube Music uses the package's own yt-dlp, so there is nothing to repair.
- The shell lives in the Nix store. Your settings, themes and wallpapers live in your home folder as usual.
