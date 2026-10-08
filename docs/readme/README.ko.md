<p align="center">
  <img src="../images/iris-2.32-principal.webp" alt="iNiR iRiS desktop" width="900">
</p>

<h1 align="center">iNiR</h1>

<p align="center">
  <b>Quickshell로 만든 Niri용 완전한 데스크톱 셸</b>
</p>

<p align="center">
  <a href="https://github.com/snowarch/inir/releases"><img src="https://img.shields.io/badge/version-2.32.0-blue?style=flat-square" alt="Version"></a>
  <a href="https://github.com/snowarch/inir/stargazers"><img src="https://img.shields.io/github/stars/snowarch/inir?style=flat-square" alt="Stars"></a>
  <a href="https://discord.gg/pAPTfAhZUJ"><img src="https://img.shields.io/badge/Discord-join-5865F2?style=flat-square&logo=discord&logoColor=white" alt="Discord"></a>
  <a href="../../LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-green?style=flat-square" alt="License"></a>
</p>

<p align="center">
  <a href="https://github.com/snowarch/inir/wiki/INSTALL">설치</a> &bull;
  <a href="https://github.com/snowarch/inir/wiki/KEYBINDS">단축키</a> &bull;
  <a href="https://github.com/snowarch/inir/wiki/IPC">IPC 레퍼런스</a> &bull;
  <a href="https://discord.gg/pAPTfAhZUJ">Discord</a> &bull;
  <a href="../../CONTRIBUTING.md">기여하기</a>
</p>

<p align="center">
  <sub>
    <a href="../../README.md">English</a> · <a href="README.es.md">Español</a> · <a href="README.ru.md">Русский</a> · <a href="README.zh.md">中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.pt.md">Português</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a> · <a href="README.ko.md">한국어</a> · <a href="README.hi.md">हिन्दी</a> · <a href="README.ar.md">العربية</a> · <a href="README.it.md">Italiano</a>
  </sub>
</p>

---

> **번역 안내:** 헷갈리는 부분은 [영어 버전](../../README.md)을 기준으로 해 주세요.

---

<details>
<summary><b>🤔 처음이신가요? 이게 다 뭔지 모르겠다면 클릭</b></summary>

### 이게 뭔가요?

iNiR는 데스크톱 전체입니다. 위쪽 바, Dock, 알림, 설정, 배경화면, 전부요. 테마도 아니고, 붙여 넣는 dotfiles도 아닙니다. Linux에서 돌아가는 완전한 셸입니다.

### 실행하려면 뭐가 필요한가요?

