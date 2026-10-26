pragma ComponentBehavior: Bound

import QtQuick
import qs
import qs.modules.common
import qs.modules.common.widgets
// A widget's mark at the head of its quick controls. iRiS: the category-tint squircle with a white
// glyph (its identity grammar); the ii family: the Global Style's tonal container.
Rectangle {
    id: root

    property string glyph: "widgets"
    property color tint: FamilyStyle.accent

    readonly property bool iris: (Config.options?.panelFamily ?? "ii") === "iris"
    readonly property real d: root.iris ? FamilyStyle.density : 1

    implicitWidth: Math.round(28 * root.d)
    implicitHeight: implicitWidth
    radius: root.iris ? FamilyStyle.iconRadius(width) : Appearance.rounding.small
    color: root.iris ? root.tint : Appearance.colors.colSecondaryContainer
    gradient: root.iris ? tintGradient : null

    Gradient {
        id: tintGradient
        GradientStop { position: 0; color: Qt.lighter(root.tint, 1.18) }
        GradientStop { position: 1; color: root.tint }
    }

    MaterialSymbol {
        anchors.centerIn: parent
        text: root.glyph
        fill: 1
        iconSize: Math.round(17 * root.d)
        color: root.iris ? FamilyStyle.onTint : Appearance.colors.colOnSecondaryContainer
    }
}
