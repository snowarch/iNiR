import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// A modal card over a dimmed screen, on the family's own surface (Material's panel skin in each global style).
// What it holds goes inside the card; a click outside is `dismissed`.
Item {
    id: root

    property real cardWidth: 480
    property real cardHeight: 360
    default property alias content: card.data
    readonly property bool own: FamilyStyle.p !== null

    signal dismissed()

    property real shownAt: 0
    Behavior on shownAt { NumberAnimation { duration: FamilyStyle.emergeDuration; easing.type: Easing.OutCubic } }
    Component.onCompleted: root.shownAt = 1

    Rectangle {
        anchors.fill: parent
        color: FamilyStyle.scrim
        opacity: 0.4 * root.shownAt
    }
    MouseArea {
        anchors.fill: parent
        onClicked: root.dismissed()
    }

    Item {
        id: card
        anchors.centerIn: parent
        width: Math.round(Math.min(root.width - 96, root.cardWidth))
        height: Math.round(Math.min(root.height - 96, root.cardHeight))
        opacity: root.shownAt
        scale: 0.97 + 0.03 * root.shownAt

        // Presses on the card are its own.
        MouseArea { anchors.fill: parent }

        Item {
            id: body
            anchors.fill: parent
            readonly property real radius: FamilyStyle.radiusSheet
        }
        StyledRectangularShadow {
            target: body
            visible: !root.own
        }
        Loader {
            anchors.fill: parent
            active: !root.own
            // its own layer: no compositor blur reaches it, so a glass style's fill showed the tools beneath sharp
            sourceComponent: PanelSurface {
                elevation: 2
                cardStyle: true
                opaqueSurface: true
                radiusOverride: FamilyStyle.radiusSheet
            }
        }
        Rectangle {
            anchors.fill: parent
            visible: root.own
            radius: FamilyStyle.radiusSheet
            color: FamilyStyle.bodySurface
            border.width: 1
            border.color: FamilyStyle.border
        }
    }
}
