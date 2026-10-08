<p align="center">
  <img src="../images/iris-2.32-principal.webp" alt="iNiR iRiS desktop" width="900">
</p>

<h1 align="center">iNiR</h1>

<p align="center">
  <b>Eine komplette Desktop-Shell für Niri, gebaut auf Quickshell</b>
</p>

<p align="center">
  <a href="https://github.com/snowarch/inir/releases"><img src="https://img.shields.io/badge/version-2.32.0-blue?style=flat-square" alt="Version"></a>
  <a href="https://github.com/snowarch/inir/stargazers"><img src="https://img.shields.io/github/stars/snowarch/inir?style=flat-square" alt="Stars"></a>
  <a href="https://discord.gg/pAPTfAhZUJ"><img src="https://img.shields.io/badge/Discord-join-5865F2?style=flat-square&logo=discord&logoColor=white" alt="Discord"></a>
  <a href="../../LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-green?style=flat-square" alt="License"></a>
</p>

<p align="center">
  <a href="https://github.com/snowarch/inir/wiki/INSTALL">Installieren</a> &bull;
  <a href="https://github.com/snowarch/inir/wiki/KEYBINDS">Tastenkürzel</a> &bull;
  <a href="https://github.com/snowarch/inir/wiki/IPC">IPC-Referenz</a> &bull;
  <a href="https://discord.gg/pAPTfAhZUJ">Discord</a> &bull;
  <a href="../../CONTRIBUTING.md">Mitwirken</a>
</p>

<p align="center">
  <sub>
    <a href="../../README.md">English</a> · <a href="README.es.md">Español</a> · <a href="README.ru.md">Русский</a> · <a href="README.zh.md">中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.pt.md">Português</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a> · <a href="README.ko.md">한국어</a> · <a href="README.hi.md">हिन्दी</a> · <a href="README.ar.md">العربية</a> · <a href="README.it.md">Italiano</a>
  </sub>
</p>

---

> **Zu dieser Übersetzung:** Im Zweifel gilt die [englische Version](../../README.md).

---

<details>
<summary><b>🤔 Neu hier? Klick, wenn du keine Ahnung hast, was das alles ist</b></summary>

### Was ist das?

iNiR ist dein ganzer Desktop. Die Leiste oben, das Dock, Benachrichtigungen, Einstellungen, Hintergründe, alles. Kein Theme, keine Dotfiles zum Reinkopieren. Eine vollständige Shell, die unter Linux läuft.

### Was brauche ich dafür?

