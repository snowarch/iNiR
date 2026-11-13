# Floating tools

Press **Super+G** and a bench of tools opens over whatever you are playing or watching: a recorder, a volume mixer,
your system's load, a frame cap, a crosshair, notes, a picture, your notifications, Discord and game performance. Pin
a tool and it stays on screen when the bench closes.

## Open a tool

1. Press **Super+G**.
2. Click a tool in the strip at the top. Open tools are lit and a dot marks the pinned ones; click again to put one away.
3. Press **Super+G** or `Esc` to close the bench.

The strip also takes a screenshot or records a region, and **Arrange** lays every open tool side by side from the
screen's edges.

## Move and size

- Drag a tool by its header. It snaps to the screen's edges and centre and to the other tools, and a line shows where.
  `Esc` during a drag puts it back.
- Notes, the mixer, notifications and resources grow from any edge. The other tools are the size of what they hold;
  scroll on the floating image to zoom it.
- The last tool you touch comes to the front.

Each tool keeps its place and size. On a smaller screen it is pulled back inside.

## Pin a tool

Press the pin in a tool's header. When the bench closes, a pinned tool stays where it is as a quiet readout: no
header, its own background.

While the bench is open, a pinned tool shows two more controls at its foot:

- **Background when pinned**: how solid its plate is.
- **Clickable**: whether you can use it while it is pinned. When it is off, clicks go through the tool to the game and
  the tool fades so the game shows. The readouts (crosshair, picture, resources, game performance, notes) start with
  clicks going through; the others start clickable.

A pinned tool comes back after a restart.

## The tools

- **Recorder**: record the screen or a region, with or without sound, take a screenshot, open the folders. The time
  runs in its header while it records.
- **Volume mixer**: each app's volume, your output and input devices, and what is playing.
- **Resources**: CPU, GPU, memory and swap as small live graphs.
- **FPS limiter**: MangoHud's frame cap. Type a number, scroll it, step it, or pick one of the usual caps; your display's
  own rate is among them. It writes `fps_limit` in `~/.config/MangoHud/MangoHud.conf` and MangoHud picks it up by itself.
  A list of caps there (MangoHud's cap toggle cycles them) keeps its other values.
- **Crosshair**: a crosshair in the centre of the screen. Paste a Valorant crosshair code to use one you already have.
- **Notes**: a note that saves as you type.
- **Floating image**: a picture kept over the game, such as a map or a build. Drop a file on it, choose one, or paste a link.
  It opens at a size that fits the screen; drag an edge or scroll on it to resize it, its shape kept.
- **Notifications**: what arrived while you played. Clearing them can be undone.
- **Discord**: mute your microphone or your sound in one click. While Discord (or a client like Vesktop) plays a call,
  the call's own volume shows beside the game's.
- **Network**: the latency to Cloudflare, Google or your router over its trace, how steady it is (jitter and lost
  replies), and what flows down and up right now. Nothing is measured while the tool is out of sight.
- **Clock**: the time in large figures, or an analog dial, with seconds and the date if you want them. It follows the
  shell's 12 or 24 hour format; drag an edge or scroll to size it.
- **Timer**: a timer, a stopwatch with laps and focus sessions, drawn as a ring. It is the shell's own timer, so the bar
  and the sidebars show the same run. Scroll the ring to set the timer a minute at a time.
- **Game performance**: FPS and frametime from MangoHud, with CPU, GPU and memory. See [Game performance](GAME_PERFORMANCE.md).

Tools with options (Clock, Timer, Network) have a tune button in their header: the tool turns over and shows them.

## Settings

- Material: **Settings › Panels › Floating tools (Super+G)**.
- Waffle: **Waffle Settings › Interface › Floating tools (Super+G)**.
- iRiS: **iRiS Settings › Gaming & Fullscreen › Floating tools**.

There you choose whether the screen behind dims and how much, how solid the tools are, how faded a pinned tool is when
clicks go through it, and the zoom when the bench opens.

## From a command or a key

`inir overlay toggle` opens and closes the bench. `inir overlay tool crosshair on` shows one tool without opening it,
`inir overlay pin notes on` pins one, and `inir overlay arrange` lays them out. Every verb is in [IPC](IPC.md).
