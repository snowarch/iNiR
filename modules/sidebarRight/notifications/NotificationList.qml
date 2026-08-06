import qs.modules.common
import qs.modules.common.widgets
import qs.services
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Item {
    id: root
    clip: true

    // Collapsed: only the status row stays visible; the empty-state area is
    // released so the sidebar can shrink around its remaining widgets.
    property bool collapsed: false
    implicitHeight: statusRow.implicitHeight

    Component.onCompleted: Notifications.ensureInitialized()

    NotificationListView { // Scrollable window
        id: listview
        visible: !root.collapsed
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: statusRow.top
        anchors.bottomMargin: 5

        clip: true
        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: listview.width
                height: listview.height
                radius: 0
            }
        }

        popup: false
    }

    Item {
        id: emptyState
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            bottom: statusRow.top
            topMargin: 24
            bottomMargin: 28
        }
        visible: opacity > 0
        opacity: (listview.count === 0 && !root.collapsed) ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.animation.elementMoveEnter.duration
                easing.type: Appearance.animation.elementMoveEnter.type
                easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 4
            visible: !emptyMascot.active

            MaterialPlaceholderMessage {
                Layout.alignment: Qt.AlignHCenter
                icon: "notifications_active"
                shape: MaterialShape.Shape.Ghostish
                text: Notifications.silent ? Translation.tr("Muted") : Translation.tr("All caught up")
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 4
            visible: emptyMascot.active

            MascotImage {
                id: emptyMascot
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 128
                Layout.preferredHeight: 128
                surface: "notifications"
                fallbackSurface: "emptyStates"
                pose: "cleanup-sweep-loop"
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Notifications.silent ? Translation.tr("Muted") : Translation.tr("All caught up")
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnSurface
            }
        }
    }

    ButtonGroup {
        id: statusRow
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }

        NotificationStatusButton {
            Layout.fillWidth: false
            buttonIcon: "notifications_paused"
            toggled: Notifications.silent
            onClicked: () => {
                Notifications.silent = !Notifications.silent;
            }
        }
        NotificationStatusButton {
            enabled: false
            Layout.fillWidth: true
            buttonText: Translation.tr("%1 notifications").arg(Notifications.list.length)
        }
        NotificationStatusButton {
            Layout.fillWidth: false
            buttonIcon: "delete_sweep"
            onClicked: () => {
                Notifications.discardAllNotifications()
            }
        }
    }
}
