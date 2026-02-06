import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.waffle.looks
import qs.modules.waffle.bar

BarIconButton {
    id: root

    visible: Updates.updateAdvised || Updates.updateStronglyAdvised
    padding: 4
    iconName: "arrow-sync"
    iconSize: 20
    iconMonochrome: true
    tooltipText: Translation.tr("Updates available: %1 packages").arg(Updates.count)

    function runUpdate(): void {
        const cmd = Config.options?.apps?.update ?? "kitty -e sudo pacman -Syu"
        ShellExec.execCmd(cmd)
    }

    onClicked: runUpdate()

    altAction: () => {
        menu.active = true
    }

    overlayingItems: Rectangle {
        anchors {
            right: parent.right
            bottom: parent.bottom
            margins: 1
        }
        implicitWidth: 8
        implicitHeight: implicitWidth
        radius: height / 2
        color: Updates.updateStronglyAdvised ? Looks.colors.warning : Looks.colors.accent
    }

    BarPopup {
        id: menu
        closeOnFocusLost: true
        closeOnHoverLost: false
        padding: 4

        contentItem: ColumnLayout {
            spacing: 2
            Layout.minimumWidth: 180

            WButton {
                Layout.fillWidth: true
                Layout.minimumWidth: 180
                horizontalPadding: 12
                verticalPadding: 8
                inset: 2
                contentItem: RowLayout {
                    spacing: 8
                    FluentIcon { icon: "arrow-sync"; implicitSize: 16 }
                    WText { text: Translation.tr("Update now") }
                }
                onClicked: {
                    menu.close()
                    root.runUpdate()
                }
            }

            WButton {
                Layout.fillWidth: true
                Layout.minimumWidth: 180
                horizontalPadding: 12
                verticalPadding: 8
                inset: 2
                contentItem: RowLayout {
                    spacing: 8
                    FluentIcon { icon: "arrow-clockwise"; implicitSize: 16 }
                    WText { text: Translation.tr("Check for updates") }
                }
                onClicked: {
                    menu.close()
                    Updates.refresh()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                Layout.topMargin: 4
                Layout.bottomMargin: 4
                color: Looks.colors.bg0Border
            }

            WButton {
                Layout.fillWidth: true
                Layout.minimumWidth: 180
                horizontalPadding: 12
                verticalPadding: 8
                inset: 2
                contentItem: RowLayout {
                    spacing: 8
                    FluentIcon { icon: "settings"; implicitSize: 16 }
                    WText { text: Translation.tr("Settings") }
                }
                onClicked: {
                    menu.close()
                    Quickshell.execDetached(["/usr/bin/qs", "-c", "ii", "ipc", "call", "settings", "open"])
                }
            }
        }
    }
}