Einen Compositor. Der verwaltet deine Fenster und bringt die Pixel auf den Bildschirm. iNiR ist für [Niri](https://github.com/YaLTeR/niri) gemacht (ein Tiling-Compositor für Wayland). Es gibt noch alten Hyprland-Code aus der Zeit, als das hier ein Fork von end-4s Dots war, aber Niri ist das, was ich wirklich benutze und teste.

Die Shell läuft auf [Quickshell](https://quickshell.outfoxxed.me/), einem Framework für Shells in QML (der UI-Sprache von Qt). Davon musst du nichts wissen: Alles lässt sich über die Oberfläche oder eine JSON-Datei einstellen.

### Wie alles zusammenhängt

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

### Ist es stabil?

Es ist ein privates Projekt, das aus dem Ruder gelaufen ist. Ich nutze es täglich, viele Leute im Discord auch. Aber manchmal geht etwas kaputt, der Code ist stellenweise chaotisch, und ich lerne unterwegs.

Wenn etwas nicht geht, behebt `inir doctor` das meiste. Sonst ist der Discord aktiv. Erwarte nur keine polierte Software: Das ist der Rice einer Person, der anderen zufällig auch gefällt.

### Warum gibt es das?

Ich wollte, dass mein Desktop auf eine bestimmte Art aussieht und funktioniert, und nichts hat genau das gemacht. Angefangen als end-4s Hyprland-Dots, wurde daraus eine komplette Neuentwicklung für Niri mit deutlich mehr Funktionen.

### Begriffe, die dir begegnen

- **Shell**: die Oberflächenschicht (Leiste, Panels, Overlays)
- **Compositor**: verwaltet Fenster und zeichnet auf den Bildschirm (Niri, Hyprland, Sway...)
- **Wayland**: das Anzeigeprotokoll von Linux (das neue, ersetzt X11)
- **QML**: die deklarative UI-Sprache von Qt, in der iNiR geschrieben ist
- **Material You**: Googles Farbsystem, das Paletten aus Bildern erzeugt (so funktioniert das automatische Theming)
- **ii / waffle / iRiS**: die drei Panel-Familien. ii = Material Design, waffle = Windows 11, iRiS = eine Island, die zu dem wird, was du öffnest. `Super+Shift+W` wechselt zwischen ihnen

</details>

---

## Screenshots

<details open>
<summary><b>iRiS</b>: Island, Customize, Menüleiste, Cards und Dock</summary>

<p align="center">
  <img src="../images/iris-2.31-desktop.webp" alt="iRiS desktop layout" width="49%">
  <img src="../images/iris-2.31-card.webp" alt="iRiS card surface" width="49%">
</p>

<p align="center">
  <img src="../images/iris-2.31-dock.webp" alt="iRiS Dock and edge layout" width="99%">
</p>

</details>

<details open>
<summary><b>Material ii</b>: schwebende Leiste, Sidebars, Material-Design-Optik</summary>

| | |
|:---:|:---:|
| ![](https://github.com/user-attachments/assets/1fe258bc-8aec-4fd9-8574-d9d7472c3cc8) | ![](https://github.com/user-attachments/assets/3ce2055b-648c-45a1-9d09-705c1b4a03b7) |
| ![](https://github.com/user-attachments/assets/ea2311dc-769e-44dc-a46d-37cf8807d2cc) | ![](https://github.com/user-attachments/assets/da6beb4a-ccee-40ba-a372-5eea77b595f8) |
| ![](https://github.com/user-attachments/assets/ba866063-b26a-47cb-83c8-d77bd033bf8b) | ![](https://github.com/user-attachments/assets/88e76566-061b-4f8c-a9a8-53c157950138) |

</details>

<details>
<summary><b>Waffle</b>: Taskleiste unten, Info-Center, Windows-11-Stil</summary>

| | |
|:---:|:---:|
| ![](https://github.com/user-attachments/assets/5c5996e7-90eb-4789-9921-0d5fe5283fa3) | ![](https://github.com/user-attachments/assets/fadf9562-751e-4138-a3a1-b87b31114d44) |

</details>

---

> [!WARNING]
> Nichts für schwache Rechner.
> Du kannst es aber stark abspecken: Effekte aus, Panels weg, Design vereinfachen. In den Einstellungen oder in `config.json`, wie du willst.

## Funktionen

**Drei Panel-Familien**, im laufenden Betrieb umschaltbar mit `Super+Shift+W`:
- **Material ii**: schwebende Leiste, Sidebars, Dock und 9 globale Stile (Material, Cards, Aurora, iNiR, Angel, Regalia, ZZZ, Cookie Shapes, Editorial)
- **Waffle**: Taskleiste, Startmenü, Info-Center und Benachrichtigungszentrum im Stil von Windows 11
- **iRiS**: die Vorzeigefamilie. Eine Island an jedem Bildschirmrand, die zu Seiten, Cards und Panels wächst, Pieces zum Mitnehmen, ein Dock an jedem Rand, Glass, Themes, die alles neu gestalten, Hell, Tinte und Dunkel, und Customize direkt auf der Shell

**Automatisches Theming**. Wähl einen Hintergrund, und alles passt sich an:
- Shell-Farben über Material You, weitergegeben an GTK3/4, Qt, Terminals, Firefox, Discord, SDDM
- 10 Theming-Ziele: Terminals, Editoren, Browser, Spicetify, Steam, Cava und mehr
- Theme-Vorlagen: Regalia / Regalia Ivory, Gruvbox, Catppuccin, Rosé Pine und eigene

**Gebaut für Niri.** Der Hyprland-Code hat den Fork überlebt, wird aber nicht getestet.

**Kira**, das Maskottchen, wohnt auf deinem Desktop, wenn du sie dort haben willst. Standardmäßig aus, das Grafikpaket ist ein separater Download.

<details>
<summary><b>Alle Funktionen</b></summary>

### iRiS

- **Die Island**: eine Form am Bildschirmrand, die zeigt, was gerade passiert, und zur Seite, Card oder zum Panel wird, das du geöffnet hast, und sich dann wieder zusammenfaltet. Oben, unten, links oder rechts (`inir iris edge <side>`, oder zieh sie dorthin). An der Seite stellt sie sich auf, mit gestapelter Uhr und Bubbles darüber und darunter
- **Menüleiste**: ein schmaler Streifen mit deinen Workspaces, dem Fenster und den Pieces, die Island hängt daran wie eine Notch (`inir iris layout menubar`)
- **Leiste in voller Breite** mit Start-, Mitte- und Endzonen für die Island, Workspaces, das fokussierte Fenster, die Uhrzeit oder beliebige Pieces (`inir iris zone start|center|end kinds+joined+with+plus`)
- **Pieces**: Wetter, Ton, Mikrofon, Tray, Benachrichtigungen, Werkzeuge, Medien, VPN, ein Visualizer, Anime (Airing und Continue) und deine eigenen Apps als Bubbles, die du auf der Island, am Bildschirmrand oder frei auf dem Desktop ablegst
- **Pieces verbinden sich mit dem, was sie berühren**: leg eines an den Rand des Docks oder der Island, und es wird Teil davon, statt darüber zu schweben
- **Dock** an jedem Rand (`inir iris dockEdge <side|auto>`); auf auto sitzt es gegenüber der Island, und schickst du eines an den Rand des anderen, tauschen sie die Plätze
- **Glass**, das den Hintergrund unter jeder Fläche mattiert und Text auch auf hellen oder unruhigen Hintergründen lesbar hält. Compositor-Blur gibt es auch, aber er ist noch im Bau, also urteil noch nicht
- **Themes**: 20 kuratierte Neugestaltungen (Liquid Glass, Frost, Obsidian, Terminal, Neo Tokyo, Twilight, Lume, Sakura, Unit-01 und mehr) plus deine eigenen als teilbare JSON-Dateien (`inir iris theme`)
- **Hell, Tinte und Dunkel**, jeweils mit eigenem Ton und eigener Mattierung, und Farbthemen (Catppuccin, Nord, Rosé Pine, Tokyo Night…), die auch deine Apps tragen (`inir iris palette`)
- **Form**: Kapsel, rund, Squircle oder eckig für Island und Dock
- **Customize auf der Shell**: tipp auf die Island, das Dock oder eine Bubble, und ihre Optionen wachsen direkt daraus hervor, mit Themes, Look, Pieces und Rückgängig unter der Island (`inir iris edit`). Wer lieber ein Panel mag: Studio zeigt alles in einer Spalte neben dem Bildschirm
- **Ein Control Center, das du selbst anordnest**: jeder gemeinsame Schnellschalter, der Player und jeder Regler sind Zellen, die du ziehst, an einer Ecke skalierst und aus einer Bibliothek daneben hinzufügst, mit sechs Startlayouts; ein Rechtsklick klappt ein Steuerelement auf (`inir iris control edit`)
- **Ein Sperrbildschirm zum Proben**: die echte Sperre öffnet sich bearbeitbar, ohne dass etwas entsperrt werden muss; verschieb Uhr, Player und Anmeldefeld und wähl, was dahinter läuft, Video inklusive (`inir iris lock edit`)

### Theming und Aussehen

- **9 globale Stile**: Material (deckend), Cards, Aurora (Glass mit Blur), iNiR (TUI-inspiriert), Angel (Neo-Brutalismus), Regalia (schwarzes Chassis, warme Elfenbeintinte, zurückhaltende Champagner-Details), ZZZ (Poster-Platten), Cookie Shapes (animierte Formen), Editorial (Papier-und-Tinte-Typografie)
- **Dynamische Farben aus dem Hintergrund** über Material You, systemweit
- **10 Terminal- und TUI-Werkzeuge automatisch gethemt**: foot, kitty, alacritty, ghostty, wezterm, starship, fuzzel, btop, lazygit, yazi
- **App-Theming**: GTK3/4, Qt (über plasma-integration und darkly), Firefox, Discord/Vesktop (System24), Zed, Spicetify, Steam, SDDM
- **Theme-Vorlagen**: Gruvbox, Catppuccin, Rosé Pine und mehr, oder deine eigene
- **Video-Hintergründe**: mp4/webm/gif mit optionalem Blur, oder das erste Bild eingefroren für mehr Leistung
- **Desktop-Widgets**: ein Design für alle (iRiS, Material, iNstrument oder Readout), Stapel, die sich wie unter iOS drehen, und Tinte, die dem Hintergrund darunter folgt

### Leiste

- **6 Leistenstile**: classic, islands, scenic, frame, Material-3-Kapseln und pill
- **Pill-Leiste**: eine wandelbare Insel in der Mitte, die beim Überfahren Workspaces, Launcher, Mixer, Medien, Kalender und einen Bildschirmrekorder öffnet
- **Modulares Layout** mit Drag-Editor in den Einstellungen, jedes Modul kann überall hin
- **Vertikale Leiste** für alle, die den Bildschirmrand zurückwollen

### Sidebars und Widgets (Material ii)

Linke Sidebar (App-Schublade):
- **KI-Chat**: Live-Modellkataloge von Ollama, LM Studio, OpenRouter, Gemini, Groq, Mistral, Cerebras, Anthropic, OpenAI und OpenCode
- **YT Music**: InnerTube-Player ohne Cookies, mit Suche, Warteschlange, Radio und synchronisierten Songtexten
- **Wallhaven-Browser**: Hintergründe direkt suchen und anwenden
- **Anime-Tracker**: AniList-Anbindung mit Sendeplan
- **Übersetzer**: über Gemini oder translate-shell
- **Verschiebbare Widgets**: Krypto, Mediaplayer, Schnellnotizen, Statusringe, Wochenkalender

Rechte Sidebar:
- **Kalender** mit Terminen
- **Benachrichtigungszentrum**
- **Schnellschalter**: WLAN, Bluetooth, Nachtlicht, Nicht stören, Energieprofile, WARP VPN, EasyEffects
- **Lautstärkemixer** pro App
- **Bluetooth und WLAN**: Geräteverwaltung
- **Pomodoro-Timer**, **To-do-Liste**, **Rechner**, **Notizblock**
- **Systemmonitor**: CPU, RAM, Temperatur

### Werkzeuge

- **Workspace-Übersicht**: angepasst an Niris Scroll-Modell, mit App-Suche und Rechner
- **Dashboard**: konfigurierbares Overlay in drei Spalten mit Terminen, Benachrichtigungen, To-dos, Notizen, Medien und Wetter
- **Workspace-Leiste am Rand**: Schiene beim Überfahren mit Live-Vorschau und Umsortieren per Drag
- **Fensterwechsler**: ein animiertes Alt-Tab über alle Workspaces, optional, seit Niri ein eigenes hat
- **Zwischenablage**: Verlauf mit Suche und Bildvorschau
- **Bereichswerkzeuge**: Screenshots, Bildschirmaufnahme, OCR, umgekehrte Bildersuche
- **Cheatsheet**: Tastenkürzel direkt aus deiner Niri-Konfiguration
- **Mediensteuerung**: vollständiger MPRIS-Player mit mehreren Layouts
- **OSD**: Lautstärke, Helligkeit und Medien
- **Songerkennung**: wie Shazam, über SongRec
- **Spracheingabe**: lokales whisper.cpp, wenn installiert, oder ein verbundenes Groq, Gemini oder OpenAI

### System

- **Grafische Einstellungen**: alles einstellbar, ohne Dateien anzufassen
- **GameMode**: schaltet Effekte bei Vollbild-Apps automatisch ab
- **Updates**: `inir update` mit Rollback, Migrationen und Erhalt deiner Änderungen
- **Sperrbildschirm** und **Sitzungsbildschirm** (Abmelden/Neustart/Herunterfahren/Ruhezustand)
- **Polkit-Agent**, **Bildschirmtastatur**, **Autostart-Verwaltung** auf Basis von Niris eigener Startdatei
- **Kira**: ein Pixel-Art-Katzenmädchen, das über die Bildschirmränder läuft, auf dich reagiert und einen Chaosmodus hat. Optional, mit separatem Grafikpaket von ~32 MiB unter `./setup` › Extras
- **18 Sprachen** mit automatischer Erkennung, darunter Indonesisch (`id_ID`) und Grönländisch (`kl_GL`)
- **Nachtlicht**: nach Zeitplan oder von Hand
- **Wetter**: Open-Meteo, mit GPS, manuellen Koordinaten oder Ortsname
- **Akkuverwaltung**: einstellbare Schwellen, automatischer Ruhezustand bei kritischem Stand
- **Ereignistöne** mit Gesamtlautstärke und eigener Audiodatei pro Ereignis
- **Update-Prüfung**: meldet, wenn es eine neue Version gibt

</details>

---

## Schnellstart

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup install       # interactive, asks before each step
./setup install -y    # automatic, no questions asked
```

Der Installer kümmert sich um Abhängigkeiten, Systemkonfiguration und Theming. Danach startest du die Shell mit `inir run`, oder du meldest dich ab und wieder an.

```bash
inir run                        # launch the shell
inir settings                   # open settings GUI
inir logs                       # check runtime logs
inir doctor                     # auto-diagnose and fix
inir update                     # pull + migrate + restart
```

Andere Wege, falls `./setup install` nicht das ist, was du willst:

```bash
./setup                 # TUI menu, pick what you want
sudo make install       # system-wide instead of your home
./setup rollback        # undo the last update
```

**Distributionen:** Arch ist das Hauptziel. Fedora und Debian/Ubuntu haben ebenfalls automatische Abhängigkeitspfade, die zuerst die Paketquellen der Distribution nutzen; andere Distributionen folgen der allgemeinen Anleitung in der [Paketliste](https://github.com/snowarch/inir/wiki/PACKAGES). iNiR braucht Qt 6.9 oder neuer: Ubuntu 25.10, Fedora 43 und Debian testing oder später.

---

## Tastenkürzel

| Taste | Aktion |
|-----|--------|
| <kbd>Super</kbd> + <kbd>Space</kbd> | Übersicht: Apps suchen, zwischen Workspaces wechseln |
| <kbd>Super</kbd> + <kbd>V</kbd> | Verlauf der Zwischenablage |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>S</kbd> | Screenshot eines Bereichs |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>X</kbd> | OCR eines Bereichs |
| <kbd>Super</kbd> + <kbd>,</kbd> | Einstellungen |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>W</kbd> | Panel-Familie wechseln |
| <kbd>Super</kbd> + <kbd>/</kbd> | Cheatsheet, falls du den Rest vergisst |

Vollständige Liste: [Tastenkürzel](https://github.com/snowarch/inir/wiki/KEYBINDS)

---

## Hintergründe

15 Hintergründe sind dabei. Mehr gibt es in [iNiR-Walls](https://github.com/snowarch/iNiR-Walls), einer kuratierten Sammlung, die gut mit Material You funktioniert.

---

## Dokumentation

Alles für Nutzer steht im [Wiki](https://github.com/snowarch/inir/wiki) (auf Englisch).

| Seite | Inhalt |
|---|---|
| [Install](https://github.com/snowarch/inir/wiki/INSTALL) | Zum Laufen bringen |
| [Setup](https://github.com/snowarch/inir/wiki/SETUP) | Updates, Migrationen, Rollback |
| [Keybinds](https://github.com/snowarch/inir/wiki/KEYBINDS) | Alle Tastenkürzel |
| [IPC](https://github.com/snowarch/inir/wiki/IPC) | Befehle für Tastenkürzel und Skripte |
| [Packages](https://github.com/snowarch/inir/wiki/PACKAGES) | Jede Abhängigkeit und warum sie da ist |
| [Limitations](https://github.com/snowarch/inir/wiki/LIMITATIONS) | Bekannte Probleme und wie man sie umgeht |
| [Architecture](../../ARCHITECTURE.md) | Wie der Code aufgebaut ist |

---

## Fehlerbehebung

```bash
inir logs                       # check recent runtime logs
inir restart                    # restart the active runtime
inir repair                     # doctor + restart + filtered log check
./setup doctor                  # auto-diagnose and fix common problems
./setup rollback                # undo the last update
```

Schau in [Limitations](https://github.com/snowarch/inir/wiki/LIMITATIONS), bevor du ein Issue öffnest. Wenn du lieber jemanden fragst: Im Discord geht es schneller.

---

## Mitwirken

In [CONTRIBUTING.md](../../CONTRIBUTING.md) stehen Entwicklungsumgebung, Code-Konventionen und wie du einen Pull Request einreichst.

---

## Danksagungen

- [**end-4**](https://github.com/end-4/dots-hyprland): illogical-impulse, die Hyprland-Dots, aus denen iNiR hervorging
- [**pctrade/end4-pC**](https://github.com/pctrade/end4-pC): ein Fork, der ab und zu eine wirklich gute Idee hat
- [**Gakuseei**](https://github.com/Gakuseei): [Ricelin](https://github.com/Gakuseei/Ricelin), woher die Pill-Leiste und der Washi- und Flame-Look stammen
- [**Quickshell**](https://quickshell.outfoxxed.me/): das Framework, auf dem es läuft
- [**Niri**](https://github.com/YaLTeR/niri): der Compositor, für den es gebaut ist

GPL-3.0, wie end-4s Dots. Copyright (C) 2025-2026 snowarch.

---

<p align="center">
  <img src="https://raw.githubusercontent.com/snowarch/inir-mascot/main/inir-mascot-hero-banner.png" alt="iNiR mascot leaning on the iNiR logotype" width="720">
</p>

---

<p align="center">
  <a href="https://github.com/snowarch/inir/graphs/contributors">Mitwirkende</a> &bull;
  <a href="../../CHANGELOG.md">Changelog</a> &bull;
  <a href="../../LICENSE">GPL-3.0-Lizenz</a>
</p>
