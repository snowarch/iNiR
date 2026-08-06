pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common
import qs.modules.common.functions

// Compact ZZZ glyph carrier: square technical badge with corner cut cue.
Rectangle {
    id: root

    property string symbol: ""
    property color accentColor: Appearance.zzz.sticker
    property color inkColor: Appearance.zzz.onSticker
    property int badgeSize: 26
    property bool filled: false

    implicitWidth: badgeSize
    implicitHeight: badgeSize
    radius: Appearance.zzz.cornerRadius
    color: root.filled ? accentColor : ColorUtils.transparentize(accentColor, 0.82)
    border.width: Appearance.zzz.borderThick
    border.color: accentColor
    clip: true

    MaterialSymbol {
        anchors.centerIn: parent
        text: root.symbol
        iconSize: Math.round(root.badgeSize * 0.62)
        color: root.filled ? root.inkColor : root.accentColor
    }
}
