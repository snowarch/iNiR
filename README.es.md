<p align="center">
  <img src="https://github.com/user-attachments/assets/da6beb4a-ccee-40ba-a372-5eea77b595f8" alt="iNiR" width="800">
</p>

<p align="center">
  🌐 <b>Idiomas:</b> <a href="README.md">English</a> | <a href="README.es.md">Español</a> | <a href="README.ru.md">Русский</a>
</p>

<h1 align="center">iNiR</h1>

<p align="center">
  <b>Una configuración completa de Quickshell para el compositor Niri</b><br>
  <sub>Fork de illogical-impulse de end-4, reimaginado para Niri</sub>
</p>

<p align="center">
  <a href="docs/INSTALL.md">Instalación</a> •
  <a href="docs/KEYBINDS.md">Atajos de teclado</a> •
  <a href="docs/IPC.md">Referencia IPC</a> •
  <a href="https://discord.gg/pAPTfAhZUJ">Discord</a>
</p>

---

> ⚠️ **Nota sobre la traducción:** Esta es una traducción comunitaria. Si algo no está claro, consulta la [versión en inglés](README.md). Este proyecto asume que trabajas cómodamente con la terminal y estás dispuesto a aprender.

---

## Características

- **Dos familias de paneles** — Estilo Material Design o Windows 11, intercambiables al vuelo
- **Tres estilos visuales** — Material (sólido), Aurora (desenfoque de vidrio), Inir (inspirado en TUI)
- **Vista general de espacios de trabajo** — Adaptada al modelo de espacios de trabajo deslizantes de Niri
- **Selector de ventanas** — Alt+Tab que funciona en todos los espacios de trabajo
- **Herramientas de región** — Capturas de pantalla, grabación de pantalla, OCR, búsqueda inversa de imágenes
- **Gestor de portapapeles** — Historial con búsqueda y vista previa de imágenes
- **Tematización dinámica** — Matugen extrae colores de tu fondo de pantalla
- **Presets de temas** — Gruvbox, Catppuccin y más, o crea el tuyo propio
- **GameMode** — Desactiva automáticamente los efectos cuando se detectan aplicaciones en pantalla completa
- **Configuración GUI** — Configura todo sin tocar JSON

---

## Capturas de pantalla

<details open>
<summary><b>Material ii</b> — Barra flotante, barras laterales, estética Material Design</summary>

| | |
|:---:|:---:|
| ![](https://github.com/user-attachments/assets/1fe258bc-8aec-4fd9-8574-d9d7472c3cc8) | ![](https://github.com/user-attachments/assets/3ce2055b-648c-45a1-9d09-705c1b4a03b7) |
| ![](https://github.com/user-attachments/assets/ea2311dc-769e-44dc-a46d-37cf8807d2cc) | ![](https://github.com/user-attachments/assets/da6beb4a-ccee-40ba-a372-5eea77b595f8) |
| ![](https://github.com/user-attachments/assets/ba866063-b26a-47cb-83c8-d77bd033bf8b) | ![](https://github.com/user-attachments/assets/88e76566-061b-4f8c-a9a8-53c157950138) |

</details>

<details>
<summary><b>Waffle</b> — Barra de tareas inferior, centro de acciones, vibras Windows 11</summary>

| | |
|:---:|:---:|
| ![](https://github.com/user-attachments/assets/5c5996e7-90eb-4789-9921-0d5fe5283fa3) | ![](https://github.com/user-attachments/assets/fadf9562-751e-4138-a3a1-b87b31114d44) |

</details>

---

## Inicio rápido

**Arch Linux:**

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup install
```

**Otras distros:** Consulta [docs/INSTALL.md](docs/INSTALL.md) para instalación manual.

**Actualización:**

```bash
./setup update
```

Tus configuraciones permanecen intactas. Las nuevas características se ofrecen como migraciones opcionales.

---

## Atajos de teclado predeterminados

| Tecla | Acción |
|-----|--------|
| `Super+Space` | Vista general (búsqueda + navegación de espacios de trabajo) |
| `Alt+Tab` | Selector de ventanas |
| `Super+V` | Historial del portapapeles |
| `Super+Shift+S` | Captura de pantalla de región |
| `Super+Shift+X` | OCR de región |
| `Super+,` | Configuración |
| `Super+Shift+W` | Cambiar entre familias de paneles |

Lista completa: [docs/KEYBINDS.md](docs/KEYBINDS.md)

---

## Documentación

| Documento | Descripción |
|----------|-------------|
| [INSTALL.md](docs/INSTALL.md) | Guía de instalación |
| [SETUP.md](docs/SETUP.md) | Script de configuración, actualizaciones, rollback |
| [KEYBINDS.md](docs/KEYBINDS.md) | Atajos de teclado |
| [IPC.md](docs/IPC.md) | Objetivos IPC para atajos personalizados |
| [PACKAGES.md](docs/PACKAGES.md) | Paquetes requeridos |
| [LIMITATIONS.md](docs/LIMITATIONS.md) | Limitaciones conocidas |

---

## Solución de problemas

```bash
qs log -c ii                    # Revisar logs
qs kill -c ii && qs -c ii       # Reiniciar shell
./setup doctor                  # Auto-reparar problemas comunes
./setup rollback                # Deshacer última actualización
```

---

## Créditos

- [**end-4**](https://github.com/end-4/dots-hyprland) — illogical-impulse original para Hyprland
- [**Quickshell**](https://quickshell.outfoxxed.me/) — El framework que impulsa este shell
- [**Niri**](https://github.com/YaLTeR/niri) — El compositor Wayland de mosaico deslizante

---

<p align="center">
  <sub>Este es un proyecto personal. Funciona en mi máquina. Tu experiencia puede variar.</sub>
</p>
