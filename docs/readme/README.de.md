<p align="center">
  <img src="../images/iris-2.32-principal.webp" alt="iNiR-Desktop mit der Familie iRiS" width="900">
</p>

<h1 align="center">iNiR</h1>

<p align="center">
  Eine vollständige Desktop-Shell für <a href="https://github.com/YaLTeR/niri">Niri</a>. Wähle eine Familie, passe sie an deinen Geschmack an und halte sie mit einem Befehl aktuell.
</p>

<p align="center">
  <a href="https://inir.space">inir.space</a> ·
  <a href="https://inir.space/docs">Dokumentation</a> ·
  <a href="https://inir.space/hub">Hub</a> ·
  <a href="https://discord.gg/pAPTfAhZUJ">Discord</a>
</p>

<p align="center">
  <sub>
    <a href="../../README.md">English</a> · <a href="README.es.md">Español</a> · <a href="README.ru.md">Русский</a> · <a href="README.zh.md">中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.pt.md">Português</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a> · <a href="README.ko.md">한국어</a> · <a href="README.hi.md">हिन्दी</a> · <a href="README.ar.md">العربية</a> · <a href="README.it.md">Italiano</a>
  </sub>
</p>

## Installation

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup install
```

Arch, Fedora, Debian, Ubuntu, Void und NixOS. Der [Installationsleitfaden](https://inir.space/docs/install/) beschreibt, was jede braucht.

## Aktualisierung

```bash
inir update
```

Deine Konfiguration und deine Änderungen bleiben erhalten. Startet die neue Version nicht, stellt das Update die vorherige wieder her.

## Familien

| Material | Waffle | iRiS |
|:---:|:---:|:---:|
| <img src="../shots/families-material.webp" alt="Material" width="290"> | <img src="../shots/families-waffle.webp" alt="Waffle" width="290"> | <img src="../shots/families-iris.webp" alt="iRiS" width="290"> |
| Eine Leiste an jedem Rand, Seitenleisten, Übersicht, neun globale Stile | Eine Windows-11-Taskleiste und ein Aktionszentrum | Eine Island an jedem Rand, die zu dem wird, was du öffnest, plus ein Dock |

`Super+Shift+W` wechselt zwischen ihnen. Weitere Looks, Widgets, Themes und Web-Apps gibt es im [Hub](https://inir.space/hub).

## Aufbau

iNiR ist eine Basis und die Teile darum herum, jeder in einem eigenen Repository. Auf deinem Rechner wird nichts kompiliert: Setup und
`inir update` laden jeden Teil fertig gebaut herunter und prüfen ihn mit sha256.

| Repository | Funktion | Neueste Version |
|---|---|---|
| **iNiR** (dieses) | Die Basis: Dienste, Konfiguration, Settings, der Willkommensassistent, Setup und Aktualisierung, der Plugin-Host | ![](https://img.shields.io/github/v/release/snowarch/iNiR?label=&style=flat-square) |
| [inir-hub](https://github.com/snowarch/inir-hub) | Alle Plugins: die drei Familien, Komponenten, Themes, Widgets, Web-Apps | [inir.space/hub](https://inir.space/hub) |
| [qs-rs](https://github.com/snowarch/qs-rs) | Die Laufzeitumgebung: Quickshell, in Rust neu geschrieben, mit eigenem Qt | ![](https://img.shields.io/github/v/release/snowarch/qs-rs?label=&style=flat-square) |
| [inir-accel](https://github.com/snowarch/inir-accel) | Was die Shell im Hintergrund ausführt, in Rust: Farben, Miniaturen, Sensoren, Suche | ![](https://img.shields.io/github/v/release/snowarch/inir-accel?label=&style=flat-square) |
| [inir-cli](https://github.com/snowarch/inir-cli) | Der Befehl `inir`: IPC, doctor, Aktualisierung, `inir hub` | ![](https://img.shields.io/github/v/release/snowarch/inir-cli?label=&style=flat-square) |
| [inir-site](https://github.com/snowarch/inir-site) | [inir.space](https://inir.space): die Website, die Dokumentation, der Hub-Katalog | |
| [iNiR-Walls](https://github.com/snowarch/iNiR-Walls), [inir-mascot](https://github.com/snowarch/inir-mascot) | Das Hintergrundbild-Paket und Kiras Artwork, beides optional im Setup | |

Die [Architektur](../ARCHITECTURE_OVERVIEW.md) zeigt den ganzen Aufbau. Um etwas hinzuzufügen, mach es zu einem Plugin:
[Leitfaden von inir-hub](https://github.com/snowarch/inir-hub/blob/main/CONTRIBUTING.md). Um an der Basis etwas zu ändern:
[CONTRIBUTING](../../.github/CONTRIBUTING.md).

## Danksagungen

- [end-4](https://github.com/end-4/dots-hyprland): illogical-impulse, die Hyprland-Dotfiles, mit denen iNiR begann
- [Quickshell](https://quickshell.outfoxxed.me/) von outfoxxed: das Framework und die API, die qs-rs beibehält
- [Niri](https://github.com/YaLTeR/niri) von YaLTeR: der Compositor
- [Gakuseei](https://github.com/Gakuseei): [Ricelin](https://github.com/Gakuseei/Ricelin), woher die Pill-Leiste und die Looks washi und flame stammen
- [pctrade/end4-pC](https://github.com/pctrade/end4-pC): ein Fork mit Ideen, die sich lohnen
- Alle, die [beitragen](https://github.com/snowarch/iNiR/graphs/contributors) und auf Discord testen

[GPL-3.0](../../LICENSE) mit den Bedingungen in [NOTICE](../../NOTICE). Copyright (C) 2025-2026 snowarch.

<p align="center">
  <img src="https://raw.githubusercontent.com/snowarch/inir-mascot/main/inir-mascot-hero-banner.png" alt="Kira, das Maskottchen von iNiR, lehnt sich an das iNiR-Logo" width="640">
</p>
