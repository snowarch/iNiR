# Install

iNiR installs with one script. Arch is the main target. Void Linux (glibc and runit), Fedora 43 or newer, Debian testing and Ubuntu 25.10 or newer have automated dependency paths too. Debian 13 installs with a warning, because it ships Qt 6.8. Debian 12 and older, and Ubuntu 25.04 and older, stop early, because iNiR needs Qt 6.9 or newer. NixOS has [its own page](NIXOS.md).

## Arch

Run these in a terminal:

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup install
```

Use `./setup install -y` to skip the questions.

When it finishes, restart the computer. Logging out is not enough, because Niri's environment and your new groups only load at login. Then pick Niri at the login screen.

If the login screen is black on a laptop with NVIDIA and integrated graphics, the default X11 greeter may be starting on the GPU with no screens. Open `./setup`, choose Extras, and set up the Wayland login screen with Niri from there.

## Void Linux

Void uses the same command. Run the first install without `-y`. Setup shows a system snapshot and the install plan, then asks before it changes networking or the login screen. A `-y` run leaves both alone. Graphics drivers come from your base system. Setup checks that the graphics stack works, but it does not install GPU drivers.

See the [Void Linux guide](VOID.md) for the details.

## Ubuntu 26.04

Ubuntu 26.04 never had a working 2.33 install, so there is nothing to update: start with a fresh install
(`git clone https://github.com/snowarch/iNiR && cd iNiR && ./setup install`) instead of `inir update`.

## Other distros by hand

If your distro has no automated path, install the packages yourself, then skip setup's dependency step:

1. Install `niri`, `quickshell`, `syntax-highlighting`, `kirigami`, `kdialog`, `wl-clipboard`, `cliphist`, `grim`, `slurp`, and PipeWire with WirePlumber. The [Packages](PACKAGES.md) page has the full list.
2. From the cloned `inir` folder, run `./setup install --skip-deps`.
3. Restart the computer.

## Did it work?

After the restart you should see the bar at the top. Then try these:

- Super+Tab opens Niri's overview.
- Super+Space opens iNiR's overview and app launcher.
- Alt+Tab switches windows with Niri's own switcher.
- Super+V opens clipboard history.
- Super+Shift+S opens the region tools.

If something is wrong, `inir doctor` checks the install and fixes what it can. `inir logs` shows why the shell did not start.
