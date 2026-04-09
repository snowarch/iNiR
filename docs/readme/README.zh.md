<p align="center">
  <img src="https://github.com/user-attachments/assets/da6beb4a-ccee-40ba-a372-5eea77b595f8" alt="iNiR" width="800">
</p>

<h1 align="center">iNiR</h1>

<p align="center">
  <b>基于 Quickshell 的 Niri 完整桌面 Shell</b>
</p>

<p align="center">
  <a href="https://github.com/snowarch/inir/releases"><img src="https://img.shields.io/badge/version-2.18.0-blue?style=flat-square" alt="Version"></a>
  <a href="https://github.com/snowarch/inir/stargazers"><img src="https://img.shields.io/github/stars/snowarch/inir?style=flat-square" alt="Stars"></a>
  <a href="https://discord.gg/pAPTfAhZUJ"><img src="https://img.shields.io/badge/Discord-join-5865F2?style=flat-square&logo=discord&logoColor=white" alt="Discord"></a>
</p>

<p align="center">
  <a href="../INSTALL.md">安装</a> &bull;
  <a href="../KEYBINDS.md">快捷键</a> &bull;
  <a href="../IPC.md">IPC 参考</a> &bull;
  <a href="https://discord.gg/pAPTfAhZUJ">Discord</a> &bull;
  <a href="../../CONTRIBUTING.md">贡献</a>
</p>

<p align="center">
  <sub>
    <a href="../../README.md">English</a> · <a href="README.es.md">Español</a> · <a href="README.ru.md">Русский</a> · <a href="README.zh.md">中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.pt.md">Português</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a> · <a href="README.ko.md">한국어</a> · <a href="README.hi.md">हिन्दी</a> · <a href="README.ar.md">العربية</a> · <a href="README.it.md">Italiano</a>
  </sub>
</p>

---

> **关于翻译：** 社区翻译。如有不明之处，请参阅[英文版](../../README.md)。

---

<details>
<summary><b>🤔 第一次来？如果不知道这是什么，点这里</b></summary>

### 这是什么？

iNiR 是你的整个桌面。顶部的栏、Dock、通知、设置、壁纸，全部。不是主题，不是复制粘贴的配置文件。是一个运行在 Linux 上的完整 Shell。

### 运行需要什么？

