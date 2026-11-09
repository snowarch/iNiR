# NixOS

iNiR ships a flake with a package, a NixOS module, a Home Manager module and a starter template. On NixOS you get
the same iNiR as on Arch: the same three families, the same Hub, the same Settings and the same updates.

## How it fits together

- **The base comes with your flake.** The package holds iNiR's base and the programs it needs. It moves when you
  update the flake input and rebuild.
- **Your copy lives in your home.** The first time the shell starts after the package changes, it brings
  `~/.config/quickshell/inir` in step with the package, as `inir update` does on other distros. Your config,
  wallpapers and themes stay where they are.
- **Families, themes and widgets come from the Hub.** Material, Waffle and iRiS are Hub items, like every theme and
  widget. The shell installs the families your config uses from [inir.space/hub](https://inir.space/hub) on its
  first start, and **Settings › Hub** adds more. You don't declare them in Nix, and switching family works the moment
  the shell is up.

## Start a new system from the template

```bash
mkdir ~/nixos && cd ~/nixos
nix flake init -t github:snowarch/inir
cp /etc/nixos/hardware-configuration.nix .
```

Open `configuration.nix`, rename the `you` user to yours, and keep your own boot loader lines if your machine does
not boot with systemd-boot. Then:

```bash
sudo nixos-rebuild switch --flake .#inir
```

Reboot and pick the Niri session on the login screen. The welcome wizard opens on the first start.

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
  users = [ "alice" ];
  desktop.enable = true; # leave it off if your config already sets up Niri and a login screen
};
```

iNiR's flake follows nixos-unstable, and that is where it is tested.

## Options

| Option | Default | What it does |
|---|---|---|
| `programs.inir.enable` | `false` | Installs iNiR and its user service, started with Niri |
| `programs.inir.users` | `[ ]` | People who use iNiR. They join the groups its tools need: `video`, `input`, `i2c`, `ydotool` |
| `programs.inir.desktop.enable` | `false` | Niri, a login screen, PipeWire, NetworkManager, Bluetooth |
| `programs.inir.desktop.displayManager` | `"sddm"` | `sddm` (with iNiR's ii-pixel theme), `greetd` or `none` |
| `programs.inir.desktop.loginBackground` | `null` | A picture for the SDDM login screen |
| `programs.inir.fonts.enable` | `true` | The fonts iNiR's styles use |
| `programs.inir.niriConfig.seed` | `true` | Copies iNiR's Niri config to `~/.config/niri` at login if you have none |
| `programs.inir.webEngine` | `false` | Qt WebEngine for the Web Apps tab of Material's sidebar (about 200 MB) |
| `programs.inir.extraPackages` | `[ ]` | More programs installed with iNiR, for the apps your config names |
| `programs.inir.service.enable` | `true` | The `inir` systemd user service |
| `programs.inir.package` | `inir` | Use `inir.packages.${system}.inir-with-mascot` for Kira's art pack |

The Niri config is copied once and is yours from then on. iNiR never overwrites it.

## Home Manager

Import `inir.homeModules.default` and set `programs.inir.enable = true;`. It installs the package, its programs and
fonts for you, and the user service Niri starts. Niri itself, the login screen, PipeWire, NetworkManager, UPower,
power profiles and the groups need root: they belong to your NixOS config. On other distros, install iNiR with its
[install script](INSTALL.md) instead.

## Updates

The base updates with your flake:

```bash
nix flake update inir
sudo nixos-rebuild switch --flake .#inir
```

Your copy follows the next time the shell starts. To apply it right away, run `inir service restart`.

Families, themes and widgets update from the Hub, as on every distro. The shell tells you when one has an update.
Update it from **Settings › Hub** or with `inir update`. On NixOS, `inir update` updates only Hub items and tells you
the base comes with your flake.

## What is different here

- **The login screen keeps one picture.** On Arch, the SDDM theme follows your wallpaper and colours. On NixOS, the
  system declares the login screen and the shell can't write to it. Set a picture with
  `programs.inir.desktop.loginBackground = ./login.png;`.
- **Coming from the 3.0.1 package:** it left a launcher in `~/.local/bin` and a user unit in
  `~/.config/systemd/user`, which hide the new package. The module removes them at your next login or rebuild, and
  logs `inir: removed …, left by an older iNiR package`.

## When something is wrong

`inir doctor` checks the install as on other distros and knows where NixOS keeps things. The shell's log is
`journalctl --user -u inir`.