컴포지터가 필요합니다. 창을 관리하고 화면에 픽셀을 그리는 녀석이죠. iNiR는 [Niri](https://github.com/YaLTeR/niri)(Wayland 타일링 컴포지터)를 위해 만들어졌습니다. end-4의 dots를 포크하던 시절의 오래된 Hyprland 코드도 남아 있지만, 실제로 쓰고 테스트하는 건 Niri입니다.

셸은 [Quickshell](https://quickshell.outfoxxed.me/) 위에서 돌아갑니다. QML(Qt의 UI 언어)로 셸을 만드는 프레임워크예요. 쓰는 데 이걸 알 필요는 없습니다. 모든 건 GUI나 JSON 파일로 설정됩니다.

### 전체 구조

```
your apps
   ↓
iNiR (shell: bar, sidebars, dock, notifications, settings...)
   ↓
Quickshell (runs QML shells)
   ↓
Niri (compositor: windows, rendering)
   ↓
Wayland → GPU
```

### 안정적인가요?

손을 쓸 수 없게 커져 버린 개인 프로젝트입니다. 저는 매일 쓰고, Discord의 많은 분들도 씁니다. 하지만 가끔 뭔가 망가지고, 코드는 군데군데 지저분하고, 저도 하면서 배우는 중입니다.

뭔가 안 되면 `inir doctor`가 대부분 고쳐 줍니다. 그래도 안 되면 Discord가 활발해요. 다만 다듬어진 소프트웨어는 기대하지 마세요. 한 사람의 rice를 다른 사람들도 마침 좋아하게 된 것뿐입니다.

### 왜 만들었나요?

데스크톱이 특정한 모습으로, 특정한 방식으로 동작하길 원했는데 딱 그렇게 해 주는 게 없었어요. end-4의 Hyprland dots에서 시작해, 훨씬 많은 기능을 갖춘 Niri용 완전한 재작성이 되었습니다.

### 자주 보게 될 단어

- **셸**: UI 계층(바, 패널, 오버레이)
- **컴포지터**: 창을 관리하고 화면에 그림(Niri, Hyprland, Sway...)
- **Wayland**: Linux의 디스플레이 프로토콜(새로운 것, X11을 대체)
- **QML**: Qt의 선언형 UI 언어, iNiR가 이걸로 작성됨
- **Material You**: 이미지에서 팔레트를 만드는 Google의 색상 시스템(자동 테마의 원리)
- **ii / waffle / iRiS**: 세 가지 패널 패밀리. ii = Material Design 느낌, waffle = Windows 11 느낌, iRiS = 여는 것으로 변하는 Island. `Super+Shift+W`로 전환

</details>

---

## 스크린샷

<details open>
<summary><b>iRiS</b>: Island, Customize, 메뉴 막대, 카드, Dock</summary>

<p align="center">
  <img src="../images/iris-2.31-desktop.webp" alt="iRiS desktop layout" width="49%">
  <img src="../images/iris-2.31-card.webp" alt="iRiS card surface" width="49%">
</p>

<p align="center">
  <img src="../images/iris-2.31-dock.webp" alt="iRiS Dock and edge layout" width="99%">
</p>

</details>

<details open>
<summary><b>Material ii</b>: 떠 있는 바, 사이드바, Material Design 스타일</summary>

| | |
|:---:|:---:|
| ![](https://github.com/user-attachments/assets/1fe258bc-8aec-4fd9-8574-d9d7472c3cc8) | ![](https://github.com/user-attachments/assets/3ce2055b-648c-45a1-9d09-705c1b4a03b7) |
| ![](https://github.com/user-attachments/assets/ea2311dc-769e-44dc-a46d-37cf8807d2cc) | ![](https://github.com/user-attachments/assets/da6beb4a-ccee-40ba-a372-5eea77b595f8) |
| ![](https://github.com/user-attachments/assets/ba866063-b26a-47cb-83c8-d77bd033bf8b) | ![](https://github.com/user-attachments/assets/88e76566-061b-4f8c-a9a8-53c157950138) |

</details>

<details>
<summary><b>Waffle</b>: 하단 작업 표시줄, 알림 센터, Windows 11 느낌</summary>

| | |
|:---:|:---:|
| ![](https://github.com/user-attachments/assets/5c5996e7-90eb-4789-9921-0d5fe5283fa3) | ![](https://github.com/user-attachments/assets/fadf9562-751e-4138-a3a1-b87b31114d44) |

</details>

---

> [!WARNING]
> 저사양 기기용이 아닙니다.
> 그래도 꽤 가볍게 만들 수 있어요. 효과를 끄고, 패널을 빼고, 디자인을 단순하게. 설정에서든 `config.json`에서든 편한 대로.

## 기능

**세 가지 패널 패밀리**, `Super+Shift+W`로 바로 전환:
- **Material ii**: 떠 있는 바, 사이드바, Dock, 9가지 글로벌 스타일(Material, Cards, Aurora, iNiR, Angel, Regalia, ZZZ, Cookie Shapes, Editorial)
- **Waffle**: Windows 11 스타일의 작업 표시줄, 시작 메뉴, 빠른 설정, 알림 센터
- **iRiS**: 플래그십 패밀리. 화면 어느 가장자리에나 두고 페이지, 카드, 패널로 펼쳐지는 Island, 옮겨 다닐 수 있는 조각, 어느 가장자리에나 두는 Dock, 글래스, 모든 걸 다시 디자인하는 Themes, 라이트·잉크·다크, 그리고 셸 위에서 바로 하는 Customize

**자동 테마**. 배경화면을 고르면 모든 게 맞춰집니다:
- Material You로 만든 셸 색상을 GTK3/4, Qt, 터미널, Firefox, Discord, SDDM에 적용
- 10가지 테마 대상: 터미널, 에디터, 브라우저, Spicetify, Steam, Cava 등
- 테마 프리셋: Regalia / Regalia Ivory, Gruvbox, Catppuccin, Rosé Pine, 직접 만든 것

**Niri를 위해 만들었습니다.** Hyprland 코드는 포크 시절의 흔적이며 테스트하지 않습니다.

**Kira**는 마스코트로, 원하면 데스크톱에 삽니다. 기본은 꺼져 있고 아트 팩은 따로 내려받습니다.

<details>
<summary><b>전체 기능 목록</b></summary>

### iRiS

- **Island**: 화면 가장자리의 한 형태로, "지금 무슨 일이 일어나는지" 알려 주고 여러분이 연 페이지, 카드, 패널로 변했다가 다시 접힙니다. 위, 아래, 왼쪽, 오른쪽(`inir iris edge <side>`, 또는 끌어다 놓기). 옆에 두면 세로로 서서 시계가 세로로 쌓이고 버블이 위아래에 놓입니다
- **메뉴 막대**: 작업 공간, 창, 조각이 놓인 얇은 띠로, Island가 노치처럼 매달립니다(`inir iris layout menubar`)
- **전체 폭 바 모드**: 시작, 가운데, 끝 영역에 Island, 작업 공간, 포커스된 창, 시간, 어떤 조각이든 배치(`inir iris zone start|center|end kinds+joined+with+plus`)
- **조각(pieces)**: 날씨, 소리, 마이크, 트레이, 알림, 도구, 미디어, VPN, 비주얼라이저, 애니메이션(Airing과 Continue), 내 앱을 버블로 만들어 Island 위, 화면 윤곽, 데스크톱 어디에나 둘 수 있습니다
- **조각은 닿은 것과 합쳐집니다**: Dock이나 Island 가장자리에 두면 위에 떠 있지 않고 그 몸체의 일부가 됩니다
- **Dock**은 어느 가장자리에나(`inir iris dockEdge <side|auto>`). auto에서는 Island 반대편에 놓이고, 하나를 다른 쪽 가장자리로 보내면 자리를 바꿉니다
- **글래스**: 모든 표면 아래의 배경화면을 반투명 유리처럼 처리하고, 밝거나 복잡한 배경화면에서도 글자를 읽기 쉽게 유지합니다. 컴포지터 블러도 있지만 아직 작업 중이니 너무 일찍 판단하지는 마세요
- **Themes**: 20가지 엄선된 리디자인(Liquid Glass, Frost, Obsidian, Terminal, Neo Tokyo, Twilight, Lume, Sakura, Unit-01 등)과 공유할 수 있는 JSON 파일로 된 나만의 테마(`inir iris theme`)
- **라이트, 잉크, 다크**: 각각 고유한 톤과 반투명도를 가지며, 앱에도 적용되는 색상 테마(Catppuccin, Nord, Rosé Pine, Tokyo Night…)도 있습니다(`inir iris palette`)
- **모양**: Island와 Dock을 캡슐, 원형, 스쿼클, 사각형 중에서
- **셸 위에서 바로 Customize**: Island, Dock, 버블을 탭하면 그 자리에서 옵션이 펼쳐지고, Island 아래에 Themes, Look, Pieces, 실행 취소가 있습니다(`inir iris edit`). 원하면 Studio가 모든 걸 화면 옆 패널 하나에 모아 줍니다
- **직접 배치하는 제어 센터**: 공유 빠른 토글, 플레이어, 각 슬라이더가 칸이 되어 끌고, 모서리로 크기를 바꾸고, 옆의 라이브러리에서 추가할 수 있습니다. 시작 레이아웃 6가지, 우클릭으로 컨트롤이 펼쳐집니다(`inir iris control edit`)
- **리허설하는 잠금 화면**: 실제 잠금 화면이 편집 가능한 상태로 열리고 잠금 해제할 것은 없습니다. 시계, 플레이어, 로그인 칸을 옮기고, 뒤에 재생할 것을 동영상까지 골라요(`inir iris lock edit`)

### 테마와 모양

- **9가지 글로벌 스타일**: Material(단색), Cards, Aurora(글래스 블러), iNiR(TUI 영감), Angel(네오 브루탈리즘), Regalia(검은 섀시, 따뜻한 아이보리 잉크, 절제된 샴페인 장식), ZZZ(포스터 판), Cookie Shapes(움직이는 도형), Editorial(종이와 잉크 타이포그래피)
- **배경화면 기반 동적 색상**: Material You로 시스템 전체에
- **10가지 터미널·TUI 도구 자동 테마**: foot, kitty, alacritty, ghostty, wezterm, starship, fuzzel, btop, lazygit, yazi
- **앱 테마**: GTK3/4, Qt(plasma-integration과 darkly), Firefox, Discord/Vesktop(System24), Zed, Spicetify, Steam, SDDM
- **테마 프리셋**: Gruvbox, Catppuccin, Rosé Pine 등, 또는 직접 만들기
- **동영상 배경화면**: mp4/webm/gif, 블러는 선택. 성능을 위해 첫 프레임 고정도 가능
- **데스크톱 위젯**: 모든 위젯에 하나의 디자인(iRiS, Material, iNstrument, Readout), iOS처럼 넘어가는 스택, 아래 배경화면을 따라가는 잉크

### 바

- **6가지 바 스타일**: classic, islands, scenic, frame, Material 3 캡슐, pill
- **Pill 바**: 모양이 바뀌는 가운데 섬으로, 마우스를 올리면 작업 공간, 런처, 믹서, 미디어, 캘린더, 화면 녹화가 열립니다
- **모듈식 레이아웃**: 설정의 드래그 편집기로 어떤 모듈이든 어디에나
- **세로 바**: 화면 가장자리를 되찾고 싶은 분들을 위해

### 사이드바와 위젯(Material ii)

왼쪽 사이드바(앱 서랍):
- **AI 채팅**: Ollama, LM Studio, OpenRouter, Gemini, Groq, Mistral, Cerebras, Anthropic, OpenAI, OpenCode의 실시간 모델 목록
- **YT Music**: 쿠키 없이 쓰는 InnerTube 플레이어, 검색, 대기열, 라디오, 싱크 가사 지원
- **Wallhaven 브라우저**: 배경화면을 바로 검색하고 적용
- **애니메이션 트래커**: AniList 연동과 방영 일정
- **번역기**: Gemini 또는 translate-shell
- **끌 수 있는 위젯**: 암호화폐, 미디어 플레이어, 빠른 메모, 상태 링, 주간 캘린더

오른쪽 사이드바:
- **캘린더**와 일정 연동
- **알림 센터**
- **빠른 토글**: WiFi, Bluetooth, 야간 모드, 방해 금지, 전원 프로필, WARP VPN, EasyEffects
- **볼륨 믹서**(앱별)
- **Bluetooth와 WiFi** 기기 관리
- **뽀모도로 타이머**, **할 일 목록**, **계산기**, **메모장**
- **시스템 모니터**: CPU, RAM, 온도

### 도구

- **작업 공간 개요**: Niri의 스크롤 모델에 맞춰, 앱 검색과 계산기 포함
- **대시보드**: 일정, 알림, 할 일, 메모, 미디어, 날씨를 담은 설정 가능한 3열 오버레이
- **가장자리 작업 공간 띠**: 마우스를 올리면 나오는 레일, 실시간 미리보기와 드래그 정렬
- **창 전환기**: 모든 작업 공간을 오가는 애니메이션 Alt-Tab. Niri에 자체 기능이 생겨서 선택 사항
- **클립보드 관리자**: 검색과 이미지 미리보기가 있는 기록
- **영역 도구**: 스크린샷, 화면 녹화, OCR, 이미지 역검색
- **치트 시트**: Niri 설정에서 가져온 단축키
- **미디어 컨트롤**: 여러 레이아웃의 완전한 MPRIS 플레이어
- **OSD**: 볼륨, 밝기, 미디어
- **노래 인식**: SongRec으로 Shazam처럼 인식
- **음성 입력**: 설치되어 있으면 로컬 whisper.cpp, 아니면 연결된 Groq, Gemini, OpenAI

### 시스템

- **GUI 설정**: 파일을 건드리지 않고 모든 걸 설정
- **GameMode**: 전체 화면 앱에서 효과를 자동으로 끔
- **자동 업데이트**: `inir update`, 롤백, 마이그레이션, 내 변경 사항 보존
- **잠금 화면**과 **세션 화면**(로그아웃/재부팅/종료/절전)
- **Polkit 에이전트**, **화상 키보드**, niri 자체 시작 파일을 쓰는 **자동 시작 관리자**
- **Kira**: 화면 가장자리를 돌아다니고, 여러분의 행동에 반응하고, 카오스 모드도 있는 픽셀 아트 고양이 소녀. 선택 사항이며, 약 32 MiB 아트 팩은 `./setup` › Extras에서 따로
- **18개 언어** 자동 감지, 인도네시아어(`id_ID`)와 그린란드어(`kl_GL`) 포함
- **야간 모드**: 예약 또는 수동
- **날씨**: Open-Meteo, GPS, 수동 좌표, 도시 이름 지원
- **배터리 관리**: 임계값 설정, 위험 수준에서 자동 절전
- **이벤트 소리**: 전체 볼륨과 이벤트별 오디오 파일
- **업데이트 확인**: 새 버전이 나오면 알려 줌

</details>

---

## 빠른 시작

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup install       # interactive, asks before each step
./setup install -y    # automatic, no questions asked
```

설치 프로그램이 의존성, 시스템 설정, 테마를 처리합니다. 설치 후 `inir run`으로 셸을 시작하거나, 로그아웃했다가 다시 로그인하세요.

```bash
inir run                        # launch the shell
inir settings                   # open settings GUI
inir logs                       # check runtime logs
inir doctor                     # auto-diagnose and fix
inir update                     # pull + migrate + restart
```

`./setup install`이 원하는 방식이 아니라면:

```bash
./setup                 # TUI menu, pick what you want
sudo make install       # system-wide instead of your home
./setup rollback        # undo the last update
```

**배포판:** Arch가 주 대상입니다. Fedora와 Debian/Ubuntu도 배포판 저장소를 먼저 쓰는 자동 의존성 설치가 있고, 그 밖의 배포판은 [패키지 목록](https://github.com/snowarch/inir/wiki/PACKAGES)의 일반 안내를 따르면 됩니다. iNiR는 Qt 6.9 이상이 필요합니다: Ubuntu 25.10, Fedora 43, Debian testing 이후.

---

## 단축키

| 키 | 동작 |
|-----|--------|
| <kbd>Super</kbd> + <kbd>Space</kbd> | 개요: 앱 검색, 작업 공간 이동 |
| <kbd>Super</kbd> + <kbd>V</kbd> | 클립보드 기록 |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>S</kbd> | 영역 스크린샷 |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>X</kbd> | 영역 OCR |
| <kbd>Super</kbd> + <kbd>,</kbd> | 설정 |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>W</kbd> | 패널 패밀리 전환 |
| <kbd>Super</kbd> + <kbd>/</kbd> | 치트 시트, 나머지를 잊었을 때 |

전체 목록: [단축키](https://github.com/snowarch/inir/wiki/KEYBINDS)

---

## 배경화면

배경화면 15장이 기본으로 들어 있습니다. 더 원하면 Material You와 잘 어울리는 엄선 컬렉션 [iNiR-Walls](https://github.com/snowarch/iNiR-Walls)를 보세요.

---

## 문서

사용자용 내용은 모두 [Wiki](https://github.com/snowarch/inir/wiki)(영어)에 있습니다.

| 페이지 | 내용 |
|---|---|
| [Install](https://github.com/snowarch/inir/wiki/INSTALL) | 실행까지 |
| [Setup](https://github.com/snowarch/inir/wiki/SETUP) | 업데이트, 마이그레이션, 롤백 |
| [Keybinds](https://github.com/snowarch/inir/wiki/KEYBINDS) | 모든 단축키 |
| [IPC](https://github.com/snowarch/inir/wiki/IPC) | 단축키나 스크립트에 쓰는 명령 |
| [Packages](https://github.com/snowarch/inir/wiki/PACKAGES) | 모든 의존성과 필요한 이유 |
| [Limitations](https://github.com/snowarch/inir/wiki/LIMITATIONS) | 알려진 문제와 해결 방법 |
| [Architecture](../../ARCHITECTURE.md) | 코드 구성 |

---

## 문제 해결

```bash
inir logs                       # check recent runtime logs
inir restart                    # restart the active runtime
inir repair                     # doctor + restart + filtered log check
./setup doctor                  # auto-diagnose and fix common problems
./setup rollback                # undo the last update
```

이슈를 열기 전에 [Limitations](https://github.com/snowarch/inir/wiki/LIMITATIONS)를 확인하세요. 사람에게 묻고 싶다면 Discord가 더 빠릅니다.

---

## 기여하기

개발 환경, 코드 규칙, 풀 리퀘스트 방법은 [CONTRIBUTING.md](../../CONTRIBUTING.md)를 참고하세요.

---

## 크레딧

- [**end-4**](https://github.com/end-4/dots-hyprland): illogical-impulse, iNiR가 포크해 온 Hyprland dots
- [**pctrade/end4-pC**](https://github.com/pctrade/end4-pC): 가끔 정말 좋은 아이디어가 나오는 포크
- [**Gakuseei**](https://github.com/Gakuseei): [Ricelin](https://github.com/Gakuseei/Ricelin), pill 바와 washi·flame 스타일의 출처
- [**Quickshell**](https://quickshell.outfoxxed.me/): 이 셸이 돌아가는 프레임워크
- [**Niri**](https://github.com/YaLTeR/niri): 이 셸이 만들어진 대상 컴포지터

GPL-3.0, end-4의 dots와 같습니다. Copyright (C) 2025-2026 snowarch.

---

<p align="center">
  <img src="https://raw.githubusercontent.com/snowarch/inir-mascot/main/inir-mascot-hero-banner.png" alt="iNiR mascot leaning on the iNiR logotype" width="720">
</p>

---

<p align="center">
  <a href="https://github.com/snowarch/inir/graphs/contributors">기여자</a> &bull;
  <a href="../../CHANGELOG.md">변경 기록</a> &bull;
  <a href="../../LICENSE">GPL-3.0 라이선스</a>
</p>
