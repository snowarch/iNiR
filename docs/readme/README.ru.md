<p align="center">
  <img src="../images/iris-2.32-principal.webp" alt="iNiR iRiS desktop" width="900">
</p>

<h1 align="center">iNiR</h1>

<p align="center">
  <b>Полноценная оболочка рабочего стола для Niri на Quickshell</b>
</p>

<p align="center">
  <a href="https://github.com/snowarch/inir/releases"><img src="https://img.shields.io/badge/version-2.32.0-blue?style=flat-square" alt="Version"></a>
  <a href="https://github.com/snowarch/inir/stargazers"><img src="https://img.shields.io/github/stars/snowarch/inir?style=flat-square" alt="Stars"></a>
  <a href="https://discord.gg/pAPTfAhZUJ"><img src="https://img.shields.io/badge/Discord-join-5865F2?style=flat-square&logo=discord&logoColor=white" alt="Discord"></a>
  <a href="../../LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-green?style=flat-square" alt="License"></a>
</p>

<p align="center">
  <a href="https://github.com/snowarch/inir/wiki/INSTALL">Установка</a> &bull;
  <a href="https://github.com/snowarch/inir/wiki/KEYBINDS">Горячие клавиши</a> &bull;
  <a href="https://github.com/snowarch/inir/wiki/IPC">Справка по IPC</a> &bull;
  <a href="https://discord.gg/pAPTfAhZUJ">Discord</a> &bull;
  <a href="../../CONTRIBUTING.md">Участие</a>
</p>

<p align="center">
  <sub>
    <a href="../../README.md">English</a> · <a href="README.es.md">Español</a> · <a href="README.ru.md">Русский</a> · <a href="README.zh.md">中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.pt.md">Português</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a> · <a href="README.ko.md">한국어</a> · <a href="README.hi.md">हिन्दी</a> · <a href="README.ar.md">العربية</a> · <a href="README.it.md">Italiano</a>
  </sub>
</p>

---

> **О переводе:** если что-то непонятно, ориентируйтесь на [английскую версию](../../README.md).

---

<details>
<summary><b>🤔 Впервые здесь? Нажмите, если не понимаете, что всё это такое</b></summary>

### Что это?

iNiR — это весь ваш рабочий стол. Панель сверху, док, уведомления, настройки, обои, всё сразу. Не тема и не дотфайлы для копирования. Полноценная оболочка, которая работает в Linux.

### Что нужно для запуска?

