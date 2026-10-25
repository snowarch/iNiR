pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.common
import qs.modules.iris.style
import qs.modules.iris.components

// The picker's three faces, one click away in each of them (as Settings' modes are).
IrisSegmented {
    id: root

    required property string layout

    glyphOnly: true
    implicitHeight: Math.round(36 * IrisStyle.density)
    accessibleName: Translation.tr("Layout")
    options: [{ value: "reel", label: Translation.tr("Reel"), glyph: "view_carousel" },
        { value: "mosaic", label: Translation.tr("Mosaic"), glyph: "dashboard" },
        { value: "browser", label: Translation.tr("Browser"), glyph: "grid_view" }]
    current: root.layout
    onPicked: value => Config.setNestedValue("iris.wallpaper.layout", value)
}
