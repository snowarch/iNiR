import qs.modules.common
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls

/**
 * Material 3 styled SpinBox component.
 */
SpinBox {
    id: root

    property real baseHeight: Appearance.regaliaEverywhere ? Appearance.regalia.controlHeight : 40
    // M3 Expressive: a pill holding round - and + targets, the value between them
    property real radius: Appearance.regaliaEverywhere ? Appearance.regalia.roundSmall
        : Appearance.angelEverywhere ? Appearance.angel.roundingSmall
        : Appearance.zzzEverywhere ? Appearance.zzz.controlRadius
        : root.baseHeight / 2
    property real innerButtonRadius: Appearance.regaliaEverywhere ? Appearance.regalia.roundVerySmall
        : Appearance.angelEverywhere ? Appearance.angel.roundingSmall
        : Appearance.zzzEverywhere ? Appearance.zzz.controlRadius
        : root.baseHeight / 2
    readonly property color _face: Appearance.angelEverywhere ? Appearance.angel.colGlassCard : SettingsMaterialPreset.controlColor
    hoverEnabled: true
    editable: true
    // the lowest value's word when it means something else than a number ("Auto" for -1, "Off" for 0)
    property string specialValueText: ""
    textFromValue: function(value, locale) {
        return value === root.from && root.specialValueText.length > 0 ? root.specialValueText : String(value)
    }
    valueFromText: function(text, locale) {
        if (root.specialValueText.length > 0 && String(text).trim().toLowerCase() === root.specialValueText.toLowerCase())
            return root.from
        const parsed = Number.parseInt(String(text).trim(), 10)
        return Number.isFinite(parsed) ? parsed : root.value
    }

    opacity: root.enabled ? 1 : 0.4

    Rectangle {
        readonly property real out: 5
        visible: root.visualFocus && !Appearance.editorialEverywhere && !Appearance.regaliaEverywhere
        z: 2
        x: -out
        y: -out
        width: root.width + 2 * out
        height: root.height + 2 * out
        radius: root.radius + out
        color: "transparent"
        border.width: 3
        border.color: Appearance.colors.colSecondary
    }

    background: Rectangle {
        color: Appearance.regaliaEverywhere ? "transparent"
            : Appearance.angelEverywhere ? Appearance.angel.colGlassCard
            : root._face
        radius: root.radius
        border.width: Appearance.editorialEverywhere ? (root.activeFocus ? 2 : 1) : 0
        border.color: Appearance.editorialEverywhere
            ? (root.activeFocus ? Appearance.editorial.accent : Appearance.editorial.rule)
            : "transparent"

        RegaliaControlFace {
            anchors.fill: parent
            visible: Appearance.regaliaEverywhere
            radius: root.radius
            hovered: root.hovered
            focused: root.activeFocus
        }

        Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
        Behavior on radius { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve } }
        Behavior on border.color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
    }

    // Keyboard focus lands in the number with it selected, so typing replaces it (it landed on an empty Item: digits
    // went nowhere); the pill wears M3's focus ring.
    contentItem: FocusScope {
        implicitHeight: root.baseHeight
        implicitWidth: Math.max(labelText.implicitWidth, 40)

        StyledTextInput {
            id: labelText
            focus: true
            onActiveFocusChanged: if (activeFocus && root.visualFocus) selectAll()
            anchors.centerIn: parent
            text: root.displayText
            color: Appearance.regaliaEverywhere ? Appearance.regalia.onColor : Appearance.colors.colOnSurface
            font.family: Appearance.font.family.numbers
            font.variableAxes: Appearance.font.variableAxes.numbers
            font.pixelSize: Appearance.font.pixelSize.normal
            font.features: { "tnum": 1 }
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

        color: Appearance.regaliaEverywhere ? "transparent"
            : root.down.pressed ? ColorUtils.mix(root._face, Appearance.colors.colOnSurface, 0.88)
            : root.down.hovered ? ColorUtils.mix(root._face, Appearance.colors.colOnSurface, 0.92)
            : ColorUtils.transparentize(root._face)
        RegaliaControlFace {
            anchors.fill: parent
            visible: Appearance.regaliaEverywhere
            fillColor: Appearance.regalia.controlPlate
            radius: root.innerButtonRadius
            hovered: root.down.hovered
            pressed: root.down.pressed
        }

        Behavior on color {
            animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }

        MaterialSymbol {
            anchors.centerIn: parent
            text: "remove"
            iconSize: Appearance.regaliaEverywhere ? 16 : 20
            color: Appearance.regaliaEverywhere ? Appearance.regalia.onColor : Appearance.colors.colOnSurfaceVariant
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

        color: Appearance.regaliaEverywhere ? "transparent"
            : root.up.pressed ? ColorUtils.mix(root._face, Appearance.colors.colOnSurface, 0.88)
            : root.up.hovered ? ColorUtils.mix(root._face, Appearance.colors.colOnSurface, 0.92)
            : ColorUtils.transparentize(root._face)
        RegaliaControlFace {
            anchors.fill: parent
            visible: Appearance.regaliaEverywhere
            fillColor: Appearance.regalia.controlPlate
            radius: root.innerButtonRadius
            hovered: root.up.hovered
            pressed: root.up.pressed
        }

        Behavior on color {
            animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }

        MaterialSymbol {
            anchors.centerIn: parent
            text: "add"
            iconSize: Appearance.regaliaEverywhere ? 16 : 20
            color: Appearance.regaliaEverywhere ? Appearance.regalia.onColor : Appearance.colors.colOnSurfaceVariant
        }
    }
}
