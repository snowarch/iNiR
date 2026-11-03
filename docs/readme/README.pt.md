<p align="center">
  <img src="../images/iris-2.32-principal.webp" alt="Área de trabalho do iNiR com a família iRiS" width="900">
</p>

<h1 align="center">iNiR</h1>

<p align="center">
  Uma shell de área de trabalho completa para o <a href="https://github.com/YaLTeR/niri">Niri</a>. Escolha uma família, personalize-a e mantenha-a atualizada com um único comando.
</p>

<p align="center">
  <a href="https://inir.space">inir.space</a> ·
  <a href="https://inir.space/docs">Documentação</a> ·
  <a href="https://inir.space/hub">Hub</a> ·
  <a href="https://discord.gg/pAPTfAhZUJ">Discord</a>
</p>

<p align="center">
  <sub>
    <a href="../../README.md">English</a> · <a href="README.es.md">Español</a> · <a href="README.ru.md">Русский</a> · <a href="README.zh.md">中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.pt.md">Português</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a> · <a href="README.ko.md">한국어</a> · <a href="README.hi.md">हिन्दी</a> · <a href="README.ar.md">العربية</a> · <a href="README.it.md">Italiano</a>
  </sub>
</p>

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

## Famílias

| Material | Waffle | iRiS |
|:---:|:---:|:---:|
| <img src="../shots/families-material.webp" alt="Material" width="290"> | <img src="../shots/families-waffle.webp" alt="Waffle" width="290"> | <img src="../shots/families-iris.webp" alt="iRiS" width="290"> |
| Uma barra em qualquer borda, painéis laterais, visão geral, nove estilos globais | Uma barra de tarefas do Windows 11 e centro de ação | Uma Island em qualquer borda, que se transforma no que você abre, mais um dock |

`Super+Shift+W` alterna entre elas. Mais aparências, widgets, temas e aplicativos web estão no [hub](https://inir.space/hub).

## Como é construído

O iNiR é uma base e as partes ao redor dela, cada uma em seu próprio repositório. Nada é compilado na sua máquina: o setup e
`inir update` baixam cada parte já compilada e verificam com sha256.

| Repositório | O que é | Última versão |
|---|---|---|
| **iNiR** (este) | A base: serviços, configuração, Settings, o assistente de boas-vindas, setup e atualização, o host de plugins | ![](https://img.shields.io/github/v/release/snowarch/iNiR?label=&style=flat-square) |
| [inir-hub](https://github.com/snowarch/inir-hub) | Todos os plugins: as três famílias, componentes, temas, widgets, aplicativos web | [inir.space/hub](https://inir.space/hub) |
| [qs-rs](https://github.com/snowarch/qs-rs) | O runtime: Quickshell reescrito em Rust, com o próprio Qt | ![](https://img.shields.io/github/v/release/snowarch/qs-rs?label=&style=flat-square) |
| [inir-accel](https://github.com/snowarch/inir-accel) | O que o shell executa em segundo plano, em Rust: cores, miniaturas, sensores, busca | ![](https://img.shields.io/github/v/release/snowarch/inir-accel?label=&style=flat-square) |
| [inir-cli](https://github.com/snowarch/inir-cli) | O comando `inir`: IPC, doctor, atualização, `inir hub` | ![](https://img.shields.io/github/v/release/snowarch/inir-cli?label=&style=flat-square) |
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
