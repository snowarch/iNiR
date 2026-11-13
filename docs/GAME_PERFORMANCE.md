# Game performance panel

The Game performance panel shows the game you are playing: its FPS and frametime, plus your CPU, GPU and RAM use. It lives in the Super+G overlay.

## Show the panel

1. Press **Super+G** to open the overlay.
2. Press **Game performance** in the strip at the top. More on the bench in [Floating tools](FLOATING_TOOLS.md).

## Get FPS and frametime

FPS comes from MangoHud, not from iNiR, so install MangoHud with your package manager and start the game through it. On Arch that is `sudo pacman -S mangohud`, plus `lib32-mangohud` for 32-bit games.

- For a Steam game, add `mangohud %command%` to its launch options.
- For a Proton game, add `MANGOHUD=1 %command%` instead.

Keep any options the game already has after `%command%`, then restart the game. Installing MangoHud alone does not change a Steam game.

Until MangoHud writes a log, the panel says what is missing: MangoHud is not installed, MangoHud logging is not active, or it asks you to launch the game with MangoHud logging. It shows `--` for values the game does not report, rather than a guess.

iNiR has no control for MangoHud's log. Set `autostart_log=1` and `output_folder=~/.local/state/quickshell/user/mangohud` in `~/.config/MangoHud/MangoHud.conf`.

## Change the view

The panel starts small: FPS over a trace of its frame times, where a stutter shows as a spike, with CPU, GPU, video
memory and memory beneath. Press the unfold button
in its header to see everything: each sensor that reports (clocks, power, temperatures), every CPU core, and the
game's session (resolution, graphics API, Wine or Proton, driver). The one you pick is kept.

## Change the background

The panel follows the overlay's background opacity unless you set its own.

- Material: **Settings › Panels › Floating tools (Super+G) › Background & dim**, then **Game Performance background opacity (%)**. Zero is fully transparent.
- Waffle: **Waffle Settings › Interface › Floating tools (Super+G)**, then the same opacity control.

**Transparent Game Performance background** makes the panel fully transparent. It wins over the opacity value.
