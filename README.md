<p align="center">
  <img src="docs/images/releases/3.0.0/00-hero.webp" alt="iNiR 3.0: the iRiS desktop on a snowy forest at night" width="100%">
</p>

<h1 align="center">iNiR</h1>

<p align="center">
  A complete desktop shell for <a href="https://github.com/YaLTeR/niri">Niri</a>.<br>
  Pick a family, make it yours, keep it current with one command.
</p>

<p align="center">
  <a href="https://github.com/snowarch/iNiR/releases/latest"><img src="https://img.shields.io/github/v/release/snowarch/iNiR?style=flat-square&label=release&color=111111" alt="Latest release"></a>
  <a href="https://github.com/snowarch/iNiR/stargazers"><img src="https://img.shields.io/github/stars/snowarch/iNiR?style=flat-square&color=111111" alt="Stars"></a>
  <a href="https://discord.gg/pAPTfAhZUJ"><img src="https://img.shields.io/badge/discord-join-111111?style=flat-square&logo=discord&logoColor=white" alt="Discord"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-111111?style=flat-square" alt="GPL-3.0"></a>
</p>

<p align="center">
  <a href="https://inir.space">inir.space</a> ·
  <a href="https://inir.space/docs/install/">Install</a> ·
  <a href="https://inir.space/docs">Docs</a> ·
  <a href="https://inir.space/hub">Hub</a> ·
  <a href="https://inir.space/changelog">Changelog</a> ·
  <a href="https://discord.gg/pAPTfAhZUJ">Discord</a>
</p>

<p align="center">
  <sub>
    <a href="README.md">English</a> · <a href="docs/readme/README.es.md">Español</a> · <a href="docs/readme/README.ru.md">Русский</a> · <a href="docs/readme/README.zh.md">中文</a> · <a href="docs/readme/README.ja.md">日本語</a> · <a href="docs/readme/README.pt.md">Português</a> · <a href="docs/readme/README.fr.md">Français</a> · <a href="docs/readme/README.de.md">Deutsch</a> · <a href="docs/readme/README.ko.md">한국어</a> · <a href="docs/readme/README.hi.md">हिन्दी</a> · <a href="docs/readme/README.ar.md">العربية</a> · <a href="docs/readme/README.it.md">Italiano</a>
  </sub>
</p>

## What's new in 3.0

