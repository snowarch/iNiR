<p align="center">
  <img src="../images/releases/3.0.0/00-hero.webp" alt="iNiR 3.0: il desktop iRiS su un bosco innevato di notte" width="100%">
</p>

<h1 align="center">iNiR</h1>

<p align="center">
  Una shell desktop completa per <a href="https://github.com/YaLTeR/niri">Niri</a> e <a href="https://github.com/noctalia-dev/umbriel">Umbriel</a>. Scegli una famiglia, rendila tua e tienila aggiornata con un solo comando.
</p>

<p align="center">
  <a href="https://github.com/snowarch/iNiR/releases/latest"><img src="https://img.shields.io/github/v/release/snowarch/iNiR?style=flat-square&label=release&color=111111" alt="Latest release"></a>
  <a href="https://github.com/snowarch/iNiR/stargazers"><img src="https://img.shields.io/github/stars/snowarch/iNiR?style=flat-square&color=111111" alt="Stars"></a>
  <a href="https://discord.gg/pAPTfAhZUJ"><img src="https://img.shields.io/badge/discord-join-111111?style=flat-square&logo=discord&logoColor=white" alt="Discord"></a>
  <a href="../../LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-111111?style=flat-square" alt="GPL-3.0"></a>
</p>

<p align="center">
  <a href="https://inir.space">inir.space</a> ·
  <a href="https://inir.space/docs/install/">Installazione</a> ·
  <a href="https://inir.space/docs">Documentazione</a> ·
  <a href="https://inir.space/hub">Hub</a> ·
  <a href="https://inir.space/changelog">Changelog</a> ·
  <a href="https://discord.gg/pAPTfAhZUJ">Discord</a>
</p>

<p align="center">
  <sub>
    <a href="../../README.md">English</a> · <a href="README.es.md">Español</a> · <a href="README.ru.md">Русский</a> · <a href="README.zh.md">中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.pt.md">Português</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a> · <a href="README.ko.md">한국어</a> · <a href="README.hi.md">हिन्दी</a> · <a href="README.ar.md">العربية</a> · <a href="README.it.md">Italiano</a>
  </sub>
</p>

## Novità della 3.0

