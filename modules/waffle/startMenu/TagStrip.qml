pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.waffle.looks

RowLayout {
    id: root
    spacing: 4

    WPanelIconButton {
        implicitWidth: 32
        implicitHeight: 32
        iconName: "arrow-left"
        onClicked: LauncherSearch.query = ""
    }

    ListView {
        id: tagListView
        Layout.fillWidth: true
        Layout.preferredHeight: 32
        orientation: Qt.Horizontal
        spacing: 4
        clip: true

        model: [
            { name: Translation.tr("All"), prefix: "" },
            { name: Translation.tr("Apps"), prefix: Config.options?.search?.prefix?.app ?? "/" },
            { name: Translation.tr("Actions"), prefix: Config.options?.search?.prefix?.action ?? ">" },
            { name: Translation.tr("Clipboard"), prefix: Config.options?.search?.prefix?.clipboard ?? ";" },
            { name: Translation.tr("Emojis"), prefix: Config.options?.search?.prefix?.emojis ?? ":" },
            { name: Translation.tr("Math"), prefix: Config.options?.search?.prefix?.math ?? "=" },
            { name: Translation.tr("Commands"), prefix: Config.options?.search?.prefix?.shellCommand ?? "$" },
            { name: Translation.tr("Web"), prefix: Config.options?.search?.prefix?.webSearch ?? "?" },
        ]

        delegate: WBorderedButton {
            id: tagButton
            required property var modelData
            required property int index

            border.width: 1
            radius: height / 2
            implicitWidth: tagText.implicitWidth + 20
            implicitHeight: 28

            checked: {
                if (modelData.prefix !== "") {
                    return LauncherSearch.query.startsWith(modelData.prefix)
                }
                // "All" is checked when no prefix matches
                const prefixes = tagListView.model.filter(m => m.prefix !== "").map(m => m.prefix)
                return !prefixes.some(p => LauncherSearch.query.startsWith(p))
            }

            contentItem: Item {
                WText {
                    id: tagText
                    anchors.centerIn: parent
                    text: tagButton.modelData.name
                    color: tagButton.fgColor
                    font.pixelSize: Looks.font.pixelSize.small
                }
            }

            onClicked: LauncherSearch.ensurePrefix(modelData.prefix)
        }
    }
}
