# Wallpaper

Pick a wallpaper, rotate them, give each monitor its own, and tune videos and the backdrop. Colours that follow the wallpaper are on [Colours and themes](THEMING_PRESETS.md).

## Change the wallpaper

- Press **Ctrl+Alt+T** to open the wallpaper picker. It works on the monitor you are focused on.
- In **Settings › Quick › Wallpaper**, **Selector** opens the full picker and **Choose file** picks any image on your system.
- The Wallhaven browser in the left sidebar (Material) searches wallhaven.cc. NSFW results need a Wallhaven API key.

## Rotate wallpapers

Settings › Wallpaper › Source › Shuffle wallpapers:

- **Shuffle wallpapers automatically** is off by default. **Change every** sets the interval, 30 minutes by default.
- **Shuffle folder (optional)** picks another folder. Leave it empty to shuffle the current one.
- **Regenerate theme colors on shuffle** is on by default. Turn it off to change the picture and keep the colours.

**Wallpapers folder** on the same tab sets where the picker looks. It defaults to `~/Pictures/Wallpapers`.

## Monitors and scaling

- **Settings › Wallpaper › Screens › Multi-monitor**: turn on **Per-monitor wallpapers**, pick a monitor, then use **Change wallpaper**, **Random**, **Reset to global** or **Apply to all**.
- **Wallpaper scaling** (same tab): **Fill** crops the picture to the screen, **Fit** shows the whole picture with bars, and **Span** lays one picture across every screen. Stretch, Tile and Center are there too.
- **Hide main wallpaper in fullscreen** (Screens › Fullscreen behavior) is on by default. The overview backdrop stays.
- iNiR warns you when a picture is smaller than your monitor. **Hide wallpaper upscale notification** (Settings › Wallpaper › Notifications) turns that off.

## Transitions and renderer

- **Settings › Wallpaper › Motion › Wallpaper transitions**: pick a **Transition style** such as Fade, Wipe, Grow, Dissolve or Glitch. **Random** picks one at random.
- **Settings › Wallpaper › Source › Wallpaper renderer**: **Standard** is the default. **Interactive web** shows a local HTML file or a web page as the wallpaper, and needs Qt 6 WebEngine.

## Videos and GIFs

Videos can be mp4, webm, mkv, avi or mov. Pictures can be jpg, png, webp, avif, bmp, gif, tif or svg.

- **Play videos and GIFs as wallpaper** (Screens › Wallpaper scaling) is on by default. Off shows a still frame instead.
- **Freeze videos and GIFs while on battery power** is on by default.
- **Effects › Wallpaper effects**: **Enable wallpaper blur** is off by default. **Blur radius** (32) and **Thumbnail blur strength (%)** tune it, the second for videos.

## Backdrop

The backdrop is a separate, blurred layer that shows while the overview is open. Settings › Wallpaper › Effects › Backdrop (overview):

- **Enable backdrop layer for overview** is on by default. **Use main wallpaper** is on too. Turn it off to **Pick backdrop wallpaper**.
- **Backdrop blur radius** (64) and **Backdrop dim (%)** (20) tune the look.
- **Hide main wallpaper (show only backdrop)** is off by default.
- **Aurora glass effect** gives glass panels colours from the wallpaper, like the sidebars.

Waffle keeps its wallpaper effects and backdrop under **Waffle Settings › Background**.
