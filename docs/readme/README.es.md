<p align="center">
  <img src="https://github.com/user-attachments/assets/da6beb4a-ccee-40ba-a372-5eea77b595f8" alt="iNiR" width="800">
</p>

<h1 align="center">iNiR</h1>

<p align="center">
  <b>Un shell de escritorio completo para Niri, hecho con Quickshell</b>
</p>

<p align="center">
  <a href="https://github.com/snowarch/inir/releases"><img src="https://img.shields.io/badge/version-2.18.0-blue?style=flat-square" alt="Version"></a>
  <a href="https://github.com/snowarch/inir/stargazers"><img src="https://img.shields.io/github/stars/snowarch/inir?style=flat-square" alt="Stars"></a>
  <a href="https://discord.gg/pAPTfAhZUJ"><img src="https://img.shields.io/badge/Discord-join-5865F2?style=flat-square&logo=discord&logoColor=white" alt="Discord"></a>
</p>

<p align="center">
  <a href="../INSTALL.md">Instalar</a> &bull;
  <a href="../KEYBINDS.md">Atajos</a> &bull;
  <a href="../IPC.md">Referencia IPC</a> &bull;
  <a href="https://discord.gg/pAPTfAhZUJ">Discord</a> &bull;
  <a href="../../CONTRIBUTING.md">Contribuir</a>
</p>

<p align="center">
  <sub>
    <a href="../../README.md">English</a> · <a href="README.es.md">Español</a> · <a href="README.ru.md">Русский</a> · <a href="README.zh.md">中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.pt.md">Português</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a> · <a href="README.ko.md">한국어</a> · <a href="README.hi.md">हिन्दी</a> · <a href="README.ar.md">العربية</a> · <a href="README.it.md">Italiano</a>
  </sub>
</p>

---

> **Sobre la traducción:** Traducción comunitaria. Si algo no se entiende, consultá la [versión en inglés](../../README.md).

---

<details>
<summary><b>🤔 ¿Nuevo acá? Clickeá si no tenés idea de qué es esto</b></summary>

### ¿Qué es esto?

iNiR es todo tu escritorio. La barra de arriba, el dock, notificaciones, configuración, wallpapers, todo. No es un theme, no son dotfiles que pegás. Es un shell completo que corre en Linux.

### ¿Qué necesito para usarlo?

