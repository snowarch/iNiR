<p align="center">
  <img src="../images/releases/3.0.0/00-hero.webp" alt="iNiR 3.0: o desktop iRiS sobre uma floresta nevada à noite" width="100%">
</p>

<h1 align="center">iNiR</h1>

<p align="center">
  Uma shell de área de trabalho completa para o <a href="https://github.com/YaLTeR/niri">Niri</a>. Escolha uma família, personalize-a e mantenha-a atualizada com um único comando.
</p>

<p align="center">
  <a href="https://github.com/snowarch/iNiR/releases/latest"><img src="https://img.shields.io/github/v/release/snowarch/iNiR?style=flat-square&label=release&color=111111" alt="Latest release"></a>
  <a href="https://github.com/snowarch/iNiR/stargazers"><img src="https://img.shields.io/github/stars/snowarch/iNiR?style=flat-square&color=111111" alt="Stars"></a>
  <a href="https://discord.gg/pAPTfAhZUJ"><img src="https://img.shields.io/badge/discord-join-111111?style=flat-square&logo=discord&logoColor=white" alt="Discord"></a>
  <a href="../../LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-111111?style=flat-square" alt="GPL-3.0"></a>
</p>

<p align="center">
  <a href="https://inir.space">inir.space</a> ·
  <a href="https://inir.space/docs/install/">Instalação</a> ·
  <a href="https://inir.space/docs">Documentação</a> ·
  <a href="https://inir.space/hub">Hub</a> ·
  <a href="https://inir.space/changelog">Changelog</a> ·
  <a href="https://discord.gg/pAPTfAhZUJ">Discord</a>
</p>

<p align="center">
  <sub>
    <a href="../../README.md">English</a> · <a href="README.es.md">Español</a> · <a href="README.ru.md">Русский</a> · <a href="README.zh.md">中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.pt.md">Português</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a> · <a href="README.ko.md">한국어</a> · <a href="README.hi.md">हिन्दी</a> · <a href="README.ar.md">العربية</a> · <a href="README.it.md">Italiano</a>
  </sub>
</p>

## Novidades da 3.0

