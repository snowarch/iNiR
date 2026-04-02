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
    property real tileSize: 70
    readonly property bool compact: tileSize < 56
    opacity: element.type != "empty" ? 1 : 0
    implicitHeight: tileSize
    implicitWidth: tileSize
    buttonRadius: Appearance.rounding.small

    // Track if element was just copied
    property bool justCopied: false

    // Tooltip with detailed element information (Requirements: 5.1)
    PopupToolTip {
        id: elementTooltip
        delay: 300
        extraVisibleCondition: root.element.type !== "empty"
        anchorEdges: Edges.Top
        contentItem: ElementTooltip {
            element: root.element
            shown: false
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

    // Atomic number — top-left
    StyledText {
        id: elementNumber
        visible: !root.compact
        anchors {
            top: parent.top
            left: parent.left
            topMargin: 3
            leftMargin: 4
        }
        color: root.textColor
        text: root.element.number
        font.pixelSize: Math.max(8, root.tileSize * 0.14)
        opacity: 0.8
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
        anchors.verticalCenterOffset: root.compact ? 0 : -2
        color: root.textColor
        font.pixelSize: Math.max(10, root.tileSize * 0.32)
        font.weight: Font.DemiBold
        text: root.element.symbol
    }

    StyledText {
        id: elementName
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: root.compact ? 2 : 4
        }
        font.pixelSize: Math.max(7, root.tileSize * 0.13)
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
            iconSize: Math.max(8, root.tileSize * 0.16)
            color: root.textColor
        }

        StyledText {
            text: Translation.tr("Copied")
            font.pixelSize: Math.max(7, root.tileSize * 0.13)
            color: root.textColor
        }
    }
}
