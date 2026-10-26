# Void capabilities

What works on Void Linux and how far it was checked. A capability counts as supported only after its providers are installed, it is switched on, it runs, and it is checked. "VM" means a Void virtual machine with an accelerated display.

| Capability | Void provider | Status |
|---|---|---|
| Niri and Quickshell | XBPS `niri`, `quickshell`, Qt 6 | VM |
| Login | XBPS `sddm`, `xorg-minimal`, the `ii-pixel-sddm` greeter | VM. The greeter survived a reboot and started the Niri session |
| Session D-Bus and login | XBPS `dbus`, `elogind`, `turnstile` | VM |
| Network | XBPS `NetworkManager` | VM and physical laptop. Wi-Fi connected after the migration and a reboot |
| Bluetooth | XBPS `bluez`, `blueman`; audio adds `libspa-bluetooth` | VM, and the controller was detected and powered on a physical laptop. Pairing a device was not tested |
| Power profiles | XBPS `power-profiles-daemon` | VM, persisted across reboot |
| Wallpaper | XBPS `awww` | VM |
| Interactive web wallpaper | XBPS `qt6-webengine`, `layer-shell-qt` | VM |
| Game Mode | Built in | VM. Manual on and off worked. `discover-overlay` is not on Void, so its switch stays hidden. Niri animation switching was not tested |
| Screenshots | XBPS `grim`, `slurp`, `swappy`, `wl-clipboard`, `jq` | VM |
| Screen recording | XBPS `wf-recorder`, `ffmpeg`, the PipeWire stack | VM |
| Clipboard history and paste | XBPS `wl-clipboard`, `cliphist`; pinned ydotool | VM. Superpaste was not tested on its own |
| Cloudflare WARP | Pinned upstream package, run as an iNiR runit service | VM for install, daemon, socket, version and logging. Account registration, connection and trace are pending |
| Mission Center | Flathub `io.missioncenter.MissionCenter` | VM |
| OCR | XBPS Tesseract language packages, pinned vertical models | VM |
| Themes, icons and cursors | Pinned adw-gtk3, WhiteSur and Capitaine | VM |
| UI fonts | XBPS `nerd-fonts-ttf`, `noto-fonts-emoji`, `fontconfig`, plus pinned Material Symbols, Roboto Flex, Gabarito, Oxanium and Rubik | VM |
| Darkly style and settings | Pinned Darkly source, built with KDecoration | VM. Style and settings module both installed and linked |
| Foot terminal theming | XBPS `foot` | VM |
| Shell desktop parity | XBPS `plasma-integration`, `kf6-syntax-highlighting` | VM. Rendered icons were not confirmed by eye |
| Package search, install and remove | XBPS | VM. The password prompt was not automated |
| Power and ABI repair | XBPS diagnostics | VM |
| Super-tap (legacy, opt-in) | XBPS `python3-evdev` and helper | VM. Off by default |

## Rules

- The Void installer offers the same profiles as the Arch installer.
- A missing optional profile does not block the base shell. Choosing a profile installs all of its providers.
- WARP never starts a privileged service or creates an account from the shell. It reports a stopped daemon, and you register it yourself.
- An XBPS package for iNiR is out of scope for now.
