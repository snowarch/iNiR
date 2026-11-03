<p align="center">
  <img src="../images/iris-2.32-principal.webp" alt="Desktop di iNiR con la famiglia iRiS" width="900">
</p>

<h1 align="center">iNiR</h1>

<p align="center">
  Una shell desktop completa per <a href="https://github.com/YaLTeR/niri">Niri</a>. Scegli una famiglia, rendila tua e tienila aggiornata con un solo comando.
</p>

<p align="center">
  <a href="https://inir.space">inir.space</a> ·
  <a href="https://inir.space/docs">Documentazione</a> ·
  <a href="https://inir.space/hub">Hub</a> ·
  <a href="https://discord.gg/pAPTfAhZUJ">Discord</a>
</p>

<p align="center">
  <sub>
    <a href="../../README.md">English</a> · <a href="README.es.md">Español</a> · <a href="README.ru.md">Русский</a> · <a href="README.zh.md">中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.pt.md">Português</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a> · <a href="README.ko.md">한국어</a> · <a href="README.hi.md">हिन्दी</a> · <a href="README.ar.md">العربية</a> · <a href="README.it.md">Italiano</a>
  </sub>
</p>

## Installazione

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup install
```

Arch, Fedora, Debian, Ubuntu, Void e NixOS. La [guida all'installazione](https://inir.space/docs/install/) indica cosa serve per ciascuna.

## Aggiornamento

```bash
inir update
```

La tua configurazione e le tue modifiche restano. Se la nuova versione non si avvia, l'aggiornamento ripristina quella che avevi.

## Famiglie

| Material | Waffle | iRiS |
|:---:|:---:|:---:|
| <img src="../shots/families-material.webp" alt="Material" width="290"> | <img src="../shots/families-waffle.webp" alt="Waffle" width="290"> | <img src="../shots/families-iris.webp" alt="iRiS" width="290"> |
| Una barra su qualsiasi bordo, pannelli laterali, panoramica, nove stili globali | Una barra delle applicazioni di Windows 11 e un centro azioni | Una Island su qualsiasi bordo che diventa ciò che apri, più un dock |

`Super+Shift+W` passa da una all'altra. Altri aspetti, widget, temi e web app sono nell'[hub](https://inir.space/hub).

## Come è costruito

iNiR è una base e le parti che le stanno intorno, ciascuna nel proprio repository. Sul tuo computer non si compila nulla: setup e
`inir update` scaricano ogni parte già compilata e la verificano con sha256.

| Repository | Cos'è | Ultima versione |
|---|---|---|
| **iNiR** (questo) | La base: servizi, configurazione, Settings, la procedura guidata di benvenuto, setup e aggiornamento, l'host dei plugin | ![](https://img.shields.io/github/v/release/snowarch/iNiR?label=&style=flat-square) |
| [inir-hub](https://github.com/snowarch/inir-hub) | Tutti i plugin: le tre famiglie, componenti, temi, widget, web app | [inir.space/hub](https://inir.space/hub) |
| [qs-rs](https://github.com/snowarch/qs-rs) | Il runtime: Quickshell riscritto in Rust, con il proprio Qt | ![](https://img.shields.io/github/v/release/snowarch/qs-rs?label=&style=flat-square) |
| [inir-accel](https://github.com/snowarch/inir-accel) | Ciò che la shell esegue in background, in Rust: colori, miniature, sensori, ricerca | ![](https://img.shields.io/github/v/release/snowarch/inir-accel?label=&style=flat-square) |
| [inir-cli](https://github.com/snowarch/inir-cli) | Il comando `inir`: IPC, doctor, aggiornamento, `inir hub` | ![](https://img.shields.io/github/v/release/snowarch/inir-cli?label=&style=flat-square) |
| [inir-site](https://github.com/snowarch/inir-site) | [inir.space](https://inir.space): il sito, la documentazione, il catalogo dell'hub | |
| [iNiR-Walls](https://github.com/snowarch/iNiR-Walls), [inir-mascot](https://github.com/snowarch/inir-mascot) | Il pacchetto di sfondi e l'arte di Kira, entrambi opzionali in setup | |

L'[architettura](../ARCHITECTURE_OVERVIEW.md) mostra la mappa completa. Per aggiungere qualcosa, fallo come plugin:
[guida di inir-hub](https://github.com/snowarch/inir-hub/blob/main/CONTRIBUTING.md). Per modificare la base:
[CONTRIBUTING](../../.github/CONTRIBUTING.md).

## Crediti

- [end-4](https://github.com/end-4/dots-hyprland): illogical-impulse, i dotfiles di Hyprland da cui è partito iNiR
- [Quickshell](https://quickshell.outfoxxed.me/) di outfoxxed: il framework e l'API che qs-rs mantiene
- [Niri](https://github.com/YaLTeR/niri) di YaLTeR: il compositor
- [Gakuseei](https://github.com/Gakuseei): [Ricelin](https://github.com/Gakuseei/Ricelin), da cui vengono la barra pill e gli stili washi e flame
- [pctrade/end4-pC](https://github.com/pctrade/end4-pC): un fork con idee da riprendere
- Tutte le persone che [contribuiscono](https://github.com/snowarch/iNiR/graphs/contributors) e testano su Discord

[GPL-3.0](../../LICENSE) con i termini in [NOTICE](../../NOTICE). Copyright (C) 2025-2026 snowarch.

<p align="center">
  <img src="https://raw.githubusercontent.com/snowarch/inir-mascot/main/inir-mascot-hero-banner.png" alt="Kira, la mascotte di iNiR, appoggiata al logotipo di iNiR" width="640">
</p>
