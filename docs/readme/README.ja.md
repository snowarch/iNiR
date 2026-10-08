<p align="center">
  <img src="../images/iris-2.32-principal.webp" alt="iNiR iRiS desktop" width="900">
</p>

<h1 align="center">iNiR</h1>

<p align="center">
  <b>Quickshell で作られた、Niri のための完全なデスクトップシェル</b>
</p>

<p align="center">
  <a href="https://github.com/snowarch/inir/releases"><img src="https://img.shields.io/badge/version-2.32.0-blue?style=flat-square" alt="Version"></a>
  <a href="https://github.com/snowarch/inir/stargazers"><img src="https://img.shields.io/github/stars/snowarch/inir?style=flat-square" alt="Stars"></a>
  <a href="https://discord.gg/pAPTfAhZUJ"><img src="https://img.shields.io/badge/Discord-join-5865F2?style=flat-square&logo=discord&logoColor=white" alt="Discord"></a>
  <a href="../../LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-green?style=flat-square" alt="License"></a>
</p>

<p align="center">
  <a href="https://github.com/snowarch/inir/wiki/INSTALL">インストール</a> &bull;
  <a href="https://github.com/snowarch/inir/wiki/KEYBINDS">キーバインド</a> &bull;
  <a href="https://github.com/snowarch/inir/wiki/IPC">IPC リファレンス</a> &bull;
  <a href="https://discord.gg/pAPTfAhZUJ">Discord</a> &bull;
  <a href="../../CONTRIBUTING.md">コントリビュート</a>
</p>

<p align="center">
  <sub>
    <a href="../../README.md">English</a> · <a href="README.es.md">Español</a> · <a href="README.ru.md">Русский</a> · <a href="README.zh.md">中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.pt.md">Português</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a> · <a href="README.ko.md">한국어</a> · <a href="README.hi.md">हिन्दी</a> · <a href="README.ar.md">العربية</a> · <a href="README.it.md">Italiano</a>
  </sub>
</p>

---

> **翻訳について：** 分かりにくい点があれば、[英語版](../../README.md)を正としてください。

---

<details>
<summary><b>🤔 初めての方へ：これが何か分からなければクリック</b></summary>

### これは何？

iNiR はデスクトップ全体です。上のバー、Dock、通知、設定、壁紙、そのすべて。テーマでも、貼り付けるだけの dotfiles でもありません。Linux で動く完全なシェルです。

### 動かすのに何が必要？

