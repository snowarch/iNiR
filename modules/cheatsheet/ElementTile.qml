import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

RippleButton {
    id: root
    required property var element
    opacity: element.type != "empty" ? 1 : 0
    implicitHeight: 70
    implicitWidth: 70
    buttonRadius: Appearance.rounding.small

    // Track if element was just copied
    property bool justCopied: false

    // Tooltip with detailed element information (Requirements: 5.1)
    ToolTip {
        id: elementTooltip
        visible: root.hovered && root.element.type !== "empty"
        delay: 300
        background: null
        padding: 0

        contentItem: ElementTooltip {
            element: root.element
        }
    }

    // Category color mapping using M3 colors - dynamically bound to theme
    readonly property color metalColor: Appearance.colors.colSecondary
    readonly property color nonmetalColor: Appearance.colors.colTertiary
    readonly property color noblegasColor: Appearance.colors.colPrimary
    readonly property color lanthanumColor: Appearance.colors.colPrimaryContainer
    readonly property color actiniumColor: Appearance.colors.colSecondaryContainer

    // Get color for current element's category
    colBackground: {
        switch (element.type) {
            case "metal": return metalColor
            case "nonmetal": return nonmetalColor
            case "noblegas": return noblegasColor
            case "lanthanum": return lanthanumColor
            case "actinium": return actiniumColor
            case "empty": return "transparent"
            default: return Appearance.colors.colLayer2
        }
    }

    // Copy element symbol to clipboard on click
    onClicked: {
        if (element.type !== "empty") {
            Quickshell.clipboardText = element.symbol;
            justCopied = true;
            copyConfirmTimer.restart();
        }
    }

    // Timer to reset the copied state
    Timer {
        id: copyConfirmTimer
        interval: 1500
        repeat: false
        onTriggered: {
            root.justCopied = false;
        }
    }

    Rectangle {
        id: numberBadge
        anchors {
            top: parent.top
            left: parent.left
            topMargin: 4
            leftMargin: 4
        }
        color: ColorUtils.transparentize(root.colBackground, 0.3)
        radius: Appearance.rounding.full
        implicitWidth: Math.max(20, elementNumber.implicitWidth)
        implicitHeight: Math.max(20, elementNumber.implicitHeight)
        width: height

        // Color transition animation for theme changes
        Behavior on color {
            enabled: Appearance.animationsEnabled
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }

        StyledText {
            id: elementNumber
            anchors.left: parent.left
            color: root.textColor
            text: root.element.number
            font.pixelSize: Appearance.font.pixelSize.smallest
        }
    }

    Rectangle {
        id: weightBadge
        anchors {
            top: parent.top
            right: parent.right
            topMargin: 4
            rightMargin: 4
        }
        color: ColorUtils.transparentize(root.colBackground, 0.3)
        radius: Appearance.rounding.full
        implicitWidth: Math.max(20, elementWeight.implicitWidth)
        implicitHeight: Math.max(20, elementWeight.implicitHeight)
        width: height

        // Color transition animation for theme changes
        Behavior on color {
            enabled: Appearance.animationsEnabled
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }

        StyledText {
            id: elementWeight
            anchors.right: parent.right
            color: root.textColor
            text: root.element.weight
            font.pixelSize: Appearance.font.pixelSize.smallest
        }
    }

    // Get appropriate text color based on background - dynamically bound to theme
    readonly property color textColor: {
        const type = element.type;
        if (type === "noblegas" || type === "metal" || type === "nonmetal") {
            return Appearance.colors.colOnPrimary;
        } else if (type === "lanthanum") {
            return Appearance.colors.colOnPrimaryContainer;
        } else if (type === "actinium") {
            return Appearance.colors.colOnSecondaryContainer;
        }
        return Appearance.colors.colOnLayer2;
    }

    StyledText {
        id: elementSymbol
        anchors.centerIn: parent
        color: root.textColor
        font.pixelSize: Appearance.font.pixelSize.huge
        text: root.element.symbol
    }

    StyledText {
        id: elementName
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: 4
        }
        font.pixelSize: Appearance.font.pixelSize.smallest
        color: root.textColor
        text: root.element.name
        visible: !root.justCopied
    }

    // Copy confirmation indicator
    RowLayout {
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: 4
        }
        spacing: 2
        visible: root.justCopied
        opacity: root.justCopied ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }

        MaterialSymbol {
            text: "check"
            iconSize: Appearance.font.pixelSize.smallest
            color: root.textColor
        }

        StyledText {
            text: Translation.tr("Copied")
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: root.textColor
        }
    }
}
