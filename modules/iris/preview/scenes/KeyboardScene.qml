pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.preview.parts

// Keyboard & Mouse: a key held down. After the repeat delay it repeats at its speed into the line above; the
// shortcut key is lit as Mod; the pointer at its size hides while you type when it is set to.
PreviewScene {
    id: keysRoot
    readonly property real naturalWidth: Math.round(600 * keysRoot.d)
    readonly property real naturalHeight: Math.round(300 * keysRoot.d)
    narrowest: Math.round(420 * keysRoot.d)
    subject: Qt.rect(board.x, board.y, board.width, board.height)
    readonly property int delay: Math.max(150, Number(keysRoot.niri("input", "keyboard.repeat-delay", 600)))
    readonly property int rate: Math.max(10, Number(keysRoot.niri("input", "keyboard.repeat-rate", 25)))
    readonly property string mod: String(keysRoot.niri("input", "mod-key", "Super"))
    readonly property int cursorSize: Number(keysRoot.niri("input", "cursor.xcursor-size", 24))
    readonly property bool hideTyping: keysRoot.niri("input", "cursor.hide-when-typing", false) === true

    // One press: the first letter at once, then nothing for the delay, then the rate. Starts over after a rest.
    property int typed: 0
    property bool holding: false
    Timer {
        id: cycle
        interval: 2600
        running: keysRoot.playing
        repeat: true
        triggeredOnStart: true
        onTriggered: { keysRoot.typed = 1; keysRoot.holding = true; hold.restart() }
    }
    Timer { id: hold; interval: keysRoot.delay; onTriggered: repeater.restart() }
    Timer {
        id: repeater
        interval: Math.round(1000 / keysRoot.rate)
        repeat: true
        onTriggered: {
            keysRoot.typed += 1
            if (keysRoot.typed >= 26) { repeater.stop(); keysRoot.holding = false }
        }
    }
    readonly property string line: "a".repeat(keysRoot.typed)

    Plate {
        id: field
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(24 * keysRoot.d)
        width: board.width
        height: Math.round(44 * keysRoot.d)
        radius: height / 2
        IrisText {
            x: Math.round(18 * keysRoot.d)
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 2 * x
            elide: Text.ElideLeft
            text: keysRoot.line + "|"
            font.family: IrisStyle.fontMono
            font.pixelSize: IrisStyle.typeLabel
        }
    }
    Plate {
        id: board
        anchors.horizontalCenter: parent.horizontalCenter
        y: field.y + field.height + Math.round(14 * keysRoot.d)
        width: Math.round(Math.min(keysRoot.width - 40 * keysRoot.d, 470 * keysRoot.d))
        height: Math.round(150 * keysRoot.d)
        radius: IrisStyle.radiusPlate
        readonly property real key: Math.round((board.width - 28 * keysRoot.d - 9 * 5 * keysRoot.d) / 10)
        Column {
            anchors.centerIn: parent
            spacing: Math.round(6 * keysRoot.d)
            Repeater {
                model: ["qwertyuiop", "asdfghjkl", "zxcvbnm"]
                Row {
                    id: keyRow
                    required property string modelData
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Math.round(6 * keysRoot.d)
                    Repeater {
                        model: keyRow.modelData.split("")
                        Rectangle {
                            id: cap
                            required property string modelData
                            readonly property bool down: cap.modelData === "a" && keysRoot.holding
                            width: board.key
                            height: Math.round(board.key * 0.78)
                            radius: Math.round(6 * keysRoot.d)
                            color: cap.down ? IrisStyle.accent : IrisStyle.fill
                            scale: cap.down ? 0.92 : 1
                            Behavior on scale { NumberAnimation { duration: IrisStyle.duration(90); easing.type: IrisStyle.feedbackEasing } }
                            IrisText {
                                anchors.centerIn: parent
                                text: cap.modelData
                                color: cap.down ? IrisStyle.inkOnAccent : IrisStyle.textSecondary
                                font.pixelSize: IrisStyle.typeMeta
                                font.weight: Font.Medium
                            }
                        }
                    }
                }
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Math.round(6 * keysRoot.d)
                Repeater {
                    model: ["Ctrl", "Super", "Alt", " ", "Alt", "Ctrl"]
                    Rectangle {
                        id: modKey
                        required property string modelData
                        required property int index
                        // The left one of the chosen key is Mod.
                        readonly property bool lit: modKey.modelData === keysRoot.mod && modKey.index < 3
                        width: modKey.modelData === " " ? board.key * 4.2 : board.key * 1.2
                        height: Math.round(board.key * 0.78)
                        radius: Math.round(6 * keysRoot.d)
                        color: modKey.lit ? Qt.rgba(IrisStyle.accent.r, IrisStyle.accent.g, IrisStyle.accent.b, 0.22) : IrisStyle.fill
                        border.width: modKey.lit ? 1 : 0
                        border.color: IrisStyle.accent
                        IrisText {
                            anchors.centerIn: parent
                            text: modKey.lit ? Translation.tr("Mod") : modKey.modelData
                            color: modKey.lit ? IrisStyle.accent : IrisStyle.textTertiary
                            font.pixelSize: IrisStyle.typeCaption
                            font.weight: modKey.lit ? Font.DemiBold : Font.Medium
                        }
                    }
                }
            }
        }
    }
    MaterialSymbol {
        x: board.x + board.width - Math.round(30 * keysRoot.d)
        y: board.y - Math.round(10 * keysRoot.d)
        text: "arrow_selector_tool"
        fill: 1
        iconSize: Math.round(keysRoot.cursorSize * 0.9 * keysRoot.d)
        color: IrisStyle.onMedia
        opacity: keysRoot.hideTyping && keysRoot.holding ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(160); easing.type: IrisStyle.feedbackEasing } }
    }
    Caption {
        glyph: "keyboard"
        text: Translation.tr("Mod is %1").arg(keysRoot.mod) + (keysRoot.hideTyping ? " · " + Translation.tr("pointer hides while typing") : "")
    }
}
