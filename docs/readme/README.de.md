<p align="center">
  <img src="https://github.com/user-attachments/assets/da6beb4a-ccee-40ba-a372-5eea77b595f8" alt="iNiR" width="800">
</p>

<h1 align="center">iNiR</h1>

<p align="center">
  <b>Eine vollständige Desktop-Shell für Niri, gebaut mit Quickshell</b>
</p>

<p align="center">
  <a href="https://github.com/snowarch/inir/releases"><img src="https://img.shields.io/badge/version-2.18.0-blue?style=flat-square" alt="Version"></a>
  <a href="https://github.com/snowarch/inir/stargazers"><img src="https://img.shields.io/github/stars/snowarch/inir?style=flat-square" alt="Stars"></a>
  <a href="https://discord.gg/pAPTfAhZUJ"><img src="https://img.shields.io/badge/Discord-join-5865F2?style=flat-square&logo=discord&logoColor=white" alt="Discord"></a>
</p>

<p align="center">
  <a href="../INSTALL.md">Installation</a> &bull;
  <a href="../KEYBINDS.md">Tastenkürzel</a> &bull;
  <a href="../IPC.md">IPC-Referenz</a> &bull;
  <a href="https://discord.gg/pAPTfAhZUJ">Discord</a> &bull;
  <a href="../../CONTRIBUTING.md">Mitwirken</a>
</p>

<p align="center">
  <sub>
    <a href="../../README.md">English</a> · <a href="README.es.md">Español</a> · <a href="README.ru.md">Русский</a> · <a href="README.zh.md">中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.pt.md">Português</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a> · <a href="README.ko.md">한국어</a> · <a href="README.hi.md">हिन्दी</a> · <a href="README.ar.md">العربية</a> · <a href="README.it.md">Italiano</a>
  </sub>
</p>

---

> **Zur Übersetzung:** Community-Übersetzung. Bei Unklarheiten bitte die [englische Version](../../README.md) konsultieren.

---

<details>
<summary><b>🤔 Neu hier? Klick wenn du keine Ahnung hast was das ist</b></summary>

### Was ist das?

iNiR ist dein kompletter Desktop. Die Leiste oben, das Dock, Benachrichtigungen, Einstellungen, Hintergründe, alles. Kein Theme, keine Dotfiles zum Kopieren. Eine vollständige Shell die auf Linux läuft.

### Was brauche ich?

