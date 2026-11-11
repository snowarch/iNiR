pragma ComponentBehavior: Bound

// The wallpaper drawn as glyph art (`background.effects.glyphs`), for every desktop that draws a wallpaper: it sits
// over the item that holds the picture (still, GIF or video) and reads it. Off, nothing of it exists.

import QtQuick
import qs.services
import qs.modules.common

Loader {
    id: root

    // The item that draws the wallpaper, and the wallpaper's path (a new one grows in).
    property Item picture
    property string path: ""
    readonly property var options: Config.options?.background?.effects?.glyphs ?? ({})

    active: Wallpapers.glyphs && root.picture !== null
    sourceComponent: GlyphArt {
        id: art
        picture: root.picture
        lookName: String(root.options.look ?? "signal")
        glyphPixel: Math.max(1, Math.min(4, Number(root.options.size ?? 1)))
        glowAmount: Math.max(0, Number(root.options.glow ?? 100)) / 100
        accent: Appearance.colors.colPrimary

        readonly property string path: root.path
        onPathChanged: if (Appearance.animationsEnabled) art.appear()
    }
}
