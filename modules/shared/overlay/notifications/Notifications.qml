pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.shared.overlay

// What arrived while playing, newest first, each with its actions; quiet mode, read, and clear with a moment to undo.
StyledOverlayWidget {
    id: root

    Component.onCompleted: Notifications.ensureInitialized()
    readonly property var items: Notifications.list.slice().reverse()
    // Nothing to count says itself in the body; only silence is worth the header then.
    fact: Notifications.list.length === 0 ? (Notifications.silent ? Translation.tr("Silent") : "")
        : Notifications.silent ? Translation.tr("Silent · %1 total").arg(Notifications.list.length)
        : Translation.tr("%1 unread · %2 total").arg(Notifications.unread).arg(Notifications.list.length)

    // A row's own button never removes the row inside its click.
    property var _later: null
    function later(fn: var): void {
        root._later = fn
        laterTimer.restart()
    }
    Timer {
        id: laterTimer
        interval: 0
        onTriggered: {
            const fn = root._later
            root._later = null
            if (fn) fn()
        }
    }

    // "Clear all" turns into Undo for a few seconds.
    property bool undoShown: false
    Timer {
        id: undoTimer
        interval: 6000
        onTriggered: root.undoShown = false
    }

    contentItem: Item {
        anchors.fill: parent
        implicitWidth: Math.round(320 * root.d)
        implicitHeight: Math.round(300 * root.d)

        ColumnLayout {
            anchors.fill: parent
            spacing: Math.round(8 * root.d)

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: Math.round(2 * root.d)
                boundsBehavior: Flickable.StopAtBounds
                model: ScriptModel {
                    values: root.items
                    objectProp: "notificationId"
                }
                delegate: NotificationRow {
                    width: ListView.view.width
                }

                Column {
                    anchors.centerIn: parent
                    visible: root.items.length === 0
                    spacing: Math.round(6 * root.d)
                    MaterialSymbol {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Notifications.silent ? "notifications_paused" : "notifications_active"
                        iconSize: Math.round(28 * root.d)
                        color: OverlayLook.colFaint
                    }
                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Translation.tr("All caught up")
                        color: OverlayLook.colFaint
                        font.family: OverlayLook.fontMain
                        font.pixelSize: OverlayLook.typeMeta
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Math.round(2 * root.d)
                OverlayButton {
                    glyph: "notifications_paused"
                    toggled: Notifications.silent
                    tip: Translation.tr("Do not disturb")
                    onClicked: Notifications.silent = !Notifications.silent
                }
                OverlayButton {
                    glyph: "done_all"
                    enabled: Notifications.unread > 0
                    tip: Translation.tr("Mark all as read")
                    onClicked: Notifications.markAllRead()
                }
                OverlayButton {
                    glyph: "right_panel_open"
                    tip: Translation.tr("Open notification center")
                    onClicked: {
                        GlobalStates.overlayOpen = false
                        GlobalStates.openSidebarRight("")
                    }
                }
                Item { Layout.fillWidth: true }
                OverlayButton {
                    visible: root.undoShown && Notifications.lastCleared.length > 0
                    glyph: "undo"
                    label: Translation.tr("Undo")
                    toggled: true
                    onClicked: {
                        Notifications.restoreCleared()
                        root.undoShown = false
                    }
                }
                OverlayButton {
                    visible: !(root.undoShown && Notifications.lastCleared.length > 0)
                    enabled: Notifications.list.length > 0
                    glyph: "delete_sweep"
                    label: Translation.tr("Clear all")
                    onClicked: {
                        Notifications.discardAllNotifications()
                        root.undoShown = true
                        undoTimer.restart()
                    }
                }
            }
        }
    }

    component NotificationRow: Item {
        id: row
        required property var modelData
        readonly property var notif: row.modelData
        readonly property var actions: (row.notif?.actions ?? []).filter(a => a.identifier !== "default")
        implicitHeight: body.implicitHeight + Math.round(16 * root.d)

        Rectangle {
            anchors.fill: parent
            radius: OverlayLook.roundingSmall
            color: rowHover.hovered ? OverlayLook.colLayer2Hover : row.notif?.popup ? OverlayLook.colLayer2 : "transparent"
            Behavior on color { ColorAnimation { duration: FamilyStyle.feedbackDuration } }
        }
        HoverHandler { id: rowHover }

        RowLayout {
            id: body
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Math.round(8 * root.d)
            spacing: Math.round(10 * root.d)

            NotificationAppIcon {
                Layout.alignment: Qt.AlignTop
                implicitSize: Math.round(30 * root.d)
                appIcon: row.notif?.appIcon ?? ""
                image: row.notif?.image ?? ""
                summary: row.notif?.summary ?? ""
                urgency: row.notif?.urgency ?? 1
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Math.round(1 * root.d)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Math.round(6 * root.d)
                    StyledText {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: row.notif?.appName ?? ""
                        color: OverlayLook.colSubtext
                        font.family: OverlayLook.fontMain
                        font.pixelSize: OverlayLook.typeFootnote
                        font.weight: Font.DemiBold
                    }
                    StyledText {
                        text: NotificationUtils.getFriendlyNotifTimeString(row.notif?.time ?? 0)
                        color: OverlayLook.colFaint
                        font.family: OverlayLook.fontNumbers
                        font.pixelSize: OverlayLook.typeFootnote
                    }
                }
                StyledText {
                    Layout.fillWidth: true
                    Layout.rightMargin: Math.round(22 * root.d)
                    elide: Text.ElideRight
                    text: row.notif?.summary ?? ""
                    color: OverlayLook.colOnLayer1
                    font.family: OverlayLook.fontMain
                    font.pixelSize: OverlayLook.typeBody
                    font.weight: Font.DemiBold
                }
                StyledText {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    text: NotificationUtils.processNotificationBody(row.notif?.body ?? "", row.notif?.appName ?? "").replace(/<[^>]*>/g, "")
                    color: OverlayLook.colSubtext
                    font.family: OverlayLook.fontMain
                    font.pixelSize: OverlayLook.typeMeta
                }
                Flow {
                    Layout.fillWidth: true
                    Layout.topMargin: Math.round(4 * root.d)
                    visible: row.actions.length > 0
                    spacing: Math.round(4 * root.d)
                    Repeater {
                        model: row.actions
                        OverlayButton {
                            required property var modelData
                            filled: true
                            size: Math.round(26 * root.d)
                            label: modelData.text
                            onClicked: {
                                const id = row.notif.notificationId
                                const action = modelData.identifier
                                root.later(() => Notifications.attemptInvokeAction(id, action))
                            }
                        }
                    }
                }
            }
        }

        OverlayButton {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: Math.round(4 * root.d)
            size: Math.round(24 * root.d)
            opacity: rowHover.hovered ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: FamilyStyle.feedbackDuration } }
            glyph: "close"
            tip: Translation.tr("Dismiss")
            onClicked: {
                const id = row.notif.notificationId
                root.later(() => Notifications.discardNotification(id))
            }
        }
    }
}
