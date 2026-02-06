import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.waffle.looks

// TODO: Replace the icon with QMLized svg (with /usr/lib/qt6/bin/svgtoqml) for proper micro-animation
AppButton {
    id: root

    leftInset: (Config.options?.waffles?.bar?.leftAlignApps ?? false) ? 12 : 0
    iconName: down ? "start-here-pressed" : "start-here"

    checked: GlobalStates.searchOpen && LauncherSearch.query === ""
    onClicked: {
        GlobalStates.searchOpen = !GlobalStates.searchOpen;
    }

    BarToolTip {
        id: tooltip
        text: Translation.tr("Start")
        extraVisibleCondition: root.shouldShowTooltip
    }

    altAction: () => {
        contextMenu.active = true;
    }

    BarMenu {
        id: contextMenu

        model: [
            {
                text: Translation.tr("Terminal"),
                action: () => {
                    const cmd = Config.options?.apps?.terminal ?? "kitty"
                    ShellExec.execCmd(cmd)
                }
            },
            {
                text: Translation.tr("Task Manager"),
                action: () => {
                    const cmd = Config.options?.apps?.taskManager ?? "missioncenter"
                    ShellExec.execCmd(cmd)
                }
            },
            {
                text: Translation.tr("Settings"),
                action: () => {
                    Quickshell.execDetached(["/usr/bin/qs", "-c", "ii", "ipc", "call", "settings", "open"]);
                }
            },
            {
                text: Translation.tr("File Explorer"),
                action: () => {
                    Qt.openUrlExternally(Directories.home);
                }
            },
            {
                text: Translation.tr("Search"),
                action: () => {
                    Quickshell.execDetached(["/usr/bin/qs", "-c", "ii", "ipc", "call", "overview", "toggle"]);
                }
            },
        ]
    }
}
