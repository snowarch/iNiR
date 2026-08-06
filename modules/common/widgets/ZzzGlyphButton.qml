pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import QtQuick

// Interactive square glyph carrier — the clickable sibling of ZzzGlyphBadge.
// For dense ZZZ action rows: a manufactured square plate with a corner cut, a
// Material symbol, and hover/down/selected signal states. Use ZzzGlyphBadge for
// purely decorative carriers and this when the carrier is actionable.
Rectangle {
    id: root

    property string symbol: ""
    property bool selected: false
    property int badgeSize: 30
    property color accentColor: Appearance.zzz.sticker
    property color activeColor: Appearance.zzz.signal
    property var downAction
    property var releaseAction
    property var altAction

    readonly property bool _engaged: root.selected || mouseArea.containsPress
    readonly property bool _lit: root._engaged || mouseArea.containsMouse

    implicitWidth: badgeSize
    implicitHeight: badgeSize
    radius: Appearance.zzz.cornerRadius
    color: root._engaged ? root.activeColor
        : root._lit ? root.accentColor
        : ColorUtils.transparentize(root.accentColor, 0.82)
    border.width: Appearance.zzz.borderThick
    border.color: root._engaged ? root.activeColor : root.accentColor
    clip: true

    Behavior on color {
        enabled: Appearance.animationsEnabled
        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }
    Behavior on border.color {
        enabled: Appearance.animationsEnabled
        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }
    Behavior on border.width {
        enabled: Appearance.animationsEnabled
        NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }
    Behavior on radius {
        enabled: Appearance.animationsEnabled
        NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }

    MaterialSymbol {
        anchors.centerIn: parent
        text: root.symbol
        iconSize: Math.round(root.badgeSize * 0.6)
        color: root._engaged ? Appearance.zzz.onSignal
            : root._lit ? Appearance.zzz.onSticker
            : root.accentColor
    }

    // Corner cut cue.
    Rectangle {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: Math.round(root.badgeSize * 0.42)
        height: Appearance.zzz.borderThick
        rotation: -45
        color: root._engaged ? Appearance.zzz.onSignal : Appearance.zzz.borderColor
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: (event) => {
            if (event.button === Qt.RightButton) { if (root.altAction) root.altAction(event); return }
            if (root.downAction) root.downAction()
        }
        onReleased: (event) => {
            if (event.button === Qt.LeftButton && root.releaseAction) root.releaseAction()
        }
    }
}