Una base piccola con ogni famiglia come plugin, un runtime tutto suo, una casa su [inir.space](https://inir.space) e nuove Settings per iRiS. Un solo `inir update` porta tutto e mantiene la tua configurazione. [Leggi il changelog completo](../../CHANGELOG.md).

<table>
<tr>
<td width="50%" valign="top"><img src="../images/releases/3.0.0/01-prism.webp" alt="Prism" width="100%"><br><sub><b>Prism</b><br>Le Settings di iRiS rifatte: ogni opzione in un solo posto, con un'anteprima dal vivo di ciò che cambia.</sub></td>
<td width="50%" valign="top"><img src="../images/releases/3.0.0/02-island.webp" alt="L'Island" width="100%"><br><sub><b>L'Island</b><br>Musica, timer e attività dal vivo in un solo oggetto in alto, in sedici design.</sub></td>
</tr>
<tr>
<td width="50%" valign="top"><img src="../images/releases/3.0.0/04-airisu.webp" alt="AIRISU" width="100%"><br><sub><b>AIRISU</b><br>Il primo Design: pannelli, layout e voce propri sul motore di iRiS.</sub></td>
<td width="50%" valign="top"><img src="../images/releases/3.0.0/03-edit-mode.webp" alt="Modalità modifica" width="100%"><br><sub><b>Modalità modifica</b><br>Trascina, ridimensiona e salva i widget del desktop, poi cambia interi desktop con un clic.</sub></td>
</tr>
<tr>
<td width="50%" valign="top"><img src="../images/releases/3.0.0/06-material.webp" alt="Material" width="100%"><br><sub><b>Material</b><br>Gli stessi widget con i volti propri di Material, con Settings e tipografia rinnovate.</sub></td>
<td width="50%" valign="top"><img src="../images/releases/3.0.0/05-hub.webp" alt="iNiR Hub" width="100%"><br><sub><b>iNiR Hub</b><br>Famiglie, Design, temi e widget come plugin, su inir.space/hub e dentro la shell.</sub></td>
</tr>
</table>

## Famiglie

| Material | Waffle | iRiS |
|:---:|:---:|:---:|
| <img src="../shots/families-material.webp" alt="Material" width="290"> | <img src="../shots/families-waffle.webp" alt="Waffle" width="290"> | <img src="../shots/families-iris.webp" alt="iRiS" width="290"> |
| Una barra su qualsiasi bordo, pannelli laterali, panoramica, nove stili globali | Una barra delle applicazioni di Windows 11 e un centro azioni | Una Island su qualsiasi bordo che diventa ciò che apri, più un dock |

`Super+Shift+W` passa da una all'altra. Altri aspetti, widget, temi e web app sono nell'[hub](https://inir.space/hub).

## Installazione

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup install
```

Arch, Fedora, Debian, Ubuntu, Void e NixOS. La [guida all'installazione](https://inir.space/docs/install/) indica cosa serve per ciascuna. Funziona su Niri e su Umbriel: [Compositor](https://inir.space/docs/compositors/) spiega come aggiungere Umbriel.

## Aggiornamento

```bash
inir update
```

La tua configurazione e le tue modifiche restano. Se la nuova versione non si avvia, l'aggiornamento ripristina quella che avevi.

## Come è costruito

iNiR è una base e le parti che le stanno intorno, ciascuna nel proprio repository. Sul tuo computer non si compila nulla: setup e
`inir update` scaricano ogni parte già compilata e la verificano con sha256.

| Repository | Cos'è | Ultima versione |
|---|---|---|
| **iNiR** (questo) | La base: servizi, configurazione, Settings, la procedura guidata di benvenuto, setup e aggiornamento, l'host dei plugin | ![](https://img.shields.io/github/v/release/snowarch/iNiR?label=&style=flat-square&color=111111) |
| [inir-hub](https://github.com/snowarch/inir-hub) | Tutti i plugin: le tre famiglie, componenti, temi, widget, web app | [inir.space/hub](https://inir.space/hub) |
| [qs-rs](https://github.com/snowarch/qs-rs) | Il runtime: Quickshell riscritto in Rust, con il proprio Qt | ![](https://img.shields.io/github/v/release/snowarch/qs-rs?label=&style=flat-square&color=111111) |
| [inir-accel](https://github.com/snowarch/inir-accel) | Ciò che la shell esegue in background, in Rust: colori, miniature, sensori, ricerca | ![](https://img.shields.io/github/v/release/snowarch/inir-accel?label=&style=flat-square&color=111111) |
| [inir-cli](https://github.com/snowarch/inir-cli) | Il comando `inir`: IPC, doctor, aggiornamento, `inir hub` | ![](https://img.shields.io/github/v/release/snowarch/inir-cli?label=&style=flat-square&color=111111) |
| [inir-site](https://github.com/snowarch/inir-site) | [inir.space](https://inir.space): il sito, la documentazione, il catalogo dell'hub | |
| [iNiR-Walls](https://github.com/snowarch/iNiR-Walls), [inir-mascot](https://github.com/snowarch/inir-mascot) | Il pacchetto di sfondi e l'arte di Kira, entrambi opzionali in setup | |

L'[architettura](../ARCHITECTURE_OVERVIEW.md) mostra la mappa completa. Per aggiungere qualcosa, fallo come plugin:
[guida di inir-hub](https://github.com/snowarch/inir-hub/blob/main/CONTRIBUTING.md). Per modificare la base:
[CONTRIBUTING](../../.github/CONTRIBUTING.md).

## Crediti

- [end-4](https://github.com/end-4/dots-hyprland): illogical-impulse, i dotfiles di Hyprland da cui è partito iNiR
- [Quickshell](https://quickshell.outfoxxed.me/) di outfoxxed: il framework e l'API che qs-rs mantiene
- [Niri](https://github.com/YaLTeR/niri) di YaLTeR: il compositor
- [Umbriel](https://github.com/noctalia-dev/umbriel) del team Noctalia: l'altro compositor su cui gira iNiR
- [Gakuseei](https://github.com/Gakuseei): [Ricelin](https://github.com/Gakuseei/Ricelin), da cui vengono la barra pill e gli stili washi e flame
- [pctrade/end4-pC](https://github.com/pctrade/end4-pC): un fork con idee da riprendere
- Tutte le persone che [contribuiscono](https://github.com/snowarch/iNiR/graphs/contributors) e testano su Discord

[GPL-3.0](../../LICENSE) con i termini in [NOTICE](../../NOTICE). Copyright (C) 2025-2026 snowarch.