Un compositor. Es lo que maneja tus ventanas y pone los pixeles en pantalla. iNiR está hecho para [Niri](https://github.com/YaLTeR/niri) (un compositor Wayland de tiling). Hay código viejo de Hyprland de cuando esto era un fork de los dots de end-4, pero Niri es lo que realmente uso y testeo.

El shell corre sobre [Quickshell](https://quickshell.outfoxxed.me/), un framework para hacer shells en QML (el lenguaje de UI de Qt). No necesitás saber nada de eso para usarlo igual, todo se configura por la GUI o un JSON.

### Cómo encaja todo

```
tus apps
   ↓
iNiR (shell: barra, sidebars, dock, notificaciones, settings...)
   ↓
Quickshell (corre shells QML)
   ↓
Niri (compositor: ventanas, rendering)
   ↓
Wayland → GPU
```

### ¿Es estable?

Es un proyecto personal que se fue de las manos. Lo uso todos los días, mucha gente en el Discord también. Pero a veces se rompen cosas, el código está desprolijo en partes, voy aprendiendo sobre la marcha.

Si algo no anda, `inir doctor` arregla la mayoría. El Discord está activo si eso no ayuda. No esperes software pulido, esto es el rice de una persona que a otros les gustó.

### ¿Por qué existe?

Quería que mi escritorio se vea y funcione de cierta forma y nada lo hacía exactamente así. Empezó como los dots de Hyprland de end-4, terminó siendo un rewrite completo para Niri con muchas más features.

### Palabras que vas a ver

- **Shell**: la capa de UI (barra, paneles, overlays)
- **Compositor**: maneja ventanas, dibuja en pantalla (Niri, Hyprland, Sway...)
- **Wayland**: protocolo de display de Linux (el nuevo, reemplaza X11)
- **QML**: lenguaje declarativo de UI de Qt, en lo que está escrito iNiR
- **Material You**: sistema de colores de Google que hace paletas de imágenes (así funciona el auto-theming)
- **ii / waffle**: los dos estilos de panel. ii = onda Material Design, waffle = onda Windows 11. `Super+Shift+W` cambia entre ellos

</details>

---

## Capturas

<details open>
<summary><b>Material ii</b> — barra flotante, sidebars, estética Material Design</summary>

| | |
|:---:|:---:|
| ![](https://github.com/user-attachments/assets/1fe258bc-8aec-4fd9-8574-d9d7472c3cc8) | ![](https://github.com/user-attachments/assets/3ce2055b-648c-45a1-9d09-705c1b4a03b7) |
| ![](https://github.com/user-attachments/assets/ea2311dc-769e-44dc-a46d-37cf8807d2cc) | ![](https://github.com/user-attachments/assets/da6beb4a-ccee-40ba-a372-5eea77b595f8) |
| ![](https://github.com/user-attachments/assets/ba866063-b26a-47cb-83c8-d77bd033bf8b) | ![](https://github.com/user-attachments/assets/88e76566-061b-4f8c-a9a8-53c157950138) |

</details>

<details>
<summary><b>Waffle</b> — barra de tareas abajo, centro de acciones, onda Windows 11</summary>

| | |
|:---:|:---:|
| ![](https://github.com/user-attachments/assets/5c5996e7-90eb-4789-9921-0d5fe5283fa3) | ![](https://github.com/user-attachments/assets/fadf9562-751e-4138-a3a1-b87b31114d44) |

</details>

---

## Features

**Dos familias de paneles**, intercambiables al vuelo con `Super+Shift+W`:
- **Material ii** — barra flotante, sidebars, dock, 5 estilos visuales (material, cards, aurora, inir, angel)
- **Waffle** — barra de tareas estilo Windows 11, menú inicio, centro de acciones, centro de notificaciones

**Tematización automática** — elegís un wallpaper y todo se adapta:
- Colores del shell vía Material You, propagados a GTK3/4, Qt, terminales, Firefox, Discord, SDDM
- 10 herramientas de terminal auto-tematizadas (foot, kitty, alacritty, starship, fuzzel, btop, lazygit, yazi)
- Presets de temas: Gruvbox, Catppuccin, Rosé Pine, y custom

**Compositor** — hecho para Niri.

<details>
<summary><b>Lista completa de features</b></summary>

### Temas y apariencia

Elegís un wallpaper y todo el sistema sigue — shell, apps GTK/Qt, terminales, Firefox, Discord, pantalla de login SDDM. Todo automático.

- **5 estilos visuales** — Material (sólido), Cards, Aurora (blur de vidrio), iNiR (inspirado en TUI), Angel (neo-brutalismo)
- **Colores dinámicos del wallpaper** vía Material You — se propagan a todo el sistema
- **10 herramientas de terminal auto-tematizadas** — foot, kitty, alacritty, starship, fuzzel, pywalfox, btop, lazygit, yazi
- **Tematización de apps** — GTK3/4, Qt (vía plasma-integration + darkly), Firefox (MaterialFox), Discord/Vesktop (System24)
- **Presets de temas** — Gruvbox, Catppuccin, Rosé Pine, y más — o creá el tuyo
- **Wallpapers de video** — mp4/webm/gif con blur opcional, o primer frame congelado para rendimiento
- **Tema SDDM de login** — colores Material You sincronizados con tu wallpaper
- **Widgets de escritorio** — reloj (varios estilos), clima, controles de media en la capa de wallpaper

### Sidebars y widgets (Material ii)

Sidebar izquierdo (cajón de apps):
- **Chat IA** — Gemini, Mistral, OpenRouter, o modelos locales vía Ollama
- **YT Music** — reproductor completo con búsqueda, cola y controles
- **Browser de Wallhaven** — buscá y aplicá wallpapers directamente
- **Anime tracker** — integración con AniList y vista de schedule
- **Feed de Reddit** — navegá subreddits inline
- **Traductor** — vía Gemini o translate-shell
- **Widgets arrastrables** — crypto, media player, notas rápidas, status rings, calendario semanal

Sidebar derecho:
- **Calendario** con integración de eventos
- **Centro de notificaciones**
- **Quick toggles** — WiFi, Bluetooth, luz nocturna, DND, perfiles de energía, WARP VPN, EasyEffects
- **Mixer de volumen** — control por app
- **Bluetooth y WiFi** — gestión de dispositivos
- **Timer pomodoro**, **lista de tareas**, **calculadora**, **notepad**
- **Monitor del sistema** — CPU, RAM, temperatura

### Herramientas

- **Overview de workspaces** — adaptado al modelo scrolling de Niri, con búsqueda de apps y calculadora
- **Selector de ventanas** — Alt+Tab entre todos los workspaces
- **Gestor de portapapeles** — historial con búsqueda y preview de imágenes
- **Herramientas de región** — capturas, grabación de pantalla, OCR, búsqueda inversa de imágenes
- **Cheatsheet** — visor de atajos sacados de tu config de Niri
- **Controles de media** — reproductor MPRIS completo con varios presets de layout
- **On-screen display** — OSD de volumen, brillo y media
- **Reconocimiento de canciones** — identificación tipo Shazam vía SongRec
- **Búsqueda por voz** — grabá y buscá vía Gemini

### Sistema

- **Configuración GUI** — configurá todo sin tocar archivos
- **GameMode** — desactiva efectos automáticamente con apps en pantalla completa
- **Auto-updates** — `inir update` con rollback, migraciones y preservación de cambios del usuario
- **Pantalla de bloqueo** y **pantalla de sesión** (logout/reboot/shutdown/suspend)
- **Agente polkit**, **teclado en pantalla**, **gestor de autostart**
- **9 idiomas** — detección automática, con generación de traducciones asistida por IA
- **Luz nocturna** — programada o manual
- **Clima** — Open-Meteo, soporta GPS, coordenadas manuales o nombre de ciudad
- **Gestión de batería** — umbrales configurables, auto-suspend en crítico
- **Checker de updates del shell** — avisa cuando hay versiones nuevas

</details>

---

## Inicio rápido

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup install       # interactivo — pregunta antes de cada paso
./setup install -y    # automático — instala todo sin preguntas
```

El instalador maneja dependencias, config del sistema, tematización — todo. Después de instalar, ejecutá `inir run` para iniciar el shell, o cerrá sesión y volvé a entrar.

```bash
inir run                        # iniciar el shell
inir settings                   # abrir configuración GUI
inir logs                       # ver logs del runtime
inir doctor                     # auto-diagnosticar y arreglar
inir update                     # pull + migrar + reiniciar
```

**Distros soportadas:** Arch (instalador automatizado). Otras distros pueden instalar manualmente — ver [PACKAGES.md](../PACKAGES.md).

| Método | Comando |
|--------|---------|
| Instalación de sistema | `sudo make install && inir run` |
| Menú TUI | `./setup` |
| Rollback | `./setup rollback` |

---

## Atajos

| Tecla | Acción |
|-----|--------|
| `Super+Space` | Overview — buscar apps, navegar workspaces |
| `Alt+Tab` | Selector de ventanas |
| `Super+V` | Historial del portapapeles |
| `Super+Shift+S` | Captura de región |
| `Super+Shift+X` | OCR de región |
| `Super+,` | Configuración |
| `Super+Shift+W` | Cambiar familia de paneles |

Lista completa: [KEYBINDS.md](../KEYBINDS.md)

---

## Wallpapers

15 wallpapers vienen incluidos. Para más, mirá [iNiR-Walls](https://github.com/snowarch/iNiR-Walls) — una colección curada que funciona bien con el pipeline de Material You.

---

## Documentación

| | |
|---|---|
| [INSTALL.md](../INSTALL.md) | Guía de instalación |
| [SETUP.md](../SETUP.md) | Comandos del setup — updates, migraciones, rollback |
| [KEYBINDS.md](../KEYBINDS.md) | Todos los atajos de teclado |
| [IPC.md](../IPC.md) | Targets IPC para scripting y atajos custom |
| [PACKAGES.md](../PACKAGES.md) | Cada paquete y por qué está |
| [LIMITATIONS.md](../LIMITATIONS.md) | Limitaciones conocidas y workarounds |
| [ARCHITECTURE.md](../ARCHITECTURE.md) | Arquitectura técnica del proyecto |

---

## Solución de problemas

```bash
inir logs                       # revisá los logs — la respuesta suele estar ahí
inir restart                    # reiniciar el shell
inir repair                     # doctor + restart + chequeo de logs filtrado
./setup doctor                  # auto-diagnosticar y arreglar problemas comunes
./setup rollback                # deshacer la última actualización
```

Revisá [LIMITATIONS.md](../LIMITATIONS.md) antes de abrir un issue.

---

## Contribuir

Ver [CONTRIBUTING.md](../../CONTRIBUTING.md) para setup de desarrollo, patrones de código y lineamientos de PRs.

---

## Créditos

- [**end-4**](https://github.com/end-4/dots-hyprland) — illogical-impulse original para Hyprland
- [**Quickshell**](https://quickshell.outfoxxed.me/) — el framework que hace posible este shell
- [**Niri**](https://github.com/YaLTeR/niri) — el compositor Wayland de tiling scrollable

---

<p align="center">
  <a href="https://github.com/snowarch/inir/graphs/contributors">Contribuidores</a> &bull;
  <a href="CHANGELOG.md">Changelog</a> &bull;
  <a href="LICENSE">Licencia MIT</a>
</p>
