pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services

// On-screen keyboard for lock screen password entry.
// Designed for touch and tablet users. Connects via signals -- the lock surface
// wires keyClicked/backspaceClicked/enterClicked to its TextInput.
// Exposes theme properties so both ii (Appearance) and waffle (Looks) can use it.
Rectangle {
    id: kbd
    height: 290
    radius: kbd.themeRounding
    color: kbd.themeBgColor
    border.color: ColorUtils.transparentize(kbd.themeTextColor, 0.88)
    border.width: 1

    signal keyClicked(string key)
    signal backspaceClicked()
    signal enterClicked()
    signal closeRequested()

    property bool showSymbols: false
    property bool isShifted: false

    // The session's keyboard layout (synced from the compositor), labelled by xkbcommon: the keys type
    // the letters the person's own keyboard types, and a layout's extra letters (ñ, ü, ج…) get keys.
    readonly property string xkbLayout: Config.options?.osk?.layout ?? ""
    property var xkbKeys: ({})
    property var xkbCombine: ({})
    property var xkbLetters: []
    property string xkbLayoutShort: ""
    // A dead key waits for the next letter and joins it (´ then e → é), as the physical keyboard does.
    property string pendingMark: ""
    property string pendingSpacing: ""

    // The US letters and the ?123 symbols by key position, used until xkbcommon answers (or without it).
    readonly property var usLetter: ({ 16: "q", 17: "w", 18: "e", 19: "r", 20: "t", 21: "y", 22: "u", 23: "i", 24: "o", 25: "p",
        30: "a", 31: "s", 32: "d", 33: "f", 34: "g", 35: "h", 36: "j", 37: "k", 38: "l",
        44: "z", 45: "x", 46: "c", 47: "v", 48: "b", 49: "n", 50: "m" })
    readonly property var usSymbol: ({ 16: "1", 17: "2", 18: "3", 19: "4", 20: "5", 21: "6", 22: "7", 23: "8", 24: "9", 25: "0",
        30: "@", 31: "#", 32: "$", 33: "%", 34: "&", 35: "-", 36: "+", 37: "(", 38: ")",
        44: "*", 45: "\"", 46: "'", 47: ":", 48: ";", 49: "!", 50: "?" })

    function rowCodes(base, extra): var {
        return base.concat(extra.filter(code => kbd.xkbLetters.indexOf(code) >= 0))
    }
    function pressKey(code, level, shown): void {
        const text = shown.replace("\u25cc", "")
        const marks = code >= 0 ? kbd.xkbCombine[String(code)] : undefined
        const mark = marks ? (marks[level] || "") : ""
        if (mark.length > 0) {
            const repeated = kbd.pendingMark === mark
            if (kbd.pendingMark.length > 0)
                kbd.keyClicked(kbd.pendingSpacing)
            if (repeated) { // ´ ´ types one ´, like xkb's compose table
                kbd.pendingMark = ""
                return
            }
            kbd.pendingMark = mark
            kbd.pendingSpacing = text
            return
        }
        if (kbd.pendingMark.length > 0) {
            const composed = (text + kbd.pendingMark).normalize("NFC")
            kbd.keyClicked(text === " " ? kbd.pendingSpacing
                : composed.length === text.length ? composed : kbd.pendingSpacing + text)
            kbd.pendingMark = ""
            return
        }
        kbd.keyClicked(text)
    }

    onXkbLayoutChanged: loadLayout()
    Component.onCompleted: loadLayout()
    function loadLayout(): void {
        kbd.xkbKeys = ({})
        kbd.xkbCombine = ({})
        kbd.xkbLetters = []
        kbd.xkbLayoutShort = ""
        kbd.pendingMark = ""
        if (kbd.xkbLayout.length === 0)
            return
        labelProc.running = false
        labelProc.command = ["/usr/bin/env", "python3", Quickshell.shellPath("scripts/osk-layout-labels.py"), kbd.xkbLayout]
        labelProc.running = true
    }

    Process {
        id: labelProc
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim().length === 0)
                    return // stopped for a newer layout
                try {
                    const labels = JSON.parse(text)
                    if (!labels.keys)
                        return
                    kbd.xkbKeys = labels.keys
                    kbd.xkbCombine = labels.combine ?? ({})
                    kbd.xkbLetters = labels.letters ?? []
                    kbd.xkbLayoutShort = String(labels.layout ?? "").toUpperCase()
                } catch (e) {
                    console.warn("[LockKeyboard] could not read key labels for", kbd.xkbLayout, e)
                }
            }
        }
    }

    // Theme properties — defaults are ii (Appearance). Override for waffle (Looks).
    property color themeBgColor: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.06)
    property color themeKeySurfaceColor: Appearance.colors.colLayer1
    property color themeTextColor: Appearance.colors.colOnSurface
    property color themeSubtextColor: Appearance.colors.colOnSurfaceVariant
    property color themeAccentColor: Appearance.colors.colPrimary
    property color themeAccentActiveColor: Appearance.colors.colPrimaryActive
    property color themeAccentTextColor: Appearance.colors.colOnPrimary
    property real themeRounding: Appearance.rounding.large
    property real themeKeyRounding: Appearance.rounding.small
    property int themeAnimDuration: Appearance.animation.elementMoveFast.duration
    property real themeFontSize: Appearance.font.pixelSize.normal
    property real themeFontSizeLarge: Appearance.font.pixelSize.large
    property real themeFontSizeSmall: Appearance.font.pixelSize.smaller
    property string themeFontFamily: Appearance.font.family.main

    component KeyButton: Rectangle {
        id: keyBtn
        property int code: -1
        property string label: ""
        property string shiftLabel: label.toUpperCase()
        property string symLabel: ""
        property real keyWidth: 1
        readonly property var xkb: code >= 0 ? kbd.xkbKeys[String(code)] : undefined
        readonly property string plainText: xkb ? (xkb[0] || xkb[1]) : label
        readonly property string shiftText: xkb ? (xkb[1] || xkb[0]) : shiftLabel
        readonly property bool symbolMode: kbd.showSymbols && symLabel.length > 0
        readonly property string shown: symbolMode ? symLabel : kbd.isShifted ? shiftText : plainText

        Layout.fillHeight: true
        Layout.fillWidth: true
        Layout.preferredWidth: keyWidth

        color: keyArea.pressed
            ? ColorUtils.transparentize(kbd.themeTextColor, 0.7)
            : ColorUtils.transparentize(kbd.themeKeySurfaceColor, 0.2)
        radius: kbd.themeKeyRounding

        Behavior on color {
            ColorAnimation { duration: kbd.themeAnimDuration }
        }

        Text {
            anchors.centerIn: parent
            text: keyBtn.shown
            color: kbd.themeTextColor
            font.pixelSize: kbd.themeFontSize
            font.weight: Font.Medium
            font.family: kbd.themeFontFamily
        }

        MouseArea {
            id: keyArea
            anchors.fill: parent
            onClicked: {
                kbd.pressKey(keyBtn.symbolMode ? -1 : keyBtn.code, kbd.isShifted ? 1 : 0, keyBtn.shown)
                if (kbd.isShifted) kbd.isShifted = false
            }
        }
    }

    component FuncButton: Rectangle {
        id: funcBtn
        property string icon: ""
        property string textLabel: ""
        property var action: null
        property bool active: false
        property bool isEnter: false
        property real keyWidth: isEnter ? 2.2 : 1.6

        Layout.fillHeight: true
        Layout.fillWidth: true
        Layout.preferredWidth: keyWidth

        color: (funcBtn.active || funcBtn.isEnter)
            ? (funcArea.pressed ? kbd.themeAccentActiveColor : kbd.themeAccentColor)
            : (funcArea.pressed
                ? ColorUtils.transparentize(kbd.themeTextColor, 0.7)
                : ColorUtils.transparentize(kbd.themeKeySurfaceColor, 0.3))
        radius: kbd.themeKeyRounding

        Behavior on color {
            ColorAnimation { duration: kbd.themeAnimDuration }
        }

        Text {
            anchors.centerIn: parent
            text: funcBtn.icon !== "" ? funcBtn.icon : funcBtn.textLabel
            color: (funcBtn.active || funcBtn.isEnter) ? kbd.themeAccentTextColor : kbd.themeTextColor
            font.pixelSize: funcBtn.isEnter ? kbd.themeFontSize : kbd.themeFontSizeLarge
            font.weight: Font.Medium
            font.family: kbd.themeFontFamily
        }

        MouseArea {
            id: funcArea
            anchors.fill: parent
            onClicked: if (funcBtn.action) funcBtn.action()
        }
    }

    ColumnLayout {
        anchors { fill: parent; margins: 10 }
        spacing: 5

        // Header: label + close
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            spacing: 0

            Text {
                text: kbd.xkbLayoutShort.length > 0 ? Translation.tr("Virtual Keyboard") + " · " + kbd.xkbLayoutShort : Translation.tr("Virtual Keyboard")
                font.pixelSize: kbd.themeFontSizeSmall
                font.family: kbd.themeFontFamily
                color: kbd.themeSubtextColor
                Layout.fillWidth: true
                Layout.leftMargin: 4
            }

            Rectangle {
                width: 28; height: 28
                radius: kbd.themeKeyRounding
                color: closeHover.containsMouse
                    ? ColorUtils.transparentize(kbd.themeTextColor, 0.85)
                    : "transparent"

                Behavior on color {
                    ColorAnimation { duration: kbd.themeAnimDuration }
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "close"
                    iconSize: 16
                    color: closeHover.containsMouse
                        ? kbd.themeTextColor
                        : kbd.themeSubtextColor
                }

                MouseArea {
                    id: closeHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: kbd.closeRequested()
                }
            }
        }

        // Row 1: qwertyuiop, plus the layout's letters to its right (ج د, ü…)
        RowLayout { spacing: 4; Layout.fillWidth: true; Layout.fillHeight: true
            Repeater {
                model: kbd.rowCodes([16, 17, 18, 19, 20, 21, 22, 23, 24, 25], [26, 27])
                KeyButton { required property int modelData; code: modelData; label: kbd.usLetter[modelData] ?? ""; symLabel: kbd.usSymbol[modelData] ?? "" }
            }
        }

        // Row 2: asdfghjkl (inset), plus ñ, ö ä, ك ط ذ…
        RowLayout { spacing: 4; Layout.fillWidth: true; Layout.fillHeight: true
            Item { Layout.preferredWidth: 0.5; Layout.fillWidth: true }
            Repeater {
                model: kbd.rowCodes([30, 31, 32, 33, 34, 35, 36, 37, 38], [39, 40, 41])
                KeyButton { required property int modelData; code: modelData; label: kbd.usLetter[modelData] ?? ""; symLabel: kbd.usSymbol[modelData] ?? "" }
            }
            Item { Layout.preferredWidth: 0.5; Layout.fillWidth: true }
        }

        // Row 3: shift + zxcvbnm + backspace
        RowLayout { spacing: 4; Layout.fillWidth: true; Layout.fillHeight: true
            FuncButton { icon: "\u21E7"; active: kbd.isShifted; action: function() { kbd.isShifted = !kbd.isShifted } }
            Repeater {
                model: kbd.rowCodes([44, 45, 46, 47, 48, 49, 50], [51, 52, 53])
                KeyButton { required property int modelData; code: modelData; label: kbd.usLetter[modelData] ?? ""; symLabel: kbd.usSymbol[modelData] ?? "" }
            }
            FuncButton { icon: "\u232B"; action: function() { kbd.pendingMark = ""; kbd.backspaceClicked() } }
        }

        // Row 4: ?123 / space / enter
        RowLayout { spacing: 4; Layout.fillWidth: true; Layout.fillHeight: true
            FuncButton { textLabel: "?123"; active: kbd.showSymbols; action: function() { kbd.showSymbols = !kbd.showSymbols } }
            KeyButton { label: ","; symLabel: ","; keyWidth: 1 }
            KeyButton { label: " "; symLabel: " "; keyWidth: 4.5 }
            KeyButton { label: "."; symLabel: "."; keyWidth: 1 }
            FuncButton { icon: "\u23CE"; isEnter: true; action: function() { kbd.enterClicked() } }
        }
    }
}
