pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs
import qs.modules.common
import qs.modules.common.functions

// Lume: how iNiR keeps content readable over whatever is behind it. Three steps, each usable alone:
//
// 1. Read what sits behind a rect (`read`): the wallpaper that output shows (preview included, a video's
//    still), summed from WallpaperLuma's grid: gamma level, spread and mean colour, instant and live. When
//    windows cover the output (`covered`), what shows through compositor blur is unknown: treat it as bright.
// 2. Decide the ink (`lightAfter`): dark ink once the backdrop is clearly light, light ink once it is
//    clearly dark, with a gap between the two thresholds so a moving surface never flickers.
// 3. Solve the material (`veil`, `frost`): the least alpha of a dark veil (light ink) or a light frost
//    (dark ink) that holds a contrast ratio over the worst part of the backdrop (mean ± weighted spread).
//
// 4. Plate a panel (`plateOver`, `stack`): a translucent body keeps its tint for the look and puts a plate
//    only under what holds text, as thick as the backdrop needs and no thicker.
//
// Consumers: desktop widgets (AbstractBackgroundWidget, iRiS faces via IrisStyle.legibleVeil/legibleFrost),
// Waffle's desktop clock, iRiS Places (IrisStyle.placePlate/readingCard: Settings sidebar and cards).
// Family tokens decide the colours; Lume decides how much of them.
Singleton {
    id: root

    readonly property int revision: WallpaperLuma.revision

    function screenNamed(name: string): var {
        return Quickshell.screens.find(screen => screen?.name === name) ?? null
    }
    function wallpaperOf(output: string): string {
        return WallpaperLuma.imagePath(Wallpapers.internalPreviewFor(output, Wallpapers.currentMainWallpaperPath(output)))
    }

    // {level, spread, color, luminance} of the wallpaper under a rect in output coordinates, null until read.
    function read(output: string, x: real, y: real, w: real, h: real): var {
        return root.readFrom(root.wallpaperOf(output), output, x, y, w, h)
    }
    // The same for a surface that shows its own image (Waffle's wallpaper, a lock background).
    function readFrom(path: string, output: string, x: real, y: real, w: real, h: real): var {
        void root.revision
        const screen = root.screenNamed(output)
        if (!screen || !path) return null
        return WallpaperLuma.sample(path, Math.round(screen.width), Math.round(screen.height), x, y, w, h)
    }

    // Windows are open on the output's active workspace: compositor blur shows them, not the wallpaper.
    function covered(output: string): bool {
        if (!CompositorService.isNiri) return false
        const ws = (NiriService.allWorkspaces ?? []).find(item => item.output === output && item.is_active)
        if (!ws) return false
        return (NiriService.windows ?? []).some(w => w.workspace_id === ws.id && !MinimizedWindows.isMinimized(w.id))
    }

    function lightAfter(luminance: real, wasLight: bool, enter: real, leave: real): bool {
        if (luminance < 0) return false
        return wasLight ? luminance > (leave ?? 0.21) : luminance > (enter ?? 0.30)
    }

    // Alpha of a veil of `surface` over the backdrop so `ink` keeps `contrast` on its brightest part.
    function veil(level: real, spread: real, spreadWeight: real, surface: color, ink: color, contrast: real, floor: real, cap: real): real {
        if (level < 0) return Math.max(floor, 0.42)
        const worst = Math.min(1, level + spread * spreadWeight)
        const region = Math.pow(worst, 2.2)
        const base = ColorUtils.relativeLuminance(surface)
        const allowed = (ColorUtils.relativeLuminance(ink) + 0.05) / contrast - 0.05
        const needed = region > allowed ? (region - allowed) / Math.max(0.001, region - base) : 0
        return Math.max(floor, Math.min(cap, needed))
    }

    // Alpha of a frost of `surface` so dark `ink` keeps `contrast` on the backdrop's darkest part.
    function frost(level: real, spread: real, spreadWeight: real, surface: color, ink: color, contrast: real, floor: real, cap: real): real {
        if (level < 0) return Math.max(floor, 0.42)
        const darkest = Math.max(0, level - spread * spreadWeight)
        const region = Math.pow(darkest, 2.2)
        const needed = (ColorUtils.relativeLuminance(ink) + 0.05) * contrast - 0.05
        const alpha = region < needed ? (needed - region) / Math.max(0.001, ColorUtils.relativeLuminance(surface) - region) : 0
        return Math.max(floor, Math.min(cap, alpha))
    }

    // `seed`'s own hue at the lightness that keeps `contrast` on the worst part of a backdrop: deeper for dark ink,
    // brighter for light ink. Warm hues lean toward red as they deepen, where darkening alone turns them brown.
    function mark(seed: color, level: real, spread: real, darkInk: bool, contrast: real): color {
        const c = Qt.color(seed)
        if (level < 0 || c.hslSaturation < 0.08) return c
        const worst = Math.pow(darkInk ? Math.max(0, level - spread) : Math.min(1, level + spread), 2.2)
        const hue = Math.max(0, c.hslHue)
        let l = c.hslLightness
        let out = c
        for (let i = 0; i < 48; i++) {
            const lean = darkInk && hue > 0.05 && hue < 0.17 ? Math.min(1, (c.hslLightness - l) * 2.5) : 0
            out = Qt.hsla(hue - (hue - 0.04) * lean, c.hslSaturation, l, 1)
            const own = ColorUtils.relativeLuminance(out)
            const ratio = darkInk ? (worst + 0.05) / (own + 0.05) : (own + 0.05) / (worst + 0.05)
            if (ratio >= contrast || l <= 0.08 || l >= 0.94) break
            l += darkInk ? -0.02 : 0.02
        }
        return out
    }

    // A plate inside a body that already veils its backdrop by `tint`: the alpha it adds to reach `needed`.
    // Two veils of one surface stack as 1 - (1 - a)(1 - b).
    function plateOver(tint: real, needed: real): real {
        return needed <= tint ? 0 : Math.min(1, (needed - tint) / Math.max(0.001, 1 - tint))
    }
    // `top` over `bottom`, both translucent, as one colour: a fill on a plate painted by one Rectangle.
    function stack(bottom: color, top: color): color {
        const a = top.a + bottom.a * (1 - top.a)
        if (a <= 0) return Qt.rgba(0, 0, 0, 0)
        const mixed = (t, b) => (t * top.a + b * bottom.a * (1 - top.a)) / a
        return Qt.rgba(mixed(top.r, bottom.r), mixed(top.g, bottom.g), mixed(top.b, bottom.b), a)
    }
}