Einen Compositor. Das ist das Ding das deine Fenster verwaltet und Pixel auf den Bildschirm bringt. iNiR ist für [Niri](https://github.com/YaLTeR/niri) gebaut (ein Tiling Wayland Compositor). Es gibt alten Hyprland-Code von als das noch ein Fork von end-4s dots war, aber Niri ist was ich wirklich teste und benutze.

Die Shell läuft auf [Quickshell](https://quickshell.outfoxxed.me/), ein Framework um Shells in QML zu bauen (Qts UI-Sprache). Du musst das nicht kennen um es zu nutzen, alles wird über GUI oder JSON konfiguriert.

### Wie alles zusammenhängt

```
deine Apps
   ↓
iNiR (Shell: Leiste, Sidebars, Dock, Benachrichtigungen, Einstellungen...)
   ↓
Quickshell (führt QML Shells aus)
   ↓
Niri (Compositor: Fenster, Rendering)
   ↓
Wayland → GPU
```

### Ist es stabil?

Ein persönliches Projekt das außer Kontrolle geraten ist. Ich benutze es täglich, viele Leute im Discord auch. Aber manchmal geht was kaputt, der Code ist stellenweise unordentlich, ich lerne während ich mache.

Wenn was nicht funktioniert, `inir doctor` behebt das meiste. Discord ist aktiv wenn das nicht hilft. Erwarte keine polierte Software, das ist der Rice einer Person den andere mochten.

### Warum existiert das?

Ich wollte dass mein Desktop auf eine bestimmte Art aussieht und funktioniert, und nichts anderes machte das genau so. Hat als end-4s Hyprland dots angefangen, wurde ein komplettes Rewrite für Niri mit viel mehr Features.

### Wörter die du sehen wirst

- **Shell**: die UI-Ebene (Leiste, Panels, Overlays)
- **Compositor**: verwaltet Fenster, zeichnet auf Bildschirm (Niri, Hyprland, Sway...)
- **Wayland**: Linux Display-Protokoll (das neue, ersetzt X11)
- **QML**: Qts deklarative UI-Sprache, iNiR ist darin geschrieben
- **Material You**: Googles Farbsystem das Paletten aus Bildern generiert (so funktioniert das Auto-Theming)
- **ii / waffle**: die zwei Panel-Stile. ii = Material Design Vibes, waffle = Windows 11 Vibes. `Super+Shift+W` wechselt

</details>

---

## Screenshots

<details open>
<summary><b>Material ii</b> — schwebende Leiste, Seitenleisten, Material-Design-Ästhetik</summary>

| | |
|:---:|:---:|
| ![](https://github.com/user-attachments/assets/1fe258bc-8aec-4fd9-8574-d9d7472c3cc8) | ![](https://github.com/user-attachments/assets/3ce2055b-648c-45a1-9d09-705c1b4a03b7) |
| ![](https://github.com/user-attachments/assets/ea2311dc-769e-44dc-a46d-37cf8807d2cc) | ![](https://github.com/user-attachments/assets/da6beb4a-ccee-40ba-a372-5eea77b595f8) |
| ![](https://github.com/user-attachments/assets/ba866063-b26a-47cb-83c8-d77bd033bf8b) | ![](https://github.com/user-attachments/assets/88e76566-061b-4f8c-a9a8-53c157950138) |

</details>

<details>
<summary><b>Waffle</b> — Taskleiste unten, Aktionscenter, Windows-11-Atmosphäre</summary>

| | |
|:---:|:---:|
| ![](https://github.com/user-attachments/assets/5c5996e7-90eb-4789-9921-0d5fe5283fa3) | ![](https://github.com/user-attachments/assets/fadf9562-751e-4138-a3a1-b87b31114d44) |

</details>

---

## Funktionen

**Zwei Panel-Familien**, im laufenden Betrieb umschaltbar mit `Super+Shift+W`:
- **Material ii** — schwebende Leiste, Seitenleisten, Dock, 5 visuelle Stile (material, cards, aurora, inir, angel)
- **Waffle** — Taskleiste im Windows-11-Stil, Startmenü, Aktionscenter, Benachrichtigungscenter

**Automatische Thematisierung** — Hintergrundbild wählen und alles passt sich an:
- Shell-Farben über Material You, weitergeleitet an GTK3/4, Qt, Terminals, Firefox, Discord, SDDM
- 10 Terminal-Tools automatisch thematisiert (foot, kitty, alacritty, starship, fuzzel, btop, lazygit, yazi)
- Theme-Vorlagen: Gruvbox, Catppuccin, Rosé Pine, und eigene

**Compositor** — für Niri gebaut.

<details>
<summary><b>Vollständige Funktionsliste</b></summary>

### Themes und Aussehen

Hintergrundbild wählen und das gesamte System folgt — Shell, GTK/Qt-Apps, Terminals, Firefox, Discord, SDDM-Anmeldebildschirm. Vollautomatisch.

- **5 visuelle Stile** — Material (einfarbig), Cards, Aurora (Glasunschärfe), iNiR (TUI-inspiriert), Angel (Neo-Brutalismus)
- **Dynamische Hintergrundfarben** über Material You — systemweit propagiert
- **10 Terminal-Tools automatisch thematisiert** — foot, kitty, alacritty, starship, fuzzel, pywalfox, btop, lazygit, yazi
- **App-Thematisierung** — GTK3/4, Qt (über plasma-integration + darkly), Firefox (MaterialFox), Discord/Vesktop (System24)
- **Theme-Vorlagen** — Gruvbox, Catppuccin, Rosé Pine und mehr — oder eigenes erstellen
- **Video-Hintergrundbilder** — mp4/webm/gif mit optionaler Unschärfe, oder eingefrorenes erstes Bild für Performance
- **SDDM-Anmeldetheme** — Material-You-Farben synchronisiert mit dem Hintergrundbild
- **Desktop-Widgets** — Uhr (mehrere Stile), Wetter, Mediensteuerung auf der Hintergrundebene

### Seitenleisten und Widgets (Material ii)

Linke Seitenleiste (App-Schublade):
- **KI-Chat** — Gemini, Mistral, OpenRouter, oder lokale Modelle über Ollama
- **YT Music** — vollständiger Player mit Suche, Warteschlange und Steuerung
- **Wallhaven-Browser** — Hintergrundbilder direkt suchen und anwenden
- **Anime-Tracker** — AniList-Integration mit Sendeplan
- **Reddit-Feed** — Subreddits inline durchsuchen
- **Übersetzer** — über Gemini oder translate-shell
- **Verschiebbare Widgets** — Krypto, Medienplayer, Schnellnotizen, Statusringe, Wochenkalender

Rechte Seitenleiste:
- **Kalender** mit Ereignisintegration
- **Benachrichtigungscenter**
- **Schnellschalter** — WiFi, Bluetooth, Nachtlicht, DND, Energieprofile, WARP VPN, EasyEffects
- **Lautstärkemixer** — Steuerung pro App
- **Bluetooth und WiFi** Geräteverwaltung
- **Pomodoro-Timer**, **Aufgabenliste**, **Taschenrechner**, **Notizblock**
- **Systemmonitor** — CPU, RAM, Temperatur

### Werkzeuge

- **Arbeitsbereich-Übersicht** — angepasst an Niris Scroll-Modell, mit App-Suche und Taschenrechner
- **Fensterwechsler** — Alt+Tab über alle Arbeitsbereiche
- **Zwischenablage-Manager** — Verlauf mit Suche und Bildvorschau
- **Bereichswerkzeuge** — Screenshots, Bildschirmaufnahme, OCR, umgekehrte Bildersuche
- **Spickzettel** — Tastenkürzel-Viewer aus der Niri-Konfiguration
- **Mediensteuerung** — vollständiger MPRIS-Player mit mehreren Layout-Vorlagen
- **Bildschirmanzeige** — OSD für Lautstärke, Helligkeit und Medien
- **Musikerkennung** — Shazam-ähnliche Identifikation über SongRec
- **Sprachsuche** — aufnehmen und über Gemini suchen

### System

- **GUI-Einstellungen** — alles konfigurieren ohne Dateien zu bearbeiten
- **GameMode** — deaktiviert Effekte automatisch bei Vollbild-Apps
- **Auto-Updates** — `inir update` mit Rollback, Migrationen und Erhalt von Benutzeränderungen
- **Sperrbildschirm** und **Sitzungsbildschirm** (Abmelden/Neustart/Herunterfahren/Ruhezustand)
- **Polkit-Agent**, **Bildschirmtastatur**, **Autostart-Manager**
- **9 Sprachen** — automatische Erkennung, mit KI-unterstützter Übersetzungsgenerierung
- **Nachtlicht** — geplant oder manuell
- **Wetter** — Open-Meteo, unterstützt GPS, manuelle Koordinaten oder Stadtnamen
- **Batterieverwaltung** — konfigurierbare Schwellenwerte, automatischer Ruhezustand bei kritischem Stand
- **Shell-Update-Checker** — benachrichtigt bei neuen Versionen

</details>

---

## Schnellstart

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup install       # interaktiv — fragt vor jedem Schritt
./setup install -y    # automatisch — ohne Rückfragen
```

Der Installer kümmert sich um Abhängigkeiten, Systemkonfiguration, Thematisierung — alles. Nach der Installation `inir run` starten oder ab- und wieder anmelden.

```bash
inir run                        # Shell starten
inir settings                   # Einstellungen-GUI öffnen
inir logs                       # Runtime-Logs prüfen
inir doctor                     # Auto-Diagnose und Reparatur
inir update                     # Pull + Migrationen + Neustart
```

**Unterstützte Distributionen:** Arch (automatisierter Installer). Andere Distributionen können manuell installieren — siehe [PACKAGES.md](../PACKAGES.md).

| Methode | Befehl |
|--------|---------|
| Systeminstallation | `sudo make install && inir run` |
| TUI-Menü | `./setup` |
| Rollback | `./setup rollback` |

---

## Tastenkürzel

| Taste | Aktion |
|-----|--------|
| `Super+Space` | Übersicht — Apps suchen, Arbeitsbereiche navigieren |
| `Alt+Tab` | Fensterwechsler |
| `Super+V` | Zwischenablage-Verlauf |
| `Super+Shift+S` | Bereich-Screenshot |
| `Super+Shift+X` | Bereich-OCR |
| `Super+,` | Einstellungen |
| `Super+Shift+W` | Panel-Familie wechseln |

Vollständige Liste: [KEYBINDS.md](../KEYBINDS.md)

---

## Hintergrundbilder

15 Hintergrundbilder sind enthalten. Für mehr siehe [iNiR-Walls](https://github.com/snowarch/iNiR-Walls) — eine kuratierte Sammlung, die gut mit der Material-You-Pipeline funktioniert.

---

## Dokumentation

| | |
|---|---|
| [INSTALL.md](../INSTALL.md) | Installationsanleitung |
| [SETUP.md](../SETUP.md) | Setup-Befehle — Updates, Migrationen, Rollback |
| [KEYBINDS.md](../KEYBINDS.md) | Alle Tastenkürzel |
| [IPC.md](../IPC.md) | IPC-Ziele für Scripting und benutzerdefinierte Tastenkürzel |
| [PACKAGES.md](../PACKAGES.md) | Jede Abhängigkeit und warum sie da ist |
| [LIMITATIONS.md](../LIMITATIONS.md) | Bekannte Einschränkungen und Lösungen |
| [ARCHITECTURE.md](../ARCHITECTURE.md) | Technische Architekturübersicht |

---

## Fehlerbehebung

```bash
inir logs                       # Logs prüfen — die Antwort ist meist dort
inir restart                    # Shell neu starten
inir repair                     # Doctor + Neustart + gefilterte Log-Prüfung
./setup doctor                  # Auto-Diagnose und Behebung häufiger Probleme
./setup rollback                # Letztes Update rückgängig machen
```

Bitte [LIMITATIONS.md](../LIMITATIONS.md) prüfen, bevor ein Issue eröffnet wird.

---

## Mitwirken

Siehe [CONTRIBUTING.md](../../CONTRIBUTING.md) für Entwicklungseinrichtung, Code-Patterns und PR-Richtlinien.

---

## Danksagungen

- [**end-4**](https://github.com/end-4/dots-hyprland) — Original illogical-impulse für Hyprland
- [**Quickshell**](https://quickshell.outfoxxed.me/) — das Framework hinter dieser Shell
- [**Niri**](https://github.com/YaLTeR/niri) — der scrollende Tiling-Wayland-Compositor

---

<p align="center">
  <a href="https://github.com/snowarch/inir/graphs/contributors">Mitwirkende</a> &bull;
  <a href="CHANGELOG.md">Changelog</a> &bull;
  <a href="LICENSE">MIT-Lizenz</a>
</p>
