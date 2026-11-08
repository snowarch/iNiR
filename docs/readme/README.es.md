<p align="center">
  <img src="../images/releases/3.0.0/00-hero.webp" alt="iNiR 3.0: el escritorio iRiS sobre un bosque nevado de noche" width="100%">
</p>

<h1 align="center">iNiR</h1>

<p align="center">
  Una shell de escritorio completa para <a href="https://github.com/YaLTeR/niri">Niri</a>. Elige una familia, hazla tuya y mantenla al día con un solo comando.
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

## Novedades de 3.0

Una base pequeña con cada familia como plugin, un runtime propio, un hogar en [inir.space](https://inir.space) y unos Settings nuevos para iRiS. Un `inir update` lo trae todo y conserva tu configuración. [Lee el registro de cambios completo](../../CHANGELOG.md).

<table>
<tr>
<td width="50%" valign="top"><img src="../images/releases/3.0.0/01-prism.webp" alt="Prism" width="100%"><br><sub><b>Prism</b><br>Settings de iRiS rehecho: cada opción en un solo lugar, con una vista previa en vivo de lo que cambia.</sub></td>
<td width="50%" valign="top"><img src="../images/releases/3.0.0/02-island.webp" alt="La Island" width="100%"><br><sub><b>La Island</b><br>Música, temporizadores y actividades en vivo en un solo objeto arriba, con dieciséis diseños.</sub></td>
</tr>
<tr>
<td width="50%" valign="top"><img src="../images/releases/3.0.0/04-airisu.webp" alt="AIRISU" width="100%"><br><sub><b>AIRISU</b><br>El primer Design: sus propios paneles, distribución y voz sobre el motor de iRiS.</sub></td>
<td width="50%" valign="top"><img src="../images/releases/3.0.0/03-edit-mode.webp" alt="Modo edición" width="100%"><br><sub><b>Modo edición</b><br>Arrastra, cambia el tamaño y guarda los widgets del escritorio, y cambia escritorios enteros con un clic.</sub></td>
</tr>
<tr>
<td width="50%" valign="top"><img src="../images/releases/3.0.0/06-material.webp" alt="Material" width="100%"><br><sub><b>Material</b><br>Los mismos widgets con las caras propias de Material, con sus Settings y tipografía renovados.</sub></td>
<td width="50%" valign="top"><img src="../images/releases/3.0.0/05-hub.webp" alt="iNiR Hub" width="100%"><br><sub><b>iNiR Hub</b><br>Familias, Designs, temas y widgets como plugins, en inir.space/hub y dentro de la shell.</sub></td>
</tr>
</table>

## Familias

| Material | Waffle | iRiS |
|:---:|:---:|:---:|
| <img src="../shots/families-material.webp" alt="Material" width="290"> | <img src="../shots/families-waffle.webp" alt="Waffle" width="290"> | <img src="../shots/families-iris.webp" alt="iRiS" width="290"> |
| Una barra en cualquier borde, paneles laterales, vista general, nueve estilos globales | Una barra de tareas de Windows 11 y centro de acción | Una Island en cualquier borde que se convierte en lo que abres, más un dock |

`Super+Shift+W` cambia entre ellas. Más aspectos, widgets, temas y aplicaciones web están en el [hub](https://inir.space/hub).

## Instalación

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup install
```

Arch, Fedora, Debian, Ubuntu, Void y NixOS. La [guía de instalación](https://inir.space/docs/install/) indica lo que necesita cada uno.

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
- [Gakuseei](https://github.com/Gakuseei): [Ricelin](https://github.com/Gakuseei/Ricelin), de donde vienen la barra pill y los estilos washi y flame
- [pctrade/end4-pC](https://github.com/pctrade/end4-pC): un fork con ideas que vale la pena aprovechar
- Todas las personas que [contribuyen](https://github.com/snowarch/iNiR/graphs/contributors) y prueban en Discord

[GPL-3.0](../../LICENSE) con los términos de [NOTICE](../../NOTICE). Copyright (C) 2025-2026 snowarch.
