pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import QtQuick.Layouts

// Reusable ZZZ poster section header: square glyph badge + Oxanium-black uppercase
// title + a registration index code (e.g. "SYS / 04"). Gives any card or section the
// game-menu header without re-deriving the boilerplate each time.
RowLayout {
    id: root

    property string title: ""
    property string symbol: ""
    property string index: ""
    property color accentColor: Appearance.zzz.accent

    spacing: 10
    visible: Appearance.zzzEverywhere

    ZzzGlyphBadge {
        Layout.alignment: Qt.AlignVCenter
        visible: root.symbol.length > 0
        symbol: root.symbol
        accentColor: root.accentColor
        inkColor: Appearance.zzz.onAccent
        badgeSize: 24
        filled: true
    }

    StyledText {
        Layout.alignment: Qt.AlignVCenter
        text: root.title.toUpperCase()
        font.family: Appearance.font.family.title
        font.pixelSize: Appearance.font.pixelSize.large
        font.weight: Font.Black
        font.italic: true
        color: Appearance.zzz.ink
        elide: Text.ElideRight
        Layout.fillWidth: true
    }

    // Registration rail tick before the index code.
    Rectangle {
        Layout.alignment: Qt.AlignVCenter
        visible: root.index.length > 0
        implicitWidth: Appearance.zzz.markerLength
        implicitHeight: Appearance.zzz.borderThick
        color: root.accentColor
    }
    StyledText {
        Layout.alignment: Qt.AlignVCenter
        visible: root.index.length > 0
        text: root.index.toUpperCase()
        font.family: Appearance.font.family.numbers
        font.pixelSize: Appearance.font.pixelSize.smaller
        font.weight: Font.Black
        color: Appearance.zzz.inkMuted
    }
}
