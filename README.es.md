<p align="center">
  <img src="https://github.com/user-attachments/assets/da6beb4a-ccee-40ba-a372-5eea77b595f8" alt="iNiR" width="800">
</p>

<p align="center">
  🌐 <b>Idiomas:</b> <a href="README.md">English</a> | <a href="README.es.md">Español</a> | <a href="README.ru.md">Русский</a>
</p>

<h1 align="center">iNiR</h1>

<p align="center">
  <b>Un shell de escritorio completo hecho con Quickshell para el compositor Niri</b><br>
  <sub>Fork original de illogical-impulse de end-4 — evolucionó a algo propio</sub>
</p>

<p align="center">
  <a href="docs/INSTALL.md">Instalar</a> •
  <a href="docs/KEYBINDS.md">Atajos</a> •
  <a href="docs/IPC.md">Referencia IPC</a> •
  <a href="https://discord.gg/pAPTfAhZUJ">Discord</a>
</p>

---

> ⚠️ **Sobre la traducción:** Traducción comunitaria. Si algo no se entiende, consultá la [versión en inglés](README.md).

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

### Temas y apariencia

Elegís un wallpaper y todo se adapta — el shell, apps GTK/Qt, terminales, Firefox, Discord, hasta la pantalla de login SDDM. Automático.

- **5 estilos visuales** — Material (sólido), Cards, Aurora (blur de vidrio), iNiR (inspirado en TUI), Angel (neo-brutalismo)
- **Colores dinámicos del wallpaper** vía matugen — se propagan a todo el sistema
- **10 herramientas de terminal auto-tematizadas** — foot, kitty, alacritty, starship, fuzzel, pywalfox, btop, lazygit, yazi
- **Tematización de apps** — GTK3/4, Qt (vía plasma-integration + darkly), Firefox (MaterialFox), Discord/Vesktop (System24)
- **Presets de temas** — Gruvbox, Catppuccin, Rosé Pine, y más — o creá el tuyo
- **Wallpapers de video** — mp4/webm/gif con blur opcional, o primer frame congelado para rendimiento
- **Tema SDDM de login** — colores Material You sincronizados con tu wallpaper
- **Widgets de escritorio** — reloj (varios estilos), clima, controles de media en la capa de wallpaper

### Dos familias de paneles

Cambiá entre ellas al vuelo con `Super+Shift+W`:

- **Material ii** — barra flotante (arriba/abajo, 4 estilos de esquinas), sidebars, dock (las 4 posiciones), panel de control, variante de barra vertical
- **Waffle** — barra de tareas estilo Windows 11, menú inicio, centro de acciones, centro de notificaciones, panel de widgets, vista de tareas

### Sidebars y widgets (Material ii)

El sidebar izquierdo funciona como cajón de apps:

- **Chat IA** — Gemini, Mistral, OpenRouter, o modelos locales vía Ollama
- **YT Music** — reproductor completo con búsqueda, cola y controles
- **Browser de Wallhaven** — buscá y aplicá wallpapers directamente
- **Anime tracker** — integración con AniList y vista de schedule
- **Feed de Reddit** — navegá subreddits inline
- **Traductor** — con Gemini o translate-shell
- **Widgets arrastrables** — crypto, media player, notas rápidas, status rings, calendario semanal

El sidebar derecho cubre lo esencial del día a día:

- **Calendario** con integración de eventos
- **Centro de notificaciones**
- **Quick toggles** — WiFi, Bluetooth, luz nocturna, DND, perfiles de energía, WARP VPN, EasyEffects (layout Android o clásico)
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
- **Auto-updates** — `./setup update` con rollback, migraciones y preservación de cambios del usuario
- **Pantalla de bloqueo** y **pantalla de sesión** (logout/reboot/shutdown/suspend)
- **Agente polkit**, **teclado en pantalla**, **gestor de autostart**
- **15+ idiomas** — detección automática, con generación de traducciones asistida por IA
- **Luz nocturna** — programada o manual
- **Clima** — Open-Meteo, soporta GPS, coordenadas manuales o nombre de ciudad
- **Gestión de batería** — umbrales configurables, auto-suspend en crítico
- **Checker de updates del shell** — avisa cuando hay versiones nuevas

---

## Inicio rápido

**Arch Linux:**

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup install       # Interactivo — pregunta antes de cada paso
./setup install -y    # Automático — instala todo sin preguntas
```

El instalador maneja dependencias, configs, tematización — todo.

**Otras distros:** El instalador soporta Arch completamente. Guía de instalación manual en [docs/INSTALL.md](docs/INSTALL.md).

**Actualizar:**

```bash
inir update           # Wrapper cómodo del mismo flujo de update de setup
```

`inir update` y `./setup update` usan el mismo motor de actualización. Usá `inir update` como comando diario del launcher, y `./setup` cuando quieras el entrypoint de mantenimiento subyacente o el menú TUI interactivo.

Tus configs no se tocan. Las features nuevas vienen como migraciones opcionales. Incluye rollback por si algo se rompe (`./setup rollback`).

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

Lista completa y guía de personalización: [docs/KEYBINDS.md](docs/KEYBINDS.md)

---

## Documentación

| | |
|---|---|
| [INSTALL.md](docs/INSTALL.md) | Guía de instalación |
| [SETUP.md](docs/SETUP.md) | Comandos del setup — updates, migraciones, rollback, desinstalar |
| [KEYBINDS.md](docs/KEYBINDS.md) | Todos los atajos de teclado |
| [IPC.md](docs/IPC.md) | Targets IPC para scripting y atajos custom |
| [PACKAGES.md](docs/PACKAGES.md) | Cada paquete y por qué está |
| [LIMITATIONS.md](docs/LIMITATIONS.md) | Limitaciones conocidas y workarounds |
| [OPTIMIZATION.md](docs/OPTIMIZATION.md) | Guía de rendimiento QML para contribuidores |

---

## Solución de problemas

```bash
inir logs                       # Revisá los logs — la respuesta suele estar ahí
inir restart                    # Reiniciar el shell
./setup doctor                  # Auto-diagnosticar y arreglar problemas comunes
./setup rollback                # Deshacer la última actualización
```

Revisá [LIMITATIONS.md](docs/LIMITATIONS.md) antes de abrir un issue — capaz ya está documentado.

---

## Créditos

- [**end-4**](https://github.com/end-4/dots-hyprland) — illogical-impulse original para Hyprland, donde empezó todo esto
- [**Quickshell**](https://quickshell.outfoxxed.me/) — el framework que hace posible este shell
- [**Niri**](https://github.com/YaLTeR/niri) — el compositor Wayland de tiling scrollable

---

<p align="center">
  <sub>Este es un proyecto personal. Funciona en mi máquina. Tu experiencia puede variar.</sub>
</p>
