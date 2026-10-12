pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.services
import qs.modules.common
import qs.modules.iris.style
import "../components"
import "../parts"

// AIRISU's lock (board Lock): a 2.39 letterbox over the dimmed scene, mono slates in the bars, the insignia over the
// license plate, the key row «CLAVE │ ●●● │ ❯❯», the session's name at the lower right and a ticker of the machine
// along the bottom bar. IrisLockSurface keeps the session lock, the scene behind it and the submit; this is the stage.
Item {
    id: root
    property var context
    signal submitted()
    readonly property alias input: key
    readonly property real d: Airisu.d
    readonly property real bar: Math.max(Math.round(56 * root.d), Math.round((root.height - root.width / 2.39) / 2))
    readonly property bool failing: root.context?.showFailure ?? false
    readonly property bool busy: root.context?.unlockInProgress ?? false

    // The scene behind, held down to night: lacquer over it, the letterbox bars solid.
    Rectangle { anchors.fill: parent; color: Airisu.lacquer; opacity: 0.8 } // iris-literal: the night grade over the scene
    Rectangle { width: parent.width; height: root.bar; color: Airisu.lacquer }
    Rectangle { width: parent.width; height: root.bar; y: parent.height - height; color: Airisu.lacquer }

    component Slate: AText { voice: "mono"; color: Airisu.quiet }

    // Top bar: what is filming.
    Item {
        width: parent.width
        height: root.bar
        Slate { x: Math.round(56 * root.d); anchors.verticalCenter: parent.verticalCenter; text: "REC ● 2.39:1" }
        Slate {
            anchors.centerIn: parent
            text: `${SystemInfo.hostname || SystemInfo.distroName} / ${Translation.tr("Session locked")}`
        }
        Slate {
            anchors.right: parent.right
            anchors.rightMargin: Math.round(56 * root.d)
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.locale().toString(DateTime.clock.date, "ddd d MMM")
        }
    }

    // Night view, standing at the left: an ornament, faint.
    Column {
        x: Math.round(96 * root.d)
        anchors.verticalCenter: parent.verticalCenter
        Repeater {
            model: ["夜", "景"]
            Text {
                required property string modelData
                text: modelData
                font.family: "Noto Sans CJK JP"
                font.weight: Font.Black
                font.pixelSize: Math.round(116 * root.d)
                color: Airisu.gofun
                opacity: 0.1 // iris-literal: an ornament, never information
                lineHeight: 0.92
                renderType: Text.NativeRendering
            }
        }
    }

    Column {
        id: centre
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -Math.round(24 * root.d)
        spacing: Math.round(36 * root.d)

        Insignia {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.round(78 * root.d); height: width
        }
        ALicense {
            anchors.horizontalCenter: parent.horizontalCenter
            plateWidth: Math.min(Math.round(636 * root.d), root.width - Math.round(64 * root.d))
        }
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Math.round(18 * root.d)
            // The key row: its name, the dots, the seal. A wrong key shakes it three times, four pixels.
            Item {
                id: row
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.round(460 * root.d)
                height: Math.round(56 * root.d)
                property real shake: 0
                transform: Translate { x: row.shake }
                SequentialAnimation {
                    id: negation
                    loops: 3
                    NumberAnimation { target: row; property: "shake"; to: 4 * root.d; duration: 40 }
                    NumberAnimation { target: row; property: "shake"; to: -4 * root.d; duration: 60 }
                    NumberAnimation { target: row; property: "shake"; to: 0; duration: 40 }
                }
                Connections {
                    target: root.context
                    ignoreUnknownSignals: true
                    function onShowFailureChanged(): void { if (root.context.showFailure && IrisStyle.motionEnabled) negation.restart() }
                }
                Rectangle {
                    anchors.fill: parent
                    anchors.rightMargin: seal.width
                    color: Airisu.lacquer
                    border.width: Airisu.line
                    border.color: root.failing ? Airisu.amber : Airisu.fillet
                }
                AText {
                    id: label
                    width: Math.round(80 * root.d)
                    height: parent.height
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    voice: "mono"
                    color: Airisu.data
                    text: Translation.tr("Password")
                }
                ARule { vertical: true; x: label.width; height: parent.height }
                TextInput {
                    id: key
                    anchors.left: label.right
                    anchors.leftMargin: Math.round(20 * root.d)
                    anchors.right: seal.left
                    anchors.rightMargin: Math.round(16 * root.d)
                    anchors.verticalCenter: parent.verticalCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "●"
                    font.family: Airisu.mono
                    font.pixelSize: IrisStyle.typeBody
                    font.letterSpacing: Math.round(6 * root.d)
                    color: Airisu.gofun
                    selectionColor: Airisu.seal
                    clip: true
                    focus: true
                    enabled: !root.busy
                    text: root.context?.currentText ?? ""
                    onTextChanged: if (root.context && root.context.currentText !== key.text) root.context.currentText = key.text
                    onAccepted: root.submitted()
                    cursorDelegate: Rectangle { width: Math.round(2 * root.d); color: Airisu.seal; visible: key.activeFocus }
                }
                ASeal {
                    id: seal
                    anchors.right: parent.right
                    width: parent.height
                    height: parent.height
                    opacity: root.busy ? 0.6 : 1
                    onClicked: root.submitted()
                    AChevrons {
                        anchors.centerIn: parent
                        colour: Airisu.inkOnSeal
                        running: root.busy
                    }
                }
            }
            AText {
                anchors.horizontalCenter: parent.horizontalCenter
                voice: "mono"
                color: root.failing ? Airisu.amber : Airisu.quiet
                text: root.busy ? Translation.tr("Unlocking…") : root.failing ? Translation.tr("Incorrect password") : Translation.tr("Type your password")
            }
        }
    }

    // Who is behind the glass.
    Column {
        anchors.right: parent.right
        anchors.rightMargin: Math.round(64 * root.d)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.bar + Math.round(36 * root.d)
        spacing: Math.round(2 * root.d)
        Slate { anchors.right: parent.right; text: Translation.tr("Session") }
        AText {
            anchors.right: parent.right
            voice: "wide"
            size: IrisStyle.typeDisplay + Math.round(4 * IrisStyle.typeScale)
            text: `[${SystemInfo.username}]`
        }
    }

    // Bottom bar: the machine, as a ticker of slates.
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height - root.bar + Math.round((root.bar - height) / 2)
        spacing: Math.round(28 * root.d)
        readonly property var player: MprisController.activePlayer ?? null
        readonly property var items: [
            Battery.available ? `BAT ${Math.round(Battery.percentage * 100)}%` : "",
            Network.ethernet ? Translation.tr("Ethernet") : Network.networkName.length > 0 ? `Wi-Fi ${Network.networkName}` : "",
            String(Weather.data?.temp ?? "").startsWith("--") ? "" : `${Weather.data?.temp ?? ""} ${Weather.visibleCity ?? ""}`.trim(),
            (Notifications.list?.length ?? 0) > 0 ? `${Notifications.list.length} ${Translation.tr("Notifications")}` : "",
            player ? `● ${Translation.tr("Playing")} ${MprisController.titleOf(player)}` : "",
            `${Translation.tr("Uptime")} ${DateTime.uptime}`
        ].filter(item => item.length > 0)
        Repeater {
            model: parent.items
            Row {
                required property string modelData
                required property int index
                spacing: Math.round(28 * root.d)
                Slate { visible: index > 0; text: "·" }
                Slate {
                    width: Math.min(implicitWidth, Math.round(320 * root.d))
                    text: modelData
                    color: modelData.startsWith("●") ? Airisu.sealText : Airisu.data
                }
            }
        }
    }
}
