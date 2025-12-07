import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.waffle.looks
import qs.modules.waffle.bar.tasks
import qs.modules.waffle.bar.tray

Rectangle {
    id: root

    color: Looks.colors.bg0
    implicitHeight: 48

    // Right-click context menu anchor (invisible, positioned at click)
    Item {
        id: contextMenuAnchor
        width: 1
        height: 1
    }

    // Right-click context menu
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        z: -1  // Below other elements so they can handle their own right-clicks
        onClicked: (mouse) => {
            contextMenuAnchor.x = mouse.x
            contextMenuAnchor.y = 0
            taskbarContextMenu.active = true
        }
    }

    BarMenu {
        id: taskbarContextMenu
        anchorItem: contextMenuAnchor

        model: [
            {
                iconName: "pulse",
                text: Translation.tr("Task Manager"),
                action: () => {
                    Quickshell.execDetached(["missioncenter"])
                }
            },
            { type: "separator" },
            {
                iconName: "settings",
                text: Translation.tr("Taskbar settings"),
                action: () => {
                    Quickshell.execDetached(["qs", "-c", "ii", "ipc", "call", "settings", "open"])
                }
            }
        ]
    }

    Rectangle {
        id: border
        anchors {
            left: parent.left
            right: parent.right
            top: Config.options.waffles.bar.bottom ? parent.top : undefined
            bottom: Config.options.waffles.bar.bottom ? undefined : parent.bottom
        }
        color: Looks.colors.bg0Border
        implicitHeight: 1
    }

    BarGroupRow {
        id: bloatRow
        anchors.left: parent.left
        opacity: Config.options.waffles.bar.leftAlignApps ? 0 : 1
        visible: opacity > 0
        Behavior on opacity {
            animation: Looks.transition.opacity.createObject(this)
        }

        WidgetsButton {}
    }

    BarGroupRow {
        id: appsRow
        anchors.left: undefined
        anchors.horizontalCenter: parent.horizontalCenter

        states: State {
            name: "left"
            when: Config.options.waffles.bar.leftAlignApps
            AnchorChanges {
                target: appsRow
                anchors.left: parent.left
                anchors.horizontalCenter: undefined
            }
        }

        transitions: Transition {
            animations: Looks.transition.anchor.createObject(this)
        }

        StartButton {}
        SearchButton {}
        TaskViewButton {}
        Tasks {}
    }

    BarGroupRow {
        id: systemRow
        anchors.right: parent.right
        FadeLoader {
            Layout.fillHeight: true
            shown: Config.options.waffles.bar.leftAlignApps
            sourceComponent: WidgetsButton {}
        }
        Tray {}
        TimerButton {}
        UpdatesButton {}
        SystemButton {}
        TimeButton {}
        DesktopPeekButton {}
    }

    component BarGroupRow: RowLayout {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        spacing: 0
    }
}
