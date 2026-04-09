# Project Map

## Purpose

This document explains how iNiR is composed, how its main parts relate to each other, what each part is responsible for, and what changes usually affect when you touch it.

It is written for contributors and code agents.

The goal is not to list every file. The goal is to give you a reliable mental model of the project so you can find the right source of truth before changing behavior.

## What iNiR is

iNiR is a desktop shell built on Quickshell and QML.

At runtime, it is not a single monolithic UI. It is a composition of:

- a shell entrypoint
- shared state singletons
- configuration and theme singletons
- UI modules loaded on demand
- compositor-facing services
- system integration scripts
- setup and update tooling
- user-facing documentation and translation assets

The shell is built for the Niri compositor. Legacy Hyprland code paths exist from the end-4 fork origin but are not actively maintained or supported.

## The shortest accurate mental model

At a high level, the runtime works like this:

1. `shell.qml` starts the shell and forces critical services to exist.
2. The shell waits for `Config.ready`.
3. When config is ready, it applies the active theme, initializes icon theming, and normalizes enabled panels for the selected family.
4. The shell loads only one panel family at a time:
   - `ShellIiPanels.qml`
   - `ShellWafflePanels.qml`
5. Those loaders create user-facing modules only when the module is enabled in config and any extra conditions are satisfied.
6. Modules read shared state from services and singletons such as:
   - `Config`
   - `Appearance`
   - `GlobalStates`
   - compositor services
   - feature services like audio, notifications, wallpapers, media, network, and weather
7. Scripts and external tools are invoked when the shell needs work that should not live inside QML, such as wallpaper switching, theme propagation, screenshot tooling, recording, setup, and maintenance.

That is the core dependency direction of the project:

`config + services + shared singletons -> panel loaders -> modules -> user-visible shell behavior`

## Top-level project structure

### `shell.qml`

This is the runtime entrypoint for the main shell.

It is responsible for:

- instantiating critical services early
- reacting to `Config.ready`
- applying theme initialization
- deciding which panel family to load
- exposing IPC for settings and panel-family switching
- coordinating family transition animation

It affects the whole runtime because this is where startup order is defined.

If you change `shell.qml`, you are changing startup behavior, family loading, or shell-wide routing.

### `ShellIiPanels.qml`

This file defines the runtime composition for the `ii` family.

It uses a `PanelLoader` pattern built on `LazyLoader`. A module becomes active only when:

- config is ready
- its identifier is present in `Config.options?.enabledPanels`
- any family-specific condition is true

This file is the authoritative list of `ii` panels that the shell can materialize.

A change here affects module availability, startup cost, and the visible shell surface of the `ii` family.

### `ShellWafflePanels.qml`

This is the equivalent composition root for the `waffle` family.

It defines:

- waffle-native panels such as taskbar, start menu, action center, notification center, widgets, and waffle-specific clipboard/alt-switcher/task view
- shared modules that also remain available under waffle

A change here affects the Windows-11-like family and, in many cases, the expectations of family switching.

### `modules/`

This directory contains the user-facing UI surface of the shell.

In practice, `modules/` is where contributors spend most of their time, because this is where visible features live:

- bars
- sidebars
- overlays
- background surfaces
- settings pages
- media controls
- clipboard UI
- overview and switchers
- wallpaper selectors
- waffle-specific interfaces

The important architectural rule is that modules are not meant to own global truth.

They usually render and orchestrate behavior, but they depend on shared sources of truth from:

- `modules/common/`
- `services/`
- `GlobalStates.qml`
- `Config.qml`

### `modules/common/`

This is the shared UI and infrastructure layer.

It contains some of the highest-impact files in the repository, because many modules depend on it.

The most important examples are:

- `Config.qml`
- `Appearance.qml`
- `Directories.qml`
- shared widgets
- shared helper functions and models

If you change this directory, you are rarely changing only one feature. You are often changing a contract used by many features.

### `modules/waffle/`

This directory contains the waffle family implementation.

It is not just a skin over `ii`. It is its own family with its own UI composition and visual identity.

