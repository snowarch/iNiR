pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common
import qs.modules.iris.style

// One scene of the Settings previews. It reads its host IrisGroupPreview only through these properties; a scene also
// declares naturalWidth and naturalHeight, and cropBottom when its lower part may be cut instead of scaled.
Item {
    id: scene

    required property Item preview
    // The smallest size the scene still reads at when its parts follow its size: drawn smaller than its natural size it
    // is laid out at the drawn size and shrunk only below these. 0: that side is shrunk whole from its natural size.
    property real narrowest: 0
    property real lowest: 0
    readonly property real d: IrisStyle.density
    readonly property int rev: Config.revision
    // A scene moves while it is seen and awake (IrisGroupPreview.awake), then rests on what it shows.
    readonly property bool playing: scene.preview.playing && (scene.preview.awake ?? true)
    readonly property string section: scene.preview.section
    readonly property string group: scene.preview.group
    readonly property string wallpaper: scene.preview.wallpaper
    // The host's wallpaper, decoded once: glass and blur sample its textureItem.
    readonly property Item wallpaperView: scene.preview.wallpaperView

    function opt(path: string, fallback: var): var {
        scene.rev
        return Config.getNestedValue(path, fallback)
    }
    // What Niri holds (gaps, borders, keyboard, the screen), handed in by the host: Settings reads it, scenes cannot.
    readonly property int niriRev: scene.preview.niriRevision ?? 0
    function niri(section: string, key: string, fallback: var): var {
        scene.niriRev
        const read = scene.preview.niriValue
        const value = read ? read(section, key) : undefined
        return value === undefined || value === null || value === "" ? fallback : value
    }
}