A small base with every family as a plugin, a runtime of its own, a home at [inir.space](https://inir.space), and a
new Settings for iRiS. One `inir update` brings it and keeps your config. [Read the whole changelog](CHANGELOG.md).

<table>
<tr>
<td width="50%" valign="top"><img src="docs/images/releases/3.0.0/01-prism.webp" alt="Prism" width="100%"><br><sub><b>Prism</b><br>iRiS Settings rebuilt: every option in one place, with a live preview of what it changes.</sub></td>
<td width="50%" valign="top"><img src="docs/images/releases/3.0.0/02-island.webp" alt="The Island" width="100%"><br><sub><b>The Island</b><br>Music, timers and live activities in one object at the top, in sixteen designs.</sub></td>
</tr>
<tr>
<td width="50%" valign="top"><img src="docs/images/releases/3.0.0/04-airisu.webp" alt="AIRISU" width="100%"><br><sub><b>AIRISU</b><br>The first Design: its own panels, layout and voice on the iRiS engine.</sub></td>
<td width="50%" valign="top"><img src="docs/images/releases/3.0.0/03-edit-mode.webp" alt="Edit mode" width="100%"><br><sub><b>Edit mode</b><br>Drag, resize and save desktop widgets, then switch whole desktops in one click.</sub></td>
</tr>
<tr>
<td width="50%" valign="top"><img src="docs/images/releases/3.0.0/06-material.webp" alt="Material" width="100%"><br><sub><b>Material</b><br>The same widgets in Material's own faces, with its rebuilt Settings and type.</sub></td>
<td width="50%" valign="top"><img src="docs/images/releases/3.0.0/05-hub.webp" alt="iNiR Hub" width="100%"><br><sub><b>iNiR Hub</b><br>Families, Designs, themes and widgets as plugins, at inir.space/hub and inside the shell.</sub></td>
</tr>
</table>

## Families

| Material | Waffle | iRiS |
|:---:|:---:|:---:|
| <img src="docs/shots/families-material.webp" alt="Material" width="290"> | <img src="docs/shots/families-waffle.webp" alt="Waffle" width="290"> | <img src="docs/shots/families-iris.webp" alt="iRiS" width="290"> |
| A bar on any edge, sidebars, overview, nine global styles | A Windows 11 taskbar and action center | One Island on any edge that becomes what you open, plus a dock |

`Super+Shift+W` switches between them. More looks, widgets, themes and web apps are in the [hub](https://inir.space/hub).

## Install

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup install
```

Arch, Fedora, Debian, Ubuntu, Void and NixOS. The [install guide](https://inir.space/docs/install/) has what each one needs.

## Update

```bash
inir update
```

Your config and your edits stay. If the new version doesn't start, the update puts back the one you had.

## How it's built

iNiR is a base and the parts around it, each in its own repository. Nothing compiles on your machine: setup and
`inir update` fetch every part prebuilt and check it by sha256.

| Repository | What it is | Latest |
|---|---|---|
| **iNiR** (this one) | The base: services, config, Settings, the welcome wizard, setup and update, the plugin host | ![](https://img.shields.io/github/v/release/snowarch/iNiR?label=&style=flat-square&color=111111) |
| [inir-hub](https://github.com/snowarch/inir-hub) | Every plugin: the three families, components, themes, widgets, web apps | [inir.space/hub](https://inir.space/hub) |
| [qs-rs](https://github.com/snowarch/qs-rs) | The runtime: Quickshell rewritten in Rust, with its own Qt | ![](https://img.shields.io/github/v/release/snowarch/qs-rs?label=&style=flat-square&color=111111) |
| [inir-accel](https://github.com/snowarch/inir-accel) | What the shell runs in the background, in Rust: colours, thumbnails, sensors, search | ![](https://img.shields.io/github/v/release/snowarch/inir-accel?label=&style=flat-square&color=111111) |
| [inir-cli](https://github.com/snowarch/inir-cli) | The `inir` command: IPC, doctor, update, `inir hub` | ![](https://img.shields.io/github/v/release/snowarch/inir-cli?label=&style=flat-square&color=111111) |
| [inir-site](https://github.com/snowarch/inir-site) | [inir.space](https://inir.space): the site, the docs, the hub catalogue | |
| [iNiR-Walls](https://github.com/snowarch/iNiR-Walls), [inir-mascot](https://github.com/snowarch/inir-mascot) | The wallpaper pack and Kira's art, both optional in setup | |

[Architecture](docs/ARCHITECTURE_OVERVIEW.md) has the whole map. To add something, make it a plugin:
[inir-hub's guide](https://github.com/snowarch/inir-hub/blob/main/CONTRIBUTING.md). To change the base:
[CONTRIBUTING](.github/CONTRIBUTING.md).

## Credits

- [end-4](https://github.com/end-4/dots-hyprland): illogical-impulse, the Hyprland dots iNiR started from
- [Quickshell](https://quickshell.outfoxxed.me/) by outfoxxed: the framework, and the API qs-rs keeps
- [Niri](https://github.com/YaLTeR/niri) by YaLTeR: the compositor
- [Gakuseei](https://github.com/Gakuseei): [Ricelin](https://github.com/Gakuseei/Ricelin), where the pill bar and the washi and flame look come from
- [pctrade/end4-pC](https://github.com/pctrade/end4-pC): a fork with ideas worth taking
- Everyone who [contributes](https://github.com/snowarch/iNiR/graphs/contributors) and tests on Discord

[GPL-3.0](LICENSE) with the terms in [NOTICE](NOTICE). Copyright (C) 2025-2026 snowarch.