That means a change that makes sense for `ii` is not automatically valid for waffle.

The contributor implication is simple:

- if a request is whole-feature in nature, verify whether waffle needs a parallel implementation
- do not assume ii-family component structure can be copied directly into waffle

### `services/`

This is the runtime integration layer.

`services/qmldir` exposes the singleton services imported by the shell and modules. These services cover areas such as:

- compositor integration
- wallpapers and theme propagation
- audio and media
- notifications
- network and Bluetooth
- search and app discovery
- autostart and persistence helpers
- updates and system state
- AI and external integrations

A service change usually has broader blast radius than a local module change because services are shared consumers of system APIs and shared producers of runtime state.

### `scripts/`

This directory contains helper scripts used by runtime features, theming, capture flows, daemons, and setup.

Scripts matter because they are where iNiR crosses the boundary from shell UI into the user system.

Typical responsibilities include:

- wallpaper/theme application
- external theme propagation
- screenshot and recording helpers
- AI helpers
- thumbnail generation
- maintenance utilities

If you change a script, you are often changing behavior that QML assumes is stable.

### `defaults/`

This directory contains distributed defaults.

The most important file here is `defaults/config.json`.

This file defines the default shape and values of the user configuration shipped by the project.

It is part of a sync group with `modules/common/Config.qml`.

If you add a new config key and forget to update both places, the UI may appear to work while the value never persists correctly.

### `docs/`

This is the canonical user-facing documentation source for the repository.

If you are documenting real product behavior, this is where it should live.

Examples already present in this directory include installation, setup/update behavior, IPC, package reference, limitations, and optimization guidance.

### `docs-site/`

This is a separate documentation web app built with Next.js.

It is not the shell runtime.

Its purpose is to render documentation as a website. It has its own frontend stack and its own structure, but conceptually it depends on the project documentation layer rather than the shell runtime.

A change here affects documentation delivery, not shell behavior.

### `translations/`

This directory contains translation files and translation maintenance tools.

Runtime UI strings are translated through the `Translation` service and translation assets under `translations/`.

The tools under `translations/tools/` help extract strings, update translation files, clean unused keys, and synchronize translation structure.

A translation change affects interface language coverage, not core runtime logic.

### `sdata/`

This directory supports installation, packaging, migrations, updates, rollback, and distro-specific behavior.

The `setup` script sources libraries from `sdata/lib/` and uses distribution data under directories such as `sdata/dist-arch/`.

If you change `sdata/`, you are usually changing how iNiR installs, updates, or maintains itself on user machines.

### `assets/`

This directory contains bundled visual resources used by the shell, such as icons, wallpapers, and images.

It affects presentation and first-run defaults, but it is not where business logic lives.

### `dots/`

This contains distributed dotfiles and shared configuration assets that are installed or referenced by setup flows.

It matters for the user environment around iNiR, especially when the project applies or ships theming-related defaults.

## Runtime architecture in more detail

## 1. Startup and shell loading

The authoritative runtime entrypoint is `shell.qml`.

Its startup responsibilities are structural, not cosmetic.

It does all of the following:

- forces critical singletons to exist early
- waits for config readiness
- applies current theme through `ThemeService`
- initializes icon theming
- ensures the selected panel family has a complete base panel set
- exposes shell-wide IPC for settings and panel-family switching
- loads only the currently active panel family

The important impact is that startup order is intentional.

If you move behavior earlier or later in the boot sequence, you can change:

- whether a module sees config in time
- whether the theme is available before first paint
- whether a panel family loads the right set of enabled panels
- whether settings open in the right surface

## 2. Panel families are runtime composition roots

The panel-family system is central to the project.

iNiR has two families:

- `ii`
- `waffle`

The active family is stored in config and switched through shell logic plus IPC.

The important point is that family selection is not just visual. It changes which modules exist at runtime.

That means changing family behavior affects:

- startup composition
- IPC routing expectations
- settings entrypoints
- module availability
- transition behavior

The family transition is coordinated through `shell.qml` and `FamilyTransitionOverlay.qml`, with state stored in `GlobalStates.qml`.

