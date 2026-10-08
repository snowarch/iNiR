pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common
import qs.modules.iris.style

// One scene of the Settings previews. It reads its host IrisGroupPreview only through these properties; a scene also
// declares naturalWidth and naturalHeight, and cropBottom when its lower part may be cut instead of scaled.
Item {
    id: scene

    required property Item preview
    readonly property real d: IrisStyle.density
    readonly property int rev: Config.revision
    readonly property bool playing: scene.preview.playing
    readonly property string section: scene.preview.section
    readonly property string group: scene.preview.group
    readonly property string wallpaper: scene.preview.wallpaper
    // The host's wallpaper, decoded once: glass and blur sample its textureItem.
    readonly property Item wallpaperView: scene.preview.wallpaperView

    function opt(path: string, fallback: var): var {
        scene.rev
        return Config.getNestedValue(path, fallback)
    }
}
