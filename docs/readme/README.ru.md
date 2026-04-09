<p align="center">
  <img src="https://github.com/user-attachments/assets/da6beb4a-ccee-40ba-a372-5eea77b595f8" alt="iNiR" width="800">
</p>

<h1 align="center">iNiR</h1>

<p align="center">
  <b>Полноценный десктопный шелл для Niri на базе Quickshell</b>
</p>

<p align="center">
  <a href="https://github.com/snowarch/inir/releases"><img src="https://img.shields.io/badge/version-2.18.0-blue?style=flat-square" alt="Version"></a>
  <a href="https://github.com/snowarch/inir/stargazers"><img src="https://img.shields.io/github/stars/snowarch/inir?style=flat-square" alt="Stars"></a>
  <a href="https://discord.gg/pAPTfAhZUJ"><img src="https://img.shields.io/badge/Discord-join-5865F2?style=flat-square&logo=discord&logoColor=white" alt="Discord"></a>
</p>

<p align="center">
  <a href="../INSTALL.md">Установка</a> &bull;
  <a href="../KEYBINDS.md">Клавиши</a> &bull;
  <a href="../IPC.md">Справка IPC</a> &bull;
  <a href="https://discord.gg/pAPTfAhZUJ">Discord</a> &bull;
  <a href="../../CONTRIBUTING.md">Участие</a>
</p>

<p align="center">
  <sub>
    <a href="../../README.md">English</a> · <a href="README.es.md">Español</a> · <a href="README.ru.md">Русский</a> · <a href="README.zh.md">中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.pt.md">Português</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a> · <a href="README.ko.md">한국어</a> · <a href="README.hi.md">हिन्दी</a> · <a href="README.ar.md">العربية</a> · <a href="README.it.md">Italiano</a>
  </sub>
</p>

---

> **О переводе:** Перевод от сообщества. Если что-то непонятно — смотрите [английскую версию](../../README.md).

---

<details>
<summary><b>🤔 Первый раз здесь? Нажми, если не понимаешь что это</b></summary>

### Что это?

iNiR — это весь твой рабочий стол. Панель сверху, док, уведомления, настройки, обои, всё. Это не тема, не конфиги для копипаста. Это полноценный шелл, работающий на Linux.

### Что нужно для запуска?

