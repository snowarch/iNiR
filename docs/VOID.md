# iNiR on Void Linux

Guide for running iNiR on Void Linux with glibc, runit, Turnstile, and XBPS.
Architecture decisions for the port live in `docs/adr/`.

## Status

- V1 scope: **the normal per-user iNiR install path works on Void**. The shell
  payload lives in the user install just as it does on the repo-managed Arch
  path; XBPS dependency transactions and system-service activation still use
  normal privilege elevation when required. Disruptive service ownership
  changes are confirmation-gated. An iNiR XBPS package is a separate milestone
  (see Packaging).
- Non-goals for V1 (documented as *compatibility profiles*, not supported):
  musl libc and `seatd` without elogind.
- Validation covers the normal installer, reboot persistence, the graphical
  SDDM/Niri session path, provider idempotency, and non-systemd supervision.

## Installer experience on Void

Run `./setup install` from a normal iNiR checkout. For the first install, keep
it interactive so setup can offer the NetworkManager and SDDM ownership
handoffs described below. Later updates use the normal `inir update` /
`./setup update` flow.

Void does not get a second-class manual-only path. `./setup install` uses the
same TUI shell as the other automated installers and adapts the operations
behind it to XBPS/runit. A normal first run presents:

- the detected distro/package manager, CPU/GPU/RAM/session summary;
- an install plan and backup destination before package/config work starts;
- progress for dependencies, system configuration, config installation and
  version tracking;
- low-memory guidance when the machine is small enough for it to matter;
- a dynamic XBPS free-space check for only the packages still missing, plus
  download/build headroom;
- confirmation-gated system-service changes rather than silently assuming
  systemd or replacing existing service owners.

Two first-install prompts are deliberately special. If Void is still using its
base `dhcpcd`/standalone `wpa_supplicant` stack, setup can migrate it to
NetworkManager with rollback if activation fails. After the install itself is
complete, setup can enable SDDM so the next normal login uses Void's packaged
`niri --session` entry. Non-interactive `-y` runs leave both of those ownership
decisions unchanged.

## How the port decides what to do

Everything systemd-sensitive is gated by one predicate, never by distro name:

```
usable systemd user manager =
    -S $XDG_RUNTIME_DIR/systemd/private          (socket exists; /run/user/$UID when unset)
    AND `timeout 3s systemctl --user show-environment` answers or times out
```

A probe that times out with the socket present is a busy manager, still systemd.

Void can run systemd; Arch can lack a user manager. See ADR-0002.

## Session supervisor (non-systemd)

Three tiers, decided by the predicate (ADR-0001):

1. **systemd** (predicate holds) → `inir.service`, as on Arch.
2. **turnstile** (`turnstiled` service active) → per-user service
   `~/.config/service/inir/run`:
   ```sh
   #!/bin/sh
   exec chpst -e "$TURNSTILE_ENV_DIR" /path/to/inir run --session
   ```
   - Turnstile also provides the session D-Bus bus via a dedicated
     user service. Install `~/.config/service/dbus/run` and
     `~/.config/service/dbus/check` from turnstile examples,
     then add `dbus` to `core_services` in
     `~/.config/service/turnstile-ready/conf`.
    - With elogind: `manage_rundir = no` in `/etc/turnstile/turnstiled.conf`.
   - Session env for services: `turnstile-update-runit-env VAR=value`, read
      with `exec chpst -e "$TURNSTILE_ENV_DIR" ...`.
3. **runsvdir fallback** (zero system deps) → Niri spawns it:
   ```kdl
   spawn-sh-at-startup "exec runsvdir ~/.config/service"
   ```
    Niri kills its spawn on exit; session env is inherited from Niri. This is
    distinct from the runsvdir process that turnstile's runit backend owns.

Control: `sv restart|down|up ~/.config/service/inir` (non-systemd
equivalent of `systemctl --user`). `inir logs` → `sv status` (journalctl
does not exist without systemd).

Audio under non-systemd supervisors is also supervised per user:
`~/.config/service/{pipewire,wireplumber,pipewire-pulse}/run`, rendered by
`reconcile_audio_user_services` with `chpst -e "$TURNSTILE_ENV_DIR"` under
turnstile. Only services carrying `# Managed by iNiR.` are touched; user-owned
services are preserved, and the systemd tier removes the owned ones.

