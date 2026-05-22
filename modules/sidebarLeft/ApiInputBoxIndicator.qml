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
    property var clickAction: null
    readonly property bool interactive: !!clickAction
    implicitHeight: rowLayout.implicitHeight + 4 * 2
    implicitWidth: rowLayout.implicitWidth + 4 * 2

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.small
        color: indicatorMA.containsMouse && root.interactive
            ? Appearance.colors.colLayer2 : "transparent"
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
            color: Appearance.m3colors.m3onSurfaceVariant
        }
        StyledText {
            id: providerName
            visible: root.text.length > 0
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.m3colors.m3onSurface
            elide: Text.ElideRight
            text: root.text
            animateChange: true
        }
        MaterialSymbol {
            visible: root.interactive
            text: "expand_more"
            iconSize: Appearance.font.pixelSize.small
            color: Appearance.m3colors.m3onSurfaceVariant
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
