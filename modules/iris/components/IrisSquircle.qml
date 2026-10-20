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
    // A mark is a colour you tell areas apart by, so it is always vivid: a palette may keep its identity hues quiet on
    // purpose (washi's blue is #869dd5), and a quiet hue under white read as a grey tile. The hue stays; the plate
    // takes the HIG band of chroma and lightness (Apple's system blue sits at s 1.0, l 0.52). Greys stay grey.
    readonly property color vivid: root.tint.hslSaturation < 0.14 ? root.tint
        : Qt.hsla(root.tint.hslHue, Math.max(root.tint.hslSaturation, 0.78), Math.max(0.46, Math.min(0.58, root.tint.hslLightness)), 1)
    readonly property color tileTop: root.plate === "white" ? IrisStyle.plateWhiteTop
        : root.plate === "tint" ? IrisStyle.tileTop(root.vivid)
        : root.plate === "surface" ? Qt.lighter(IrisStyle.surfaceHighestOpaque, 1.7)
        : IrisStyle.plateBlackTop
    readonly property color tileBase: root.plate === "white" ? IrisStyle.plateWhiteBase
        : root.plate === "tint" ? root.vivid
        : root.plate === "surface" ? IrisStyle.surfaceHighestOpaque
        : IrisStyle.plateBlackBase

    // A Design whose marks are glyphs alone (AIRISU) draws no plate: the glyph in its line weight, in the ink.
    readonly property bool plain: IrisStyle.plainMarks
    // On a chosen row's plate (a plate Design): the plain glyph in the plate's own ink.
    property bool reversed: false
    property color ink: root.plain ? (root.reversed ? IrisStyle.selectionLabel : IrisStyle.textSecondary)
        : root.tiled && root.plate !== "tint" ? root.vivid : IrisStyle.onTint
    radius: root.plain ? 0 : IrisStyle.iconRadius(width)
    color: "transparent"
    // The plate is its own child: a Rectangle's gradient cannot be bound back to none (Qt 6 keeps the last one).
    Rectangle {
        anchors.fill: parent
        visible: !root.plain
        radius: root.radius
        gradient: Gradient {
            GradientStop { position: 0; color: root.tiled ? root.tileTop : IrisStyle.tileTop(root.vivid) }
            GradientStop { position: 1; color: root.tiled ? root.tileBase : root.vivid }
        }
    }
    MaterialSymbol {
        anchors.centerIn: parent
        text: root.glyph
        fill: root.plain ? 0 : 1
        iconSize: Math.round(root.width * (root.plain ? Math.min(0.82, root.glyphShare + 0.14) : root.glyphShare))
        color: root.ink
        glyphGradient: root.tiled && !root.plain
    }
}
