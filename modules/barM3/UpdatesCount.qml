pragma ComponentBehavior: Bound
import qs.modules.barM3
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

MouseArea {
    id: root
    property bool vertical: Config.options.bar.vertical
    property bool isMaterial: Config.options.bar.m3.cornerStyle === 3
    readonly property color statusContainer: Updates.updateStronglyAdvised
        ? M3Palette.error
        : Updates.updateAdvised ? M3Palette.tertiary : M3Palette.primary
    readonly property color statusInk: Updates.updateStronglyAdvised
        ? M3Palette.errorForeground
        : Updates.updateAdvised ? M3Palette.tertiaryForeground : M3Palette.primaryForeground

    implicitWidth: vertical ? Appearance.sizes.verticalBarWidth : (contentLoader.item?.implicitWidth ?? 0)
    implicitHeight: vertical ? (contentLoader.item?.implicitHeight ?? 0) : Appearance.sizes.barHeight

    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    onClicked: mouse => {
        Updates.refresh()
        if (mouse.button === Qt.LeftButton || mouse.button === Qt.RightButton) {
            Quickshell.execDetached(["notify-send",
                Translation.tr("Updates"),
                Translation.tr("Checking for updates..."),
                "-a", "Shell"
            ])
        }
    }

    Component {
        id: textComp
        StyledText {
            leftPadding: 5
            rightPadding: 3
            font.pixelSize: Appearance.font.pixelSize.small
            color: root.isMaterial
                ? M3Palette.pillInk("updatesCount")
                : Appearance.colors.colOnLayer1
            text: Updates.count
        }
    }

    Loader {
        id: contentLoader
        anchors.centerIn: parent
        sourceComponent: root.vertical ? colContent : rowContent
    }

    Component {
        id: rowContent
        RowLayout {
            spacing: 4

            MaterialSymbol {
                visible: !root.isMaterial
                Layout.alignment: Qt.AlignVCenter
                text: "deployed_code_update"
                iconSize: Appearance.font.pixelSize.normal
                color: Updates.updateStronglyAdvised ? Appearance.m3colors.m3error
                    : Updates.updateAdvised ? Appearance.colors.colTertiary
                    : Appearance.colors.colOnLayer1
            }

            Rectangle {
                visible: root.isMaterial
                width: 24
                height: 24
                radius: Appearance.rounding.full
                color: root.statusContainer

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "deployed_code_update"
                    iconSize: Appearance.font.pixelSize.normal
                    color: root.statusInk
                }
            }

            Loader {
                Layout.alignment: Qt.AlignVCenter
                sourceComponent: textComp
            }
        }
    }

    Component {
        id: colContent
        ColumnLayout {
            spacing: 4

            MaterialSymbol {
                visible: !root.isMaterial
                Layout.alignment: Qt.AlignHCenter
                text: "deployed_code_update"
                iconSize: Appearance.font.pixelSize.normal
                color: Updates.updateStronglyAdvised ? Appearance.m3colors.m3error
                    : Updates.updateAdvised ? Appearance.colors.colTertiary
                    : Appearance.colors.colOnLayer1
            }

            Rectangle {
                visible: root.isMaterial
                width: 24
                height: 24
                radius: Appearance.rounding.full
                color: root.statusContainer
                Layout.alignment: Qt.AlignHCenter

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "deployed_code_update"
                    iconSize: Appearance.font.pixelSize.normal
                    color: root.statusInk
                }
            }

            Loader {
                Layout.alignment: Qt.AlignHCenter
                sourceComponent: textComp
            }
        }
    }
}
