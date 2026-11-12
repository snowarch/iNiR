<p align="center">
  <img src="../images/readme/hero.webp" alt="눈 내린 밤 숲 위의 iRiS 데스크톱" width="100%">
</p>

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: light)" srcset="../images/readme/mark-light.svg">
    <img src="../images/readme/mark-dark.svg" alt="" width="56">
  </picture>
</p>

<h1 align="center">iNiR</h1>

<p align="center">
  <a href="https://github.com/YaLTeR/niri">Niri</a>와 <a href="https://github.com/noctalia-dev/umbriel">Umbriel</a>용 완전한 데스크톱 셸입니다. 패밀리를 고르고, 취향대로 꾸미고, 명령어 하나로 최신 상태를 유지하세요.
</p>

<p align="center">
  <a href="https://github.com/snowarch/iNiR/releases/latest"><img src="https://img.shields.io/github/v/release/snowarch/iNiR?style=flat-square&label=release&color=111111" alt="Latest release"></a>
  <a href="https://github.com/snowarch/iNiR/stargazers"><img src="https://img.shields.io/github/stars/snowarch/iNiR?style=flat-square&color=111111" alt="Stars"></a>
  <a href="https://discord.gg/pAPTfAhZUJ"><img src="https://img.shields.io/badge/discord-join-111111?style=flat-square&logo=discord&logoColor=white" alt="Discord"></a>
  <a href="../../LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-111111?style=flat-square" alt="GPL-3.0"></a>
</p>

<p align="center">
  <a href="https://inir.space">inir.space</a> ·
  <a href="https://inir.space/docs/install/">설치</a> ·
  <a href="https://inir.space/docs">문서</a> ·
  <a href="https://inir.space/hub">Hub</a> ·
  <a href="https://inir.space/changelog">변경 내역</a> ·
  <a href="https://discord.gg/pAPTfAhZUJ">Discord</a>
</p>

<p align="center">
  <sub>
    <a href="../../README.md">English</a> · <a href="README.es.md">Español</a> · <a href="README.ru.md">Русский</a> · <a href="README.zh.md">中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.pt.md">Português</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a> · <a href="README.ko.md">한국어</a> · <a href="README.hi.md">हिन्दी</a> · <a href="README.ar.md">العربية</a> · <a href="README.it.md">Italiano</a>
  </sub>
</p>

## 패밀리

<p align="center"><img src="../shots/at-work-iris.webp" alt="iRiS" width="100%"><br><sub><b>iRiS</b> · 어느 가장자리에나 둘 수 있는 Island 하나. 여는 내용에 따라 모양이 바뀌며, 도크도 있습니다</sub></p>

<table>
<tr>
<td width="50%" valign="top"><img src="../shots/at-work-material.webp" alt="Material" width="100%"><br><sub><b>Material</b> · 어느 가장자리에나 둘 수 있는 바, 사이드바, 오버뷰, 전역 스타일</sub></td>
<td width="50%" valign="top"><img src="../shots/at-work-waffle.webp" alt="Waffle" width="100%"><br><sub><b>Waffle</b> · Windows 11 작업 표시줄과 작업 센터</sub></td>
</tr>
</table>

`Super+Shift+W`로 전환합니다. 더 많은 룩, 위젯, 테마, 웹 앱은 [hub](https://inir.space/hub)에 있습니다.

## 설치

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup install
```

Arch, Fedora, Debian, Ubuntu, Void, NixOS를 지원합니다. 각 환경에 필요한 것은 [설치 가이드](https://inir.space/docs/install/)에 나와 있습니다. Niri와 Umbriel 모두에서 동작하며, Umbriel을 추가하는 방법은 [컴포지터](https://inir.space/docs/compositors/)에 있습니다.

## 업데이트

```bash
inir update
```

설정과 직접 수정한 내용은 그대로 남습니다. 새 버전이 시작되지 않으면 업데이트가 이전 버전으로 되돌립니다.

## 구성

iNiR은 기반과 그 주변 부품들로 이루어져 있으며, 각 부품은 자체 저장소에 있습니다. 내 컴퓨터에서는 아무것도 컴파일되지 않습니다. setup과
`inir update`가 모든 부품을 미리 빌드된 상태로 가져오고 sha256으로 검증합니다.

| 저장소 | 내용 | 최신 버전 |
|---|---|---|
| **iNiR** (이 저장소) | 기반: 서비스, 설정, Settings, 환영 마법사, setup과 업데이트, 플러그인 호스트 | ![](https://img.shields.io/github/v/release/snowarch/iNiR?label=&style=flat-square&color=111111) |
| [inir-hub](https://github.com/snowarch/inir-hub) | 모든 플러그인: 세 가지 패밀리, 컴포넌트, 테마, 위젯, 웹 앱 | [inir.space/hub](https://inir.space/hub) |
| [qs-rs](https://github.com/snowarch/qs-rs) | 런타임: Rust로 다시 쓴 Quickshell, 자체 Qt 포함 | ![](https://img.shields.io/github/v/release/snowarch/qs-rs?label=&style=flat-square&color=111111) |
| [inir-accel](https://github.com/snowarch/inir-accel) | 셸이 백그라운드에서 실행하는 작업을 Rust로 구현: 색, 썸네일, 센서, 검색 | ![](https://img.shields.io/github/v/release/snowarch/inir-accel?label=&style=flat-square&color=111111) |
| [inir-cli](https://github.com/snowarch/inir-cli) | `inir` 명령: IPC, 진단, 업데이트, `inir hub` | ![](https://img.shields.io/github/v/release/snowarch/inir-cli?label=&style=flat-square&color=111111) |
| [inir-site](https://github.com/snowarch/inir-site) | [inir.space](https://inir.space): 사이트, 문서, hub 카탈로그 | |
| [iNiR-Walls](https://github.com/snowarch/iNiR-Walls), [inir-mascot](https://github.com/snowarch/inir-mascot) | 배경화면 팩과 Kira의 일러스트. 둘 다 setup에서 선택 사항입니다 | |

[아키텍처](../ARCHITECTURE_OVERVIEW.md)에 전체 구조가 있습니다. 기능을 추가하려면 플러그인으로 만드세요:
[inir-hub 가이드](https://github.com/snowarch/inir-hub/blob/main/CONTRIBUTING.md). 기반을 바꾸려면:
[CONTRIBUTING](../../.github/CONTRIBUTING.md).

## 크레딧

- [end-4](https://github.com/end-4/dots-hyprland): illogical-impulse, iNiR이 시작된 Hyprland 설정(dots)
- [Quickshell](https://quickshell.outfoxxed.me/), 제작자 outfoxxed: 프레임워크, 그리고 qs-rs가 유지하는 API
- [Niri](https://github.com/YaLTeR/niri), 제작자 YaLTeR: 컴포지터
- [Umbriel](https://github.com/noctalia-dev/umbriel), 제작 Noctalia 팀: iNiR가 동작하는 또 하나의 컴포지터
- [Gakuseei](https://github.com/Gakuseei): [Ricelin](https://github.com/Gakuseei/Ricelin), 필 모양 바와 washi·flame 외관이 나온 곳
- [pctrade/end4-pC](https://github.com/pctrade/end4-pC): 가져올 만한 아이디어가 담긴 포크
- [기여](https://github.com/snowarch/iNiR/graphs/contributors)하고 Discord에서 테스트해 주시는 모든 분

[GPL-3.0](../../LICENSE) 라이선스이며, 조건은 [NOTICE](../../NOTICE)에 있습니다. 저작권 (C) 2025-2026 snowarch.
