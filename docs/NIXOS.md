# NixOS

> Experimental. The Arch installer is still the primary supported path.

iNiR provides a flake with:

| Output | Purpose |
|---|---|
| `packages.<system>.default` | Packaged iNiR runtime and `inir` launcher |
| `nixosModules.inir` | NixOS module for system package + user service |
| `homeModules.inir` | Home Manager module for user package + user service |

The module does not run `./setup install` or `./setup update`. Nix owns the installed files, and iNiR runs from the package store path.

The package and modules are ordinary Nix expressions under `nix/`. Flakes are only one entrypoint, so traditional Nix configurations can import them directly. Both entrypoints use the same `package.nix`, NixOS module, and Home Manager module rather than maintaining separate implementations.

## Without flakes

Point `inirSrc` at a local checkout or a source pinned with your preferred Nix fetcher:

```nix
{ pkgs, ... }:
let
  inirSrc = /path/to/inir;
in
{
  imports = [
    (import (inirSrc + "/nix/nixos-module.nix"))
  ];

  programs.inir = {
    enable = true;
    package = pkgs.callPackage (inirSrc + "/nix/package.nix") { inherit pkgs; };
    service.compositor = "niri";
  };
}
```

For Home Manager, import `nix/home-module.nix` instead. The package expression accepts the consumer's `pkgs` set explicitly, so traditional configurations can choose or pin nixpkgs without converting the project to a flake. Both modules use that same package expression by default unless `programs.inir.package` is overridden.

## With niri-flake

Add both flakes:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    niri.url = "github:sodiboo/niri-flake";
    inir.url = "github:snowarch/inir";
  };
}
```

Then import both modules in your NixOS configuration:

```nix
{ config, inputs, ... }: {
  imports = [
    inputs.niri.nixosModules.niri
    inputs.inir.nixosModules.inir
  ];

  programs.niri.enable = true;

  programs.inir = {
    enable = true;
    service.compositor = "niri";
    extraPackages = [ config.programs.niri.package ];
  };
}
```

`programs.inir.service.compositor = "niri"` creates the user unit wiring under `niri.service.wants/inir.service`. It does not wire iNiR to `graphical-session.target`, so it will not auto-start under KDE, GNOME, or other desktop sessions.

`extraPackages = [ config.programs.niri.package ];` puts the same `niri` client binary used by your compositor on iNiR's runtime `PATH`, so features that call `niri msg` use the matching package.

For useful default shortcuts, merge iNiR actions into `programs.niri.settings.binds`:

```nix
{
  programs.niri.settings.binds = {
    "Mod+Space" = {
      repeat = false;
      action.spawn = [ "inir" "overview" "toggle" ];
    };

    "Mod+V".action.spawn = [ "inir" "clipboard" "toggle" ];
    "Mod+Comma".action.spawn = [ "inir" "settings" ];
    "Mod+Slash".action.spawn = [ "inir" "cheatsheet" "toggle" ];
    "Mod+Shift+W".action.spawn = [ "inir" "panelFamily" "cycle" ];

    "Mod+Alt+L" = {
      allow-when-locked = true;
      action.spawn = [ "inir" "lock" "activate" ];
    };

    "Mod+Shift+S".action.spawn = [ "inir" "region" "screenshot" ];
    "Mod+Shift+X".action.spawn = [ "inir" "region" "ocr" ];
    "Mod+Shift+A".action.spawn = [ "inir" "region" "search" ];
  };
}
```

## Home Manager

If you manage your user session with Home Manager, import the Home Manager module instead:

```nix
{ inputs, ... }: {
  imports = [
    inputs.inir.homeModules.inir
  ];

  programs.inir = {
    enable = true;
    service.compositor = "niri";
  };
}
```

The Home Manager module can also expose the packaged runtime at:

```text
~/.config/quickshell/inir
```

That symlink keeps tools that expect the traditional config path working, but it is opt-in because it will conflict with an existing repo checkout at the same path. Enable it with:

```nix
programs.inir.configSymlink.enable = true;
```

## Hyprland

Hyprland users can wire the service to the UWSM unit:

```nix
programs.inir.service.compositor = "hyprland";
```

This creates `wayland-wm@Hyprland.service.wants/inir.service`.

## Manual service wiring

To create the service but avoid auto-start wiring:

```nix
programs.inir.service.compositor = null;
```

Then start it manually:

```bash
systemctl --user start inir.service
```

## Notes

- Use `inir logs --full` for runtime errors.
- The packaged `inir` launcher wraps Quickshell and runtime tools in `PATH`.
- User preferences still live in iNiR's normal config/state files; the packaged QML source itself is immutable.
- `inir update` is not the right update path for a Nix install. Update through your flake inputs and rebuild.