Композитор. Это то, что управляет окнами и выводит пиксели на экран. iNiR сделан для [Niri](https://github.com/YaLTeR/niri) (тайлинговый композитор Wayland). Остался старый код для Hyprland со времён, когда это был форк дотфайлов end-4, но пользуюсь и тестирую я именно Niri.

Оболочка работает на [Quickshell](https://quickshell.outfoxxed.me/), фреймворке для создания оболочек на QML (языке интерфейсов Qt). Знать это не обязательно: всё настраивается через интерфейс или JSON-файл.

### Как всё связано

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

### Это стабильно?

Это личный проект, который вышел из-под контроля. Я пользуюсь им каждый день, как и многие в Discord. Но иногда что-то ломается, код местами запутан, и я учусь на ходу.

Если что-то не работает, `inir doctor` исправляет большую часть проблем. Если не помогло, в Discord отвечают. Только не ждите отполированного софта: это райс одного человека, который понравился и другим.

### Зачем это существует?

Я хотел, чтобы мой рабочий стол выглядел и работал определённым образом, и ничего не делало именно так. Всё началось с дотфайлов end-4 для Hyprland и превратилось в полную переработку под Niri с гораздо большим числом функций.

### Слова, которые вы здесь встретите

- **Оболочка (shell)**: слой интерфейса (панель, окна-панели, оверлеи)
- **Композитор**: управляет окнами и рисует на экране (Niri, Hyprland, Sway...)
- **Wayland**: протокол отображения в Linux (новый, заменяет X11)
- **QML**: декларативный язык интерфейсов Qt, на нём написан iNiR
- **Material You**: цветовая система Google, которая строит палитру по картинке (так работает автотема)
- **ii / waffle / iRiS**: три семейства панелей. ii — в духе Material Design, waffle — в духе Windows 11, iRiS — Island, которая превращается в то, что вы открываете. `Super+Shift+W` переключает между ними

</details>

---

## Скриншоты

<details open>
<summary><b>iRiS</b>: Island, Customize, строка меню, карточки и Dock</summary>

<p align="center">
  <img src="../images/iris-2.31-desktop.webp" alt="iRiS desktop layout" width="49%">
  <img src="../images/iris-2.31-card.webp" alt="iRiS card surface" width="49%">
</p>

<p align="center">
  <img src="../images/iris-2.31-dock.webp" alt="iRiS Dock and edge layout" width="99%">
</p>

</details>

<details open>
<summary><b>Material ii</b>: плавающая панель, боковые панели, эстетика Material Design</summary>

| | |
|:---:|:---:|
| ![](https://github.com/user-attachments/assets/1fe258bc-8aec-4fd9-8574-d9d7472c3cc8) | ![](https://github.com/user-attachments/assets/3ce2055b-648c-45a1-9d09-705c1b4a03b7) |
| ![](https://github.com/user-attachments/assets/ea2311dc-769e-44dc-a46d-37cf8807d2cc) | ![](https://github.com/user-attachments/assets/da6beb4a-ccee-40ba-a372-5eea77b595f8) |
| ![](https://github.com/user-attachments/assets/ba866063-b26a-47cb-83c8-d77bd033bf8b) | ![](https://github.com/user-attachments/assets/88e76566-061b-4f8c-a9a8-53c157950138) |

</details>

<details>
<summary><b>Waffle</b>: панель задач снизу, центр действий, в духе Windows 11</summary>

| | |
|:---:|:---:|
| ![](https://github.com/user-attachments/assets/5c5996e7-90eb-4789-9921-0d5fe5283fa3) | ![](https://github.com/user-attachments/assets/fadf9562-751e-4138-a3a1-b87b31114d44) |

</details>

---

> [!WARNING]
> Не для слабых машин.
> Но облегчить можно сильно: отключите эффекты, уберите панели, упростите оформление. В настройках или в `config.json`, как удобнее.

## Возможности

**Три семейства панелей**, переключаются на лету через `Super+Shift+W`:
- **Material ii**: плавающая панель, боковые панели, док и 9 глобальных стилей (Material, Cards, Aurora, iNiR, Angel, Regalia, ZZZ, Cookie Shapes, Editorial)
- **Waffle**: панель задач, меню «Пуск», центр действий и центр уведомлений в стиле Windows 11
- **iRiS**: флагманское семейство. Island на любом краю экрана, которая раскрывается в страницы, карточки и панели, элементы, которые можно переносить, Dock на любом краю, стекло, темы-редизайны, светлая, чернильная и тёмная схемы и Customize прямо на оболочке

**Автоматическая тема**. Выберите обои, и всё подстроится:
- Цвета оболочки через Material You, с передачей в GTK3/4, Qt, терминалы, Firefox, Discord, SDDM
- 10 целей для темы: терминалы, редакторы, браузеры, Spicetify, Steam, Cava и другие
- Пресеты тем: Regalia / Regalia Ivory, Gruvbox, Catppuccin, Rosé Pine и свои

**Сделано для Niri.** Код Hyprland остался от форка, но не тестируется.

**Kira**, талисман, живёт на рабочем столе, если вы этого хотите. По умолчанию выключена, набор графики скачивается отдельно.

<details>
<summary><b>Полный список возможностей</b></summary>

### iRiS

- **Island**: одна форма на краю экрана, которая показывает, что происходит, и превращается в открытую страницу, карточку или панель, а потом сворачивается обратно. Сверху, снизу, слева или справа (`inir iris edge <side>` или просто перетащите). Сбоку она встаёт вертикально, с часами в столбик и пузырями сверху и снизу
- **Строка меню**: тонкая полоса с рабочими столами, окном и элементами, а Island свисает с неё как вырез (`inir iris layout menubar`)
- **Режим панели во всю ширину** с зонами начала, центра и конца для Island, рабочих столов, активного окна, времени или любого элемента (`inir iris zone start|center|end kinds+joined+with+plus`)
- **Элементы (pieces)**: погода, звук, микрофон, трей, уведомления, инструменты, музыка, VPN, визуализатор, аниме (Airing и Continue) и ваши приложения в виде пузырей, которые можно оставить на Island, на контуре экрана или прямо на рабочем столе
- **Элементы присоединяются к тому, чего касаются**: положите один на край Dock или Island, и он станет частью этого тела, а не будет парить сверху
- **Dock** на любом краю (`inir iris dockEdge <side|auto>`); в режиме auto он стоит напротив Island, а если отправить один на край другого, они поменяются местами
- **Стекло**, которое матирует обои под каждой поверхностью и сохраняет читаемость текста даже на светлых и пёстрых обоях. Размытие композитора тоже есть, но оно ещё в работе, так что не судите строго
- **Темы**: 20 отобранных редизайнов (Liquid Glass, Frost, Obsidian, Terminal, Neo Tokyo, Twilight, Lume, Sakura, Unit-01 и другие) плюс ваши собственные в JSON-файлах, которыми можно делиться (`inir iris theme`)
- **Светлая, чернильная и тёмная** схемы, у каждой свой тон и матовость, и цветовые темы (Catppuccin, Nord, Rosé Pine, Tokyo Night…), которые подхватывают и приложения (`inir iris palette`)
- **Форма**: капсула, круг, сквиркл или квадрат для Island и Dock
- **Customize прямо на оболочке**: нажмите на Island, Dock или пузырь, и настройки вырастают прямо из него, а Themes, Look, Pieces и отмена находятся под Island (`inir iris edit`). Если удобнее, Studio собирает всё в одну панель сбоку экрана
- **Центр управления, который вы собираете сами**: каждый общий быстрый переключатель, плеер и каждый ползунок — это ячейки, которые можно перетаскивать, растягивать за угол и добавлять из библиотеки рядом, с шестью стартовыми раскладками; правый клик раскрывает элемент (`inir iris control edit`)
- **Экран блокировки с репетицией**: настоящая блокировка открывается в режиме правки, разблокировать ничего не нужно; двигайте часы, плеер и поле входа и выбирайте, что идёт на фоне, включая видео (`inir iris lock edit`)

### Темы и оформление

- **9 глобальных стилей**: Material (сплошной), Cards, Aurora (стекло с размытием), iNiR (в духе TUI), Angel (необрутализм), Regalia (чёрное шасси, тёплые цвета слоновой кости, сдержанная фурнитура цвета шампанского), ZZZ (плакатные плашки), Cookie Shapes (анимированные формы), Editorial (типографика бумаги и чернил)
- **Динамические цвета из обоев** через Material You, по всей системе
- **10 терминальных и TUI-инструментов с автотемой**: foot, kitty, alacritty, ghostty, wezterm, starship, fuzzel, btop, lazygit, yazi
- **Темы для приложений**: GTK3/4, Qt (через plasma-integration и darkly), Firefox, Discord/Vesktop (System24), Zed, Spicetify, Steam, SDDM
- **Пресеты тем**: Gruvbox, Catppuccin, Rosé Pine и другие, или создайте свой
- **Видеообои**: mp4/webm/gif с размытием по желанию или замороженный первый кадр для экономии
- **Виджеты рабочего стола**: один дизайн для всех (iRiS, Material, iNstrument или Readout), стопки, которые листаются как в iOS, и чернила, которые подстраиваются под обои под ними

### Панель

- **6 стилей панели**: classic, islands, scenic, frame, капсулы Material 3 и pill
- **Панель pill**: трансформирующийся центральный остров, который при наведении открывает рабочие столы, лаунчер, микшер, музыку, календарь и запись экрана
- **Модульная раскладка** с редактором перетаскивания в настройках: любой модуль куда угодно
- **Вертикальная панель** для тех, кто хочет вернуть себе край экрана

### Боковые панели и виджеты (Material ii)

Левая боковая панель (ящик приложений):
- **ИИ-чат**: актуальные каталоги моделей Ollama, LM Studio, OpenRouter, Gemini, Groq, Mistral, Cerebras, Anthropic, OpenAI и OpenCode
- **YT Music**: плеер InnerTube без cookies, с поиском, очередью, радио и синхронизированным текстом
- **Браузер Wallhaven**: ищите и ставьте обои напрямую
- **Трекер аниме**: интеграция с AniList и расписание
- **Переводчик**: через Gemini или translate-shell
- **Перетаскиваемые виджеты**: крипта, плеер, быстрые заметки, кольца статуса, календарь на неделю

Правая боковая панель:
- **Календарь** с событиями
- **Центр уведомлений**
- **Быстрые переключатели**: WiFi, Bluetooth, ночной свет, «Не беспокоить», профили питания, WARP VPN, EasyEffects
- **Микшер громкости** по приложениям
- **Bluetooth и WiFi**: управление устройствами
- **Помодоро**, **задачи**, **калькулятор**, **блокнот**
- **Системный монитор**: CPU, RAM, температура

### Инструменты

- **Обзор рабочих столов**: под прокручиваемую модель Niri, с поиском приложений и калькулятором
- **Dashboard**: настраиваемый оверлей в три колонки с расписанием, уведомлениями, задачами, заметками, музыкой и погодой
- **Полоса рабочих столов у края**: направляющая при наведении с живыми превью и перестановкой перетаскиванием
- **Переключатель окон**: анимированный Alt-Tab по всем рабочим столам, опционально, раз уж в Niri есть свой
- **Буфер обмена**: история с поиском и превью изображений
- **Инструменты для областей**: скриншоты, запись экрана, OCR, обратный поиск по картинке
- **Шпаргалка**: горячие клавиши из вашего конфига Niri
- **Управление медиа**: полноценный MPRIS-плеер с несколькими раскладками
- **OSD**: громкость, яркость и медиа
- **Распознавание песен**: как Shazam, через SongRec
- **Голосовой ввод**: локальный whisper.cpp, если установлен, или подключённый Groq, Gemini или OpenAI

### Система

- **Графические настройки**: всё настраивается без правки файлов
- **GameMode**: сам отключает эффекты для полноэкранных приложений
- **Обновления**: `inir update` с откатом, миграциями и сохранением ваших изменений
- **Экран блокировки** и **экран сеанса** (выход/перезагрузка/выключение/сон)
- **Агент polkit**, **экранная клавиатура**, **менеджер автозапуска** на базе собственного файла автозапуска niri
- **Kira**: пиксельная девочка-кошка, которая бродит по краям экрана, реагирует на ваши действия и умеет устраивать хаос. По желанию, отдельный набор графики ~32 МиБ в `./setup` › Extras
- **18 языков** с автоопределением, включая индонезийский (`id_ID`) и гренландский (`kl_GL`)
- **Ночной свет**: по расписанию или вручную
- **Погода**: Open-Meteo, по GPS, координатам или названию города
- **Управление батареей**: настраиваемые пороги, автоматический сон при критическом заряде
- **Звуки событий** с общей громкостью и своим файлом на каждое событие
- **Проверка обновлений**: сообщает о новых версиях

</details>

---

## Быстрый старт

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup install       # interactive, asks before each step
./setup install -y    # automatic, no questions asked
```

Установщик сам разберётся с зависимостями, настройкой системы и темой. После установки запустите оболочку командой `inir run` или выйдите из сеанса и войдите снова.

```bash
inir run                        # launch the shell
inir settings                   # open settings GUI
inir logs                       # check runtime logs
inir doctor                     # auto-diagnose and fix
inir update                     # pull + migrate + restart
```

Другие способы, если `./setup install` вам не подходит:

```bash
./setup                 # TUI menu, pick what you want
sudo make install       # system-wide instead of your home
./setup rollback        # undo the last update
```

**Дистрибутивы:** основная цель — Arch. У Fedora и Debian/Ubuntu тоже есть автоматическая установка зависимостей, сначала из репозиториев дистрибутива; остальным подойдёт общее руководство в [списке пакетов](https://github.com/snowarch/inir/wiki/PACKAGES). iNiR нужен Qt 6.9 или новее: Ubuntu 25.10, Fedora 43, Debian testing и новее.

---

## Горячие клавиши

| Клавиша | Действие |
|-----|--------|
| <kbd>Super</kbd> + <kbd>Space</kbd> | Обзор: поиск приложений, переход между рабочими столами |
| <kbd>Super</kbd> + <kbd>V</kbd> | История буфера обмена |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>S</kbd> | Скриншот области |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>X</kbd> | OCR области |
| <kbd>Super</kbd> + <kbd>,</kbd> | Настройки |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>W</kbd> | Сменить семейство панелей |
| <kbd>Super</kbd> + <kbd>/</kbd> | Шпаргалка, если забудете остальное |

Полный список: [Горячие клавиши](https://github.com/snowarch/inir/wiki/KEYBINDS)

---

## Обои

В комплекте 15 обоев. Больше — в [iNiR-Walls](https://github.com/snowarch/iNiR-Walls), отобранной коллекции, которая хорошо работает с Material You.

---

## Документация

Всё для пользователей — в [Wiki](https://github.com/snowarch/inir/wiki) (на английском).

| Страница | Что там |
|---|---|
| [Install](https://github.com/snowarch/inir/wiki/INSTALL) | Как запустить |
| [Setup](https://github.com/snowarch/inir/wiki/SETUP) | Обновления, миграции, откат |
| [Keybinds](https://github.com/snowarch/inir/wiki/KEYBINDS) | Все горячие клавиши |
| [IPC](https://github.com/snowarch/inir/wiki/IPC) | Команды для привязок и скриптов |
| [Packages](https://github.com/snowarch/inir/wiki/PACKAGES) | Каждая зависимость и зачем она нужна |
| [Limitations](https://github.com/snowarch/inir/wiki/LIMITATIONS) | Известные проблемы и как их обойти |
| [Architecture](../../ARCHITECTURE.md) | Как устроен код |

---

## Решение проблем

```bash
inir logs                       # check recent runtime logs
inir restart                    # restart the active runtime
inir repair                     # doctor + restart + filtered log check
./setup doctor                  # auto-diagnose and fix common problems
./setup rollback                # undo the last update
```

Загляните в [Limitations](https://github.com/snowarch/inir/wiki/LIMITATIONS), прежде чем открывать issue. Если проще спросить человека, в Discord ответят быстрее.

---

## Участие

В [CONTRIBUTING.md](../../CONTRIBUTING.md) описаны среда разработки, соглашения по коду и как отправить pull request.

---

## Благодарности

- [**end-4**](https://github.com/end-4/dots-hyprland): illogical-impulse, дотфайлы для Hyprland, из которых вырос iNiR
- [**pctrade/end4-pC**](https://github.com/pctrade/end4-pC): форк, в котором время от времени бывают по-настоящему хорошие идеи
- [**Gakuseei**](https://github.com/Gakuseei): [Ricelin](https://github.com/Gakuseei/Ricelin), откуда взялись панель pill и оформление washi и flame
- [**Quickshell**](https://quickshell.outfoxxed.me/): фреймворк, на котором всё работает
- [**Niri**](https://github.com/YaLTeR/niri): композитор, для которого всё сделано

GPL-3.0, как и дотфайлы end-4. Copyright (C) 2025-2026 snowarch.

---

<p align="center">
  <img src="https://raw.githubusercontent.com/snowarch/inir-mascot/main/inir-mascot-hero-banner.png" alt="iNiR mascot leaning on the iNiR logotype" width="720">
</p>

---

<p align="center">
  <a href="https://github.com/snowarch/inir/graphs/contributors">Участники</a> &bull;
  <a href="../../CHANGELOG.md">Changelog</a> &bull;
  <a href="../../LICENSE">Лицензия GPL-3.0</a>
</p>
