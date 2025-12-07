import QtQuick
import qs
import qs.services
import qs.modules.common
import qs.modules.waffle.looks

Rectangle {
    id: root
    implicitWidth: 6
    implicitHeight: parent.height
    color: hoverArea.containsMouse ? Looks.colors.bg1 : "transparent"

    readonly property bool hoverPeekEnabled: Config.options?.waffles?.bar?.desktopPeek?.hoverPeek ?? false
    readonly property int hoverDelay: Config.options?.waffles?.bar?.desktopPeek?.hoverDelay ?? 500
    property bool isPeeking: false

    Behavior on color { animation: Looks.transition.color.createObject(this) }

    Timer {
        id: peekTimer
        interval: root.hoverDelay
        onTriggered: {
            if (hoverArea.containsMouse) {
                root.isPeeking = true
                if (CompositorService.isNiri) {
                    NiriService.toggleOverview()
                } else {
                    GlobalStates.overviewOpen = true
                }
            }
        }
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true

        onEntered: {
            if (root.hoverPeekEnabled) {
                peekTimer.start()
            }
        }

        onExited: {
            peekTimer.stop()
            if (root.isPeeking) {
                if (CompositorService.isNiri) {
                    NiriService.toggleOverview()
                } else {
                    GlobalStates.overviewOpen = false
                }
                root.isPeeking = false
            }
        }

        onClicked: {
            peekTimer.stop()
            if (root.isPeeking) {
                root.isPeeking = false
                // Already showing, click toggles off
            } else {
                if (CompositorService.isNiri) {
                    NiriService.toggleOverview()
                } else {
                    GlobalStates.overviewOpen = !GlobalStates.overviewOpen
                }
            }
        }
    }

    BarToolTip {
        extraVisibleCondition: hoverArea.containsMouse
        text: Translation.tr("Show desktop")
    }
}
