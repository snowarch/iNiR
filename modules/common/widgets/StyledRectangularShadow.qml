pragma ComponentBehavior: Bound

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
    property real blur: Appearance.regaliaEverywhere ? 5
        : Appearance.cookieEverywhere
            ? Appearance.cookie.shadowBlur
            : ((Appearance.sizes && Appearance.sizes.elevationMargin !== undefined)
                ? (0.9 * Number(Appearance.sizes.elevationMargin)) : 0)
    property real spread: Appearance.regaliaEverywhere ? 0
        : Appearance.cookieEverywhere ? Appearance.cookie.shadowSpread : 1
    property color color: Appearance.regaliaEverywhere
        ? Appearance.regalia.shadow
        : Appearance.cookieEverywhere ? Appearance.cookie.shadowColor : Appearance.colors.colShadow
    property vector2d offset: Appearance.regaliaEverywhere ? Qt.vector2d(0.0, 1.0)
        : Appearance.cookieEverywhere
            ? Qt.vector2d(0.0, Appearance.cookie.shadowOffset)
            : Qt.vector2d(0.0, 1.0)

    visible: !Appearance.zzzEverywhere
        && !Appearance.gameModeMinimal
        && (Appearance.angelEverywhere || Appearance.effectsEnabled)
    anchors.fill: target

    // ─── MATERIAL MODE: standard blur shadow ───
    // RectangularShadow shrinks its effective corner radius by ~blur*0.75 (see
    // Qt's clampedRadius()), so with a wide blur the shadow corners turn squarer
    // than the target and poke out past its rounded corners. Compensate so the
    // shadow's rendered radius matches the panel outline.
    RectangularShadow {
        visible: !Appearance.angelEverywhere && !Appearance.zzzEverywhere
        anchors.fill: parent
        radius: root.radius + root.blur * 0.75
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
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        Behavior on y {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        Behavior on color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
    }
}
