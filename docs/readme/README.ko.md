<p align="center">
  <img src="https://github.com/user-attachments/assets/da6beb4a-ccee-40ba-a372-5eea77b595f8" alt="iNiR" width="800">
</p>

<h1 align="center">iNiR</h1>

<p align="center">
  <b>Quickshell 기반의 Niri용 완전한 데스크톱 셸</b>
</p>

<p align="center">
  <a href="https://github.com/snowarch/inir/releases"><img src="https://img.shields.io/badge/version-2.18.0-blue?style=flat-square" alt="Version"></a>
  <a href="https://github.com/snowarch/inir/stargazers"><img src="https://img.shields.io/github/stars/snowarch/inir?style=flat-square" alt="Stars"></a>
  <a href="https://discord.gg/pAPTfAhZUJ"><img src="https://img.shields.io/badge/Discord-join-5865F2?style=flat-square&logo=discord&logoColor=white" alt="Discord"></a>
</p>

<p align="center">
  <a href="../INSTALL.md">설치</a> &bull;
  <a href="../KEYBINDS.md">단축키</a> &bull;
  <a href="../IPC.md">IPC 레퍼런스</a> &bull;
  <a href="https://discord.gg/pAPTfAhZUJ">Discord</a> &bull;
  <a href="../../CONTRIBUTING.md">기여</a>
</p>

<p align="center">
  <sub>
    <a href="../../README.md">English</a> · <a href="README.es.md">Español</a> · <a href="README.ru.md">Русский</a> · <a href="README.zh.md">中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.pt.md">Português</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a> · <a href="README.ko.md">한국어</a> · <a href="README.hi.md">हिन्दी</a> · <a href="README.ar.md">العربية</a> · <a href="README.it.md">Italiano</a>
  </sub>
</p>

---

> **번역에 대해:** 커뮤니티 번역입니다. 불명확한 부분은 [영어 버전](../../README.md)을 참조하세요.

---

<details>
<summary><b>🤔 처음이신가요? 이게 뭔지 모르겠으면 클릭</b></summary>

### 이게 뭔가요?

iNiR은 데스크톱 전체입니다. 위의 바, 독, 알림, 설정, 배경화면, 전부. 테마가 아니고, 복붙하는 dotfiles도 아닙니다. Linux에서 돌아가는 완전한 셸이에요.

### 실행하려면 뭐가 필요해요?