## 3. Config is the persistent source of truth

`modules/common/Config.qml` is the configuration singleton.

It is backed by a `FileView` and a `JsonAdapter`, and exposes:

- `options`
- `ready`
- `configChanged()`
- `setNestedValue(...)`

Its role is larger than just reading JSON.

It also defines the schema that QML can safely write to, debounces reads and writes, and acts as the reactive config source for the shell.

This is why config changes have broad impact:

- modules read visual and behavioral preferences from it
- services read runtime feature settings from it
- startup behavior depends on it
- settings pages write back into it

The practical contributor rule is:

- config reads come from `Config.options?.` with null-safe access
- config writes must go through `Config.setNestedValue(...)`
- adding a config key is incomplete unless `Config.qml`, `defaults/config.json`, and the consumer surface all agree

## 4. Appearance is the visual contract for the ii family

`modules/common/Appearance.qml` is the theme and visual token singleton for the shared/ii side of the shell.

It defines the reactive visual system for:

- style detection
- color tokens
- transparency behavior
- rounding
- typography
- animation timing
- GameMode-aware effect suppression
- wallpaper-informed visual adaptation

It also centralizes style dispatch for the five supported styles:

- material
- cards
- aurora
- inir
- angel

Its impact is very broad because modules rely on it for visual consistency rather than defining their own local token systems.

If you change `Appearance.qml`, you are changing a contract used by many visible surfaces.

## 5. GlobalStates is the transient UI state hub

`GlobalStates.qml` stores shell-wide transient state.

This is not persisted user preference. It is runtime coordination state.

Examples include:

- whether a sidebar is open
- whether the overview is open
- whether the clipboard panel is open
- whether the screen is locked
- which wallpaper selector target is active
- whether a family transition is running
- which waffle popup is allowed to remain open

This file matters because independent modules use it to coordinate open/close behavior without each feature inventing its own global state channel.

Changing it can affect panel coordination, mutual exclusion, transitions, and IPC-visible behavior.

## 6. Services bridge UI and system behavior

The services layer is the project's runtime backbone.

Modules render the shell, but services usually know how to talk to the outside world.

Some important examples from the verified service surface are:

- `ThemeService.qml`
- `Wallpapers.qml`
- `NiriService.qml`
- `CompositorService.qml`
- `Audio.qml`
- `Notifications.qml`
- `Network.qml`
- `MprisController.qml`
- `ShellUpdates.qml`
- `Translation.qml`
- `FirstRunExperience.qml`

### `ThemeService.qml`

This service reacts to theme config, applies current theme state, and triggers external theme propagation when appropriate.

It depends on:

- `Config`
- theme presets and material theme loading
- wallpaper-driven theme generation
- theme scripts under `scripts/colors/`

A change here affects both shell visuals and, potentially, external applications if theme propagation is enabled.

### `Wallpapers.qml`

This service is responsible for wallpaper selection and wallpaper-path resolution.

Its job is more complex than simply storing a file path.

It resolves the effective wallpaper based on:

- current panel family
- backdrop configuration
- whether multi-monitor wallpaper is enabled
- whether wallpaper theming should use the main wallpaper or backdrop wallpaper
- whether the wallpaper is a video and needs a first-frame thumbnail

It also invokes the wallpaper switch script and updates config for per-monitor wallpaper assignments.

This means wallpaper changes affect:

- background rendering
- aurora/glass visual consistency
- dynamic theme generation
- per-monitor behavior
- thumbnail and cache generation

### `NiriService.qml`

This service is the authoritative runtime bridge to Niri.

It tracks data such as:

- outputs
- workspaces
- focused workspace
- windows
- active window
- keyboard layouts

It consumes Niri event streams and commands and keeps shell state aligned with compositor state.

A change here affects workspace UIs, overviews, switchers, window-aware widgets, and any feature that reasons about outputs or focused windows.

### `FirstRunExperience.qml`

This service coordinates first-run detection.

It:

- checks whether a first-run marker file exists
- picks a default wallpaper candidate from bundled wallpapers
- applies it
- opens `welcome.qml`

