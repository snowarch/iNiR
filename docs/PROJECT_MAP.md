# Project Map

How iNiR is laid out, what each part owns, and what a change there reaches. Read it before you change a shared contract. It names owners, not every file.

## Top-level layout

| Path | Owns | Risk |
|---|---|---|
| `shell.qml` | Startup order, family loading, shell-wide IPC, family transitions | High |
| `services/Plugins.qml`, `modules/*/plugin.json` | Which families are installed and their entry files (shell.qml loads them through it) | High |
| `GlobalStates.qml`, `FamilyTransitionOverlay.qml` | Transient UI state and the family transition | High |
| `settings.qml`, `waffleSettings.qml`, `welcome.qml` | Settings entry points and the first-run wizard | Normal |
| `modules/common/` | Config, Appearance, Directories, shared widgets | High |
| `modules/ii/`, `modules/waffle/`, `modules/iris/` | Each family's composition and surfaces | Normal |
| `modules/shared/` | Surfaces that two or more families load | Normal |
| `services/` | System integration and shared runtime state | High |
| `scripts/` | Work outside QML: wallpapers, theme propagation, capture, AI, thumbnails, the `inir` launcher | High |
| `defaults/` | Shipped `config.json`, Niri config, widgets, app configs | Medium |
| `setup`, `sdata/` | Install, update, migrations, distro data | High |
| `translations/` | 18 catalogues, and their tools in `translations/tools/` | Low |
| `docs/` | User documentation, published on the website | Low |
| `assets/`, `dots/` | Icons and wallpapers; dotfiles that setup installs | Medium |
| `nix/`, `distro/`, `flake.nix`, `Makefile` | Packaging | Medium |

## How a start goes

1. `shell.qml` forces the critical singletons to exist.
2. It waits for `Config.ready`.
3. It applies the theme, initialises icon theming and resets the panel list if it is empty.
4. It loads one family's critical host, then the family's deferred wrapper after the first frame.
5. The family's implementation root creates a module only when it is enabled and its conditions hold.
6. Modules read shared state from services and singletons.
7. Scripts do the work that should not live in QML.

The dependency direction is `config + services + shared singletons -> panel loaders -> modules -> behaviour`. The full timeline is in [Runtime and Boot](RUNTIME.md).

## Persisted and transient state

- **Persisted preferences** live in `modules/common/Config.qml` (the schema) and `defaults/config.json` (the defaults). They must agree. A key added to one and not the other looks fine in the UI and never persists.
- **Transient state** lives in `GlobalStates.qml`: open and close state, the lock, the family transition, the wallpaper selector target, Waffle popups. It is not saved.

## Families

- Composition roots: `modules/ii/ShellIiPanelsImpl.qml`, `modules/waffle/ShellWafflePanelsImpl.qml`, `modules/iris/ShellIrisPanelsImpl.qml`, and the `critical/` hosts beside them.
- Waffle is not a skin over ii. It has its own composition and layouts, so check whether it needs a parallel version before you copy an ii pattern.
- Family selection changes which modules exist, not just how they look.

## Services and scripts

- `services/qmldir` and `services/deferred/qmldir` register the singletons. See [Services Catalogue](SERVICES.md).
- Services are the shared producers of runtime state, so a change to one reaches every consumer.
- Scripts are where iNiR leaves QML: wallpaper switching and theme propagation (`scripts/colors`), capture, AI, thumbnails and maintenance. QML assumes their behaviour is stable.
- `scripts/inir` is the launcher. It hands commands to the Go CLI (`inir-cli`) when a binary exists at `$INIR_CLI`, `~/.local/share/inir/cli/inir`, or `/usr/local/lib/inir/inir` or `/usr/lib/inir/inir`. `INIR_NO_CLI=1` turns the hand-off off. `run --session` never goes through it.

## Setup and distribution

- `setup` sources `sdata/lib/` and reads the distro data in `sdata/dist-*/` (arch, debian, fedora, generic and void).
- The Void path is not a package-name alias. It has its own XBPS profiles and runit provider logic. See [Void](VOID.md) and [Void Capabilities](VOID_CAPABILITIES.md).
- `sdata/migrations/` holds the numbered migrations that run on update.

## Change impact

The riskiest changes are the shared contracts:

- Config schema and defaults (`Config.qml`, `defaults/config.json`).
- Shared visual tokens (`Appearance.qml`, `Looks`, `IrisStyle`).
- Startup order (`shell.qml`).
- Family loading rules (the `Shell*PanelsImpl.qml` roots and the `critical/` hosts).
- Global transient state (`GlobalStates.qml`).
- Service APIs used by many modules, and scripts that services call.

A change to one module or one settings page stays local. If a change alters user-visible behaviour, update the user docs in `docs/`.

## Where to start reading

- **Runtime**: `shell.qml`, `modules/ii/critical/ShellIiCriticalPanels.qml`, `modules/ii/ShellIiPanelsImpl.qml`, `GlobalStates.qml`.
- **Persistence and theming**: `modules/common/Config.qml`, `defaults/config.json`, `modules/common/Appearance.qml`, `services/ThemeService.qml`, `services/Wallpapers.qml`.
- **Setup**: `setup`, `sdata/lib/`, [Setup](SETUP.md), [Packages](PACKAGES.md).
- **Scripting**: [IPC](IPC.md).
- **Known limits**: [Limitations](LIMITATIONS.md).