컴포지터. 창을 관리하고 화면에 픽셀을 그리는 거예요. iNiR은 [Niri](https://github.com/YaLTeR/niri) (타일링 Wayland 컴포지터)용으로 만들어졌어요. end-4의 dots에서 포크했을 때의 오래된 Hyprland 코드가 있지만, 실제로 테스트하고 쓰는 건 Niri입니다.

셸은 [Quickshell](https://quickshell.outfoxxed.me/) 위에서 돌아가요. QML(Qt의 UI 언어)로 셸을 만드는 프레임워크. 이걸 몰라도 쓸 수 있어요, 모든 설정은 GUI나 JSON 파일로 가능합니다.

### 어떻게 연결되어 있나요

```
당신의 앱
   ↓
iNiR (셸: 바, 사이드바, 독, 알림, 설정...)
   ↓
Quickshell (QML 셸 실행)
   ↓
Niri (컴포지터: 창, 렌더링)
   ↓
Wayland → GPU
```

### 안정적인가요?

손을 벗어난 개인 프로젝트예요. 매일 쓰고 있고, Discord의 많은 사람들도 그래요. 근데 가끔 망가지고, 코드가 지저분한 곳도 있고, 하면서 배우는 중이에요.

뭔가 안 되면 `inir doctor`가 대부분 고쳐요. 그래도 안 되면 Discord가 활발해요. 완성된 소프트웨어를 기대하지 마세요, 이건 다른 사람들이 좋아하게 된 한 사람의 rice입니다.

### 왜 존재하나요?

데스크톱이 특정한 모양과 동작을 하길 원했는데, 다른 건 정확히 그걸 못 했어요. end-4의 Hyprland dots로 시작해서 Niri용 완전 재작성이 되었고 기능도 많이 늘었어요.

### 보게 될 용어들

- **Shell**: UI 레이어 (바, 패널, 오버레이)
- **Compositor**: 창 관리, 화면에 그림 (Niri, Hyprland, Sway...)
- **Wayland**: Linux 디스플레이 프로토콜 (새것, X11 대체)
- **QML**: Qt의 선언적 UI 언어, iNiR은 이걸로 작성됨
- **Material You**: 이미지에서 팔레트 생성하는 Google 색상 시스템 (자동 테마가 이렇게 작동함)
- **ii / waffle**: 두 패널 스타일. ii = Material Design 느낌, waffle = Windows 11 느낌. `Super+Shift+W`로 전환

</details>

---

## 스크린샷

<details open>
<summary><b>Material ii</b> — 플로팅 바, 사이드바, Material Design 미학</summary>

| | |
|:---:|:---:|
| ![](https://github.com/user-attachments/assets/1fe258bc-8aec-4fd9-8574-d9d7472c3cc8) | ![](https://github.com/user-attachments/assets/3ce2055b-648c-45a1-9d09-705c1b4a03b7) |
| ![](https://github.com/user-attachments/assets/ea2311dc-769e-44dc-a46d-37cf8807d2cc) | ![](https://github.com/user-attachments/assets/da6beb4a-ccee-40ba-a372-5eea77b595f8) |
| ![](https://github.com/user-attachments/assets/ba866063-b26a-47cb-83c8-d77bd033bf8b) | ![](https://github.com/user-attachments/assets/88e76566-061b-4f8c-a9a8-53c157950138) |

</details>

<details>
<summary><b>Waffle</b> — 하단 작업 표시줄, 알림 센터, Windows 11 스타일</summary>

| | |
|:---:|:---:|
| ![](https://github.com/user-attachments/assets/5c5996e7-90eb-4789-9921-0d5fe5283fa3) | ![](https://github.com/user-attachments/assets/fadf9562-751e-4138-a3a1-b87b31114d44) |

</details>

---

## 기능

**두 가지 패널 패밀리**, `Super+Shift+W`로 즉시 전환:
- **Material ii** — 플로팅 바, 사이드바, 독, 5가지 비주얼 스타일 (material, cards, aurora, inir, angel)
- **Waffle** — Windows 11 스타일 작업 표시줄, 시작 메뉴, 알림 센터, 액션 센터

**자동 테마** — 배경화면을 고르면 모든 것이 맞춰짐:
- Material You를 통한 셸 색상, GTK3/4, Qt, 터미널, Firefox, Discord, SDDM으로 전파
- 10개 터미널 도구 자동 테마 적용 (foot, kitty, alacritty, starship, fuzzel, btop, lazygit, yazi)
- 테마 프리셋: Gruvbox, Catppuccin, Rosé Pine, 커스텀

**컴포지터** — Niri 전용으로 제작.

<details>
<summary><b>전체 기능 목록</b></summary>

### 테마와 외관

배경화면을 고르면 전체 시스템이 따라감 — 셸, GTK/Qt 앱, 터미널, Firefox, Discord, SDDM 로그인 화면. 전부 자동.

- **5가지 비주얼 스타일** — Material (솔리드), Cards, Aurora (유리 블러), iNiR (TUI 영감), Angel (네오 브루탈리즘)
- **배경화면 동적 색상** — Material You로 시스템 전체에 전파
- **10개 터미널 도구 자동 테마** — foot, kitty, alacritty, starship, fuzzel, pywalfox, btop, lazygit, yazi
- **앱 테마 적용** — GTK3/4, Qt (plasma-integration + darkly), Firefox (MaterialFox), Discord/Vesktop (System24)
- **테마 프리셋** — Gruvbox, Catppuccin, Rosé Pine 등 — 또는 직접 만들기
- **비디오 배경화면** — mp4/webm/gif, 선택적 블러 또는 성능을 위한 첫 프레임 고정
- **SDDM 로그인 테마** — 배경화면과 동기화된 Material You 색상
- **데스크톱 위젯** — 시계 (여러 스타일), 날씨, 배경화면 레이어의 미디어 컨트롤

### 사이드바와 위젯 (Material ii)

왼쪽 사이드바 (앱 서랍):
- **AI 채팅** — Gemini, Mistral, OpenRouter, 또는 Ollama를 통한 로컬 모델
- **YT Music** — 검색, 대기열, 컨트롤이 있는 풀 플레이어
- **Wallhaven 브라우저** — 배경화면 직접 검색 및 적용
- **애니메 트래커** — AniList 연동, 방영 일정 보기
- **Reddit 피드** — 인라인 서브레딧 탐색
- **번역기** — Gemini 또는 translate-shell
- **드래그 가능 위젯** — 암호화폐, 미디어 플레이어, 빠른 메모, 상태 링, 주간 캘린더

오른쪽 사이드바:
- **캘린더** — 이벤트 연동
- **알림 센터**
- **빠른 토글** — WiFi, Bluetooth, 야간 모드, 방해 금지, 전원 프로필, WARP VPN, EasyEffects
- **볼륨 믹서** — 앱별 제어
- **Bluetooth 및 WiFi** 기기 관리
- **포모도로 타이머**, **할 일 목록**, **계산기**, **메모장**
- **시스템 모니터** — CPU, RAM, 온도

### 도구

- **워크스페이스 개요** — Niri 스크롤 모델에 맞춤, 앱 검색과 계산기 포함
- **창 전환기** — 모든 워크스페이스에서 Alt+Tab
- **클립보드 관리자** — 검색과 이미지 미리보기가 있는 기록
- **영역 도구** — 스크린샷, 화면 녹화, OCR, 역방향 이미지 검색
- **단축키 보기** — Niri 설정에서 가져온 단축키 뷰어
- **미디어 컨트롤** — 여러 레이아웃 프리셋이 있는 풀 MPRIS 플레이어
- **화면 표시** — 볼륨, 밝기, 미디어 OSD
- **음악 인식** — SongRec를 통한 Shazam 스타일 식별
- **음성 검색** — 녹음 후 Gemini로 검색

### 시스템

- **GUI 설정** — 파일 편집 없이 모든 것 설정
- **GameMode** — 전체 화면 앱에서 이펙트 자동 비활성화
- **자동 업데이트** — `inir update`, 롤백·마이그레이션·사용자 변경 보존 포함
- **잠금 화면** 및 **세션 화면** (로그아웃/재시작/종료/절전)
- **Polkit 에이전트**, **화면 키보드**, **자동 시작 관리자**
- **9개 언어** — 자동 감지, AI 지원 번역 생성
- **야간 모드** — 예약 또는 수동
- **날씨** — Open-Meteo, GPS·수동 좌표·도시명 지원
- **배터리 관리** — 설정 가능한 임계값, 위험 수준에서 자동 절전
- **셸 업데이트 확인** — 새 버전 알림

</details>

---

## 빠른 시작

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup install       # 대화식 — 각 단계마다 확인
./setup install -y    # 자동 — 확인 없이 설치
```

인스톨러가 의존성, 시스템 설정, 테마 — 모든 것을 처리합니다. 설치 후 `inir run`으로 셸을 시작하거나 로그아웃 후 다시 로그인하세요.

```bash
inir run                        # 셸 시작
inir settings                   # 설정 GUI 열기
inir logs                       # 런타임 로그 확인
inir doctor                     # 자동 진단 및 수정
inir update                     # pull + 마이그레이션 + 재시작
```

**지원 배포판:** Arch (자동 설치 프로그램). 다른 배포판은 수동 설치 가능 — [PACKAGES.md](../PACKAGES.md) 참조.

| 방법 | 명령 |
|--------|---------|
| 시스템 설치 | `sudo make install && inir run` |
| TUI 메뉴 | `./setup` |
| 롤백 | `./setup rollback` |

---

## 단축키

| 키 | 동작 |
|-----|--------|
| `Super+Space` | 개요 — 앱 검색, 워크스페이스 탐색 |
| `Alt+Tab` | 창 전환기 |
| `Super+V` | 클립보드 기록 |
| `Super+Shift+S` | 영역 스크린샷 |
| `Super+Shift+X` | 영역 OCR |
| `Super+,` | 설정 |
| `Super+Shift+W` | 패널 패밀리 전환 |

전체 목록: [KEYBINDS.md](../KEYBINDS.md)

---

## 배경화면

15개 배경화면이 기본 포함됩니다. 더 필요하면 [iNiR-Walls](https://github.com/snowarch/iNiR-Walls)를 확인하세요 — Material You 파이프라인과 잘 맞는 큐레이션 컬렉션입니다.

---

## 문서

| | |
|---|---|
| [INSTALL.md](../INSTALL.md) | 설치 가이드 |
| [SETUP.md](../SETUP.md) | Setup 명령어 — 업데이트, 마이그레이션, 롤백 |
| [KEYBINDS.md](../KEYBINDS.md) | 모든 키보드 단축키 |
| [IPC.md](../IPC.md) | 스크립팅 및 단축키용 IPC 대상 |
| [PACKAGES.md](../PACKAGES.md) | 모든 의존성과 이유 |
| [LIMITATIONS.md](../LIMITATIONS.md) | 알려진 제한 사항과 해결 방법 |
| [ARCHITECTURE.md](../ARCHITECTURE.md) | 기술 아키텍처 개요 |

---

## 문제 해결

```bash
inir logs                       # 최근 런타임 로그 확인
inir restart                    # 활성 런타임 재시작
inir repair                     # doctor + 재시작 + 필터링된 로그 확인
./setup doctor                  # 일반적인 문제 자동 진단 및 수정
./setup rollback                # 마지막 업데이트 취소
```

이슈를 열기 전에 [LIMITATIONS.md](../LIMITATIONS.md)를 확인하세요.

---

## 기여

[CONTRIBUTING.md](../../CONTRIBUTING.md) 참조 — 개발 환경 설정, 코드 패턴, PR 가이드라인.

---

## 크레딧

- [**end-4**](https://github.com/end-4/dots-hyprland) — Hyprland용 오리지널 illogical-impulse
- [**Quickshell**](https://quickshell.outfoxxed.me/) — 이 셸을 구동하는 프레임워크
- [**Niri**](https://github.com/YaLTeR/niri) — 스크롤링 타일링 Wayland 컴포지터

---

<p align="center">
  <a href="https://github.com/snowarch/inir/graphs/contributors">기여자</a> &bull;
  <a href="CHANGELOG.md">변경 기록</a> &bull;
  <a href="LICENSE">MIT 라이선스</a>
</p>