## Session

- Normal installed entry is SDDM. The Void base profile installs `sddm` plus
  `xorg-minimal`; after all setup tasks complete, the interactive installer
  offers to enable `/etc/sv/sddm` through runit. On the next boot (and as soon
  as the service is enabled), SDDM presents the graphical login and launches
  Void's packaged Niri desktop entry, whose command is
  `Exec=/usr/bin/niri --session`.
- `niri --session` remains the supported manual fallback from a local TTY for
  recovery/debugging or when the user intentionally declines SDDM. The
  `niri-session` wrapper was not present in the tested Void package.
- Manual `niri` launches are unsupported: doctor warns when the session
  lacks a D-Bus bus.
- Env propagation without systemd: `dbus-update-activation-environment`
  (replaces `systemctl --user set-environment`), or turnstile's envdir.

## System services (installed once, requires root)

Auto-enabled with confirmation during setup (`ln -s /etc/sv/<svc> /var/service/`):

- `dbus` — system D-Bus (required by elogind/polkitd)
- `elogind` — logind replacement: `/run/user/$UID`, `loginctl`, power/suspend
- `polkitd` — policykit daemon (GUI sudo prompts)
- `turnstiled` — per-user services + session bus (tier 2 supervisor)
- `power-profiles-daemon` — Quickshell Power Profiles D-Bus provider
- `sddm` — graphical login/display manager. It is offered only after the
  install is complete, refuses activation when D-Bus/Niri session metadata is
  unavailable, and never replaces another enabled display manager.

Guided only (never auto-enabled): `seatd` (+ `_seatd` group).

Note: the session D-Bus bus under turnstile is provided by a **user**
service (`~/.config/service/dbus`), not the system `dbus` service.

## Dependencies (XBPS)

Primary profile (glibc + elogind): `niri`, `quickshell` (repo, not compiled),
`fish-shell` (provides `/usr/bin/fish` used by terminal and iNiR launchers),
`sddm`, `xorg-minimal`,
`elogind`, `dbus`, `polkit`, `seatd`, `turnstile`, `xdg-desktop-portal-gtk`,
`xdg-desktop-portal-wlr`, `polkit-gnome`, `qt6-qt5compat` (not `qt6-5compat`),
`uv` (repo), `NetworkManager`, `bluez`, `blueman`, `pipewire`,
`libspa-bluetooth`, `alsa-pipewire`, `libdbusmenu-gtk3`,
`power-profiles-daemon`, `kf6-kirigami`, `kdialog`, `breeze-icons`,
`qt6ct`, `qt6-webengine`, `layer-shell-qt`, `wl-clipboard`, `cliphist`,
`grim`, `slurp`, `swappy`, `swayidle`, `swaylock`, `gum`, `dunst`, `jq`,
`awww` (official XBPS wallpaper backend), fonts, etc.

Notes:

- Quickshell from the Void repo is rebuilt by Void in lockstep with Qt
  updates, so the Qt/Quickshell ABI check (`check_qs_abi`) self-heals.
  `deps-map.sh` must say `void:quickshell`, not `void:COMPILE`.
- `kf6-syntax-highlighting` and `kf6-kirigami` are base runtime dependencies
  because shared shell components import `org.kde.syntaxhighlighting` and
  `org.kde.kirigami` directly.
- Power Profiles is a visible shell capability. Void provides
  `power-profiles-daemon`, including `powerprofilesctl`, a runit service,
  the `org.freedesktop.UPower.PowerProfiles` D-Bus service, and polkit policy.
  Setup activates it only through the confirmed-elevation system-service step.
- Interactive Web Wallpaper uses the official Void `qt6-webengine` and
  `layer-shell-qt` QML providers. The host is pure Qt QML and prefers `qml6`
  or `qml`; Void's packaged fallback is `/usr/lib/qt6/bin/qml`. Quickshell is
  deliberately not used as the QtWebEngine host. Doctor repairs either missing
  QML provider through XBPS.
