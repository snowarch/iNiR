pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style

Rectangle {
    id: root

    property color tint: IrisStyle.identity.gray
    property string glyph: "settings"
    property real glyphShare: 0.64

    // The icon pack: "iris" is the family's tinted squircle. "tile" is the app-icon look,
    // a plate the user can colour, with the glyph in a gradient of its own colour.
    readonly property bool tiled: String(Config.options?.iris?.appearance?.icons?.style ?? "iris") === "tile"
    readonly property string plate: String(Config.options?.iris?.appearance?.icons?.plate ?? "black")
    readonly property color tileTop: root.plate === "white" ? IrisStyle.plateWhiteTop
        : root.plate === "tint" ? IrisStyle.tileTop(root.tint)
        : root.plate === "surface" ? Qt.lighter(IrisStyle.surfaceHighestOpaque, 1.7)
        : IrisStyle.plateBlackTop
    readonly property color tileBase: root.plate === "white" ? IrisStyle.plateWhiteBase
        : root.plate === "tint" ? root.tint
        : root.plate === "surface" ? IrisStyle.surfaceHighestOpaque
        : IrisStyle.plateBlackBase

    radius: IrisStyle.iconRadius(width)
    gradient: Gradient {
        GradientStop { position: 0; color: root.tiled ? root.tileTop : IrisStyle.tileTop(root.tint) }
        GradientStop { position: 1; color: root.tiled ? root.tileBase : root.tint }
    }
    MaterialSymbol {
        anchors.centerIn: parent
        text: root.glyph
        fill: 1
        iconSize: Math.round(root.width * root.glyphShare)
        color: root.tiled && root.plate !== "tint" ? root.tint : IrisStyle.onTint
        glyphGradient: root.tiled
    }
}
