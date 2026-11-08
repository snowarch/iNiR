<p align="center">
  <img src="../images/releases/3.0.0/00-hero.webp" alt="iNiR 3.0 : le bureau iRiS sur une forêt enneigée la nuit" width="100%">
</p>

<h1 align="center">iNiR</h1>

<p align="center">
  Un shell de bureau complet pour <a href="https://github.com/YaLTeR/niri">Niri</a> et <a href="https://github.com/noctalia-dev/umbriel">Umbriel</a>. Choisissez une famille, personnalisez-la et gardez-la à jour avec une seule commande.
</p>

<p align="center">
  <a href="https://github.com/snowarch/iNiR/releases/latest"><img src="https://img.shields.io/github/v/release/snowarch/iNiR?style=flat-square&label=release&color=111111" alt="Latest release"></a>
  <a href="https://github.com/snowarch/iNiR/stargazers"><img src="https://img.shields.io/github/stars/snowarch/iNiR?style=flat-square&color=111111" alt="Stars"></a>
  <a href="https://discord.gg/pAPTfAhZUJ"><img src="https://img.shields.io/badge/discord-join-111111?style=flat-square&logo=discord&logoColor=white" alt="Discord"></a>
  <a href="../../LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-111111?style=flat-square" alt="GPL-3.0"></a>
</p>

<p align="center">
  <a href="https://inir.space">inir.space</a> ·
  <a href="https://inir.space/docs/install/">Installation</a> ·
  <a href="https://inir.space/docs">Documentation</a> ·
  <a href="https://inir.space/hub">Hub</a> ·
  <a href="https://inir.space/changelog">Changelog</a> ·
  <a href="https://discord.gg/pAPTfAhZUJ">Discord</a>
</p>

<p align="center">
  <sub>
    <a href="../../README.md">English</a> · <a href="README.es.md">Español</a> · <a href="README.ru.md">Русский</a> · <a href="README.zh.md">中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.pt.md">Português</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a> · <a href="README.ko.md">한국어</a> · <a href="README.hi.md">हिन्दी</a> · <a href="README.ar.md">العربية</a> · <a href="README.it.md">Italiano</a>
  </sub>
</p>

## Nouveautés de la 3.0