- The legacy opt-in Super-tap daemon follows the same user-supervisor tiers as
  the shell: systemd when the ADR-0002 predicate succeeds, otherwise Turnstile
  or the runsvdir fallback. It remains disabled unless
  `II_ENABLE_SUPER_DAEMON=1` is explicitly set.
- `ydotool` is not packaged in the current Void repositories. iNiR uses the
  verified upstream v1.0.4 source, a predicate-selected user service,
  input-group `/dev/uinput` permissions, and install/Doctor update paths.
  The provider's UI operation is VM validated through the lock-screen keyboard;
  simulated paste uses the same verified daemon path but was not exercised as a
  separate UI action.
- Bluetooth uses the toolkit profile's `bluez` daemon and `blueman` frontend.
  The audio profile adds `libspa-bluetooth` for PipeWire Bluetooth audio.
- `ddcutil` on musl needs `libexecinfo-devel` + `musl-legacy-compat`.
- Repo sanity: `xbps-query -L` (doctor check).
- Darkly is built from pinned v0.5.39 source with Qt6/KF6 dependencies,
  including `kf6-kdecoration-devel`. The provider requires both
  `styles/darkly6.so` and
  `org.kde.kdecoration3.kcm/kcm_darklydecoration.so`; a style-only install is
  considered incomplete and Doctor can repair it.
- Foot wallpaper theming writes `~/.config/foot/inir-colors.ini`. The shipped
  `foot.ini`, generator, installer repair and uninstall paths all use that
  managed name; the historical `colors.ini` path is legacy cleanup only.

## Capability providers

Void follows the same dependency-profile model as Arch. A selected profile is
supported only when iNiR provisions, activates, operates, and verifies every
capability it exposes. Provider resolution prefers official XBPS packages,
then a maintained Flatpak, then a pinned upstream artifact with an update
path. See ADR-0004 and `docs/VOID_CAPABILITIES.md`.

Game Mode closes `discover-overlay` only where it is installed. Void has no
package for it, so the switch stays hidden there and nothing runs.

## Package management UI (Updates / PackageSearch / AppCatalog)

- Updates check (no root): `xbps-install -nu` (list available updates).
- Update all: `sudo xbps-install -Su` (terminal, `_runTerminalScript`).
- Search: `xbps-query -Rs "<query>" | head -200`.
- Installed: `xbps-query -s "<query>"`.
- Install: `sudo xbps-install -S -- "<pkg>"`; remove: `sudo xbps-remove -R -- "<pkg>"`.
- App catalog: add `xbps` targets to `defaults/app-catalog.json`.

## Packaging

V1 ships through the per-user installer. An XBPS package is a later
milestone with its own recipe (documented here, not yet built):

