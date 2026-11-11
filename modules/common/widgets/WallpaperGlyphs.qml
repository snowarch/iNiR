pragma ComponentBehavior: Bound

// The wallpaper drawn as glyph art (`background.effects.glyphs`), for every desktop that draws a wallpaper: it sits
// over the item that holds the picture (still, GIF or video) and reads it, or shows one of the built-in subjects or
// a word instead. Off, nothing of it exists.

import QtQuick
import qs.services
import qs.modules.common
import "GlyphArt.js" as Glyphs

Loader {
    id: root

    // The item that draws the wallpaper, and the wallpaper's path (a new one comes in with the intro).
    property Item picture
    property string path: ""
    // Off while the desktop is covered: nothing moves then.
    property bool live: true
    readonly property var options: Config.options?.background?.effects?.glyphs ?? ({})

    active: Wallpapers.glyphs && root.picture !== null
    sourceComponent: GlyphArt {
        id: art
        picture: root.picture
        source: {
            const chosen = String(root.options.source ?? "wallpaper")
            return chosen === "wallpaper" ? "picture" : chosen
        }
        word: String(root.options.word ?? "")
        settings: Glyphs.settings(key => root.options[key])
        theme: [Qt.darker(Appearance.colors.colPrimary, 2.2), Appearance.colors.colPrimary,
            Qt.lighter(Appearance.colors.colPrimary, 1.7), Appearance.colors.colTertiary]
        fontFamily: Appearance.font.family.monospace
        live: root.live

        readonly property string subject: art.source + root.path + art.word
        onSubjectChanged: if (Appearance.animationsEnabled) art.appear()
    }
}
