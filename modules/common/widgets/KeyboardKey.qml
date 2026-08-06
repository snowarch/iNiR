import qs.modules.common
import QtQuick

/**
 * Keyboard key component following M3 layer color system.
 * Uses surfaceContainer colors for subtle, theme-consistent appearance.
 */
Rectangle {
    id: root
    property string key

    property real horizontalPadding: 6
    property real verticalPadding: 2
    property real borderWidth: 1
    property real extraBottomBorderWidth: 2
    property real borderRadius: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius
        : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.verysmall

    // Special key icon mapping
    readonly property var specialKeyIcons: ({
        "Up": "arrow_upward", "Down": "arrow_downward",
        "Left": "arrow_back", "Right": "arrow_forward",
        "Enter": "keyboard_return", "Return": "keyboard_return",
        "Escape": "close", "Esc": "close", "Tab": "keyboard_tab",
        "Backspace": "backspace", "Delete": "delete",
        "Home": "first_page", "End": "last_page",
        "Page_Up": "expand_less", "Page_Down": "expand_more",
        "Space": "space_bar", "Print": "screenshot_monitor"
    })

    readonly property bool isSpecialKey: key in specialKeyIcons
    readonly property string specialKeyIcon: specialKeyIcons[key] ?? ""

    implicitWidth: keyFace.implicitWidth + borderWidth * 2
    implicitHeight: keyFace.implicitHeight + borderWidth * 2 + extraBottomBorderWidth
    radius: borderRadius

    // M3 layer colors - subtle border using surfaceContainerHigh
    color: Appearance.zzzEverywhere ? Appearance.zzz.bg3
        : Appearance.inirEverywhere ? Appearance.inir.colBorderMuted : Appearance.colors.colSurfaceContainerHigh

    Behavior on color {
        enabled: Appearance.animationsEnabled
        animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }
    Behavior on radius {
        enabled: Appearance.animationsEnabled
        animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }

    Rectangle {
        id: keyFace
        anchors {
            fill: parent
            topMargin: borderWidth
            leftMargin: borderWidth
            rightMargin: borderWidth
            bottomMargin: extraBottomBorderWidth + borderWidth
        }
        implicitWidth: keyContent.implicitWidth + horizontalPadding * 2
        implicitHeight: keyContent.implicitHeight + verticalPadding * 2

        // M3 layer colors - key face using surfaceContainer
        color: Appearance.inirEverywhere ? Appearance.inir.colLayer2 : Appearance.colors.colSurfaceContainer
        radius: borderRadius - borderWidth

        Behavior on color {
            enabled: Appearance.animationsEnabled
            animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        Behavior on radius {
            enabled: Appearance.animationsEnabled
            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }

        Item {
            id: keyContent
            anchors.centerIn: parent
            implicitWidth: root.isSpecialKey ? keyIcon.implicitWidth : keyText.implicitWidth
            implicitHeight: root.isSpecialKey ? keyIcon.implicitHeight : keyText.implicitHeight

            MaterialSymbol {
                id: keyIcon
                visible: root.isSpecialKey
                anchors.centerIn: parent
                text: root.specialKeyIcon
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnSurface
            }

            StyledText {
                id: keyText
                visible: !root.isSpecialKey
                anchors.centerIn: parent
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnSurface
                text: root.key
            }
        }
    }
}
