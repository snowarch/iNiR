import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
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
        const cmd = Config.options?.apps?.update ?? "foot -e sudo pacman -Syu"
        Quickshell.execDetached(["bash", "-c", cmd])
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

            WButton {
                Layout.fillWidth: true
                horizontalPadding: 12
                verticalPadding: 8
                inset: 2
                contentItem: RowLayout {
                    spacing: 8
                    FluentIcon { icon: "arrow-sync"; implicitSize: 16 }
                    WText { text: Translation.tr("Update now"); Layout.fillWidth: true }
                }
                onClicked: {
                    menu.close()
                    root.runUpdate()
                }
            }

            WButton {
                Layout.fillWidth: true
                horizontalPadding: 12
                verticalPadding: 8
                inset: 2
                contentItem: RowLayout {
                    spacing: 8
                    FluentIcon { icon: "arrow-clockwise"; implicitSize: 16 }
                    WText { text: Translation.tr("Check for updates"); Layout.fillWidth: true }
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
                horizontalPadding: 12
                verticalPadding: 8
                inset: 2
                contentItem: RowLayout {
                    spacing: 8
                    FluentIcon { icon: "settings"; implicitSize: 16 }
                    WText { text: Translation.tr("Settings"); Layout.fillWidth: true }
                }
                onClicked: {
                    menu.close()
                    GlobalStates.settingsState.openPage(2)
                }
            }
        }
    }
}
