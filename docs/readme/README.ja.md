<p align="center">
  <img src="https://github.com/user-attachments/assets/da6beb4a-ccee-40ba-a372-5eea77b595f8" alt="iNiR" width="800">
</p>

<h1 align="center">iNiR</h1>

<p align="center">
  <b>Quickshell ベースの Niri 向け完全デスクトップシェル</b>
</p>

<p align="center">
  <a href="https://github.com/snowarch/inir/releases"><img src="https://img.shields.io/badge/version-2.18.0-blue?style=flat-square" alt="Version"></a>
  <a href="https://github.com/snowarch/inir/stargazers"><img src="https://img.shields.io/github/stars/snowarch/inir?style=flat-square" alt="Stars"></a>
  <a href="https://discord.gg/pAPTfAhZUJ"><img src="https://img.shields.io/badge/Discord-join-5865F2?style=flat-square&logo=discord&logoColor=white" alt="Discord"></a>
</p>

<p align="center">
  <a href="../INSTALL.md">インストール</a> &bull;
  <a href="../KEYBINDS.md">キーバインド</a> &bull;
  <a href="../IPC.md">IPC リファレンス</a> &bull;
  <a href="https://discord.gg/pAPTfAhZUJ">Discord</a> &bull;
  <a href="../../CONTRIBUTING.md">コントリビュート</a>
</p>

<p align="center">
  <sub>
    <a href="../../README.md">English</a> · <a href="README.es.md">Español</a> · <a href="README.ru.md">Русский</a> · <a href="README.zh.md">中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.pt.md">Português</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a> · <a href="README.ko.md">한국어</a> · <a href="README.hi.md">हिन्दी</a> · <a href="README.ar.md">العربية</a> · <a href="README.it.md">Italiano</a>
  </sub>
</p>

---

> **翻訳について：** コミュニティ翻訳です。不明な点があれば[英語版](../../README.md)をご参照ください。

---

<details>
<summary><b>🤔 初めて？これが何か分からない人はここをクリック</b></summary>

### これは何？

iNiR はデスクトップ全体です。上のバー、ドック、通知、設定、壁紙、全部。テーマじゃない、コピペする設定ファイルでもない。Linux で動く完全なシェルです。

### 動かすのに何が必要？