Its impact is onboarding, not everyday shell behavior.

## 7. Directories centralizes path knowledge

`modules/common/Directories.qml` centralizes path derivation for:

- config
- state
- cache
- scripts
- generated files
- media cache
- wallpaper switching
- AI prompt storage
- notes, todo, and notifications

This matters because many services rely on it instead of hardcoding paths.

If you change it, you are effectively changing file locations and side effects across the project.

## 8. Settings are editor surfaces over shared state

The settings experience is split into two entrypoints:

- `settings.qml` for the main settings UI
- `waffleSettings.qml` for waffle-native settings when waffle uses its own windowed style

These settings files do not define all logic themselves. They assemble page components that read and write through shared services and config.

That means settings pages are not isolated preference screens. They are operational surfaces that mutate the same state the shell is using live.

Changing a settings page often affects:

- config persistence
- runtime reactivity
- discoverability of an existing feature
- contributor expectations about where a feature is configured

## 9. Welcome flow is a separate application surface

`welcome.qml` is a standalone onboarding UI launched on first run.

It is not just another panel in the shell. It runs as a dedicated first-run wizard surface.

Its behavior depends on:

- `Directories`
- `Config`
- `MaterialThemeLoader`
- `GlobalStates.primaryScreen`
- `FirstRunExperience`

A change here affects onboarding completion, first impression, and the first-run persistence marker.

## How the main layers relate to each other

## Shared dependency direction

Most feature work in iNiR follows this relationship chain:

- config defines what the user wants
- services and shared singletons translate that into runtime state and system interactions
- modules render the resulting behavior
- settings pages edit the same config and service-backed state
- scripts perform external work when QML should not own it directly

The project becomes easier to navigate when you identify which layer truly owns a change.

## Example: changing wallpapers

A wallpaper change is a good example because it crosses many layers.

The flow is roughly:

- the user interacts with a wallpaper UI module
- that module calls `Wallpapers`
- `Wallpapers.qml` resolves target behavior and updates config or calls scripts
- the wallpaper switch script applies the wallpaper and related theme generation
- `ThemeService` and `Appearance` react to resulting theme/wallpaper state
- background modules and glass surfaces repaint accordingly

So a wallpaper feature is not local to `modules/background/`.

It spans UI, config, scripts, and theming.

## Example: switching panel family

The flow is roughly:

- IPC or UI triggers family switching in `shell.qml`
- shell marks transition state in `GlobalStates`
- `FamilyTransitionOverlay.qml` performs the transition
- shell applies the pending family
- the corresponding panel loader tree becomes active
- settings routing changes accordingly

So family switching affects composition, not just visuals.

## Example: changing a setting toggle

The real change path is:

- a settings component writes a config value
- config emits reactivity
- services or modules bound to that key update live
- if the change touches theme, wallpaper, or compositor behavior, secondary effects may follow

So settings work is often behavior work, not just form work.

## Change impact by area

## `modules/common/Config.qml`

Touch this when:

- you need a new persisted key
- you need to change how config is read or written

Expect impact on:

- persistence
- live reactivity
- settings pages
- any module or service bound to that key

## `modules/common/Appearance.qml`

Touch this when:

- you are changing global tokens or style logic
- you are changing transparency, typography, rounding, or animation behavior

Expect impact on:

- many ii/shared modules at once
- visual regressions across styles
- GameMode-related visual behavior

## `GlobalStates.qml`

Touch this when:

- you need shell-wide transient coordination
- a panel or popup must know about another surface's state

Expect impact on:

- open/close coordination
- overlay conflict rules
- family transition logic
- waffle popup exclusivity

## `services/`

Touch this when:

- the feature needs external integration or shared runtime state
- multiple modules depend on the same logic

Expect impact on:

- all consumers of that singleton
- startup behavior if the service is eagerly instantiated
- system commands, timers, polling, or file IO

## `modules/`

Touch this when:

- the change is user-visible and local to a surface
- you are adjusting layout, interaction, or presentation

Expect impact on:

- a feature surface
- family- and style-specific rendering behavior
- config and service contracts already in use

