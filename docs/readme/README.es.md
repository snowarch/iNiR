<p align="center">
  <img src="../images/iris-2.32-principal.webp" alt="iNiR iRiS desktop" width="900">
</p>

<h1 align="center">iNiR</h1>

<p align="center">
  <b>Un shell de escritorio completo para Niri, hecho con Quickshell</b>
</p>

<p align="center">
  <a href="https://github.com/snowarch/inir/releases"><img src="https://img.shields.io/badge/version-2.32.0-blue?style=flat-square" alt="Version"></a>
  <a href="https://github.com/snowarch/inir/stargazers"><img src="https://img.shields.io/github/stars/snowarch/inir?style=flat-square" alt="Stars"></a>
  <a href="https://discord.gg/pAPTfAhZUJ"><img src="https://img.shields.io/badge/Discord-join-5865F2?style=flat-square&logo=discord&logoColor=white" alt="Discord"></a>
  <a href="../../LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-green?style=flat-square" alt="License"></a>
</p>

<p align="center">
  <a href="https://github.com/snowarch/inir/wiki/INSTALL">Instalar</a> &bull;
  <a href="https://github.com/snowarch/inir/wiki/KEYBINDS">Atajos</a> &bull;
  <a href="https://github.com/snowarch/inir/wiki/IPC">Referencia IPC</a> &bull;
  <a href="https://discord.gg/pAPTfAhZUJ">Discord</a> &bull;
  <a href="../../CONTRIBUTING.md">Contribuir</a>
</p>

<p align="center">
  <sub>
    <a href="../../README.md">English</a> · <a href="README.es.md">Español</a> · <a href="README.ru.md">Русский</a> · <a href="README.zh.md">中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.pt.md">Português</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a> · <a href="README.ko.md">한국어</a> · <a href="README.hi.md">हिन्दी</a> · <a href="README.ar.md">العربية</a> · <a href="README.it.md">Italiano</a>
  </sub>
</p>

---

> **Sobre esta traducción:** si algo no queda claro, la [versión en inglés](../../README.md) es la de referencia.

---

<details>
<summary><b>🤔 ¿Eres nuevo? Haz clic si no tienes idea de qué es todo esto</b></summary>

### ¿Qué es esto?

iNiR es todo tu escritorio. La barra de arriba, el dock, las notificaciones, la configuración, los wallpapers, todo. No es un tema ni unos dotfiles que copias. Es un shell completo que corre en Linux.

### ¿Qué necesito para usarlo?