コンポジター。ウィンドウを管理して画面にピクセルを描く部分。iNiR は [Niri](https://github.com/YaLTeR/niri)（タイリング Wayland コンポジター）向けに作られています。end-4 の dots からフォークした時の古い Hyprland コードもあるけど、実際にテストして使ってるのは Niri。

シェルは [Quickshell](https://quickshell.outfoxxed.me/) 上で動きます。QML（Qt の UI 言語）でシェルを作るフレームワーク。これを知らなくても使えます、設定は全部 GUI か JSON ファイルでできる。

### どう繋がってるか

```
あなたのアプリ
   ↓
iNiR（シェル：バー、サイドバー、ドック、通知、設定...）
   ↓
Quickshell（QML シェルを動かす）
   ↓
Niri（コンポジター：ウィンドウ、レンダリング）
   ↓
Wayland → GPU
```

### 安定してる？

手に負えなくなった個人プロジェクトです。毎日使ってる、Discord の人たちも大勢使ってる。でも時々壊れる、コードは荒いところもある、やりながら学んでる。

何か動かなかったら `inir doctor` で大体直る。それでダメなら Discord が活発。洗練されたソフトを期待しないで、これは一人の rice で、たまたま他の人も気に入っただけ。

### なぜ存在する？

デスクトップを特定の見た目と動作にしたくて、他に完全にそれをやるものがなかった。end-4 の Hyprland dots から始まって、Niri 向けの完全な書き直しになって機能もたくさん増えた。

### 見かける用語

- **Shell**：UI レイヤー（バー、パネル、オーバーレイ）
- **Compositor**：ウィンドウ管理、画面描画（Niri、Hyprland、Sway...）
- **Wayland**：Linux のディスプレイプロトコル（X11 の後継）
- **QML**：Qt の宣言的 UI 言語、iNiR はこれで書かれてる
- **Material You**：Google の配色システム、画像からパレットを生成（自動テーマの仕組み）
- **ii / waffle**：2つのパネルスタイル。ii = Material Design 風、waffle = Windows 11 風。`Super+Shift+W` で切り替え

</details>

---

## スクリーンショット

<details open>
<summary><b>Material ii</b> — フローティングバー、サイドバー、Material Design 美学</summary>

| | |
|:---:|:---:|
| ![](https://github.com/user-attachments/assets/1fe258bc-8aec-4fd9-8574-d9d7472c3cc8) | ![](https://github.com/user-attachments/assets/3ce2055b-648c-45a1-9d09-705c1b4a03b7) |
| ![](https://github.com/user-attachments/assets/ea2311dc-769e-44dc-a46d-37cf8807d2cc) | ![](https://github.com/user-attachments/assets/da6beb4a-ccee-40ba-a372-5eea77b595f8) |
| ![](https://github.com/user-attachments/assets/ba866063-b26a-47cb-83c8-d77bd033bf8b) | ![](https://github.com/user-attachments/assets/88e76566-061b-4f8c-a9a8-53c157950138) |

</details>

<details>
<summary><b>Waffle</b> — 下部タスクバー、アクションセンター、Windows 11 テイスト</summary>

| | |
|:---:|:---:|
| ![](https://github.com/user-attachments/assets/5c5996e7-90eb-4789-9921-0d5fe5283fa3) | ![](https://github.com/user-attachments/assets/fadf9562-751e-4138-a3a1-b87b31114d44) |

</details>

---

## 機能

**2つのパネルファミリー**、`Super+Shift+W` でオンザフライ切り替え：
- **Material ii** — フローティングバー、サイドバー、ドック、5つのビジュアルスタイル（material、cards、aurora、inir、angel）
- **Waffle** — Windows 11 スタイルのタスクバー、スタートメニュー、アクションセンター、通知センター

**自動テーマ** — 壁紙を選ぶだけですべてが適応：
- Material You によるシェルカラー、GTK3/4、Qt、ターミナル、Firefox、Discord、SDDM に伝播
- 10のターミナルツールが自動テーマ化（foot、kitty、alacritty、starship、fuzzel、btop、lazygit、yazi）
- テーマプリセット：Gruvbox、Catppuccin、Rosé Pine、カスタム

**コンポジター** — Niri 向けに構築。

<details>
<summary><b>全機能リスト</b></summary>

### テーマと外観

壁紙を選ぶとシステム全体が追従 — シェル、GTK/Qt アプリ、ターミナル、Firefox、Discord、SDDM ログイン画面。すべて自動。

- **5つのビジュアルスタイル** — Material（ソリッド）、Cards、Aurora（ガラスブラー）、iNiR（TUI 風）、Angel（ネオブルータリズム）
- **壁紙からの動的カラー** — Material You でシステム全体に伝播
- **10のターミナルツール自動テーマ化** — foot、kitty、alacritty、starship、fuzzel、pywalfox、btop、lazygit、yazi
- **アプリテーマ化** — GTK3/4、Qt（plasma-integration + darkly）、Firefox（MaterialFox）、Discord/Vesktop（System24）
- **テーマプリセット** — Gruvbox、Catppuccin、Rosé Pine など — または独自作成
- **動画壁紙** — mp4/webm/gif、ブラー対応、またはパフォーマンス用にフレーム固定
- **SDDM ログインテーマ** — 壁紙と同期した Material You カラー
- **デスクトップウィジェット** — 時計（複数スタイル）、天気、壁紙レイヤー上のメディアコントロール

### サイドバーとウィジェット（Material ii）

左サイドバー（アプリドロワー）：
- **AI チャット** — Gemini、Mistral、OpenRouter、または Ollama 経由のローカルモデル
- **YT Music** — 検索、キュー、コントロール付きフルプレーヤー
- **Wallhaven ブラウザ** — 壁紙を直接検索・適用
- **アニメトラッカー** — AniList 連携、放送スケジュール表示
- **Reddit フィード** — インラインで subreddit を閲覧
- **翻訳** — Gemini または translate-shell 経由
- **ドラッグ可能ウィジェット** — 暗号通貨、メディアプレーヤー、クイックメモ、ステータスリング、週間カレンダー

右サイドバー：
- **カレンダー** — イベント連携
- **通知センター**
- **クイックトグル** — WiFi、Bluetooth、ナイトライト、DND、電力プロファイル、WARP VPN、EasyEffects
- **ボリュームミキサー** — アプリごとの制御
- **Bluetooth・WiFi** デバイス管理
- **ポモドーロタイマー**、**TODO リスト**、**電卓**、**メモ帳**
- **システムモニター** — CPU、RAM、温度

### ツール

- **ワークスペース概要** — Niri のスクロールモデルに適応、アプリ検索と電卓付き
- **ウィンドウスイッチャー** — 全ワークスペース横断の Alt+Tab
- **クリップボードマネージャー** — 検索と画像プレビュー付き履歴
- **リージョンツール** — スクリーンショット、画面録画、OCR、逆画像検索
- **チートシート** — Niri 設定から抽出したキーバインドビューワー
- **メディアコントロール** — 複数レイアウトプリセット付きフル MPRIS プレーヤー
- **オンスクリーンディスプレイ** — 音量、輝度、メディア OSD
- **楽曲認識** — SongRec 経由の Shazam スタイル識別
- **音声検索** — 録音して Gemini で検索

### システム

- **GUI 設定** — ファイルを触らずにすべて設定可能
- **GameMode** — フルスクリーンアプリでエフェクト自動無効化
- **自動アップデート** — `inir update`、ロールバック・マイグレーション・ユーザー変更保持付き
- **ロック画面** と **セッション画面**（ログアウト/再起動/シャットダウン/サスペンド）
- **Polkit エージェント**、**オンスクリーンキーボード**、**自動起動マネージャー**
- **9言語** — 自動検出、AI 支援翻訳生成
- **ナイトライト** — スケジュールまたは手動
- **天気** — Open-Meteo、GPS・手動座標・都市名に対応
- **バッテリー管理** — 設定可能なしきい値、クリティカル時の自動サスペンド
- **シェル更新チェッカー** — 新バージョン通知

</details>

---

## クイックスタート

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup install       # 対話式 — 各ステップで確認
./setup install -y    # 自動 — 確認なし
```

インストーラーが依存関係、システム設定、テーマ化 — すべて処理します。インストール後、`inir run` でシェルを起動するか、ログアウトして再ログインしてください。

```bash
inir run                        # シェルを起動
inir settings                   # 設定 GUI を開く
inir logs                       # ランタイムログを確認
inir doctor                     # 自動診断と修復
inir update                     # pull + マイグレーション + 再起動
```

**対応ディストリビューション：** Arch（自動インストーラー）。他のディストリビューションは手動インストール可能 — [PACKAGES.md](../PACKAGES.md) を参照。

| 方法 | コマンド |
|--------|---------|
| システムインストール | `sudo make install && inir run` |
| TUI メニュー | `./setup` |
| ロールバック | `./setup rollback` |

---

## キーバインド

| キー | アクション |
|-----|--------|
| `Super+Space` | 概要 — アプリ検索、ワークスペースナビゲーション |
| `Alt+Tab` | ウィンドウスイッチャー |
| `Super+V` | クリップボード履歴 |
| `Super+Shift+S` | リージョンスクリーンショット |
| `Super+Shift+X` | リージョン OCR |
| `Super+,` | 設定 |
| `Super+Shift+W` | パネルファミリー切り替え |

全リスト：[KEYBINDS.md](../KEYBINDS.md)

---

## 壁紙

15枚の壁紙が同梱されています。さらに欲しい場合は [iNiR-Walls](https://github.com/snowarch/iNiR-Walls) をチェック — Material You パイプラインと相性の良いキュレーションコレクションです。

---

## ドキュメント

| | |
|---|---|
| [INSTALL.md](../INSTALL.md) | インストールガイド |
| [SETUP.md](../SETUP.md) | Setup コマンド — アップデート、マイグレーション、ロールバック |
| [KEYBINDS.md](../KEYBINDS.md) | すべてのキーボードショートカット |
| [IPC.md](../IPC.md) | スクリプトとキーバインド用 IPC ターゲット |
| [PACKAGES.md](../PACKAGES.md) | すべての依存関係とその理由 |
| [LIMITATIONS.md](../LIMITATIONS.md) | 既知の制限と回避策 |
| [ARCHITECTURE.md](../ARCHITECTURE.md) | 技術アーキテクチャ概要 |

---

## トラブルシューティング

```bash
inir logs                       # 最近のランタイムログを確認
inir restart                    # アクティブなランタイムを再起動
inir repair                     # doctor + 再起動 + フィルタ済みログチェック
./setup doctor                  # 一般的な問題の自動診断と修復
./setup rollback                # 最後のアップデートを取り消し
```

issue を開く前に [LIMITATIONS.md](../LIMITATIONS.md) を確認してください。

---

## コントリビュート

[CONTRIBUTING.md](../../CONTRIBUTING.md) を参照 — 開発環境のセットアップ、コードパターン、PR ガイドライン。

---

## クレジット

- [**end-4**](https://github.com/end-4/dots-hyprland) — Hyprland 向けオリジナル illogical-impulse
- [**Quickshell**](https://quickshell.outfoxxed.me/) — このシェルを動かすフレームワーク
- [**Niri**](https://github.com/YaLTeR/niri) — スクロール式タイリング Wayland コンポジター

---

<p align="center">
  <a href="https://github.com/snowarch/inir/graphs/contributors">コントリビューター</a> &bull;
  <a href="CHANGELOG.md">変更履歴</a> &bull;
  <a href="LICENSE">MIT ライセンス</a>
</p>