一个合成器。就是管理窗口、把像素画到屏幕上的东西。iNiR 是为 [Niri](https://github.com/YaLTeR/niri)（一个平铺式 Wayland 合成器）做的。有一些从 end-4 的 dots fork 过来的 Hyprland 旧代码，但真正在测试和使用的是 Niri。

Shell 运行在 [Quickshell](https://quickshell.outfoxxed.me/) 上，一个用 QML（Qt 的 UI 语言）构建 Shell 的框架。不需要懂这些也能用，所有配置都可以通过 GUI 或 JSON 文件完成。

### 各部分如何连接

```
你的应用
   ↓
iNiR（Shell：栏、侧边栏、Dock、通知、设置...）
   ↓
Quickshell（运行 QML Shell）
   ↓
Niri（合成器：窗口、渲染）
   ↓
Wayland → GPU
```

### 稳定吗？

这是一个失控的个人项目。我每天都在用，Discord 里很多人也是。但有时候会出问题，代码有些地方很乱，边做边学。

如果出了问题，`inir doctor` 能修大部分。Discord 很活跃，那个不行就问那边。别指望精雕细琢的软件——这是一个人的 rice，碰巧其他人也喜欢。

### 为什么存在？

我想让桌面看起来和用起来是某种样子，没有其他东西能完全做到。从 end-4 的 Hyprland dots 开始，最后变成了为 Niri 完全重写，加了很多功能。

### 会看到的术语

- **Shell**：UI 层（栏、面板、覆盖层）
- **Compositor**：管理窗口，画到屏幕上（Niri、Hyprland、Sway...）
- **Wayland**：Linux 的显示协议（新的，替代 X11）
- **QML**：Qt 的声明式 UI 语言，iNiR 就是用这个写的
- **Material You**：Google 的配色系统，从图片生成调色板（自动主题就是这么工作的）
- **ii / waffle**：两种面板风格。ii = Material Design 风，waffle = Windows 11 风。`Super+Shift+W` 切换

</details>

---

## 截图

<details open>
<summary><b>Material ii</b> — 浮动栏、侧边栏、Material Design 风格</summary>

| | |
|:---:|:---:|
| ![](https://github.com/user-attachments/assets/1fe258bc-8aec-4fd9-8574-d9d7472c3cc8) | ![](https://github.com/user-attachments/assets/3ce2055b-648c-45a1-9d09-705c1b4a03b7) |
| ![](https://github.com/user-attachments/assets/ea2311dc-769e-44dc-a46d-37cf8807d2cc) | ![](https://github.com/user-attachments/assets/da6beb4a-ccee-40ba-a372-5eea77b595f8) |
| ![](https://github.com/user-attachments/assets/ba866063-b26a-47cb-83c8-d77bd033bf8b) | ![](https://github.com/user-attachments/assets/88e76566-061b-4f8c-a9a8-53c157950138) |

</details>

<details>
<summary><b>Waffle</b> — 底部任务栏、操作中心、Windows 11 风格</summary>

| | |
|:---:|:---:|
| ![](https://github.com/user-attachments/assets/5c5996e7-90eb-4789-9921-0d5fe5283fa3) | ![](https://github.com/user-attachments/assets/fadf9562-751e-4138-a3a1-b87b31114d44) |

</details>

---

## 功能

**两套面板家族**，通过 `Super+Shift+W` 随时切换：
- **Material ii** — 浮动栏、侧边栏、Dock、5 种视觉风格（material、cards、aurora、inir、angel）
- **Waffle** — Windows 11 风格任务栏、开始菜单、操作中心、通知中心

**自动主题** — 选一张壁纸，一切自动适配：
- 通过 Material You 生成 Shell 配色，传播到 GTK3/4、Qt、终端、Firefox、Discord、SDDM
- 10 个终端工具自动主题化（foot、kitty、alacritty、starship、fuzzel、btop、lazygit、yazi）
- 主题预设：Gruvbox、Catppuccin、Rosé Pine，以及自定义

**合成器** — 为 Niri 打造。

<details>
<summary><b>完整功能列表</b></summary>

### 主题与外观

选一张壁纸，整个系统跟着变 — Shell、GTK/Qt 应用、终端、Firefox、Discord、SDDM 登录界面。全自动。

- **5 种视觉风格** — Material（纯色）、Cards、Aurora（毛玻璃）、iNiR（TUI 风格）、Angel（新残酷主义）
- **壁纸动态取色** — 通过 Material You 传播到全系统
- **10 个终端工具自动主题化** — foot、kitty、alacritty、starship、fuzzel、pywalfox、btop、lazygit、yazi
- **应用主题化** — GTK3/4、Qt（通过 plasma-integration + darkly）、Firefox（MaterialFox）、Discord/Vesktop（System24）
- **主题预设** — Gruvbox、Catppuccin、Rosé Pine 等 — 或创建自己的
- **视频壁纸** — mp4/webm/gif，可选模糊，或冻结首帧以提升性能
- **SDDM 登录主题** — Material You 配色与壁纸同步
- **桌面小部件** — 时钟（多种样式）、天气、媒体控件，位于壁纸层

### 侧边栏与小部件（Material ii）

左侧边栏（应用抽屉）：
- **AI 聊天** — Gemini、Mistral、OpenRouter，或通过 Ollama 使用本地模型
- **YT Music** — 完整播放器，支持搜索、队列和控制
- **Wallhaven 浏览器** — 直接搜索和应用壁纸
- **番剧追踪** — AniList 集成，支持放送日程
- **Reddit 订阅** — 内联浏览 subreddit
- **翻译器** — 通过 Gemini 或 translate-shell
- **可拖拽小部件** — 加密货币、媒体播放器、快速笔记、状态环、周历

右侧边栏：
- **日历** — 支持事件集成
- **通知中心**
- **快速开关** — WiFi、蓝牙、夜灯、勿扰、电源配置、WARP VPN、EasyEffects
- **音量混合器** — 按应用控制
- **蓝牙和 WiFi** 设备管理
- **番茄钟**、**待办列表**、**计算器**、**记事本**
- **系统监视器** — CPU、内存、温度

### 工具

- **工作区概览** — 适配 Niri 滚动模型，支持应用搜索和计算器
- **窗口切换器** — Alt+Tab 跨所有工作区
- **剪贴板管理器** — 历史记录，支持搜索和图片预览
- **区域工具** — 截图、录屏、OCR、反向图片搜索
- **快捷键速查** — 从 Niri 配置中提取的快捷键查看器
- **媒体控件** — 完整 MPRIS 播放器，多种布局预设
- **屏幕显示** — 音量、亮度和媒体 OSD
- **歌曲识别** — 通过 SongRec 实现 Shazam 风格识别
- **语音搜索** — 录音并通过 Gemini 搜索

### 系统

- **GUI 设置** — 无需编辑文件即可配置一切
- **GameMode** — 全屏应用时自动禁用特效
- **自动更新** — `inir update`，支持回滚、迁移和用户更改保留
- **锁屏** 和 **会话界面**（注销/重启/关机/休眠）
- **Polkit 代理**、**屏幕键盘**、**自启动管理器**
- **9 种语言** — 自动检测，支持 AI 辅助翻译生成
- **夜灯** — 定时或手动
- **天气** — Open-Meteo，支持 GPS、手动坐标或城市名
- **电池管理** — 可配置阈值，低电量自动休眠
- **Shell 更新检查** — 有新版本时通知

</details>

---

## 快速开始

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup install       # 交互式 — 每步都会询问
./setup install -y    # 自动 — 无需确认
```

安装程序处理依赖、系统配置、主题 — 一切。安装后运行 `inir run` 启动 Shell，或注销后重新登录。

```bash
inir run                        # 启动 Shell
inir settings                   # 打开设置 GUI
inir logs                       # 查看运行日志
inir doctor                     # 自动诊断和修复
inir update                     # 拉取 + 迁移 + 重启
```

**支持的发行版：** Arch（自动化安装器）。其他发行版可手动安装——参见 [PACKAGES.md](../PACKAGES.md)。

| 方式 | 命令 |
|--------|---------|
| 系统安装 | `sudo make install && inir run` |
| TUI 菜单 | `./setup` |
| 回滚 | `./setup rollback` |

---

## 快捷键

| 按键 | 操作 |
|-----|--------|
| `Super+Space` | 概览 — 搜索应用、导航工作区 |
| `Alt+Tab` | 窗口切换器 |
| `Super+V` | 剪贴板历史 |
| `Super+Shift+S` | 区域截图 |
| `Super+Shift+X` | 区域 OCR |
| `Super+,` | 设置 |
| `Super+Shift+W` | 切换面板家族 |

完整列表：[KEYBINDS.md](../KEYBINDS.md)

---

## 壁纸

内置 15 张壁纸。更多壁纸请查看 [iNiR-Walls](https://github.com/snowarch/iNiR-Walls) — 精选合集，与 Material You 管线完美配合。

---

## 文档

| | |
|---|---|
| [INSTALL.md](../INSTALL.md) | 安装指南 |
| [SETUP.md](../SETUP.md) | Setup 命令 — 更新、迁移、回滚 |
| [KEYBINDS.md](../KEYBINDS.md) | 所有快捷键 |
| [IPC.md](../IPC.md) | 用于脚本和快捷键的 IPC 目标 |
| [PACKAGES.md](../PACKAGES.md) | 每个依赖及其用途 |
| [LIMITATIONS.md](../LIMITATIONS.md) | 已知限制和解决方法 |
| [ARCHITECTURE.md](../ARCHITECTURE.md) | 技术架构概述 |

---

## 故障排除

```bash
inir logs                       # 查看最近的运行日志
inir restart                    # 重启活动运行时
inir repair                     # doctor + 重启 + 过滤日志检查
./setup doctor                  # 自动诊断和修复常见问题
./setup rollback                # 撤销上次更新
```

提交 issue 前请先查看 [LIMITATIONS.md](../LIMITATIONS.md)。

---

## 贡献

参见 [CONTRIBUTING.md](../../CONTRIBUTING.md) — 开发环境配置、代码规范和 PR 指南。

---

## 致谢

- [**end-4**](https://github.com/end-4/dots-hyprland) — 原始的 illogical-impulse（Hyprland 版）
- [**Quickshell**](https://quickshell.outfoxxed.me/) — 驱动此 Shell 的框架
- [**Niri**](https://github.com/YaLTeR/niri) — 滚动平铺式 Wayland 合成器

---

<p align="center">
  <a href="https://github.com/snowarch/inir/graphs/contributors">贡献者</a> &bull;
  <a href="CHANGELOG.md">更新日志</a> &bull;
  <a href="LICENSE">MIT 许可证</a>
</p>
