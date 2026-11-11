pragma ComponentBehavior: Bound

// The wallpaper drawn as glyph art (`background.effects.glyphs`), for every desktop that draws a wallpaper: it sits
// over the item that holds the picture (still, GIF or video) and reads it, or shows one of the built-in subjects or
// a word instead. Off, nothing of it exists.

import QtQuick
import qs
import qs.services
import qs.modules.common
import "GlyphArt.js" as Glyphs

Loader {
    id: root

    // The item that draws the wallpaper, and the wallpaper's path (a new one comes in with the intro).
    property Item picture
    property string path: ""
    // The output it is on: it moves where the shell lets a live wallpaper move (not locked, not in a game, not on
    // battery pause, not behind a fullscreen or covering window), and nowhere else.
    property string output: ""
    property bool live: true
    readonly property bool seen: root.live && (Config.options?.background?.enableAnimation ?? true)
        && !GlobalStates.screenLocked && !Appearance._gameModeActive && !Wallpapers.batteryPauseActive
        && Wallpapers.videoMotionAllowedOn(root.output)
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
        // The glyphs cover the picture whole: drawing it under them too was a full-screen pass every video frame.
        hidePicture: true
        live: root.seen
        // A video or a GIF is read fifteen times a second, whatever its own rate; the desktop redraws for its
        // widgets far more often than the glyphs change, so their last frame is kept.
        animated: Wallpapers.isVideoFile(root.path) || /\.(gif|apng)$/i.test(root.path)
        cached: true

        readonly property string subject: art.source + root.path + art.word
        onSubjectChanged: if (Appearance.animationsEnabled) art.appear()
    }
}
