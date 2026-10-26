# Void Linux

iNiR runs on Void Linux with glibc, runit, Turnstile and XBPS. It uses the same installer as the other distros, with the packages and services adapted to Void. musl libc, and seatd without elogind, are not supported.

## Install

Run `./setup install` from an iNiR checkout. Keep the first install interactive, because two questions are skipped with `-y`:

- **NetworkManager**: if Void still uses its base `dhcpcd` and `wpa_supplicant`, setup can move the machine to NetworkManager and roll back if that fails.
- **SDDM**: setup can enable it as the login screen once the install is done.

Setup checks free disk space before it starts. It counts only the packages still missing, plus 2 GiB for downloads and builds. The default set is large, because `nerd-fonts-ttf` alone takes several GiB.

Setup does not install GPU drivers, firmware or Mesa. Check that your base Void install boots and runs Wayland before you start. On a VM, use an accelerated display such as virtio-gpu with VirGL. Setup stops early on a display without usable acceleration: plain `virtio-vga` without `VIRTIO_GPU_F_VIRGL` is rejected before the big dependency install starts.

Updates later on use `inir update`. iNiR is installed per user for now. There is no XBPS package for it yet.

## Login and session

- The login screen is SDDM. It starts Void's packaged Niri session.
- If you decline SDDM, start Niri from a TTY with `niri --session`. That is also the recovery path. Plain `niri` is not supported.
- Setup never replaces a display manager that is already enabled.

## Services

Setup enables these runit services, asking first: `dbus`, `elogind`, `polkitd`, `turnstiled`, `power-profiles-daemon` and `bluetoothd`. NetworkManager and SDDM are covered in Install.

## Supervision

The shell has to stay up without systemd, so setup picks one of three ways based on the machine:

1. **systemd**, if its user manager answers. The shell runs as `inir.service`, as on Arch.
2. **Turnstile**, if `turnstiled` is active. The shell runs as a per-user runit service.
3. **runsvdir**, otherwise. Niri starts a runsvdir for the shell.

You don't choose. `inir doctor` checks the supervisor and repairs what it can.

On the non-systemd tiers, `inir logs` shows `sv status` instead of a journal, because journalctl needs systemd. Audio runs as per-user runit services there too (PipeWire, WirePlumber and pipewire-pulse). Setup only touches services marked `# Managed by iNiR.`, so your own services stay as they are.

## Validated profile

In a VM, the profile was checked for the installer, reboot persistence, the SDDM login into Niri, supervision without systemd and reinstalls that change nothing. Network and Bluetooth were also checked on a physical laptop. [VOID_CAPABILITIES](VOID_CAPABILITIES.md) lists each capability and what was tested.

## Gotchas

- **Two shells after install.** A hand-written startup line, or a second runsvdir, owns the shell's service. Remove the hand-written startup lines from your Niri config, then run `./setup install` again so setup picks one supervisor.
- **Shell stays down on the runsvdir tier.** `sv status ~/.config/service/inir` shows whether it is running. Then run `inir doctor`.
- **Quickshell mismatch after a Void Qt update.** Void rebuilds Quickshell along with Qt, so this clears by itself. To rebuild now, run `inir doctor --fix-abi`.
- **Suspend** uses `loginctl suspend` (elogind), not `systemctl suspend`.
- **ydotool** is not in Void's repositories. iNiR builds the pinned upstream v1.0.4 instead.
- **Darkly** needs both its style and its settings module. `inir doctor` repairs a style-only install.
- **Clipboard in a SPICE VM** stays unavailable in a Wayland-only session, because Void's spice-vdagent needs X11. This is not an iNiR problem.
