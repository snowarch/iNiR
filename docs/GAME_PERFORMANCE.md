# Game Performance Overlay

The `gamePerformance` widget is enabled by default in the `Super+G` overlay. It
shows the focused game's identity, system CPU/GPU/RAM telemetry, and
FPS/frametime history when MangoHud logging is active.

## Enable FPS and frametime

FPS is produced by the game renderer, not by Niri or the shell. Install MangoHud
and launch the game through it:

```bash
sudo pacman -S mangohud
```

For 32-bit games, install `lib32-mangohud` too when the multilib repository is
enabled:

```bash
sudo pacman -S lib32-mangohud
```

For native Steam games, add this to the game's launch options:

```text
mangohud %command%
```

For Proton games such as DiRT Rally 2.0, use the MangoHud Vulkan layer instead:

```text
MANGOHUD=1 %command%
```

Keep any existing game arguments after `%command%`, then fully stop and relaunch
the game. Installing MangoHud alone does not inject it into a Steam game.

Then enable a transparent, automatically-started log in
`~/.config/MangoHud/MangoHud.conf`:

```text
no_display=0
fps=1
frametime=1
frame_timing=1
frame_timing_detailed=1
cpu_stats=1
cpu_temp=1
cpu_mhz=1
core_load=1
core_bars=1
gpu_stats=1
gpu_temp=1
gpu_core_clock=1
gpu_mem_clock=1
vram=1
gpu_power=1
gpu_voltage=1
ram=1
swap=1
procmem=1
engine_version=1
engine_short_names=1
gpu_name=1
vulkan_driver=1
wine=1
exec_name=1
arch=1
display_server=1
resolution=1
fex_stats=1
log_versioning=1
alpha=0
background_alpha=0
output_folder=~/.local/state/quickshell/user/mangohud
autostart_log=1
log_interval=500
```

Create the output directory first if it does not exist:

```bash
mkdir -p ~/.local/state/quickshell/user/mangohud
```

Do not set `no_display=1` with `autostart_log`: MangoHud skips the frame path
that starts automatic logging when the HUD is disabled. The transparent config
above keeps that path active without drawing a second HUD. The overlay reads the
live CSV sample while the game is running and stops accepting it when the sample
becomes stale. If MangoHud is not installed or logging is not active, the widget
displays a clear status instead of inventing an FPS value.

The widget starts in minimal view. It is a four-line readout for GPU, CPU,
average thread load, and FPS, with colored labels and no graph or card chrome.
Its surface follows the active theme palette, while the reference green, blue,
purple, and red accents are blended 60/40 with the theme's semantic colors.
Click its view button to cycle through the persistent minimal, simple, compact,
and detailed views using the titlebar view button. Simple view restores the
graph-and-summary presentation;
compact view is intended to match the Steam performance overlay and shows only
numeric FPS, frametime, CPU, GPU, VRAM, average, minimum, and maximum values
without graphs. Detailed view adds FPS and frametime graphs, frame-pacing
statistics, CPU core bars and frequency, GPU clocks, power, voltage, RAM, swap,
disk usage, resolution, graphics API, Wine/Proton, FEX, driver, and MangoHud
metadata.

The Game Performance surface inherits `overlay.backgroundOpacity` by default.
Set `overlay.gamePerformance.backgroundOpacity` in the settings UI to override
it for this widget only. Values range from `0` (transparent) to `1` (opaque);
the setting is available under Settings -> Panels -> Floating tools -> Background
& dim in both panel families. The `Transparent Game Performance background`
toggle is a shortcut for a fully transparent panel and takes precedence over
the numeric opacity value.

MangoHud's CSV format varies by driver and version. The overlay displays `--`
when a requested field is not exported. API, Wine/Proton, FEX, and resolution
are supplemented from the target process and compositor; frame-pacing values
are calculated from the collected frametime samples. On NVIDIA systems where
`voltage.gpu` is unavailable, voltage remains `--` rather than using a guessed
value.

## Other distributions

- Debian/Ubuntu: `sudo apt install mangohud`
- Fedora: `sudo dnf install mangohud`
- Flatpak Steam: install `org.freedesktop.Platform.VulkanLayer.MangoHud` and
  enable it with `flatpak override --user --env=MANGOHUD=1 com.valvesoftware.Steam`

See the [MangoHud documentation](https://github.com/flightlessmango/MangoHud)
for renderer-specific setup and configuration options.
