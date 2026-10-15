pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

/**
 * Toast content for the morphing pill body: icon tile, app eyebrow, summary
 * with critical ember dot, optional body text and action pills, dismiss glyph
 * on the right. Draws no background of its own; the pill body behind it
 * provides the washi material. Clicking the body jumps to the source app;
 * dismiss and action pills consume their clicks. Auto-expires via
 * PillNotifs.expireAt unless the notification is critical.
 */
Item {
    id: root

    property real s: 1
    property bool compact: false
    property bool live: true
    required property var notif

    /** iNiR exposes urgency as a string, not the Quickshell enum. */
    readonly property bool critical: String(notif.urgency) === "Critical"
    readonly property var acts: (notif.actions ?? [])
        .filter(action => String(action?.text ?? "").trim().length > 0)
    readonly property string iconSource: PillNotifs.iconFor(notif)
    readonly property string imageValue: String(notif.image ?? "")
    readonly property bool imageIsIconHint: imageValue.startsWith("image://icon/")
    readonly property string defaultMaterialSymbol: NotificationUtils.findSuitableMaterialSymbol("")
    readonly property string materialSymbol: NotificationUtils.findSuitableMaterialSymbol(
        `${String(notif.appName ?? "")} ${String(notif.summary ?? "")}`)
    readonly property bool preferMaterialSymbol: !notif.appIcon && imageIsIconHint
        && materialSymbol !== defaultMaterialSymbol

    implicitHeight: Math.max(iconTile.height, col.implicitHeight)

    /**
     * Deadline is snapshotted once: binding the interval to PillNotifs.expireAt
     * restarts the timer (and drifts the lifetime) every time an unrelated
     * notification replaces the map.
     */
    property double deadline: 0
    Component.onCompleted: deadline = PillNotifs.expireAt[notif.notificationId] || (Date.now() + 6000)

    Timer {
        interval: Math.max(300, root.deadline - Date.now())
        running: root.deadline > 0 && root.live && !root.critical
        onTriggered: PillNotifs.removePopup(root.notif)
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            PillNotifs.activateNotif(root.notif);
            PillNotifs.removePopup(root.notif);
        }
    }

    Rectangle {
        id: iconTile
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.topMargin: root.compact
            ? Math.max(0, (parent.height - height) / 2) : 0
        width: (root.compact ? 18 : 28) * root.s
        height: width
        radius: (root.compact ? 5 : 9) * root.s
        color: PillTheme.tileBg
        border.width: root.compact ? 0 : 1
        border.color: PillTheme.border

        Image {
            id: toastImg
            anchors.fill: parent
            anchors.margins: root.imageValue.length > 0 && !root.imageIsIconHint
                ? 0 : (root.compact ? 3 : 6) * root.s
            source: root.iconSource
            sourceSize.width: 56
            sourceSize.height: 56
            fillMode: Image.PreserveAspectCrop
            smooth: true
            visible: !root.preferMaterialSymbol && status === Image.Ready
        }

        MaterialSymbol {
            anchors.centerIn: parent
            visible: !toastImg.visible
            text: root.materialSymbol
            iconSize: (root.compact ? 12 : 17) * root.s
            color: root.critical ? PillTheme.vermLit : PillTheme.verm
        }
    }

    Text {
        id: dismiss
        anchors.right: parent.right
        anchors.top: parent.top
        visible: !root.compact
        text: "✕"
        color: dismissArea.containsMouse ? PillTheme.cream : PillTheme.dim
        font.family: PillTheme.font
        font.pixelSize: 11 * root.s

        Behavior on color {
            ColorAnimation { duration: PillMotion.fast }
        }

        MouseArea {
            id: dismissArea
            anchors.fill: parent
            anchors.margins: -6 * root.s
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: PillNotifs.removePopup(root.notif)
        }
    }

    Column {
        id: col
        anchors.left: iconTile.right
        anchors.leftMargin: (root.compact ? 6 : 10) * root.s
        anchors.right: root.compact ? parent.right : dismiss.left
        anchors.rightMargin: root.compact ? 0 : 8 * root.s
        anchors.top: parent.top
        anchors.topMargin: root.compact
            ? Math.max(0, (parent.height - implicitHeight) / 2) : 0
        spacing: root.compact ? 1 * root.s : 3 * root.s

        Text {
            width: parent.width
            visible: !root.compact
            text: (root.notif.appName && root.notif.appName.length) ? root.notif.appName : "System"
            color: PillTheme.dim
            font.family: PillTheme.font
            font.pixelSize: 10 * root.s
            font.weight: Font.DemiBold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 1.4 * root.s
            elide: Text.ElideRight
        }

        Row {
            width: parent.width
            spacing: 5 * root.s

            Item {
                visible: root.critical
                anchors.verticalCenter: parent.verticalCenter
                width: (root.compact ? 6 : 8) * root.s
                height: width

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width
                    height: width
                    radius: 999
                    color: PillTheme.flameGlow
                    opacity: 0.3
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width / 2
                    height: width
                    radius: 999
                    color: PillTheme.flameGlow
                }
            }

            Text {
                width: parent.width - (root.critical ? 13 * root.s : 0)
                text: root.notif.summary
                color: PillTheme.cream
                font.family: PillTheme.font
                font.pixelSize: (root.compact ? 10.5 : 12) * root.s
                font.weight: Font.DemiBold
                maximumLineCount: 1
                elide: Text.ElideRight
            }
        }

        Text {
            width: parent.width
            visible: !root.compact && root.notif.body.length > 0
            text: root.notif.body
            color: PillTheme.dim
            font.family: PillTheme.font
            font.pixelSize: 10.5 * root.s
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            textFormat: Text.PlainText
        }

        Row {
            visible: !root.compact && root.acts.length > 0
            spacing: 6 * root.s
            topPadding: 4 * root.s

            Repeater {
                model: root.acts

                Rectangle {
                    id: actPill
                    required property var modelData
                    required property int index

                    height: 28 * root.s
                    width: actText.implicitWidth + 22 * root.s
                    radius: 999
                    color: PillTheme.tileBg
                    border.width: 1
                    border.color: PillTheme.border

                    Text {
                        id: actText
                        anchors.centerIn: parent
                        text: actPill.modelData.text
                        color: actPill.index === 0 ? PillTheme.vermLit : PillTheme.dim
                        font.family: PillTheme.font
                        font.pixelSize: 10.5 * root.s
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            // iNiR's action objects are plain data; the server
                            // invokes them by id, they carry no invoke() of their own.
                            Notifications.attemptInvokeAction(root.notif.notificationId,
                                                              actPill.modelData.identifier);
                            if (actPill.modelData.identifier === "default")
                                PillNotifs.raiseWindow(root.notif);
                            PillNotifs.removePopup(root.notif);
                        }
                    }
                }
            }
        }
    }
}
