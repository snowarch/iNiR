<p align="center">
  <img src="../images/iris-2.32-principal.webp" alt="Bureau iNiR avec la famille iRiS" width="900">
</p>

<h1 align="center">iNiR</h1>

<p align="center">
  Un shell de bureau complet pour <a href="https://github.com/YaLTeR/niri">Niri</a>. Choisissez une famille, personnalisez-la et gardez-la à jour avec une seule commande.
</p>

<p align="center">
  <a href="https://inir.space">inir.space</a> ·
  <a href="https://inir.space/docs">Documentation</a> ·
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

Arch, Fedora, Debian, Ubuntu, Void et NixOS. Le [guide d'installation](https://inir.space/docs/install/) indique ce dont chacun a besoin.

## Mise à jour

```bash
inir update
```

Votre configuration et vos modifications sont conservées. Si la nouvelle version ne démarre pas, la mise à jour rétablit celle que vous aviez.

## Familles

| Material | Waffle | iRiS |
|:---:|:---:|:---:|
| <img src="../shots/families-material.webp" alt="Material" width="290"> | <img src="../shots/families-waffle.webp" alt="Waffle" width="290"> | <img src="../shots/families-iris.webp" alt="iRiS" width="290"> |
| Une barre sur n'importe quel bord, des panneaux latéraux, l'aperçu, neuf styles globaux | Une barre des tâches Windows 11 et un centre d'action | Une Island sur n'importe quel bord qui devient ce que vous ouvrez, plus un dock |

`Super+Shift+W` permet de passer de l'une à l'autre. D'autres styles, widgets, thèmes et applications web sont sur le [hub](https://inir.space/hub).

## Comment il est construit

iNiR est une base et les composants qui l'entourent, chacun dans son propre dépôt. Rien ne se compile sur votre machine : le setup et
`inir update` récupèrent chaque composant déjà compilé et le vérifient avec sha256.

| Dépôt | Rôle | Dernière version |
|---|---|---|
| **iNiR** (celui-ci) | La base : services, configuration, Settings, l'assistant de bienvenue, setup et mise à jour, l'hôte des plugins | ![](https://img.shields.io/github/v/release/snowarch/iNiR?label=&style=flat-square) |
| [inir-hub](https://github.com/snowarch/inir-hub) | Tous les plugins : les trois familles, composants, thèmes, widgets, applications web | [inir.space/hub](https://inir.space/hub) |
| [qs-rs](https://github.com/snowarch/qs-rs) | Le runtime : Quickshell réécrit en Rust, avec son propre Qt | ![](https://img.shields.io/github/v/release/snowarch/qs-rs?label=&style=flat-square) |
| [inir-accel](https://github.com/snowarch/inir-accel) | Ce que le shell exécute en arrière-plan, en Rust : couleurs, miniatures, capteurs, recherche | ![](https://img.shields.io/github/v/release/snowarch/inir-accel?label=&style=flat-square) |
| [inir-cli](https://github.com/snowarch/inir-cli) | La commande `inir` : IPC, doctor, mise à jour, `inir hub` | ![](https://img.shields.io/github/v/release/snowarch/inir-cli?label=&style=flat-square) |
| [inir-site](https://github.com/snowarch/inir-site) | [inir.space](https://inir.space) : le site, la documentation, le catalogue du hub | |
| [iNiR-Walls](https://github.com/snowarch/iNiR-Walls), [inir-mascot](https://github.com/snowarch/inir-mascot) | Le pack de fonds d'écran et l'art de Kira, tous deux optionnels dans setup | |

L'[architecture](../ARCHITECTURE_OVERVIEW.md) présente la carte complète. Pour ajouter quelque chose, faites-en un plugin :
[guide d'inir-hub](https://github.com/snowarch/inir-hub/blob/main/CONTRIBUTING.md). Pour changer la base :
[CONTRIBUTING](../../.github/CONTRIBUTING.md).

## Crédits

- [end-4](https://github.com/end-4/dots-hyprland) : illogical-impulse, les dotfiles Hyprland dont iNiR est parti
- [Quickshell](https://quickshell.outfoxxed.me/) d'outfoxxed : le framework et l'API que qs-rs conserve
- [Niri](https://github.com/YaLTeR/niri) de YaLTeR : le compositeur
- [Gakuseei](https://github.com/Gakuseei) : [Ricelin](https://github.com/Gakuseei/Ricelin), d'où viennent la barre pill et les styles washi et flame
- [pctrade/end4-pC](https://github.com/pctrade/end4-pC) : un fork avec des idées à reprendre
- Toutes les personnes qui [contribuent](https://github.com/snowarch/iNiR/graphs/contributors) et testent sur Discord

[GPL-3.0](../../LICENSE) avec les conditions de [NOTICE](../../NOTICE). Copyright (C) 2025-2026 snowarch.

<p align="center">
  <img src="https://raw.githubusercontent.com/snowarch/inir-mascot/main/inir-mascot-hero-banner.png" alt="Kira, la mascotte d'iNiR, appuyée sur le logotype d'iNiR" width="640">
</p>
