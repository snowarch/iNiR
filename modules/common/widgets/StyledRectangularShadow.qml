import QtQuick
import QtQuick.Effects
import qs.modules.common
import qs.modules.common.functions

// Dual-mode shadow: material blur shadow OR angel escalonado (offset golden platform).
// When angel is active, renders as a warm golden offset rectangle behind the target,
// creating the signature neo-brutalism "stepped layer" effect from docs-site.
// 52+ usages across the shell — this ONE component themes everything.
Item {
    id: root
    required property var target
    property bool hovered: false
    property real radius: (target && target.radius !== undefined) ? Number(target.radius) : 0
    // Passthrough properties for backward compat (some sites override these)
    property real blur: (Appearance.sizes && Appearance.sizes.elevationMargin !== undefined) ? (0.9 * Number(Appearance.sizes.elevationMargin)) : 0
    property real spread: 1
    property color color: Appearance.colors.colShadow
    property vector2d offset: Qt.vector2d(0.0, 1.0)

    visible: Appearance.angelEverywhere
        ? true
        : Appearance.effectsEnabled
    anchors.fill: target

    // ─── MATERIAL MODE: standard blur shadow ───
    RectangularShadow {
        visible: !Appearance.angelEverywhere
        anchors.fill: parent
        radius: root.radius
        blur: root.blur
        offset: root.offset
        spread: root.spread
        color: root.color
        cached: true
    }

    // ─── ANGEL MODE: escalonado offset golden platform ───
    Rectangle {
        id: escalonado
        visible: Appearance.angelEverywhere

        readonly property int currentOffsetX: root.hovered ? Appearance.angel.escalonadoHoverOffsetX : Appearance.angel.escalonadoOffsetX
        readonly property int currentOffsetY: root.hovered ? Appearance.angel.escalonadoHoverOffsetY : Appearance.angel.escalonadoOffsetY

        x: currentOffsetX
        y: currentOffsetY
        width: parent.width
        height: parent.height

        color: root.hovered ? Appearance.angel.colEscalonadoHover : Appearance.angel.colEscalonado
        border.width: 1
        border.color: Appearance.angel.colEscalonadoBorder
        radius: root.radius

        Behavior on x {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
        Behavior on y {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
        Behavior on color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: 150 }
        }
    }
}