## `scripts/`

Touch this when:

- the feature already depends on external commands or generated files
- you need system integration outside QML

Expect impact on:

- runtime side effects
- setup assumptions
- package dependencies
- tool availability on user systems

## `setup` and `sdata/`

Touch these when:

- installation or update behavior is part of the feature
- package or migration assumptions change

Expect impact on:

- installation flow
- update safety
- user data preservation
- distro-specific support

## `docs/`

Touch this when:

- behavior already exists and users/contributors need the canonical explanation

Expect impact on:

- contributor onboarding
- support burden
- accuracy of public project understanding

## Canonical files by responsibility

Use this section as a routing index.

### Shell composition

- `shell.qml`
- `ShellIiPanels.qml`
- `ShellWafflePanels.qml`
- `FamilyTransitionOverlay.qml`
- `GlobalStates.qml`

### Config and shared UI contracts

- `modules/common/Config.qml`
- `defaults/config.json`
- `modules/common/Appearance.qml`
- `modules/common/Directories.qml`

### Runtime system integration

- `services/qmldir`
- `services/ThemeService.qml`
- `services/Wallpapers.qml`
- `services/NiriService.qml`
- `services/FirstRunExperience.qml`

### Settings and onboarding

- `settings.qml`
- `waffleSettings.qml`
- `welcome.qml`

### User-facing docs

- `docs/SETUP.md`
- `docs/IPC.md`
- `docs/PACKAGES.md`
- `docs/LIMITATIONS.md`
- `docs/OPTIMIZATION.md`

### Installer and distribution surface

- `setup`
- `sdata/lib/`
- `sdata/dist-*/`

### Documentation site

- `docs-site/`

### Translation surface

- `translations/*.json`
- `translations/tools/`

## How to navigate the repo without getting lost

When you need to modify something, identify which of these questions is primary.

### Is this persisted user preference or transient runtime state?

- persisted preference -> `Config.qml` and `defaults/config.json`
- transient open/close or coordination state -> `GlobalStates.qml`

### Is this shared system logic or a local UI surface?

- shared logic -> `services/`
- local surface -> `modules/`

### Is this family-specific or cross-family?

- ii/shared visual behavior -> usually `Appearance` plus ii/shared modules
- waffle-specific behavior -> waffle modules and waffle settings surfaces
- cross-family behavior -> shell composition, config, global state, or shared services

### Does this require external commands, packages, or file generation?

- yes -> check `scripts/`, `setup`, `docs/PACKAGES.md`, and any consuming service

### Does this change public behavior users rely on?

- yes -> the code change is not complete until `docs/` reflects it when the behavior is user-visible and durable

## Practical contributor guidance

## Good places to start reading

For runtime architecture:

- `shell.qml`
- `ShellIiPanels.qml`
- `ShellWafflePanels.qml`
- `GlobalStates.qml`

For persistence and theming:

- `modules/common/Config.qml`
- `defaults/config.json`
- `modules/common/Appearance.qml`
- `services/ThemeService.qml`
- `services/Wallpapers.qml`

For setup and distribution:

- `setup`
- `docs/SETUP.md`
- `docs/PACKAGES.md`

For user automation and scripting:

- `docs/IPC.md`
- IPC handlers in the relevant modules or services

## Where mistakes are usually expensive

The highest-risk changes are usually the ones that modify shared contracts rather than local views.

In practical terms, be especially careful when changing:

- config schema
- shared visual tokens
- shell startup order
- family loading rules
- global transient state rules
- service APIs used by many modules
- scripts invoked by runtime services

These areas are powerful because they are shared. That is exactly why they have wider impact.

## Final model to keep in mind

iNiR scales by separating concerns.

- `shell.qml` decides composition
- config decides persisted intent
- services translate intent into runtime/system behavior
- modules present that behavior to the user
- global state coordinates transient UI interactions
- scripts handle external side effects
- setup and `sdata/` maintain install/update lifecycle
- `docs/` explains the real product

When you work with the project in that order, the repository becomes much easier to reason about, and changes become easier to make without unintended regressions.
