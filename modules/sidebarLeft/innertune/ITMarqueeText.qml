import qs
import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// basicMarquee equivalent — scrolls the label horizontally when it overflows its width,
// otherwise renders static. Used for player/mini-player title and artist.
Item {
    id: root
    property string text: ""
    property alias font: label.font
    property color color: Appearance.colors.colOnSurface
    property int horizontalAlignment: Text.AlignLeft
    implicitHeight: label.implicitHeight
    clip: true

    readonly property real overflow: Math.max(0, label.implicitWidth - width)
    readonly property bool scrolling: overflow > 0 && Appearance.animationsEnabled

    StyledText {
        id: label
        text: root.text
        color: root.color
        width: root.scrolling ? implicitWidth : root.width
        horizontalAlignment: root.scrolling ? Text.AlignLeft : root.horizontalAlignment
        elide: root.scrolling ? Text.ElideNone : Text.ElideRight
        maximumLineCount: 1
        y: 0
    }

    // Back-and-forth scroll with end pauses (raw timings — a decorative loop, not a token Behavior).
    SequentialAnimation {
        running: root.scrolling && GlobalStates.sidebarLeftOpen
        loops: Animation.Infinite
        PauseAnimation { duration: 1200 }
        NumberAnimation { target: label; property: "x"; from: 0; to: -root.overflow; duration: Math.max(1, root.overflow) * 28; easing.type: Easing.InOutQuad }
        PauseAnimation { duration: 1200 }
        NumberAnimation { target: label; property: "x"; from: -root.overflow; to: 0; duration: Math.max(1, root.overflow) * 28; easing.type: Easing.InOutQuad }
        onRunningChanged: if (!running) label.x = 0
    }
}
