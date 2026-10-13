pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import "../components"

// AIRISU's timers: a bank of three instruments side by side, parted by hairlines. Each is its name in the data face's
// capitals, its time as a figure leaning, how far it has run as a ladder of steps, and its seal box, stamped while it
// runs (the only seal on the widget). A tap starts or holds it, a right tap sets it back; the wheel sets a countdown at
// rest. The engine's face keeps the timers and their service.
Item {
    id: root
    property var face
    readonly property bool small: root.face?.small ?? true
    function dp(v: real): real { return root.face ? root.face.dp(v) : Math.round(v) }
    function px(v: real): real { return root.face ? root.face.px(v) : Math.round(v) }
    readonly property int pad: root.dp(14)
    readonly property var timers: root.small ? [root.face?.lead].filter(t => t) : (root.face?.timers ?? [])

    AStock {
        id: stock
        anchors.fill: parent
        face: root.face
        subject: "time"
    }
    Row {
        x: root.pad
        y: root.pad
        width: root.width - 2 * root.pad
        height: root.height - 2 * root.pad
        Repeater {
            model: root.timers
            Item {
                id: bank
                required property var modelData
                required property int index
                readonly property bool live: root.face ? root.face.live(bank.modelData) : false
                width: Math.floor(parent.width / Math.max(1, root.timers.length))
                height: parent.height
                Rectangle {
                    visible: bank.index > 0
                    width: Airisu.hair
                    height: parent.height
                    color: stock.inkThird
                    antialiasing: false
                }
                Item {
                    id: inside
                    x: bank.index > 0 ? root.dp(10) : 0
                    width: parent.width - x - root.dp(6)
                    height: parent.height
                    AText {
                        width: parent.width - seal.width - root.dp(4)
                        voice: "mono"
                        size: IrisStyle.typeCaption
                        color: stock.inkSecond
                        text: String(bank.modelData.label ?? "")
                    }
                    ASeal {
                        id: seal
                        anchors.right: parent.right
                        width: root.dp(11)
                        height: width
                        stamped: bank.live
                        rule: stock.inkThird
                    }
                    AText {
                        y: root.dp(22)
                        width: parent.width
                        voice: "figure"
                        lean: Airisu.lean
                        size: root.px(root.small ? 40 : 30)
                        fontSizeMode: Text.HorizontalFit
                        minimumPixelSize: IrisStyle.typeLabel
                        color: bank.modelData.running || bank.modelData.paused ? stock.ink : stock.inkSecond
                        text: String(bank.modelData.value ?? "")
                    }
                    ASteps {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: root.dp(10)
                        rising: false
                        zoned: false
                        value: Number(bank.modelData.progress ?? 0)
                        ink: stock.ink
                    }
                }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onTapped: (point, button) => button === Qt.RightButton ? root.face?.reset(bank.modelData.key) : root.face?.toggle(bank.modelData.key)
                }
                WheelHandler {
                    enabled: bank.modelData.key === "countdown" && !bank.modelData.running
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => TimerService.adjustCountdownDuration(event.angleDelta.y > 0 ? 60 : -60)
                }
            }
        }
    }
}