Une base réduite où chaque famille est un plugin, un runtime à elle, un foyer sur [inir.space](https://inir.space) et de nouveaux Settings pour iRiS. Un seul `inir update` apporte tout cela et conserve votre configuration. [Lire le changelog complet](../../CHANGELOG.md).

<table>
<tr>
<td width="50%" valign="top"><img src="../images/releases/3.0.0/01-prism.webp" alt="Prism" width="100%"><br><sub><b>Prism</b><br>Les Settings d'iRiS refaits : chaque option au même endroit, avec un aperçu en direct de ce qu'elle change.</sub></td>
<td width="50%" valign="top"><img src="../images/releases/3.0.0/02-island.webp" alt="L'Island" width="100%"><br><sub><b>L'Island</b><br>Musique, minuteurs et activités en direct dans un seul objet en haut, en seize designs.</sub></td>
</tr>
<tr>
<td width="50%" valign="top"><img src="../images/releases/3.0.0/04-airisu.webp" alt="AIRISU" width="100%"><br><sub><b>AIRISU</b><br>Le premier Design : ses propres panneaux, sa disposition et sa voix sur le moteur d'iRiS.</sub></td>
<td width="50%" valign="top"><img src="../images/releases/3.0.0/03-edit-mode.webp" alt="Mode édition" width="100%"><br><sub><b>Mode édition</b><br>Déplacez, redimensionnez et enregistrez les widgets du bureau, puis changez de bureau entier en un clic.</sub></td>
</tr>
<tr>
<td width="50%" valign="top"><img src="../images/releases/3.0.0/06-material.webp" alt="Material" width="100%"><br><sub><b>Material</b><br>Les mêmes widgets avec les visages propres à Material, avec ses Settings et sa typographie refaits.</sub></td>
<td width="50%" valign="top"><img src="../images/releases/3.0.0/05-hub.webp" alt="iNiR Hub" width="100%"><br><sub><b>iNiR Hub</b><br>Familles, Designs, thèmes et widgets en plugins, sur inir.space/hub et dans le shell.</sub></td>
</tr>
</table>

## Familles

| Material | Waffle | iRiS |
|:---:|:---:|:---:|
| <img src="../shots/families-material.webp" alt="Material" width="290"> | <img src="../shots/families-waffle.webp" alt="Waffle" width="290"> | <img src="../shots/families-iris.webp" alt="iRiS" width="290"> |
| Une barre sur n'importe quel bord, des panneaux latéraux, l'aperçu, neuf styles globaux | Une barre des tâches Windows 11 et un centre d'action | Une Island sur n'importe quel bord qui devient ce que vous ouvrez, plus un dock |

`Super+Shift+W` permet de passer de l'une à l'autre. D'autres styles, widgets, thèmes et applications web sont sur le [hub](https://inir.space/hub).

## Installation

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup install
```

Arch, Fedora, Debian, Ubuntu, Void et NixOS. Le [guide d'installation](https://inir.space/docs/install/) indique ce dont chacun a besoin. Il fonctionne sous Niri et sous Umbriel : [Compositeurs](https://inir.space/docs/compositors/) explique comment ajouter Umbriel.

## Mise à jour

```bash
inir update
```

Votre configuration et vos modifications sont conservées. Si la nouvelle version ne démarre pas, la mise à jour rétablit celle que vous aviez.

## Comment il est construit

iNiR est une base et les composants qui l'entourent, chacun dans son propre dépôt. Rien ne se compile sur votre machine : le setup et
`inir update` récupèrent chaque composant déjà compilé et le vérifient avec sha256.

| Dépôt | Rôle | Dernière version |
|---|---|---|
| **iNiR** (celui-ci) | La base : services, configuration, Settings, l'assistant de bienvenue, setup et mise à jour, l'hôte des plugins | ![](https://img.shields.io/github/v/release/snowarch/iNiR?label=&style=flat-square&color=111111) |
| [inir-hub](https://github.com/snowarch/inir-hub) | Tous les plugins : les trois familles, composants, thèmes, widgets, applications web | [inir.space/hub](https://inir.space/hub) |
| [qs-rs](https://github.com/snowarch/qs-rs) | Le runtime : Quickshell réécrit en Rust, avec son propre Qt | ![](https://img.shields.io/github/v/release/snowarch/qs-rs?label=&style=flat-square&color=111111) |
| [inir-accel](https://github.com/snowarch/inir-accel) | Ce que le shell exécute en arrière-plan, en Rust : couleurs, miniatures, capteurs, recherche | ![](https://img.shields.io/github/v/release/snowarch/inir-accel?label=&style=flat-square&color=111111) |
| [inir-cli](https://github.com/snowarch/inir-cli) | La commande `inir` : IPC, doctor, mise à jour, `inir hub` | ![](https://img.shields.io/github/v/release/snowarch/inir-cli?label=&style=flat-square&color=111111) |
| [inir-site](https://github.com/snowarch/inir-site) | [inir.space](https://inir.space) : le site, la documentation, le catalogue du hub | |
| [iNiR-Walls](https://github.com/snowarch/iNiR-Walls), [inir-mascot](https://github.com/snowarch/inir-mascot) | Le pack de fonds d'écran et l'art de Kira, tous deux optionnels dans setup | |

L'[architecture](../ARCHITECTURE_OVERVIEW.md) présente la carte complète. Pour ajouter quelque chose, faites-en un plugin :
[guide d'inir-hub](https://github.com/snowarch/inir-hub/blob/main/CONTRIBUTING.md). Pour changer la base :
[CONTRIBUTING](../../.github/CONTRIBUTING.md).

## Crédits

- [end-4](https://github.com/end-4/dots-hyprland) : illogical-impulse, les dotfiles Hyprland dont iNiR est parti
- [Quickshell](https://quickshell.outfoxxed.me/) d'outfoxxed : le framework et l'API que qs-rs conserve
- [Niri](https://github.com/YaLTeR/niri) de YaLTeR : le compositeur
- [Umbriel](https://github.com/noctalia-dev/umbriel) de l'équipe Noctalia : l'autre compositeur sur lequel iNiR fonctionne
- [Gakuseei](https://github.com/Gakuseei) : [Ricelin](https://github.com/Gakuseei/Ricelin), d'où viennent la barre pill et les styles washi et flame
- [pctrade/end4-pC](https://github.com/pctrade/end4-pC) : un fork avec des idées à reprendre
- Toutes les personnes qui [contribuent](https://github.com/snowarch/iNiR/graphs/contributors) et testent sur Discord

[GPL-3.0](../../LICENSE) avec les conditions de [NOTICE](../../NOTICE). Copyright (C) 2025-2026 snowarch.
