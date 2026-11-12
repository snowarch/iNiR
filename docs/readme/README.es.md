<p align="center">
  <img src="../images/readme/hero.webp" alt="El escritorio iRiS sobre un bosque nevado de noche" width="100%">
</p>

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: light)" srcset="../images/readme/mark-light.svg">
    <img src="../images/readme/mark-dark.svg" alt="" width="56">
  </picture>
</p>

<h1 align="center">iNiR</h1>

<p align="center">
  Una shell de escritorio completa para <a href="https://github.com/YaLTeR/niri">Niri</a> y <a href="https://github.com/noctalia-dev/umbriel">Umbriel</a>. Elige una familia, hazla tuya y mantenla al día con un solo comando.
</p>

<p align="center">
  <a href="https://github.com/snowarch/iNiR/releases/latest"><img src="https://img.shields.io/github/v/release/snowarch/iNiR?style=flat-square&label=release&color=111111" alt="Latest release"></a>
  <a href="https://github.com/snowarch/iNiR/stargazers"><img src="https://img.shields.io/github/stars/snowarch/iNiR?style=flat-square&color=111111" alt="Stars"></a>
  <a href="https://discord.gg/pAPTfAhZUJ"><img src="https://img.shields.io/badge/discord-join-111111?style=flat-square&logo=discord&logoColor=white" alt="Discord"></a>
  <a href="../../LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-111111?style=flat-square" alt="GPL-3.0"></a>
</p>

<p align="center">
  <a href="https://inir.space">inir.space</a> ·
  <a href="https://inir.space/docs/install/">Instalación</a> ·
  <a href="https://inir.space/docs">Documentación</a> ·
  <a href="https://inir.space/hub">Hub</a> ·
  <a href="https://inir.space/changelog">Cambios</a> ·
  <a href="https://discord.gg/pAPTfAhZUJ">Discord</a>
</p>

<p align="center">
  <sub>
    <a href="../../README.md">English</a> · <a href="README.es.md">Español</a> · <a href="README.ru.md">Русский</a> · <a href="README.zh.md">中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.pt.md">Português</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a> · <a href="README.ko.md">한국어</a> · <a href="README.hi.md">हिन्दी</a> · <a href="README.ar.md">العربية</a> · <a href="README.it.md">Italiano</a>
  </sub>
</p>

## Familias

<p align="center"><img src="../shots/at-work-iris.webp" alt="iRiS" width="100%"><br><sub><b>iRiS</b> · Una Island en cualquier borde que se convierte en lo que abres, más un dock</sub></p>

<table>
<tr>
<td width="50%" valign="top"><img src="../shots/at-work-material.webp" alt="Material" width="100%"><br><sub><b>Material</b> · Una barra en cualquier borde, paneles laterales, vista general, estilos globales</sub></td>
<td width="50%" valign="top"><img src="../shots/at-work-waffle.webp" alt="Waffle" width="100%"><br><sub><b>Waffle</b> · Una barra de tareas de Windows 11 y centro de acción</sub></td>
</tr>
</table>

`Super+Shift+W` cambia entre ellas. Más aspectos, widgets, temas y aplicaciones web están en el [hub](https://inir.space/hub).

## Instalación

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup install
```

Arch, Fedora, Debian, Ubuntu, Void y NixOS. La [guía de instalación](https://inir.space/docs/install/) indica lo que necesita cada uno. Funciona en Niri y en Umbriel: [Compositores](https://inir.space/docs/compositors/) explica cómo añadir Umbriel.

## Actualización

```bash
inir update
```

Tu configuración y tus cambios se mantienen. Si la nueva versión no arranca, la actualización restaura la versión que tenías.

## Cómo está construido

iNiR es una base y las partes que la rodean, cada una en su propio repositorio. Nada se compila en tu máquina: el setup y
`inir update` descargan cada parte ya compilada y la verifican con sha256.

| Repositorio | Qué es | Última versión |
|---|---|---|
| **iNiR** (este) | La base: servicios, configuración, Settings, el asistente de bienvenida, setup y actualización, el host de plugins | ![](https://img.shields.io/github/v/release/snowarch/iNiR?label=&style=flat-square&color=111111) |
| [inir-hub](https://github.com/snowarch/inir-hub) | Todos los plugins: las tres familias, componentes, temas, widgets, aplicaciones web | [inir.space/hub](https://inir.space/hub) |
| [qs-rs](https://github.com/snowarch/qs-rs) | El runtime: Quickshell reescrito en Rust, con su propio Qt | ![](https://img.shields.io/github/v/release/snowarch/qs-rs?label=&style=flat-square&color=111111) |
| [inir-accel](https://github.com/snowarch/inir-accel) | Lo que la shell ejecuta en segundo plano, en Rust: colores, miniaturas, sensores, búsqueda | ![](https://img.shields.io/github/v/release/snowarch/inir-accel?label=&style=flat-square&color=111111) |
| [inir-cli](https://github.com/snowarch/inir-cli) | El comando `inir`: IPC, doctor, actualización, `inir hub` | ![](https://img.shields.io/github/v/release/snowarch/inir-cli?label=&style=flat-square&color=111111) |
| [inir-site](https://github.com/snowarch/inir-site) | [inir.space](https://inir.space): el sitio, la documentación, el catálogo del hub | |
| [iNiR-Walls](https://github.com/snowarch/iNiR-Walls), [inir-mascot](https://github.com/snowarch/inir-mascot) | El paquete de fondos de pantalla y el arte de Kira, ambos opcionales en el setup | |

[Arquitectura](../ARCHITECTURE_OVERVIEW.md) tiene el mapa completo. Para añadir algo, hazlo como plugin:
[guía de inir-hub](https://github.com/snowarch/inir-hub/blob/main/CONTRIBUTING.md). Para cambiar la base:
[CONTRIBUTING](../../.github/CONTRIBUTING.md).

## Créditos

- [end-4](https://github.com/end-4/dots-hyprland): illogical-impulse, los dotfiles de Hyprland desde los que empezó iNiR
- [Quickshell](https://quickshell.outfoxxed.me/) de outfoxxed: el framework y la API que conserva qs-rs
- [Niri](https://github.com/YaLTeR/niri) de YaLTeR: el compositor
- [Umbriel](https://github.com/noctalia-dev/umbriel) del equipo de Noctalia: el otro compositor en el que funciona iNiR
- [Gakuseei](https://github.com/Gakuseei): [Ricelin](https://github.com/Gakuseei/Ricelin), de donde vienen la barra pill y los estilos washi y flame
- [pctrade/end4-pC](https://github.com/pctrade/end4-pC): un fork con ideas que vale la pena aprovechar
- Todas las personas que [contribuyen](https://github.com/snowarch/iNiR/graphs/contributors) y prueban en Discord

[GPL-3.0](../../LICENSE) con los términos de [NOTICE](../../NOTICE). Copyright (C) 2025-2026 snowarch.
