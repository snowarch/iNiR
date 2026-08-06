import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property string icon: "api"
    property string text: ""
    property string tooltipText: ""
    property bool showText: true
    property bool showDisclosure: true
    property real maximumTextWidth: 160
    property var clickAction: null
    readonly property bool interactive: !!clickAction
    implicitHeight: rowLayout.implicitHeight + 4 * 2
    implicitWidth: rowLayout.implicitWidth + 4 * 2

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.small
        // The chat input wrapper this sits on is painted colLayer2 under material
        // (aurora and angel give it their own surface), so a raw colLayer2 hover
        // was the same colour as its background and the state never appeared.
        color: indicatorMA.containsMouse && root.interactive
            ? Appearance.colors.colLayer2Hover : "transparent"
        Behavior on color {
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }
    }

    RowLayout {
        id: rowLayout
        anchors.centerIn: parent
        spacing: 2

        MaterialSymbol {
            text: root.icon
            iconSize: Appearance.font.pixelSize.normal
            color: Appearance.colors.colOnSurfaceVariant
        }
        StyledText {
            id: providerName
            visible: root.showText && root.text.length > 0
            Layout.minimumWidth: 0
            Layout.maximumWidth: root.maximumTextWidth
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colOnSurface
            elide: Text.ElideRight
            text: root.text
            animateChange: true
        }
        MaterialSymbol {
            visible: root.interactive && root.showDisclosure
            text: "expand_more"
            iconSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnSurfaceVariant
        }
    }

    MouseArea {
        id: indicatorMA
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (root.clickAction) root.clickAction()
        }

        StyledToolTip {
            extraVisibleCondition: false
            alternativeVisibleCondition: indicatorMA.containsMouse && (root.tooltipText?.length ?? 0) > 0
            text: root.tooltipText
        }
    }
}
