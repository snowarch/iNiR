pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components

// The heart, where it lands (the desktop or behind the overview) and Apply.
Row {
    id: root

    required property var engine
    property var entry: root.engine.selected
    property bool targets: true
    readonly property real d: IrisStyle.density
    readonly property bool favorite: root.entry !== null && Wallpapers.isFavorite(root.entry.key)

    spacing: Math.round(8 * root.d)

    TextMetrics { id: applyMetrics; font.pixelSize: IrisStyle.typeLabel; font.weight: IrisStyle.weight(Font.DemiBold); text: Translation.tr("Apply") }

    WallpaperGlyphButton {
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: Math.round(36 * root.d)
        glyph: "favorite"
        filled: root.favorite
        selected: root.favorite
        enabled: root.entry !== null
        Accessible.name: root.favorite ? Translation.tr("Remove from favourites") : Translation.tr("Add to favourites")
        onClicked: root.engine.toggleFavorite(root.entry)
    }
    IrisSegmented {
        visible: root.targets && root.engine.overviewTargetable
        anchors.verticalCenter: parent.verticalCenter
        implicitHeight: Math.round(36 * root.d)
        implicitWidth: Math.max(Math.round(96 * root.d) * 2 + 2 * inset, fitWidth)
        accessibleName: Translation.tr("Apply to")
        options: [{ value: "main", label: Translation.tr("Desktop") }, { value: "backdrop", label: Translation.tr("Overview") }]
        current: root.engine.targetsOverview ? "backdrop" : "main"
        onPicked: value => root.engine.targetOverview(value === "backdrop")
    }
    IrisButton {
        anchors.verticalCenter: parent.verticalCenter
        implicitHeight: Math.round(36 * root.d)
        implicitWidth: Math.max(Math.round(92 * root.d), applyMetrics.advanceWidth + Math.round(40 * root.d))
        buttonRadius: IrisStyle.capsule(height)
        buttonRadiusPressed: IrisStyle.capsule(height)
        emphasized: true
        text: Translation.tr("Apply")
        enabled: root.entry !== null && root.engine.downloadingKey.length === 0
        onClicked: root.engine.apply(root.entry)
    }
}
