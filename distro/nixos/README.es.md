<div align="center">
  <h1>iNiR NixOS</h1>
  <p><b>Integración unificada y modular de iNiR + Niri Compositor para NixOS</b></p>
  <p><i>Shell de escritorio con Material You, animaciones fluidas y soporte completo para Nix Flakes</i></p>

  <p>
    <a href="https://github.com/LATAR-web/inir-nixos/actions"><img src="https://github.com/LATAR-web/inir-nixos/actions/workflows/ci.yml/badge.svg" alt="CI Status"></a>
    <a href="https://github.com/LATAR-web/inir-nixos/releases"><img src="https://img.shields.io/github/v/release/LATAR-web/inir-nixos?color=7aa2f7&label=versión" alt="Última versión"></a>
    <a href="https://nixos.org"><img src="https://img.shields.io/badge/NixOS-unstable-5277C3.svg?logo=nixos&logoColor=white" alt="NixOS"></a>
  </p>

  [English Documentation](README.md) · [Mascota Kira](modules/mascot.nix) · [SDDM Theme](https://github.com/LATAR-web/inir-sddm-nixos)
</div>

---

## Características

- **100% Declarativo:** Configuración completamente declarativa y limpia mediante módulos de NixOS y Home Manager.
- **Paleta Material You Dinámica:** Sistema de color dinámico Material You integrado nativamente con el shell de escritorio.
- **Animaciones Snappy:** Configuración de animaciones físicas ágiles, rápidas y fluidas idénticas al iNiR original.
- **Sincronización Rápida con Upstream:** Integrado directamente con el repositorio de iNiR mediante Flakes y sincronizado automáticamente cada 2 horas vía GitHub Actions.
- **Parches Idempotentes:** Adaptación automática del runtime de Arch a NixOS mediante expresiones regulares sin parches frágiles.


---

## Instalación y Uso

### Opción A: Usando Flakes (Recomendado)

En tu `/etc/nixos/flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    inir = {
      url = "github:snowarch/inir";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, inir, ... }: {
    nixosConfigurations.<tu_hostname> = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hardware-configuration.nix
        ./configuration.nix
        inir.nixosModules.default
      ];
    };
  };
}
```

En tu `/etc/nixos/configuration.nix`:

```nix
{ pkgs, ... }:
{
  # Habilitar iNiR y sus servicios integrados
  programs.inir = {
    enable = true;
    colorSync.enable = true;         # Sincronización de color Material You en vivo
    screenRecording.enable = true;   # Grabador de pantalla record-screen con audio
    hardware.brightnessControl = true; # Control de brillo DDC/CI para monitores externos
    niri = {
      enable = true;
      autoDeployConfig = true;       # Despliega automáticamente ~/.config/niri/config.d
    };
    audio.enable = true;
    desktop = {
      enable = true;
      displayManager = "gdm";        # "gdm", "greetd" o "sddm"
    };
  };

  # Elige e instala tu emulador de terminal preferido:
  environment.systemPackages = with pkgs; [
    kitty  # o ghostty, foot, wezterm, etc.
  ];

  nixpkgs.config.allowUnfree = true;
  users.users.<tu_usuario>.extraGroups = [ "wheel" "networkmanager" "video" "i2c" ];
}
```

---

### Paso Final: Reconstruir y desplegar dotfiles

1. **Reconstruye el sistema**:
   ```bash
   sudo nixos-rebuild switch --flake /etc/nixos#<tu_hostname>
   ```

2. **Inicializa los enlaces de usuario**:
   ```bash
   systemd-tmpfiles --user --create
   ```

3. **Inicia sesión**:
   Selecciona la sesión **Niri** en tu pantalla de login. Ejecuta `verify-setup` para comprobar que todos los servicios estén en verde.

---

## Atajos de Teclado

> [!NOTE]
> `Mod` corresponde a la tecla **Super** en hardware real, o **Alt** si ejecutas Niri dentro de otra sesión.

| Atajo | Acción |
|---|---|
| <kbd>Mod</kbd> + <kbd>Enter</kbd> / <kbd>T</kbd> | Terminal (`inir terminal` detecta la que tengas instalada) |
| <kbd>Mod</kbd> + <kbd>Espacio</kbd> / <kbd>Tab</kbd> | Vista general de ventanas (Overview) |
| <kbd>Mod</kbd> + <kbd>G</kbd> | Superposición de escritorio (crosshair) |
| <kbd>Mod</kbd> + <kbd>V</kbd> | Historial del portapapeles |
| <kbd>Mod</kbd> + <kbd>,</kbd> | Ajustes gráficos de iNiR |
| <kbd>Mod</kbd> + <kbd>/</kbd> | Cheatsheet de atajos |
| <kbd>Mod</kbd> + <kbd>Shift</kbd> + <kbd>S</kbd> | Menú de recorte de región |
| <kbd>Mod</kbd> + <kbd>Shift</kbd> + <kbd>X</kbd> | OCR de región (copiar texto de imagen) |
| <kbd>Mod</kbd> + <kbd>Shift</kbd> + <kbd>A</kbd> | Búsqueda visual de región (Google Lens) |
| <kbd>Mod</kbd> + <kbd>Alt</kbd> + <kbd>R</kbd> / <kbd>S</kbd> | Grabar región / Detener grabación |
| <kbd>Mod</kbd> + <kbd>Alt</kbd> + <kbd>L</kbd> | Alternar modo claro / oscuro (`inir colorMode set toggle`) |
| <kbd>Ctrl</kbd> + <kbd>Alt</kbd> + <kbd>T</kbd> | Selector de fondo de pantalla (Material You) |
| <kbd>Mod</kbd> + <kbd>Shift</kbd> + <kbd>W</kbd> | Cambiar familia de panel (animado) |
| <kbd>Super</kbd> + <kbd>E</kbd> | Gestor de archivos (Nautilus) |
| <kbd>Mod</kbd> + <kbd>B</kbd> / <kbd>Super</kbd> + <kbd>W</kbd> | Navegador web |
| <kbd>Mod</kbd> + <kbd>Q</kbd> / <kbd>Shift</kbd> + <kbd>Q</kbd> | Cerrar ventana / Diálogo de sesión |
| <kbd>Mod</kbd> + <kbd>Shift</kbd> + <kbd>E</kbd> | Salir de la sesión |
| <kbd>Mod</kbd> + <kbd>1</kbd>–<kbd>9</kbd> | Ir al espacio de trabajo 1–9 |

---

## Comandos de Consola (CLI) de iNiR

iNiR incluye potentes comandos para interactuar con el entorno y sus servicios:

### Color y Temas
```bash
# Cambiar tema claro/oscuro de forma instantánea
inir colorMode set dark       # Modo oscuro
inir colorMode set light      # Modo claro
inir colorMode set toggle     # Alternar entre claro y oscuro

# Consultar el estado y esquema de colores activo en JSON
inir colorMode get

# Selector de color interactivo en pantalla
inir colorpicker

# Ver objetivos de tematización externa disponibles
inir theme list-targets

# Aplicar temas a aplicaciones externas manualmente
inir theme apply <target>

# Forzar sincronización de paleta con Niri y terminales
niri-sync-colors              # Ejecución única
niri-sync-colors --watch      # Demonio con recarga en vivo
```

### Control del Shell y Diagnóstico
```bash
inir run                      # Iniciar el shell
inir restart                  # Reiniciar el shell de forma limpia
inir status                   # Ver estado de los servicios y componentes
inir doctor                   # Verificación completa de dependencias y salud
inir doctor --perf            # Análisis de rendimiento gráfico y multimedia
inir logs                     # Ver logs en vivo (-n 50, --full, --issues)
inir settings                 # Abrir ventana de configuración
inir terminal                 # Abrir terminal predeterminada
inir browser                  # Abrir navegador predeterminado
```

### Mascota Kira
```bash
inir mascot poke              # Tocar a Kira (reacción interactiva)
inir mascot romp              # Activar modo travieso / caos
inir mascot chase             # Iniciar minijuego de persecución
inir mascot hideSeek          # Jugar al escondite
inir mascot hide              # Ocultar mascota temporalmente
```

### Herramientas de Sistema y Sincronización
```bash
inir-sync                     # Comprobar estado de sincronización con iNiR upstream y runtime
inir-sync --update            # Traer últimos commits de iNiR y verificar integridad del flake
inir-sync --colors            # Sincronización inmediata de paleta Material You y terminales
inir-sync --seed-niri         # Desplegar ficheros de configuración modular (~/.config/niri/config.d)
inir-sync --doctor            # Diagnóstico del entorno y dependencias del sistema
record-screen                 # Iniciar grabación interactiva de pantalla con audio
verify-setup                  # Script de diagnóstico y verificación completa
```

---

## Sincronización de Color y Terminales

El servicio `niri-sync-colors` vigila la generación de paletas Material You y actualiza automáticamente:
1. **Borde de Niri:** `focus-ring.active-color` y `inactive-color` en Niri se actualizan al instante sin reiniciar ventanas.
2. **Terminales Compatibles:** Genera e inyecta la paleta en **Kitty**, **Foot**, **Ghostty**, **WezTerm** y **Alacritty** si están instalados.
3. **Terminales Activas:** Emite secuencias de escape OSC estándar a `/dev/pts/*` para que las ventanas de terminal ya abiertas cambien de color en tiempo real.
4. **GTK / GNOME:** Aplica el `accent-color` más cercano y el `color-scheme` preferido en Libadwaita / GTK.

---

## Arquitectura de Sincronización del Código

### 1. Sincronización con Upstream iNiR
- **Automática continua:** Un flujo de trabajo en GitHub Actions se ejecuta cada 2 horas (y mediante disparadores webhook/dispatch) comprobando nuevos commits en el repositorio upstream de [snowarch/iNiR](https://github.com/snowarch/iNiR). Cuando hay cambios, verifica la evaluación (`nix flake check --no-build`) y actualiza el `flake.lock`.
- **Manual desde CLI:**
  ```bash
  # Ver el estado actual respecto al repositorio remoto
  inir-sync -s

  # Actualizar flake.lock a la última versión
  inir-sync -u
  ```

### 2. Sincronización en tu Sistema NixOS
```bash
# Actualizar el input del flake en tu sistema
nix flake lock --update-input inir-nixos /etc/nixos

# Y reconstruir:
sudo nixos-rebuild switch --flake /etc/nixos#<tu_hostname>
```

---

## Estructura del Repositorio

| Archivo / Carpeta | Propósito |
|---|---|
| `modules/inir.nix` | Módulo principal de NixOS con integración Niri, QuickShell y servicios |
| `modules/inir-deps.nix` | Paquetes y dependencias del sistema y librerías Qt6/KDE |
| `modules/runtime.nix` | Variables de entorno de runtime (Qt6, nix-ld, Intel PSR) con soporte modular |
| `modules/fonts.nix` | Tipografías e iconografía oficial (Material Symbols, JetBrains Mono) |
| `modules/desktop.nix` | Gestor de inicio de sesión gráfico (GDM, greetd, SDDM) |
| `modules/audio.nix` | Pila de audio PipeWire y WirePlumber para widgets de control de volumen |
| `modules/home-manager.nix` | Módulo unificado para usuarios de Home Manager |
| `modules/mascot.nix` | Integración y paquete de recursos de la mascota Kira |
| `niri/config.d/` | Configuración modular de Niri (atajos, reglas, animaciones snappy) |
| `scripts/inir-sync` | CLI de sincronización con upstream, paleta de colores y diagnóstico |
| `scripts/niri-sync-colors` | Demonio de sincronización de colores multi-terminal y Niri |
| `scripts/record-screen` | Grabador de pantalla con audio integrado |
| `scripts/verify-setup.sh` | Verificador de diagnóstico del sistema |


---

<div align="center">
  <i>Hecho para NixOS y Niri</i>
</div>
