pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.iris.style
import qs.modules.iris.frame
import qs.modules.iris.components
import qs.modules.iris.field as Field
import qs.modules.iris.bar.island as IslandParts

// The resting Island, drawn by the field like the real one: its rim, glass edge, Afterglow and shadow come from the
// same pass instead of a bordered Rectangle that only resembled them.
Item {
    id: pill
    property bool vertical: false
    readonly property real radius: Math.min(width, height) / 2
    width: pill.vertical ? Math.round(IrisFrame.islandBand) : Math.round(150 * IrisStyle.density)
    height: pill.vertical ? Math.round(150 * IrisStyle.density) : Math.round(IrisFrame.islandBand)
    Field.IrisField {
        anchors.fill: parent
        framed: false
        shapes: [{ id: "island", x: 0, y: 0, width: pill.width, height: pill.height, radius: pill.radius }]
    }
    IrisClock {
        visible: !pill.vertical
        anchors.centerIn: parent
        pixelSize: IrisStyle.typeHeadline
        separatorColor: IrisStyle.secondaryAccent
    }
    IslandParts.IslandStackedClock {
        visible: pill.vertical
        anchors.centerIn: parent
        pixelSize: IrisStyle.typeHeadline
        accent: IrisStyle.secondaryAccent
    }
}