Композитор. Это штука, которая управляет окнами и выводит пиксели на экран. iNiR сделан для [Niri](https://github.com/YaLTeR/niri) (тайлинговый Wayland-композитор). Есть старый код для Hyprland со времён форка dots от end-4, но реально тестируется и используется Niri.

Шелл работает на [Quickshell](https://quickshell.outfoxxed.me/) — фреймворке для создания шеллов на QML (язык UI от Qt). Знать это не обязательно, всё настраивается через GUI или JSON-файл.

### Как всё связано

```
твои приложения
   ↓
iNiR (шелл: панель, сайдбары, док, уведомления, настройки...)
   ↓
Quickshell (запускает QML-шеллы)
   ↓
Niri (композитор: окна, рендеринг)
   ↓
Wayland → GPU
```

### Это стабильно?

Это личный проект, который вышел из-под контроля. Я пользуюсь им каждый день, куча людей в Discord тоже. Но иногда что-то ломается, код местами кривой, учусь на ходу.

Если что-то не работает, `inir doctor` чинит большинство проблем. Discord активный, если это не поможет. Не жди отполированного софта — это рис одного человека, который понравился другим.

### Зачем это существует?

Хотел, чтобы мой рабочий стол выглядел и работал определённым образом, и ничего другого этого не давало. Началось как dots end-4 для Hyprland, стало полным переписыванием для Niri с кучей новых фич.

### Термины, которые встретишь

- **Shell**: слой UI (панель, оверлеи)
- **Compositor**: управляет окнами, рисует на экране (Niri, Hyprland, Sway...)
- **Wayland**: протокол дисплея Linux (новый, замена X11)
- **QML**: декларативный язык UI от Qt, на нём написан iNiR
- **Material You**: система цветов Google, генерирует палитры из картинок (так работает авто-тематизация)
- **ii / waffle**: два стиля панелей. ii = Material Design вайбы, waffle = Windows 11 вайбы. `Super+Shift+W` переключает

</details>

---

## Скриншоты

<details open>
<summary><b>Material ii</b> — плавающая панель, сайдбары, эстетика Material Design</summary>

| | |
|:---:|:---:|
| ![](https://github.com/user-attachments/assets/1fe258bc-8aec-4fd9-8574-d9d7472c3cc8) | ![](https://github.com/user-attachments/assets/3ce2055b-648c-45a1-9d09-705c1b4a03b7) |
| ![](https://github.com/user-attachments/assets/ea2311dc-769e-44dc-a46d-37cf8807d2cc) | ![](https://github.com/user-attachments/assets/da6beb4a-ccee-40ba-a372-5eea77b595f8) |
| ![](https://github.com/user-attachments/assets/ba866063-b26a-47cb-83c8-d77bd033bf8b) | ![](https://github.com/user-attachments/assets/88e76566-061b-4f8c-a9a8-53c157950138) |

</details>

<details>
<summary><b>Waffle</b> — панель задач снизу, центр действий, атмосфера Windows 11</summary>

| | |
|:---:|:---:|
| ![](https://github.com/user-attachments/assets/5c5996e7-90eb-4789-9921-0d5fe5283fa3) | ![](https://github.com/user-attachments/assets/fadf9562-751e-4138-a3a1-b87b31114d44) |

</details>

---

## Возможности

**Два семейства панелей**, переключаемые на лету через `Super+Shift+W`:
- **Material ii** — плавающая панель, сайдбары, док, 5 визуальных стилей (material, cards, aurora, inir, angel)
- **Waffle** — панель задач в стиле Windows 11, стартовое меню, центр действий, центр уведомлений

**Автоматическая тематизация** — выбираете обои и всё подстраивается:
- Цвета шелла через Material You, распространяются на GTK3/4, Qt, терминалы, Firefox, Discord, SDDM
- 10 терминальных инструментов с авто-темой (foot, kitty, alacritty, starship, fuzzel, btop, lazygit, yazi)
- Пресеты тем: Gruvbox, Catppuccin, Rosé Pine, и пользовательские

**Композитор** — создан для Niri.

<details>
<summary><b>Полный список возможностей</b></summary>

### Темы и внешний вид

Выбираете обои — и вся система подстраивается: шелл, GTK/Qt приложения, терминалы, Firefox, Discord, экран входа SDDM. Автоматически.

- **5 визуальных стилей** — Material (сплошной), Cards, Aurora (стеклянное размытие), iNiR (в духе TUI), Angel (нео-брутализм)
- **Динамические цвета обоев** через Material You — распространяются на всю систему
- **10 терминальных инструментов с авто-темой** — foot, kitty, alacritty, starship, fuzzel, pywalfox, btop, lazygit, yazi
- **Тематизация приложений** — GTK3/4, Qt (через plasma-integration + darkly), Firefox (MaterialFox), Discord/Vesktop (System24)
- **Пресеты тем** — Gruvbox, Catppuccin, Rosé Pine и другие — или создайте свой
- **Видео-обои** — mp4/webm/gif с размытием или замороженный первый кадр для производительности
- **Тема SDDM** — цвета Material You, синхронизированные с обоями
- **Виджеты рабочего стола** — часы (несколько стилей), погода, медиа-контролы на слое обоев

### Сайдбары и виджеты (Material ii)

Левый сайдбар (панель приложений):
- **AI-чат** — Gemini, Mistral, OpenRouter или локальные модели через Ollama
- **YT Music** — полноценный плеер с поиском, очередью и управлением
- **Браузер Wallhaven** — поиск и установка обоев напрямую
- **Аниме-трекер** — интеграция с AniList и расписание выходов
- **Лента Reddit** — просмотр сабреддитов прямо в панели
- **Переводчик** — через Gemini или translate-shell
- **Перетаскиваемые виджеты** — криптовалюты, медиаплеер, быстрые заметки, статус-кольца, недельный календарь

Правый сайдбар:
- **Календарь** с интеграцией событий
- **Центр уведомлений**
- **Быстрые переключатели** — WiFi, Bluetooth, ночной свет, DND, профили питания, WARP VPN, EasyEffects
- **Микшер громкости** — управление по приложениям
- **Bluetooth и WiFi** — управление устройствами
- **Таймер помодоро**, **список задач**, **калькулятор**, **блокнот**
- **Системный монитор** — CPU, RAM, температура

### Инструменты

- **Обзор рабочих столов** — адаптирован под скроллинг Niri, с поиском приложений и калькулятором
- **Переключатель окон** — Alt+Tab по всем рабочим столам
- **Менеджер буфера обмена** — история с поиском и превью изображений
- **Инструменты области** — скриншоты, запись экрана, OCR, обратный поиск изображений
- **Шпаргалка** — просмотр горячих клавиш из конфига Niri
- **Медиа-контролы** — полноценный MPRIS-плеер с несколькими пресетами компоновки
- **Экранные индикаторы** — OSD громкости, яркости и медиа
- **Распознавание музыки** — идентификация в стиле Shazam через SongRec
- **Голосовой поиск** — запись и поиск через Gemini

### Система

- **GUI настройки** — настраивайте всё без редактирования файлов
- **GameMode** — автоматически отключает эффекты при полноэкранных приложениях
- **Авто-обновления** — `inir update` с откатом, миграциями и сохранением пользовательских изменений
- **Экран блокировки** и **экран сессии** (выход/перезагрузка/выключение/сон)
- **Polkit-агент**, **экранная клавиатура**, **менеджер автозапуска**
- **9 языков** — автоопределение, с генерацией переводов через AI
- **Ночной свет** — по расписанию или вручную
- **Погода** — Open-Meteo, поддержка GPS, координат или названия города
- **Управление батареей** — настраиваемые пороги, авто-сон при критическом заряде
- **Проверка обновлений шелла** — уведомляет о новых версиях

</details>

---

## Быстрый старт

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup install       # интерактивный — спрашивает перед каждым шагом
./setup install -y    # автоматический — устанавливает всё без вопросов
```

Установщик разберётся с зависимостями, системным конфигом, тематизацией — всем. После установки запустите `inir run` или перелогиньтесь.

```bash
inir run                        # запустить шелл
inir settings                   # открыть GUI настроек
inir logs                       # проверить логи
inir doctor                     # автодиагностика и исправление
inir update                     # pull + миграции + перезапуск
```

**Поддерживаемые дистрибутивы:** Arch (автоматический установщик). Другие дистрибутивы могут установить вручную — см. [PACKAGES.md](../PACKAGES.md).

| Метод | Команда |
|--------|---------|
| Системная установка | `sudo make install && inir run` |
| Меню TUI | `./setup` |
| Откат | `./setup rollback` |

---

## Клавиши

| Клавиша | Действие |
|-----|--------|
| `Super+Space` | Обзор — поиск приложений, навигация по рабочим столам |
| `Alt+Tab` | Переключатель окон |
| `Super+V` | История буфера обмена |
| `Super+Shift+S` | Скриншот области |
| `Super+Shift+X` | OCR области |
| `Super+,` | Настройки |
| `Super+Shift+W` | Переключение семейства панелей |

Полный список: [KEYBINDS.md](../KEYBINDS.md)

---

## Обои

15 обоев идут в комплекте. Больше — в [iNiR-Walls](https://github.com/snowarch/iNiR-Walls), подборка, хорошо работающая с пайплайном Material You.

---

## Документация

| | |
|---|---|
| [INSTALL.md](../INSTALL.md) | Руководство по установке |
| [SETUP.md](../SETUP.md) | Команды setup — обновления, миграции, откат |
| [KEYBINDS.md](../KEYBINDS.md) | Все горячие клавиши |
| [IPC.md](../IPC.md) | IPC-цели для скриптов и пользовательских привязок |
| [PACKAGES.md](../PACKAGES.md) | Каждый пакет и зачем он нужен |
| [LIMITATIONS.md](../LIMITATIONS.md) | Известные ограничения и обходные пути |
| [ARCHITECTURE.md](../ARCHITECTURE.md) | Техническая архитектура проекта |

---

## Решение проблем

```bash
inir logs                       # проверьте логи — ответ обычно там
inir restart                    # перезапустить шелл
inir repair                     # doctor + перезапуск + проверка логов
./setup doctor                  # автодиагностика и исправление типичных проблем
./setup rollback                # откатить последнее обновление
```

Загляните в [LIMITATIONS.md](../LIMITATIONS.md) перед открытием issue.

---

## Участие

Смотрите [CONTRIBUTING.md](../../CONTRIBUTING.md) — настройка среды разработки, паттерны кода и правила PR.

---

## Благодарности

- [**end-4**](https://github.com/end-4/dots-hyprland) — оригинальный illogical-impulse для Hyprland
- [**Quickshell**](https://quickshell.outfoxxed.me/) — фреймворк, на котором работает этот шелл
- [**Niri**](https://github.com/YaLTeR/niri) — скроллинговый тайлинговый Wayland-композитор

---

<p align="center">
  <a href="https://github.com/snowarch/inir/graphs/contributors">Участники</a> &bull;
  <a href="CHANGELOG.md">Changelog</a> &bull;
  <a href="LICENSE">Лицензия MIT</a>
</p>
