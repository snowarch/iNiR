import qs.modules.common
import qs.modules.common.functions
import QtQuick

/**
 * The text cursor every field wears (`cursorDelegate: TextCursor {}`): each time it blinks back it takes the next of
 * four colours, Google's search box turn (blue, red, yellow, green) led by the accent and kept at its tone, so the four
 * read as one set on any scheme. A custom delegate blinks on its own; Qt only places it.
 */
Rectangle {
    id: cursor

    property color accent: Appearance.colors.colPrimary
    // Google's hues as turns from its blue: red +148 deg, yellow +188, green +279
    readonly property list<color> turns: [accent, ColorUtils.atHue(accent, accent.hslHue + 148 / 360),
        ColorUtils.atHue(accent, accent.hslHue + 188 / 360), ColorUtils.atHue(accent, accent.hslHue + 279 / 360)]

    readonly property Item field: parent
    readonly property bool live: !!field && field.activeFocus && !field.readOnly
    readonly property int position: field?.cursorPosition ?? 0
    property int turn: 0

    width: 2
    radius: 1
    color: turns[turn]
    visible: live && field.selectionStart === field.selectionEnd

    // a moving cursor stays lit, in the colour it has
    onPositionChanged: {
        opacity = 1
        blink.restart()
    }

    Timer {
        id: blink
        running: cursor.live && interval > 0
        repeat: true
        interval: Application.styleHints.cursorFlashTime / 2
        onTriggered: {
            if (cursor.opacity > 0) {
                cursor.opacity = 0
            } else {
                cursor.turn = (cursor.turn + 1) % 4
                cursor.opacity = 1
            }
        }
        onRunningChanged: {
            cursor.opacity = 1
            cursor.turn = 0
        }
    }
}