コンポジターです。ウィンドウを管理して画面にピクセルを描くものです。iNiR は [Niri](https://github.com/YaLTeR/niri)（Wayland のタイル型コンポジター）向けに作られています。end-4 の dots のフォークだった頃の古い Hyprland のコードも残っていますが、実際に使ってテストしているのは Niri です。

シェルは [Quickshell](https://quickshell.outfoxxed.me/) の上で動きます。QML（Qt の UI 言語）でシェルを作るためのフレームワークです。使うだけならこれを知る必要はありません。すべて GUI か JSON ファイルで設定できます。

### 全体のつながり

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

### 安定してる？

手に負えなくなった個人プロジェクトです。私は毎日使っていて、Discord の多くの人も使っています。でもときどき壊れるし、コードは散らかっているところもあるし、やりながら学んでいます。

何かがおかしければ、`inir doctor` でほとんど直ります。それでもだめなら Discord が活発です。ただ、磨き上げられたソフトウェアは期待しないでください。一人の rice を、たまたま他の人も気に入ってくれているだけです。

### なぜ存在するの？

デスクトップをある見た目で、ある動きをするものにしたかったのに、ぴったりそうなるものがなかったからです。end-4 の Hyprland dots から始まり、ずっと多くの機能を持つ Niri 向けの完全な書き直しになりました。

### よく出てくる言葉

- **シェル**：UI の層（バー、パネル、オーバーレイ）
- **コンポジター**：ウィンドウを管理し画面に描く（Niri、Hyprland、Sway...）
- **Wayland**：Linux の表示プロトコル（新しいほう、X11 の後継）
- **QML**：Qt の宣言的 UI 言語。iNiR はこれで書かれています
- **Material You**：画像からパレットを作る Google のカラーシステム（自動テーマの仕組み）
- **ii / waffle / iRiS**：3 つのパネルファミリー。ii は Material Design 風、waffle は Windows 11 風、iRiS は開いたものに変形する Island。`Super+Shift+W` で切り替え

</details>

---

## スクリーンショット

<details open>
<summary><b>iRiS</b>：Island、Customize、メニューバー、カード、Dock</summary>

<p align="center">
  <img src="../images/iris-2.31-desktop.webp" alt="iRiS desktop layout" width="49%">
  <img src="../images/iris-2.31-card.webp" alt="iRiS card surface" width="49%">
</p>

<p align="center">
  <img src="../images/iris-2.31-dock.webp" alt="iRiS Dock and edge layout" width="99%">
</p>

</details>

<details open>
<summary><b>Material ii</b>：フローティングバー、サイドバー、Material Design の見た目</summary>

| | |
|:---:|:---:|
| ![](https://github.com/user-attachments/assets/1fe258bc-8aec-4fd9-8574-d9d7472c3cc8) | ![](https://github.com/user-attachments/assets/3ce2055b-648c-45a1-9d09-705c1b4a03b7) |
| ![](https://github.com/user-attachments/assets/ea2311dc-769e-44dc-a46d-37cf8807d2cc) | ![](https://github.com/user-attachments/assets/da6beb4a-ccee-40ba-a372-5eea77b595f8) |
| ![](https://github.com/user-attachments/assets/ba866063-b26a-47cb-83c8-d77bd033bf8b) | ![](https://github.com/user-attachments/assets/88e76566-061b-4f8c-a9a8-53c157950138) |

</details>

<details>
<summary><b>Waffle</b>：下部のタスクバー、アクションセンター、Windows 11 風</summary>

| | |
|:---:|:---:|
| ![](https://github.com/user-attachments/assets/5c5996e7-90eb-4789-9921-0d5fe5283fa3) | ![](https://github.com/user-attachments/assets/fadf9562-751e-4138-a3a1-b87b31114d44) |

</details>

---

> [!WARNING]
> 非力なマシン向けではありません。
> とはいえ、かなり軽くできます。エフェクトを切る、パネルを減らす、デザインをシンプルにする。設定からでも `config.json` からでも。

## 機能

**3 つのパネルファミリー**、`Super+Shift+W` でその場で切り替え：
- **Material ii**：フローティングバー、サイドバー、Dock、9 つのグローバルスタイル（Material、Cards、Aurora、iNiR、Angel、Regalia、ZZZ、Cookie Shapes、Editorial）
- **Waffle**：Windows 11 風のタスクバー、スタートメニュー、アクションセンター、通知センター
- **iRiS**：フラッグシップ。画面のどの端にも置けて、ページ・カード・パネルへと広がる Island、持ち運べるピース、どの端にも置ける Dock、グラス、すべてを作り直す Themes、ライト・インク・ダーク、そしてシェルの上で直接できる Customize

**自動テーマ**。壁紙を選ぶとすべてが合わせて変わります：
- Material You によるシェルの色を GTK3/4、Qt、ターミナル、Firefox、Discord、SDDM に反映
- 10 のテーマ対象：ターミナル、エディター、ブラウザー、Spicetify、Steam、Cava など
- テーマプリセット：Regalia / Regalia Ivory、Gruvbox、Catppuccin、Rosé Pine、自作

**Niri のために作られています。** Hyprland のコードはフォーク時代の名残で、テストされていません。

**Kira** はマスコットで、望めばデスクトップに住みます。デフォルトではオフで、アートパックは別ダウンロードです。

<details>
<summary><b>全機能リスト</b></summary>

### iRiS

- **Island**：画面の端にある一つの形。「いま何が起きているか」を示し、開いたページ・カード・パネルに変わって、また元に戻ります。上下左右どこにでも（`inir iris edge <side>`、またはドラッグ）。横に置くと縦向きになり、時計は縦積み、バブルが上下に並びます
- **メニューバー**：ワークスペース、ウィンドウ、ピースが並ぶ細い帯で、Island はノッチのようにそこから下がります（`inir iris layout menubar`）
- **全幅バーモード**：開始・中央・終端のゾーンに Island、ワークスペース、フォーカス中のウィンドウ、時刻、任意のピースを配置（`inir iris zone start|center|end kinds+joined+with+plus`）
- **ピース**：天気、サウンド、マイク、トレイ、通知、ツール、メディア、VPN、ビジュアライザー、アニメ（Airing と Continue）、自分のアプリを、Island の上、画面の輪郭、デスクトップの好きな場所に置けるバブルとして
- **ピースは触れたものとつながる**：Dock や Island の縁に置くと、上に浮かぶのではなくその本体の一部になります
- **Dock** はどの端にも（`inir iris dockEdge <side|auto>`）。auto では Island の反対側に置かれ、片方をもう片方の端に送ると入れ替わります
- **グラス**：あらゆる面の下の壁紙をすりガラスにし、明るい壁紙や情報量の多い壁紙でも文字を読みやすく保ちます。コンポジターのブラーもありますが、まだ作業中なので評価はもう少し待ってください
- **Themes**：20 の厳選リデザイン（Liquid Glass、Frost、Obsidian、Terminal、Neo Tokyo、Twilight、Lume、Sakura、Unit-01 など）と、共有できる JSON ファイルの自作テーマ（`inir iris theme`）
- **ライト、インク、ダーク**：それぞれ独自のトーンとすりガラスを持ち、アプリにも適用されるカラーテーマ（Catppuccin、Nord、Rosé Pine、Tokyo Night…）も（`inir iris palette`）
- **形**：Island と Dock をカプセル、丸、スクワークル、四角から
- **シェル上での Customize**：Island、Dock、バブルをタップすると、その場から設定が広がり、Island の下に Themes、Look、Pieces、元に戻すが並びます（`inir iris edit`）。好みなら Studio がすべてを画面横の一つのパネルにまとめます
- **自分で並べるコントロールセンター**：共有クイックトグル、プレイヤー、各スライダーがセルになり、ドラッグ、角からのリサイズ、横のライブラリからの追加ができます。開始レイアウトは 6 種類、右クリックでコントロールが展開します（`inir iris control edit`）
- **リハーサルできるロック画面**：本物のロック画面が編集モードで開き、解除するものはありません。時計、プレイヤー、サインイン欄を動かし、背景に流すものを動画も含めて選べます（`inir iris lock edit`）

### テーマと外観

- **9 つのグローバルスタイル**：Material（ソリッド）、Cards、Aurora（ガラスブラー）、iNiR（TUI 風）、Angel（ネオブルータリズム）、Regalia（黒いシャーシ、暖かいアイボリーのインク、控えめなシャンパンの金具）、ZZZ（ポスターのプレート）、Cookie Shapes（アニメーションする形）、Editorial（紙とインクのタイポグラフィ）
- **壁紙からのダイナミックカラー**：Material You でシステム全体に
- **10 のターミナル・TUI ツールを自動テーマ化**：foot、kitty、alacritty、ghostty、wezterm、starship、fuzzel、btop、lazygit、yazi
- **アプリのテーマ**：GTK3/4、Qt（plasma-integration と darkly 経由）、Firefox、Discord/Vesktop（System24）、Zed、Spicetify、Steam、SDDM
- **テーマプリセット**：Gruvbox、Catppuccin、Rosé Pine など、または自作
- **動画壁紙**：mp4/webm/gif、ブラーは任意。パフォーマンス重視なら最初のフレームで静止
- **デスクトップウィジェット**：すべてに共通の一つのデザイン（iRiS、Material、iNstrument、Readout）、iOS のようにめくれるスタック、下の壁紙に合わせて変わるインク

### バー

- **6 つのバースタイル**：classic、islands、scenic、frame、Material 3 カプセル、pill
- **Pill バー**：形を変える中央のアイランドで、ホバーするとワークスペース、ランチャー、ミキサー、メディア、カレンダー、画面録画が開きます
- **モジュール式レイアウト**：設定のドラッグエディターで、どのモジュールもどこにでも
- **縦型バー**：画面の端を取り戻したい人向け

### サイドバーとウィジェット（Material ii）

左サイドバー（アプリドロワー）：
- **AI チャット**：Ollama、LM Studio、OpenRouter、Gemini、Groq、Mistral、Cerebras、Anthropic、OpenAI、OpenCode のライブモデル一覧
- **YT Music**：Cookie 不要の InnerTube プレイヤー。検索、キュー、ラジオ、同期歌詞に対応
- **Wallhaven ブラウザー**：壁紙を直接検索して適用
- **アニメトラッカー**：AniList 連携と放送スケジュール
- **翻訳**：Gemini または translate-shell 経由
- **ドラッグできるウィジェット**：暗号資産、メディアプレイヤー、クイックメモ、ステータスリング、週間カレンダー

右サイドバー：
- **カレンダー**（予定の連携あり）
- **通知センター**
- **クイックトグル**：WiFi、Bluetooth、夜間モード、おやすみモード、電源プロファイル、WARP VPN、EasyEffects
- **音量ミキサー**（アプリごと）
- **Bluetooth と WiFi** のデバイス管理
- **ポモドーロタイマー**、**ToDo リスト**、**電卓**、**メモ帳**
- **システムモニター**：CPU、RAM、温度

### ツール

- **ワークスペース概要**：Niri のスクロールモデルに合わせ、アプリ検索と電卓付き
- **ダッシュボード**：予定、通知、ToDo、メモ、メディア、天気を並べる設定可能な 3 列オーバーレイ
- **画面端のワークスペースストリップ**：ホバーで出るレール。ライブプレビューとドラッグでの並べ替え
- **ウィンドウスイッチャー**：全ワークスペースを横断するアニメーション付き Alt-Tab。Niri に標準搭載されたのでオプトイン
- **クリップボード管理**：検索と画像プレビュー付きの履歴
- **範囲ツール**：スクリーンショット、画面録画、OCR、画像の逆検索
- **チートシート**：Niri の設定から読み取ったキーバインド
- **メディアコントロール**：複数レイアウトの完全な MPRIS プレイヤー
- **OSD**：音量、明るさ、メディア
- **曲の認識**：SongRec による Shazam 風の識別
- **音声入力**：インストールされていればローカルの whisper.cpp、または接続した Groq、Gemini、OpenAI

### システム

- **GUI 設定**：ファイルに触れずにすべて設定
- **GameMode**：フルスクリーンアプリでエフェクトを自動オフ
- **自動更新**：`inir update` はロールバック、マイグレーション、自分の変更の保持に対応
- **ロック画面**と**セッション画面**（ログアウト/再起動/シャットダウン/サスペンド）
- **Polkit エージェント**、**オンスクリーンキーボード**、niri 自身の起動ファイルを使う**自動起動マネージャー**
- **Kira**：画面の端を歩き回り、あなたの操作に反応し、カオスモードもあるピクセルアートの猫娘。オプトインで、約 32 MiB のアートパックは `./setup` › Extras から別途
- **18 の言語**を自動検出。インドネシア語（`id_ID`）とグリーンランド語（`kl_GL`）も含みます
- **夜間モード**：スケジュールまたは手動
- **天気**：Open-Meteo。GPS、手動座標、都市名に対応
- **バッテリー管理**：しきい値を設定可能、残量が危険域で自動サスペンド
- **イベントサウンド**：全体音量とイベントごとの音声ファイル
- **更新チェック**：新しいバージョンが出たらお知らせ

</details>

---

## クイックスタート

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup install       # interactive, asks before each step
./setup install -y    # automatic, no questions asked
```

インストーラーが依存関係、システム設定、テーマを処理します。インストール後は `inir run` でシェルを起動するか、ログアウトして入り直してください。

```bash
inir run                        # launch the shell
inir settings                   # open settings GUI
inir logs                       # check runtime logs
inir doctor                     # auto-diagnose and fix
inir update                     # pull + migrate + restart
```

`./setup install` 以外の方法がよければ：

```bash
./setup                 # TUI menu, pick what you want
sudo make install       # system-wide instead of your home
./setup rollback        # undo the last update
```

**ディストリビューション：** Arch が主なターゲットです。Fedora と Debian/Ubuntu にも、ディストリビューションのリポジトリを優先する依存関係の自動インストールがあります。その他は[パッケージ一覧](https://github.com/snowarch/inir/wiki/PACKAGES)の一般的な手順に従ってください。iNiR には Qt 6.9 以降が必要です：Ubuntu 25.10、Fedora 43、Debian testing 以降。

---

## キーバインド

| キー | 動作 |
|-----|--------|
| <kbd>Super</kbd> + <kbd>Space</kbd> | 概要：アプリ検索、ワークスペース移動 |
| <kbd>Super</kbd> + <kbd>V</kbd> | クリップボード履歴 |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>S</kbd> | 範囲のスクリーンショット |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>X</kbd> | 範囲の OCR |
| <kbd>Super</kbd> + <kbd>,</kbd> | 設定 |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>W</kbd> | パネルファミリーの切り替え |
| <kbd>Super</kbd> + <kbd>/</kbd> | チートシート（ほかを忘れたときに） |

完全なリスト：[キーバインド](https://github.com/snowarch/inir/wiki/KEYBINDS)

---

## 壁紙

15 枚の壁紙が同梱されています。もっと欲しければ、Material You と相性のいい厳選コレクション [iNiR-Walls](https://github.com/snowarch/iNiR-Walls) をどうぞ。

---

## ドキュメント

ユーザー向けの情報はすべて [Wiki](https://github.com/snowarch/inir/wiki)（英語）にあります。

| ページ | 内容 |
|---|---|
| [Install](https://github.com/snowarch/inir/wiki/INSTALL) | 動かすまで |
| [Setup](https://github.com/snowarch/inir/wiki/SETUP) | 更新、マイグレーション、ロールバック |
| [Keybinds](https://github.com/snowarch/inir/wiki/KEYBINDS) | すべてのショートカット |
| [IPC](https://github.com/snowarch/inir/wiki/IPC) | キーバインドやスクリプトで使えるコマンド |
| [Packages](https://github.com/snowarch/inir/wiki/PACKAGES) | 各依存関係とその理由 |
| [Limitations](https://github.com/snowarch/inir/wiki/LIMITATIONS) | 既知の不具合と回避策 |
| [Architecture](../../ARCHITECTURE.md) | コードの構成 |

---

## トラブルシューティング

```bash
inir logs                       # check recent runtime logs
inir restart                    # restart the active runtime
inir repair                     # doctor + restart + filtered log check
./setup doctor                  # auto-diagnose and fix common problems
./setup rollback                # undo the last update
```

issue を開く前に [Limitations](https://github.com/snowarch/inir/wiki/LIMITATIONS) を確認してください。人に聞きたいなら Discord のほうが早いです。

---

## コントリビュート

開発環境、コードの書き方、プルリクエストの出し方は [CONTRIBUTING.md](../../CONTRIBUTING.md) を参照してください。

---

## クレジット

- [**end-4**](https://github.com/end-4/dots-hyprland)：illogical-impulse。iNiR のフォーク元の Hyprland dots
- [**pctrade/end4-pC**](https://github.com/pctrade/end4-pC)：ときどき本当にいいアイデアがあるフォーク
- [**Gakuseei**](https://github.com/Gakuseei)：[Ricelin](https://github.com/Gakuseei/Ricelin)。pill バーと washi・flame の見た目はここから
- [**Quickshell**](https://quickshell.outfoxxed.me/)：動作の土台となるフレームワーク
- [**Niri**](https://github.com/YaLTeR/niri)：これが作られた対象のコンポジター

GPL-3.0、end-4 の dots と同じです。Copyright (C) 2025-2026 snowarch.

---

<p align="center">
  <img src="https://raw.githubusercontent.com/snowarch/inir-mascot/main/inir-mascot-hero-banner.png" alt="iNiR mascot leaning on the iNiR logotype" width="720">
</p>

---

<p align="center">
  <a href="https://github.com/snowarch/inir/graphs/contributors">コントリビューター</a> &bull;
  <a href="../../CHANGELOG.md">変更履歴</a> &bull;
  <a href="../../LICENSE">GPL-3.0 ライセンス</a>
</p>
