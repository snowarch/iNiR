<p align="center">
  <img src="../images/readme/hero.webp" alt="рабочий стол iRiS на фоне заснеженного ночного леса" width="100%">
</p>

<h1 align="center">iNiR</h1>

<p align="center">
  Полноценная оболочка рабочего стола для <a href="https://github.com/YaLTeR/niri">Niri</a> и <a href="https://github.com/noctalia-dev/umbriel">Umbriel</a>. Выберите семейство, настройте его под себя и обновляйте одной командой.
</p>

<p align="center">
  <a href="https://github.com/snowarch/iNiR/releases/latest"><img src="https://img.shields.io/github/v/release/snowarch/iNiR?style=flat-square&label=release&color=111111" alt="Latest release"></a>
  <a href="https://github.com/snowarch/iNiR/stargazers"><img src="https://img.shields.io/github/stars/snowarch/iNiR?style=flat-square&color=111111" alt="Stars"></a>
  <a href="https://discord.gg/pAPTfAhZUJ"><img src="https://img.shields.io/badge/discord-join-111111?style=flat-square&logo=discord&logoColor=white" alt="Discord"></a>
  <a href="../../LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-111111?style=flat-square" alt="GPL-3.0"></a>
</p>

<p align="center">
  <a href="https://inir.space">inir.space</a> ·
  <a href="https://inir.space/docs/install/">Установка</a> ·
  <a href="https://inir.space/docs">Документация</a> ·
  <a href="https://inir.space/hub">Hub</a> ·
  <a href="https://inir.space/changelog">Изменения</a> ·
  <a href="https://discord.gg/pAPTfAhZUJ">Discord</a>
</p>

<p align="center">
  <sub>
    <a href="../../README.md">English</a> · <a href="README.es.md">Español</a> · <a href="README.ru.md">Русский</a> · <a href="README.zh.md">中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.pt.md">Português</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a> · <a href="README.ko.md">한국어</a> · <a href="README.hi.md">हिन्दी</a> · <a href="README.ar.md">العربية</a> · <a href="README.it.md">Italiano</a>
  </sub>
</p>

## Семейства

<p align="center"><img src="../shots/at-work-iris.webp" alt="iRiS" width="100%"><br><sub><b>iRiS</b> · Одна Island у любого края, которая превращается в то, что вы открываете, плюс док</sub></p>

<table>
<tr>
<td width="50%" valign="top"><img src="../shots/at-work-material.webp" alt="Material" width="100%"><br><sub><b>Material</b> · Панель у любого края, боковые панели, обзор, глобальные стили</sub></td>
<td width="50%" valign="top"><img src="../shots/at-work-waffle.webp" alt="Waffle" width="100%"><br><sub><b>Waffle</b> · Панель задач Windows 11 и центр действий</sub></td>
</tr>
</table>

`Super+Shift+W` переключает между ними. Больше вариантов оформления, виджетов, тем и веб-приложений есть в [hub](https://inir.space/hub).

## Установка

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup install
```

Arch, Fedora, Debian, Ubuntu, Void и NixOS. В [руководстве по установке](https://inir.space/docs/install/) написано, что нужно каждой из них. Работает в Niri и в Umbriel: как добавить Umbriel, описано на странице [Композиторы](https://inir.space/docs/compositors/).

## Обновление

```bash
inir update
```

Ваша конфигурация и ваши правки сохраняются. Если новая версия не запускается, обновление возвращает предыдущую.

## Устройство

iNiR — это основа и части вокруг неё, каждая в своём репозитории. На вашем компьютере ничего не компилируется: setup и
`inir update` загружают каждую часть уже собранной и проверяют её по sha256.

| Репозиторий | Что это | Последняя версия |
|---|---|---|
| **iNiR** (этот) | Основа: сервисы, конфигурация, Settings, мастер приветствия, setup и обновление, хост плагинов | ![](https://img.shields.io/github/v/release/snowarch/iNiR?label=&style=flat-square&color=111111) |
| [inir-hub](https://github.com/snowarch/inir-hub) | Все плагины: три семейства, компоненты, темы, виджеты, веб-приложения | [inir.space/hub](https://inir.space/hub) |
| [qs-rs](https://github.com/snowarch/qs-rs) | Рантайм: Quickshell, переписанный на Rust, со своим Qt | ![](https://img.shields.io/github/v/release/snowarch/qs-rs?label=&style=flat-square&color=111111) |
| [inir-accel](https://github.com/snowarch/inir-accel) | То, что оболочка запускает в фоне, на Rust: цвета, миниатюры, датчики, поиск | ![](https://img.shields.io/github/v/release/snowarch/inir-accel?label=&style=flat-square&color=111111) |
| [inir-cli](https://github.com/snowarch/inir-cli) | Команда `inir`: IPC, doctor, обновление, `inir hub` | ![](https://img.shields.io/github/v/release/snowarch/inir-cli?label=&style=flat-square&color=111111) |
| [inir-site](https://github.com/snowarch/inir-site) | [inir.space](https://inir.space): сайт, документация, каталог хаба | |
| [iNiR-Walls](https://github.com/snowarch/iNiR-Walls), [inir-mascot](https://github.com/snowarch/inir-mascot) | Пакет обоев и арт Киры, оба необязательны в setup | |

[Архитектура](../ARCHITECTURE_OVERVIEW.md) содержит всю схему. Чтобы что-то добавить, сделайте это плагином:
[руководство по inir-hub](https://github.com/snowarch/inir-hub/blob/main/CONTRIBUTING.md). Чтобы изменить основу:
[CONTRIBUTING](../../.github/CONTRIBUTING.md).

## Благодарности

- [end-4](https://github.com/end-4/dots-hyprland): illogical-impulse, дотфайлы Hyprland, с которых начался iNiR
- [Quickshell](https://quickshell.outfoxxed.me/) от outfoxxed: фреймворк и API, которое сохраняет qs-rs
- [Niri](https://github.com/YaLTeR/niri) от YaLTeR: композитор
- [Umbriel](https://github.com/noctalia-dev/umbriel) от команды Noctalia: второй композитор, в котором работает iNiR
- [Gakuseei](https://github.com/Gakuseei): [Ricelin](https://github.com/Gakuseei/Ricelin), откуда пришли панель pill и стили washi и flame
- [pctrade/end4-pC](https://github.com/pctrade/end4-pC): форк с идеями, которые стоит перенять
- Все, кто [вносит вклад](https://github.com/snowarch/iNiR/graphs/contributors) и тестирует в Discord

[GPL-3.0](../../LICENSE) с условиями из [NOTICE](../../NOTICE). Copyright (C) 2025-2026 snowarch.
