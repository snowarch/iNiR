# NixOS

> Experimental. The Arch installer is still the primary supported path.

iNiR provides a flake with:

| Output                      | Purpose                                             |
| --------------------------- | --------------------------------------------------- |
| `packages.<system>.default` | Packaged iNiR runtime and `inir` launcher           |
| `nixosModules.inir`         | NixOS module for system package + user service      |
| `homeModules.inir`          | Home Manager module for user package + user service |

The module does not run `./setup install` or `./setup update`. Nix owns the
installed files, and iNiR runs from the package store path.

The package and modules are ordinary Nix expressions under `nix/`. Flakes are
only one entrypoint, so traditional Nix configurations can import them directly.
Both entrypoints use the same `package.nix`, NixOS module, and Home Manager
module rather than maintaining separate implementations.

## Without flakes

Point `inirSrc` at a local checkout or a source pinned with your preferred Nix
fetcher:

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

For Home Manager, import `nix/home-module.nix` instead. The package expression
accepts the consumer's `pkgs` set explicitly, so traditional configurations can
choose or pin nixpkgs without converting the project to a flake. Both modules
use that same package expression by default unless `programs.inir.package` is
overridden.

## With niri-flake

> [!TIP]
> For the latest updates use the **prerelease** branch of iNiR. It's where new
> features land and it's the recommended flavor for daily use.

Add both flakes:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    inir.url = "github:snowarch/inir/prerelease";
  };
}
```

Then import both modules in your NixOS configuration:

```nix
{ config, inputs, pkgs, ... }: {
  imports = [
    inputs.inir.nixosModules.inir
  ];

  programs.niri.enable = true;

  programs.inir = {
    enable = true;
    service.compositor = "niri";
    extraPackages = [
      config.programs.niri.package
      pkgs.wf-recorder
      pkgs.slurp
      pkgs.file
      pkgs.xdg-utils
      pkgs.xdg-user-dirs
      pkgs.pulseaudio
    ];
  };
}
```

`programs.inir.service.compositor = "niri"` creates the user unit wiring under
`niri.service.wants/inir.service`. It does not wire iNiR to
`graphical-session.target`, so it will not auto-start under KDE, GNOME, or other
desktop sessions.

`extraPackages = [ config.programs.niri.package ];` puts the same `niri` client
binary used by your compositor on iNiR's runtime `PATH`, so features that call
`niri msg` use the matching package.

**Recorder dependencies.** For the screen recorder to work, put these on iNiR's
runtime `PATH` via `extraPackages`:

| Package         | Why it's needed                               |
| --------------- | --------------------------------------------- |
| `wf-recorder`   | The actual screen recording engine            |
| `slurp`         | Region selection for recording/screenshots    |
| `file`          | Detect the recorded file type                 |
| `xdg-utils`     | `xdg-open` / mime helpers for opening results |
| `xdg-user-dirs` | Resolve the user's Pictures/Videos folders    |
| `pulseaudio`    | Audio capture while recording                 |

For useful keybinds, merge iNiR actions into `programs.niri.settings.binds` —
the same binds you'd put in `config.kdl`:

```nix
{
  programs.niri.settings.binds = {
    "Ctrl+Shift+L".action.spawn = [ "inir" "clipboard" "toggle" ];
    "Mod+D".action.spawn = [ "inir" "dashboard" "toggle" ];
    "Mod+Comma".action.spawn = [ "inir" "settings" ];
    "Mod+Slash".action.spawn = [ "inir" "cheatsheet" "toggle" ];

    "Mod+Space" = {
      repeat = false;
      action.spawn = [ "inir" "overview" "toggle" ];
    };

    "Mod+R".action.spawn = [ "inir" "overlay" "toggle" ];
    "Mod+Shift+P".action.spawn = [ "inir" "session" "toggle" ];
  };
}
```

## Home Manager

If you manage your user session with Home Manager, import the Home Manager
module instead:

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

That symlink keeps tools that expect the traditional config path working, but it
is opt-in because it will conflict with an existing repo checkout at the same
path. Enable it with:

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
- User preferences still live in iNiR's normal config/state files; the packaged
  QML source itself is immutable.
- `inir update` is not the right update path for a Nix install. Update through
  your flake inputs and rebuild.
