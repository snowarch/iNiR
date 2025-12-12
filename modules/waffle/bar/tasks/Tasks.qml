import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.waffle.looks

MouseArea {
    id: root

    Layout.fillHeight: true
    implicitHeight: row.implicitHeight
    implicitWidth: row.implicitWidth
    hoverEnabled: true
    
    readonly property var pinnedApps: TaskbarApps.apps.filter(app => app.pinned && app.toplevels.length === 0)
    readonly property var runningApps: TaskbarApps.apps.filter(app => app.toplevels.length > 0)
    
    // Signal to close all context menus before opening a new one
    signal closeAllContextMenus()

    function showPreviewPopup(appEntry, button) {
        previewPopup.show(appEntry, button);
    }

    Behavior on implicitWidth {
        animation: Looks.transition.move.createObject(this)
    }

    // Apps row
    RowLayout {
        id: row
        anchors {
            top: parent.top
            bottom: parent.bottom
        }
        spacing: 0

        Repeater {
            model: ScriptModel {
                objectProp: "appId"
                values: root.pinnedApps
            }
            delegate: TaskAppButton {
                required property var modelData
                appEntry: modelData
                tasksParent: root

                onHoverPreviewRequested: {
                    root.showPreviewPopup(appEntry, this)
                }
                onHoverPreviewDismissed: {
                    previewPopup.close()
                }
            }
        }

        Item {
            visible: root.pinnedApps.length > 0 && root.runningApps.length > 0
            Layout.preferredWidth: 6
        }

        Item {
            visible: root.pinnedApps.length > 0 && root.runningApps.length > 0
            Layout.fillHeight: true
            Layout.preferredWidth: 1

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: Math.max(0, parent.height - 18)
                radius: 1
                color: Looks.colors.bg1Border
                opacity: 0.6
            }
        }

        Item {
            visible: root.pinnedApps.length > 0 && root.runningApps.length > 0
            Layout.preferredWidth: 6
        }

        Repeater {
            model: ScriptModel {
                objectProp: "appId"
                values: root.runningApps
            }
            delegate: TaskAppButton {
                required property var modelData
                appEntry: modelData
                tasksParent: root

                onHoverPreviewRequested: {
                    root.showPreviewPopup(appEntry, this)
                }
                onHoverPreviewDismissed: {
                    previewPopup.close()
                }
            }
        }
    }

    // Previews popup
    TaskPreview {
        id: previewPopup
        tasksHovered: root.containsMouse
        anchor.window: root.QsWindow.window
    }

}
