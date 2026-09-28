pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property bool loading: false
    property string text: ""
    property int showDelay: 90
    property int minimumVisibleDuration: 180

    property bool _shown: false
    property bool _hidePending: false

    Layout.fillWidth: true
    Layout.preferredHeight: root._shown ? Math.max(48, loadingRow.implicitHeight + 16) : 0
    opacity: root._shown ? 1 : 0
    visible: root._shown || opacity > 0.001
    clip: true

    onLoadingChanged: {
        if (loading) {
            root._hidePending = false
            if (!root._shown)
                showDelayTimer.restart()
            return
        }

        showDelayTimer.stop()
        if (!root._shown)
            return

        if (minimumVisibleTimer.running)
            root._hidePending = true
        else
            root._shown = false
    }

    Timer {
        id: showDelayTimer
        interval: root.showDelay
        repeat: false
        onTriggered: {
            if (!root.loading)
                return
            root._shown = true
            root._hidePending = false
            minimumVisibleTimer.restart()
        }
    }

    Timer {
        id: minimumVisibleTimer
        interval: root.minimumVisibleDuration
        repeat: false
        onTriggered: {
            if (!root.loading || root._hidePending)
                root._shown = false
            root._hidePending = false
        }
    }

    Behavior on opacity {
        enabled: Appearance.animationsEnabled
        NumberAnimation {
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }
    }

    Behavior on Layout.preferredHeight {
        enabled: Appearance.animationsEnabled
        NumberAnimation {
            duration: Appearance.animation.elementResize.duration
            easing.type: Appearance.animation.elementResize.type
            easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: Appearance.editorialEverywhere
        radius: Appearance.rounding.small
        color: Appearance.editorial.layer(1)
    }

    RowLayout {
        id: loadingRow
        anchors.centerIn: parent
        width: Math.max(0, Math.min(implicitWidth, root.width - 24))
        spacing: 8

        MaterialLoadingIndicator {
            implicitSize: 26
        }

        StyledText {
            text: root.text
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.weight: Appearance.editorialEverywhere ? Font.Medium : Font.Normal
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colSubtext
        }
    }
}