Uma base pequena com cada família como plugin, um runtime próprio, uma casa em [inir.space](https://inir.space) e novas Settings para o iRiS. Um `inir update` traz tudo isso e mantém sua configuração. [Leia o changelog completo](../../CHANGELOG.md).

<table>
<tr>
<td width="50%" valign="top"><img src="../images/releases/3.0.0/01-prism.webp" alt="Prism" width="100%"><br><sub><b>Prism</b><br>As Settings do iRiS refeitas: cada opção em um só lugar, com uma prévia ao vivo do que ela muda.</sub></td>
<td width="50%" valign="top"><img src="../images/releases/3.0.0/02-island.webp" alt="A Island" width="100%"><br><sub><b>A Island</b><br>Música, timers e atividades ao vivo em um único objeto no topo, em dezesseis designs.</sub></td>
</tr>
<tr>
<td width="50%" valign="top"><img src="../images/releases/3.0.0/04-airisu.webp" alt="AIRISU" width="100%"><br><sub><b>AIRISU</b><br>O primeiro Design: painéis, layout e voz próprios sobre o motor do iRiS.</sub></td>
<td width="50%" valign="top"><img src="../images/releases/3.0.0/03-edit-mode.webp" alt="Modo de edição" width="100%"><br><sub><b>Modo de edição</b><br>Arraste, redimensione e salve os widgets da área de trabalho, e troque áreas de trabalho inteiras com um clique.</sub></td>
</tr>
<tr>
<td width="50%" valign="top"><img src="../images/releases/3.0.0/06-material.webp" alt="Material" width="100%"><br><sub><b>Material</b><br>Os mesmos widgets com as faces próprias do Material, com Settings e tipografia renovadas.</sub></td>
<td width="50%" valign="top"><img src="../images/releases/3.0.0/05-hub.webp" alt="iNiR Hub" width="100%"><br><sub><b>iNiR Hub</b><br>Famílias, Designs, temas e widgets como plugins, em inir.space/hub e dentro do shell.</sub></td>
</tr>
</table>

## Famílias

| Material | Waffle | iRiS |
|:---:|:---:|:---:|
| <img src="../shots/families-material.webp" alt="Material" width="290"> | <img src="../shots/families-waffle.webp" alt="Waffle" width="290"> | <img src="../shots/families-iris.webp" alt="iRiS" width="290"> |
| Uma barra em qualquer borda, painéis laterais, visão geral, nove estilos globais | Uma barra de tarefas do Windows 11 e centro de ação | Uma Island em qualquer borda, que se transforma no que você abre, mais um dock |

`Super+Shift+W` alterna entre elas. Mais aparências, widgets, temas e aplicativos web estão no [hub](https://inir.space/hub).

## Instalação

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup install
```

Arch, Fedora, Debian, Ubuntu, Void e NixOS. O [guia de instalação](https://inir.space/docs/install/) mostra o que cada um precisa.

## Atualização

```bash
inir update
```

Sua configuração e suas alterações são mantidas. Se a nova versão não iniciar, a atualização restaura a versão que você tinha.

## Como é construído

O iNiR é uma base e as partes ao redor dela, cada uma em seu próprio repositório. Nada é compilado na sua máquina: o setup e
`inir update` baixam cada parte já compilada e verificam com sha256.

| Repositório | O que é | Última versão |
|---|---|---|
| **iNiR** (este) | A base: serviços, configuração, Settings, o assistente de boas-vindas, setup e atualização, o host de plugins | ![](https://img.shields.io/github/v/release/snowarch/iNiR?label=&style=flat-square&color=111111) |
| [inir-hub](https://github.com/snowarch/inir-hub) | Todos os plugins: as três famílias, componentes, temas, widgets, aplicativos web | [inir.space/hub](https://inir.space/hub) |
| [qs-rs](https://github.com/snowarch/qs-rs) | O runtime: Quickshell reescrito em Rust, com o próprio Qt | ![](https://img.shields.io/github/v/release/snowarch/qs-rs?label=&style=flat-square&color=111111) |
| [inir-accel](https://github.com/snowarch/inir-accel) | O que o shell executa em segundo plano, em Rust: cores, miniaturas, sensores, busca | ![](https://img.shields.io/github/v/release/snowarch/inir-accel?label=&style=flat-square&color=111111) |
| [inir-cli](https://github.com/snowarch/inir-cli) | O comando `inir`: IPC, doctor, atualização, `inir hub` | ![](https://img.shields.io/github/v/release/snowarch/inir-cli?label=&style=flat-square&color=111111) |
| [inir-site](https://github.com/snowarch/inir-site) | [inir.space](https://inir.space): o site, a documentação, o catálogo do hub | |
| [iNiR-Walls](https://github.com/snowarch/iNiR-Walls), [inir-mascot](https://github.com/snowarch/inir-mascot) | O pacote de papéis de parede e a arte da Kira, ambos opcionais no setup | |

[Arquitetura](../ARCHITECTURE_OVERVIEW.md) mostra o mapa completo. Para adicionar algo, faça-o como plugin:
[guia do inir-hub](https://github.com/snowarch/inir-hub/blob/main/CONTRIBUTING.md). Para alterar a base:
[CONTRIBUTING](../../.github/CONTRIBUTING.md).

## Créditos

- [end-4](https://github.com/end-4/dots-hyprland): illogical-impulse, os dotfiles do Hyprland de onde o iNiR começou
- [Quickshell](https://quickshell.outfoxxed.me/) de outfoxxed: o framework e a API que o qs-rs mantém
- [Niri](https://github.com/YaLTeR/niri) de YaLTeR: o compositor
- [Gakuseei](https://github.com/Gakuseei): [Ricelin](https://github.com/Gakuseei/Ricelin), de onde vêm a barra pill e os estilos washi e flame
- [pctrade/end4-pC](https://github.com/pctrade/end4-pC): um fork com ideias que vale a pena aproveitar
- Todas as pessoas que [contribuem](https://github.com/snowarch/iNiR/graphs/contributors) e testam no Discord

[GPL-3.0](../../LICENSE) com os termos em [NOTICE](../../NOTICE). Copyright (C) 2025-2026 snowarch.

<p align="center">
  <img src="https://raw.githubusercontent.com/snowarch/inir-mascot/main/inir-mascot-hero-banner.png" alt="Kira, a mascote do iNiR, apoiada no logotipo do iNiR" width="640">
</p>
