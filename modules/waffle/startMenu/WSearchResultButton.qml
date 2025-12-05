pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.widgets
import qs.modules.waffle.looks

WChoiceButton {
    id: root

    required property LauncherSearchResult entry
    property bool showType: false

    checked: focus
    animateChoiceHighlight: false
    implicitHeight: contentLayout.implicitHeight + topPadding + bottomPadding

    onClicked: {
        GlobalStates.searchOpen = false
        root.entry.execute()
    }

    contentItem: RowLayout {
        id: contentLayout
        spacing: 12

        // Icon based on iconType
        Item {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32

            Loader {
                anchors.centerIn: parent
                active: root.entry.iconType === LauncherSearchResult.IconType.System
                sourceComponent: Image {
                    source: Quickshell.iconPath(root.entry.iconName, "application-x-executable")
                    sourceSize: Qt.size(32, 32)
                    fillMode: Image.PreserveAspectFit
                }
            }

            Loader {
                anchors.centerIn: parent
                active: root.entry.iconType === LauncherSearchResult.IconType.Material
                sourceComponent: MaterialSymbol {
                    text: root.entry.iconName
                    iconSize: 28
                    color: Looks.colors.fg
                }
            }

            Loader {
                anchors.centerIn: parent
                active: root.entry.iconType === LauncherSearchResult.IconType.Text
                sourceComponent: WText {
                    text: root.entry.iconName
                    font.pixelSize: 24
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            WText {
                Layout.fillWidth: true
                text: root.entry.name
                font.pixelSize: Looks.font.pixelSize.large
                font.family: root.entry.fontType === LauncherSearchResult.FontType.Monospace
                    ? "monospace" : Looks.font.family.ui
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            WText {
                Layout.fillWidth: true
                visible: root.entry.comment.length > 0
                text: root.entry.comment
                color: Looks.colors.fg1
                font.pixelSize: Looks.font.pixelSize.small
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        WText {
            visible: root.showType
            text: root.entry.type
            color: Looks.colors.accentUnfocused
            font.pixelSize: Looks.font.pixelSize.small
        }
    }
}