- Template for `xbps-src` (Void's build tool): requires a local
  `void-packages` checkout and an `xbps-src` chroot to build.
- Do NOT call `make install` in the template — it installs the systemd unit
  (`install-systemd` target, `Makefile:54`). Use the partial targets
  (`install-bin`, `install-shell`, `install-icon`, `install-desktop`,
  `install-docs`) or copy `sdata/runtime-root-files.txt` /
  `runtime-payload-dirs.txt` payloads directly.
- `version.json` must report `install_mode: package-managed`,
  `package_manager: xbps` (`INIR_PACKAGE_MANAGER`), so iNiR updates via
  `xbps-install -Su` instead of `inir update`.
- An official XBPS package is intentionally outside the current port scope.

## Startup template

`defaults/niri/config.d/50-startup.kdl` is the single source; setup injects
and removes marked blocks per distro and predicate (ADR-0003). The template
keeps the systemd environment command as an unmarked default; setup renders
that command, the marked runsvdir block, or no startup block for turnstile.
It also handles an existing split `config.d/50-startup.kdl` or monolithic
`config.kdl`. Injection must be idempotent, and migration 021 must remove the
runsvdir block when the predicate holds (no double shell on Void+systemd).

## Migration rules

`021-systemd-single-instance` and `022-service-compositor-wants` must be
no-ops when the predicate is false (their `command -v systemctl` check is
not enough — without the user-manager socket, `systemctl --user` hangs for
10-30s).

## External hardware prerequisites

iNiR installs the shell/rice and its userland capability providers. It does not
install or choose kernel GPU drivers, firmware, Mesa/Vulkan drivers, proprietary
GPU stacks, bootloader configuration, or hardware-specific kernel parameters.
Those remain the base Void installation's responsibility.

Before running iNiR on a new machine, the tester should first confirm that the
base Void installation can boot normally and that its graphics stack is usable
for Wayland/Niri on that hardware. This matters especially when the external
disk will be moved between machines with different GPUs. iNiR can provision its
own desktop dependencies afterward, but it should not guess which hardware
driver is correct for an unknown machine.

The default dependency set is large because `nerd-fonts-ttf` alone expands to
several GiB. The Void installer performs a dynamic XBPS disk-space preflight for
only the packages still missing and includes 2 GiB of download/build headroom.

## Validation

For VM validation, use KVM plus VirGL (or another working accelerated Wayland
graphics path). A minimal QEMU shape is:

```
qemu-system-x86_64 \
  -accel kvm -m 4096 -smp 4 \
  -display gtk,gl=on \
  -device virtio-vga-gl \
  -drive file=void.img,format=qcow2,if=virtio \
  -netdev user,id=n1 -device virtio-net-pci,netdev=n1
```

- Plain `virtio-vga` without `VIRTIO_GPU_F_VIRGL` is rejected by the graphics
  preflight because Niri has no usable accelerated output in that setup.
- `scripts/check-void-graphics.sh` catches that specific VirtIO failure before
  the installer starts the large dependency transaction. It also rejects a
  machine with no accessible DRM render node. Set
  `INIR_SKIP_GRAPHICS_PREFLIGHT=1` only when deliberately testing an unusual
  graphics stack outside the validated profile.
- Venus remains an optional VM configuration when the host/QEMU stack supports
  it: `-device virtio-gpu-gl,hostmem=8G,blob=true,venus=true`.
Recommended validation order:

1. `make test-local` on the development host.
2. `./setup install` end-to-end on a fresh Void glibc VM.
3. Reboot and log in through SDDM using the packaged `niri --session` entry.
4. Run `inir doctor` and verify the selected supervisor and session D-Bus.
5. Verify NetworkManager, BlueZ, Power Profiles, PipeWire, ydotool and any
   selected optional providers.
6. Exercise package search/install/remove and both panel families.
7. Run the versioned `scripts/check-void-*.sh` contracts when changing a
   provider or lifecycle boundary.

## FAQ / gotchas

- **Two shells after install**: a hand-written startup entry, or both Niri and
  turnstile owning `~/.config/service`. Remove hand-written
  `spawn-*`/runsvdir lines and rerun setup so it selects one tier.
- **Shell crashes and stays dead**: no supervisor (tier 3 requires the
  runsvdir entry; check `sv status ~/.config/service/inir`).
- **`inir logs` fails**: journalctl is systemd-only; use `sv status` (+
  `svlogd` if you configure a `log` directory for the service).
- **Qt/Quickshell ABI mismatch after a Void Qt update**: transient until
  Void rebuilds quickshell; `inir doctor --fix-abi` gains a Void case
  (`xbps-install -Sf quickshell` or local template rebuild).
- **Suspend/hibernate**: `loginctl suspend` (elogind) replaces
  `systemctl suspend`; `acpid` is the alternative in the seatd profile.
- **SPICE clipboard in a Wayland-only Niri session**: Void's
  `spice-vdagent` requires an X11 `DISPLAY`. The SPICE channel and daemon can
  be healthy while clipboard integration remains unavailable. This does not
  affect iNiR or turnstile.

## Sources

- Void handbook: services (`/etc/sv` → `/var/service/`), session management
  (elogind/seatd/turnstile), user services (turnstile),
  `xbps-install`/`xbps-query` usage.
- QEMU docs: virtio-gpu device (venus/gfxstream options), display backends.
- Repo facts: `scripts/inir` (service helpers, `run --session`),
  `sdata/lib/deps-map.sh`, `sdata/subcmd-install/3.files.sh`,
  migrations 021/022, `Makefile`, `dev/tests/test-local-distribution.sh`.
