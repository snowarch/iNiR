import qs.modules.common
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls

/**
 * Material 3 styled SpinBox component.
 */
SpinBox {
    id: root

    property real baseHeight: 35
    property real radius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
        : Appearance.rounding.small
    property real innerButtonRadius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
        : Appearance.rounding.unsharpen
    hoverEnabled: true
    editable: true
    textFromValue: function(value, locale) {
        return String(value)
    }
    valueFromText: function(text, locale) {
        const parsed = Number.parseInt(String(text).trim(), 10)
        return Number.isFinite(parsed) ? parsed : root.value
    }

    opacity: root.enabled ? 1 : 0.4

    background: Rectangle {
        color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
            : Appearance.inirEverywhere ? Appearance.inir.colLayer2 : Appearance.colors.colLayer2
        radius: root.radius
        Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
        Behavior on radius { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve } }
    }

    contentItem: Item {
        implicitHeight: root.baseHeight
        implicitWidth: Math.max(labelText.implicitWidth, 40)

        StyledTextInput {
            id: labelText
            anchors.centerIn: parent
            text: root.displayText
            color: Appearance.colors.colOnLayer2
            font.family: Appearance.font.family.numbers
            font.variableAxes: Appearance.font.variableAxes.numbers
            font.pixelSize: Appearance.font.pixelSize.small
            validator: root.validator
            inputMethodHints: Qt.ImhFormattedNumbersOnly
            selectByMouse: true
        }
    }

    down.indicator: Rectangle {
        anchors {
            verticalCenter: parent.verticalCenter
            left: parent.left
        }
        implicitHeight: root.baseHeight
        implicitWidth: root.baseHeight
        topLeftRadius: root.radius
        bottomLeftRadius: root.radius
        topRightRadius: root.innerButtonRadius
        bottomRightRadius: root.innerButtonRadius

        color: root.down.pressed ? (Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive : Appearance.colors.colLayer2Active) : 
            root.down.hovered ? (Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover : Appearance.colors.colLayer2Hover) : 
            ColorUtils.transparentize(Appearance.angelEverywhere ? Appearance.angel.colGlassCard : Appearance.colors.colLayer2)
        Behavior on color {
            animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }

        MaterialSymbol {
            anchors.centerIn: parent
            text: "remove"
            iconSize: 20
            color: Appearance.colors.colOnLayer2
        }
    }

    up.indicator: Rectangle {
        anchors {
            verticalCenter: parent.verticalCenter
            right: parent.right
        }
        implicitHeight: root.baseHeight
        implicitWidth: root.baseHeight
        topRightRadius: root.radius
        bottomRightRadius: root.radius
        topLeftRadius: root.innerButtonRadius
        bottomLeftRadius: root.innerButtonRadius

        color: root.up.pressed ? (Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive : Appearance.colors.colLayer2Active) : 
            root.up.hovered ? (Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover : Appearance.colors.colLayer2Hover) : 
            ColorUtils.transparentize(Appearance.angelEverywhere ? Appearance.angel.colGlassCard : Appearance.colors.colLayer2)
        Behavior on color {
            animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }

        MaterialSymbol {
            anchors.centerIn: parent
            text: "add"
            iconSize: 20
            color: Appearance.colors.colOnLayer2
        }
    }
}
