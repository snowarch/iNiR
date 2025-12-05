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

    property bool isPeeking: false

    Behavior on color { animation: Looks.transition.color.createObject(this) }

    Timer {
        id: peekTimer
        interval: 500
        onTriggered: {
            if (hoverArea.containsMouse && CompositorService.isNiri) {
                root.isPeeking = true
                // Minimize all windows temporarily (Niri doesn't have this, so just show overview)
                NiriService.toggleOverview()
            }
        }
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true

        onEntered: {
            if (Config.options?.waffles?.bar?.desktopPeek?.hoverPeek ?? false) {
                peekTimer.start()
            }
        }

        onExited: {
            peekTimer.stop()
            if (root.isPeeking && CompositorService.isNiri) {
                NiriService.toggleOverview()
                root.isPeeking = false
            }
        }

        onClicked: {
            peekTimer.stop()
            root.isPeeking = false
            if (CompositorService.isNiri) {
                NiriService.toggleOverview()
            } else {
                GlobalStates.overviewOpen = !GlobalStates.overviewOpen
            }
        }
    }

    BarToolTip {
        extraVisibleCondition: hoverArea.containsMouse
        text: Translation.tr("Show desktop")
    }
}
