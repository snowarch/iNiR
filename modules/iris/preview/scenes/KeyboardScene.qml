pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.preview.parts

// The keyboard as Niri reads it: the layouts you type in, the key your shortcuts hold, and a held key repeating at the
// delay and speed set below; the pointer at its size.
PreviewScene {
    id: keysRoot
    readonly property var layouts: String(keysRoot.niri("input", "keyboard.layout", "us")).split(",").map(code => code.trim()).filter(code => code.length > 0)
    readonly property int delay: Math.max(100, Number(keysRoot.niri("input", "keyboard.repeat-delay", 600)))
    readonly property int rate: Math.max(1, Number(keysRoot.niri("input", "keyboard.repeat-rate", 25)))
    readonly property string mod: String(keysRoot.niri("input", "mod-key", "Super"))
    readonly property real cursorSize: Math.max(16, Math.min(64, Number(keysRoot.niri("input", "cursor.xcursor-size", 24))))
    readonly property real naturalWidth: Math.round(600 * keysRoot.d)
    readonly property real naturalHeight: Math.round(280 * keysRoot.d)

    component Keycap: Rectangle {
        id: cap
        property string label: ""
        property bool held: false
        implicitWidth: Math.max(Math.round(52 * keysRoot.d), capText.implicitWidth + Math.round(28 * keysRoot.d))
        implicitHeight: Math.round(52 * keysRoot.d)
        radius: IrisStyle.radiusTile
        color: cap.held ? IrisStyle.tintFill(IrisStyle.accent) : IrisStyle.fill
        border.width: cap.held ? 1 : 0
        border.color: IrisStyle.tintBorder(IrisStyle.accent)
        // The key's lip: the same body a step down.
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 1
            height: Math.round(4 * keysRoot.d)
            radius: cap.radius
            color: IrisStyle.fillQuiet
        }
        IrisText {
            id: capText
            anchors.centerIn: parent
            text: cap.label
            color: cap.held ? IrisStyle.accent : IrisStyle.text
            font.weight: IrisStyle.weight(Font.DemiBold)
        }
    }

    property bool repeating: false
    Plate {
        surface: "cards"
        anchors.centerIn: parent
        width: keysColumn.implicitWidth + Math.round(48 * keysRoot.d)
        height: keysColumn.implicitHeight + Math.round(40 * keysRoot.d)
        radius: IrisStyle.radiusPlate
    }
    Column {
        id: keysColumn
        anchors.centerIn: parent
        spacing: Math.round(16 * keysRoot.d)

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Math.round(8 * keysRoot.d)
            Repeater {
                model: keysRoot.layouts.slice(0, 3)
                Rectangle {
                    id: layoutChip
                    required property string modelData
                    required property int index
                    width: layoutText.implicitWidth + Math.round(24 * keysRoot.d)
                    height: Math.round(30 * keysRoot.d)
                    radius: height / 2
                    color: layoutChip.index === 0 ? IrisStyle.tintFill(IrisStyle.accent) : IrisStyle.fillQuiet
                    IrisText {
                        id: layoutText
                        anchors.centerIn: parent
                        text: layoutChip.modelData.toUpperCase()
                        color: layoutChip.index === 0 ? IrisStyle.accent : IrisStyle.subtext
                        font.family: IrisStyle.fontNumbers
                        font.weight: IrisStyle.weight(Font.DemiBold)
                    }
                }
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Math.round(8 * keysRoot.d)
            Keycap { label: keysRoot.mod; held: true }
            IrisText { anchors.verticalCenter: parent.verticalCenter; text: "+"; color: IrisStyle.subtext }
            Keycap { id: repeatKey; label: "A"; held: keysRoot.repeating }
        }

        // A held key: the first letter, a pause as long as the delay, then the repeats at the speed set.
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.round(320 * keysRoot.d)
            height: Math.round(40 * keysRoot.d)
            radius: height / 2
            color: IrisStyle.fillQuiet
            clip: true
            IrisText {
                id: typedText
                property int count: 0
                anchors.verticalCenter: parent.verticalCenter
                x: Math.round(16 * keysRoot.d)
                width: parent.width - 2 * x
                elide: Text.ElideLeft
                text: "a".repeat(typedText.count) + "▏"
                font.family: IrisStyle.fontNumbers
            }
            SequentialAnimation {
                id: typed
                running: keysRoot.playing
                loops: Animation.Infinite
                ScriptAction { script: { typedText.count = 1; keysRoot.repeating = true } }
                PauseAnimation { duration: keysRoot.delay }
                NumberAnimation { target: typedText; property: "count"; from: 1; to: 1 + Math.round(keysRoot.rate * 1.2); duration: 1200 }
                ScriptAction { script: keysRoot.repeating = false }
                PauseAnimation { duration: 900 }
                ScriptAction { script: typedText.count = 0 }
                PauseAnimation { duration: 500 }
            }
        }
    }

    MaterialSymbol {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Math.round(26 * keysRoot.d)
        text: "arrow_selector_tool"
        fill: 1
        iconSize: Math.round(keysRoot.cursorSize * keysRoot.d)
        color: IrisStyle.onMedia
    }

    Caption {
        glyph: "keyboard"
        text: [keysRoot.layouts.join(", ").toUpperCase(), Translation.tr("Repeat after") + " " + keysRoot.delay + " ms",
            keysRoot.rate + " /s"].join(" · ")
    }
}
