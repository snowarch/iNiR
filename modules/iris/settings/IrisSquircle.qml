pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common.widgets
import qs.modules.iris.style

Rectangle {
    id: root

    property color tint: IrisStyle.identity.gray
    property string glyph: "settings"
    property real glyphShare: 0.64

    radius: IrisStyle.iconRadius(width)
    gradient: Gradient {
        GradientStop { position: 0; color: Qt.lighter(root.tint, 1.18) }
        GradientStop { position: 1; color: root.tint }
    }
    MaterialSymbol {
        anchors.centerIn: parent
        text: root.glyph
        fill: 1
        iconSize: Math.round(root.width * root.glyphShare)
        color: IrisStyle.onTint
    }
}