Un compositor. Es lo que maneja tus ventanas y pone los píxeles en pantalla. iNiR está hecho para [Niri](https://github.com/YaLTeR/niri) (un compositor Wayland de tiling). Queda algo de código viejo de Hyprland de cuando esto era un fork de los dots de end-4, pero Niri es lo que de verdad uso y pruebo.

El shell corre sobre [Quickshell](https://quickshell.outfoxxed.me/), un framework para hacer shells en QML (el lenguaje de interfaces de Qt). No necesitas saber nada de eso para usarlo: todo se configura desde la interfaz o un archivo JSON.

### Cómo se conecta todo

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

### ¿Es estable?

Es un proyecto personal que se fue de las manos. Lo uso todos los días, y mucha gente del Discord también. Pero a veces algo se rompe, el código está desordenado en partes y voy aprendiendo sobre la marcha.

Si algo no funciona, `inir doctor` arregla casi todo. Si no alcanza, el Discord está activo. Eso sí, no esperes software pulido: es el rice de una persona que a otros también les gustó.

### ¿Por qué existe?

Quería que mi escritorio se viera y funcionara de cierta forma y nada lo hacía exactamente así. Empezó como los dots de Hyprland de end-4 y terminó siendo una reescritura completa para Niri con muchas más funciones.

### Palabras que vas a ver

- **Shell**: la capa de interfaz (barra, paneles, overlays)
- **Compositor**: maneja las ventanas y dibuja en pantalla (Niri, Hyprland, Sway...)
- **Wayland**: el protocolo de pantalla de Linux (el nuevo, reemplaza a X11)
- **QML**: el lenguaje declarativo de interfaces de Qt, en el que está escrito iNiR
- **Material You**: el sistema de color de Google que saca paletas de una imagen (así funciona el tema automático)
- **ii / waffle / iRiS**: las tres familias de paneles. ii = estilo Material Design, waffle = estilo Windows 11, iRiS = una Island que se convierte en lo que abres. `Super+Shift+W` pasa de una a otra

</details>

---

## Capturas

<details open>
<summary><b>iRiS</b>: Island, Customize, barra de menú, cards y Dock</summary>

<p align="center">
  <img src="../images/iris-2.31-desktop.webp" alt="iRiS desktop layout" width="49%">
  <img src="../images/iris-2.31-card.webp" alt="iRiS card surface" width="49%">
</p>

<p align="center">
  <img src="../images/iris-2.31-dock.webp" alt="iRiS Dock and edge layout" width="99%">
</p>

</details>

<details open>
<summary><b>Material ii</b>: barra flotante, sidebars, estética Material Design</summary>

| | |
|:---:|:---:|
| ![](https://github.com/user-attachments/assets/1fe258bc-8aec-4fd9-8574-d9d7472c3cc8) | ![](https://github.com/user-attachments/assets/3ce2055b-648c-45a1-9d09-705c1b4a03b7) |
| ![](https://github.com/user-attachments/assets/ea2311dc-769e-44dc-a46d-37cf8807d2cc) | ![](https://github.com/user-attachments/assets/da6beb4a-ccee-40ba-a372-5eea77b595f8) |
| ![](https://github.com/user-attachments/assets/ba866063-b26a-47cb-83c8-d77bd033bf8b) | ![](https://github.com/user-attachments/assets/88e76566-061b-4f8c-a9a8-53c157950138) |

</details>

<details>
<summary><b>Waffle</b>: barra de tareas abajo, centro de acciones, estilo Windows 11</summary>

| | |
|:---:|:---:|
| ![](https://github.com/user-attachments/assets/5c5996e7-90eb-4789-9921-0d5fe5283fa3) | ![](https://github.com/user-attachments/assets/fadf9562-751e-4138-a3a1-b87b31114d44) |

</details>

---

> [!WARNING]
> No es para equipos modestos.
> Igual se puede aligerar mucho: apaga efectos, quita paneles, simplifica el diseño. Desde Settings o `config.json`, como prefieras.

## Funciones

**Tres familias de paneles**, intercambiables al vuelo con `Super+Shift+W`:
- **Material ii**: barra flotante, sidebars, dock y 9 estilos globales (Material, Cards, Aurora, iNiR, Angel, Regalia, ZZZ, Cookie Shapes, Editorial)
- **Waffle**: barra de tareas, menú inicio, centro de acciones y centro de notificaciones al estilo Windows 11
- **iRiS**: la familia insignia. Una Island en cualquier borde de la pantalla que crece en páginas, cards y paneles, piezas que puedes mover, un Dock en cualquier borde, glass, Themes que rediseñan todo, claro, tinta y oscuro, y Customize directamente sobre el shell

**Tema automático**. Eliges un wallpaper y todo se adapta:
- Colores del shell con Material You, llevados a GTK3/4, Qt, terminales, Firefox, Discord y SDDM
- 10 destinos de tema: terminales, editores, navegadores, Spicetify, Steam, Cava y más
- Presets de tema: Regalia / Regalia Ivory, Gruvbox, Catppuccin, Rosé Pine y los tuyos

**Hecho para Niri.** El código de Hyprland sobrevive del fork, pero no se prueba.

**Kira**, la mascota, vive en tu escritorio si la quieres ahí. Viene apagada y su paquete de arte se descarga aparte.

<details>
<summary><b>Lista completa de funciones</b></summary>

### iRiS

- **La Island**: una sola forma en un borde de la pantalla que dice "qué está pasando" y se convierte en la página, card o panel que abriste, y después vuelve a plegarse. Arriba, abajo, a la izquierda o a la derecha (`inir iris edge <side>`, o arrástrala). En un lateral se pone de pie, con el reloj apilado y burbujas arriba y abajo
- **Barra de menú**: una franja fina con tus workspaces, la ventana y las piezas, con la Island colgando de ella como un notch (`inir iris layout menubar`)
- **Modo barra de ancho completo** con zonas de inicio, centro y fin para la Island, los workspaces, la ventana enfocada, la hora o cualquier pieza (`inir iris zone start|center|end kinds+joined+with+plus`)
- **Piezas**: clima, sonido, micrófono, bandeja, notificaciones, herramientas, música, VPN, un visualizador, anime (Airing y Continue) y tus propias apps como burbujas que puedes dejar en la Island, en el contorno de la pantalla o sueltas en el escritorio
- **Las piezas se unen a lo que tocan**: deja una en el borde del Dock o de la Island y pasa a ser parte de ese cuerpo en lugar de flotar encima
- **Dock** en cualquier borde (`inir iris dockEdge <side|auto>`); en auto se ubica enfrente de la Island, y si mandas uno al borde del otro, intercambian lugares
- **Glass** que esmerila el wallpaper bajo cada superficie y mantiene el texto legible incluso sobre wallpapers claros o cargados. También existe el Blur del compositor, pero todavía está en construcción, así que no lo juzgues aún
- **Themes**: 20 rediseños curados (Liquid Glass, Frost, Obsidian, Terminal, Neo Tokyo, Twilight, Lume, Sakura, Unit-01 y más) y los tuyos como archivos JSON para compartir (`inir iris theme`)
- **Claro, Tinta y Oscuro**, cada uno con su tono y su esmerilado, y temas de color (Catppuccin, Nord, Rosé Pine, Tokyo Night…) que también usan tus apps (`inir iris palette`)
- **Forma**: cápsula, redonda, squircle o cuadrada para la Island y el Dock
- **Customize sobre el shell**: toca la Island, el Dock o una burbuja y sus opciones salen de ahí mismo, con Themes, Look, Pieces y deshacer bajo la Island (`inir iris edit`). Si lo prefieres, Studio reúne todo en un panel al costado de la pantalla
- **Un Control Center que tú armas**: cada interruptor rápido compartido, el reproductor y cada slider son celdas que arrastras, redimensionas desde una esquina y agregas desde una biblioteca al lado, con seis diseños de partida; con clic derecho un control se despliega (`inir iris control edit`)
- **Pantalla de bloqueo que ensayas**: el bloqueo real se abre editable y sin nada que desbloquear; mueve el reloj, el reproductor y el campo de contraseña, y elige qué se ve detrás, video incluido (`inir iris lock edit`)

### Tema y apariencia

- **9 estilos globales**: Material (sólido), Cards, Aurora (glass con blur), iNiR (inspirado en TUI), Angel (neobrutalismo), Regalia (chasis negro, tinta marfil cálida, herrajes champán sobrios), ZZZ (placas de póster), Cookie Shapes (formas animadas), Editorial (tipografía de papel y tinta)
- **Colores dinámicos del wallpaper** con Material You, en todo el sistema
- **10 herramientas de terminal y TUI con tema automático**: foot, kitty, alacritty, ghostty, wezterm, starship, fuzzel, btop, lazygit, yazi
- **Tema en las apps**: GTK3/4, Qt (con plasma-integration y darkly), Firefox, Discord/Vesktop (System24), Zed, Spicetify, Steam, SDDM
- **Presets de tema**: Gruvbox, Catppuccin, Rosé Pine y más, o crea el tuyo
- **Wallpapers de video**: mp4/webm/gif con blur opcional, o el primer cuadro congelado para ahorrar recursos
- **Widgets de escritorio**: un solo diseño para todos (iRiS, Material, iNstrument o Readout), pilas que giran como las de iOS y tinta que sigue al wallpaper que tienen debajo

### Barra

- **6 estilos de barra**: classic, islands, scenic, frame, cápsulas Material 3 y pill
- **Barra pill**: una isla central que se transforma y al pasar el puntero abre workspaces, lanzador, mezclador, música, calendario y grabador de pantalla
- **Diseño modular** con editor de arrastre en Settings, para poner cualquier módulo donde quieras
- **Barra vertical** para quien quiere recuperar el borde de la pantalla

### Sidebars y widgets (Material ii)

Sidebar izquierda (cajón de apps):
- **Chat con IA**: catálogos de modelos en vivo de Ollama, LM Studio, OpenRouter, Gemini, Groq, Mistral, Cerebras, Anthropic, OpenAI y OpenCode
- **YT Music**: reproductor InnerTube sin cookies, con búsqueda, cola, radio y letras sincronizadas
- **Navegador de Wallhaven**: busca y aplica wallpapers directamente
- **Seguimiento de anime**: integración con AniList y vista de horarios
- **Traductor**: con Gemini o translate-shell
- **Widgets arrastrables**: cripto, reproductor, notas rápidas, anillos de estado, calendario semanal

Sidebar derecha:
- **Calendario** con eventos
- **Centro de notificaciones**
- **Interruptores rápidos**: WiFi, Bluetooth, luz nocturna, No molestar, perfiles de energía, WARP VPN, EasyEffects
- **Mezclador de volumen** por app
- **Bluetooth y WiFi**: gestión de dispositivos
- **Pomodoro**, **tareas**, **calculadora**, **bloc de notas**
- **Monitor del sistema**: CPU, RAM, temperatura

### Herramientas

- **Overview de workspaces**: adaptado al modelo de desplazamiento de Niri, con búsqueda de apps y calculadora
- **Dashboard**: overlay de tres columnas configurable con agenda, notificaciones, tareas, notas, música y clima
- **Franja de workspaces en el borde**: riel al pasar el puntero con vistas previas en vivo y reordenamiento por arrastre
- **Selector de ventanas**: un Alt-Tab animado entre todos los workspaces, opcional ahora que Niri trae el suyo
- **Portapapeles**: historial con búsqueda y vista previa de imágenes
- **Herramientas de región**: capturas, grabación de pantalla, OCR, búsqueda inversa de imágenes
- **Cheatsheet**: los atajos tomados de tu config de Niri
- **Controles de música**: reproductor MPRIS completo con varios diseños
- **OSD**: volumen, brillo y música
- **Reconocimiento de canciones**: al estilo Shazam con SongRec
- **Dictado por voz**: whisper.cpp local si está instalado, o Groq, Gemini u OpenAI conectados

### Sistema

- **Configuración gráfica**: todo se ajusta sin tocar archivos
- **GameMode**: apaga efectos solo con apps en pantalla completa
- **Actualizaciones**: `inir update` con rollback, migraciones y respeto por tus cambios
- **Pantalla de bloqueo** y **pantalla de sesión** (cerrar sesión/reiniciar/apagar/suspender)
- **Agente polkit**, **teclado en pantalla**, **gestor de autoinicio** sobre el propio archivo de arranque de niri
- **Kira**: una chica gato en pixel art que recorre los bordes de la pantalla, reacciona a lo que haces y tiene un modo caos. Opcional, con un paquete de arte aparte de ~32 MiB en `./setup` › Extras
- **18 idiomas** con detección automática, incluidos indonesio (`id_ID`) y kalaallisut (`kl_GL`)
- **Luz nocturna**: programada o manual
- **Clima**: Open-Meteo, con GPS, coordenadas manuales o nombre de ciudad
- **Batería**: umbrales configurables y suspensión automática en nivel crítico
- **Sonidos de eventos** con volumen general y un archivo de audio por evento
- **Aviso de actualizaciones**: te avisa cuando hay una versión nueva

</details>

---

## Inicio rápido

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup install       # interactive, asks before each step
./setup install -y    # automatic, no questions asked
```

El instalador se encarga de las dependencias, la configuración del sistema y el tema. Después de instalar, ejecuta `inir run` para iniciar el shell, o cierra sesión y vuelve a entrar.

```bash
inir run                        # launch the shell
inir settings                   # open settings GUI
inir logs                       # check runtime logs
inir doctor                     # auto-diagnose and fix
inir update                     # pull + migrate + restart
```

Otras formas de instalar, si `./setup install` no es lo que buscas:

```bash
./setup                 # TUI menu, pick what you want
sudo make install       # system-wide instead of your home
./setup rollback        # undo the last update
```

**Distros:** Arch es el objetivo principal. Fedora y Debian/Ubuntu también tienen instalación automática de dependencias que usa primero los repositorios de la distro; las demás siguen la guía general de la [lista de paquetes](https://github.com/snowarch/inir/wiki/PACKAGES). iNiR necesita Qt 6.9 o más reciente: Ubuntu 25.10, Fedora 43 y Debian testing o posteriores.

---

## Atajos

| Tecla | Acción |
|-----|--------|
| <kbd>Super</kbd> + <kbd>Space</kbd> | Overview: buscar apps, moverse entre workspaces |
| <kbd>Super</kbd> + <kbd>V</kbd> | Historial del portapapeles |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>S</kbd> | Captura de una región |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>X</kbd> | OCR de una región |
| <kbd>Super</kbd> + <kbd>,</kbd> | Configuración |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>W</kbd> | Cambiar de familia de paneles |
| <kbd>Super</kbd> + <kbd>/</kbd> | Cheatsheet, por si olvidas el resto |

Lista completa: [Atajos](https://github.com/snowarch/inir/wiki/KEYBINDS)

---

## Wallpapers

Vienen 15 wallpapers incluidos. Para más, mira [iNiR-Walls](https://github.com/snowarch/iNiR-Walls), una colección curada que funciona bien con Material You.

---

## Documentación

Todo lo que es para usuarios está en la [Wiki](https://github.com/snowarch/inir/wiki) (en inglés).

| Página | Qué hay |
|---|---|
| [Install](https://github.com/snowarch/inir/wiki/INSTALL) | Ponerlo en marcha |
| [Setup](https://github.com/snowarch/inir/wiki/SETUP) | Actualizaciones, migraciones, rollback |
| [Keybinds](https://github.com/snowarch/inir/wiki/KEYBINDS) | Todos los atajos |
| [IPC](https://github.com/snowarch/inir/wiki/IPC) | Comandos para atajos y scripts |
| [Packages](https://github.com/snowarch/inir/wiki/PACKAGES) | Cada dependencia y por qué está |
| [Limitations](https://github.com/snowarch/inir/wiki/LIMITATIONS) | Lo que se sabe que falla, y cómo rodearlo |
| [Architecture](../../ARCHITECTURE.md) | Cómo está armado el código |

---

## Solución de problemas

```bash
inir logs                       # check recent runtime logs
inir restart                    # restart the active runtime
inir repair                     # doctor + restart + filtered log check
./setup doctor                  # auto-diagnose and fix common problems
./setup rollback                # undo the last update
```

Revisa [Limitations](https://github.com/snowarch/inir/wiki/LIMITATIONS) antes de abrir un issue. Si prefieres preguntarle a alguien, el Discord es más rápido.

---

## Contribuir

Mira [CONTRIBUTING.md](../../CONTRIBUTING.md) para el entorno de desarrollo, las convenciones de código y cómo mandar un pull request.

---

## Créditos

- [**end-4**](https://github.com/end-4/dots-hyprland): illogical-impulse, los dots de Hyprland de los que salió iNiR
- [**pctrade/end4-pC**](https://github.com/pctrade/end4-pC): un fork que de vez en cuando tiene una idea realmente buena
- [**Gakuseei**](https://github.com/Gakuseei): [Ricelin](https://github.com/Gakuseei/Ricelin), de donde vienen la barra pill y el look washi y flame
- [**Quickshell**](https://quickshell.outfoxxed.me/): el framework sobre el que corre
- [**Niri**](https://github.com/YaLTeR/niri): el compositor para el que está hecho

GPL-3.0, igual que los dots de end-4. Copyright (C) 2025-2026 snowarch.

---

<p align="center">
  <img src="https://raw.githubusercontent.com/snowarch/inir-mascot/main/inir-mascot-hero-banner.png" alt="iNiR mascot leaning on the iNiR logotype" width="720">
</p>

---

<p align="center">
  <a href="https://github.com/snowarch/inir/graphs/contributors">Contribuidores</a> &bull;
  <a href="../../CHANGELOG.md">Changelog</a> &bull;
  <a href="../../LICENSE">Licencia GPL-3.0</a>
</p>
