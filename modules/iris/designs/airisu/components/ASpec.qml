import QtQuick
import qs.modules.iris.style

// The spec sheet (ficha técnica): mono label left, value right, one row per fact. `rows`: [{ label, value, live }].
Column {
    id: root
    property var rows: []
    spacing: Math.round(6 * Airisu.d)
    Repeater {
        model: root.rows
        Item {
            required property var modelData
            width: root.width
            implicitHeight: key.implicitHeight
            AText { id: key; voice: "mono"; text: modelData.label; color: Airisu.quiet }
            AText {
                anchors.right: parent.right
                voice: "mono"
                text: modelData.value
                font.capitalization: Font.MixedCase
                color: modelData.live ? Airisu.sealText : Airisu.gofun
            }
        }
    }
}
