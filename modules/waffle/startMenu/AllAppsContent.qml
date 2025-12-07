pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.waffle.looks

WPanelPageColumn {
    id: root
    signal back()

    property string filterText: ""

    function navigateUp() {
        if (appsList.currentIndex > 0) appsList.currentIndex--
    }

    function navigateDown() {
        if (appsList.currentIndex < appsList.count - 1) appsList.currentIndex++
    }

    function activateCurrent() {
        if (appsList.currentItem) appsList.currentItem.clicked()
    }

    WPanelSeparator {}

    BodyRectangle {
        Layout.fillWidth: true
        implicitHeight: 600
        implicitWidth: 768

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                WBorderlessButton {
                    implicitHeight: 28
                    implicitWidth: backRow.implicitWidth + 16
                    contentItem: RowLayout {
                        id: backRow
                        spacing: 4
                        FluentIcon { icon: "chevron-left"; implicitSize: 12 }
                        WText { text: Translation.tr("Back"); font.pixelSize: Looks.font.pixelSize.small }
                    }
                    onClicked: root.back()
                }
                Item { Layout.fillWidth: true }
                WText {
                    text: Translation.tr("All apps")
                    font.pixelSize: Looks.font.pixelSize.large
                    font.weight: Font.DemiBold
                }
            }

            // Search filter
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 36
                radius: height / 2
                color: Looks.colors.inputBg
                border.width: 1
                border.color: Looks.colors.bg2Border

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    FluentIcon { icon: "search"; implicitSize: 14 }

                    WTextInput {
                        id: filterInput
                        Layout.fillWidth: true
                        focus: true
                        onTextChanged: root.filterText = text

                        Keys.onUpPressed: root.navigateUp()
                        Keys.onDownPressed: root.navigateDown()
                        Keys.onReturnPressed: root.activateCurrent()
                        Keys.onEnterPressed: root.activateCurrent()
                        Keys.onEscapePressed: root.back()

                        WText {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            color: Looks.colors.accentUnfocused
                            text: Translation.tr("Filter apps...")
                            visible: filterInput.text.length === 0
                            font.pixelSize: Looks.font.pixelSize.normal
                        }
                    }
                }
            }

            ListView {
                id: appsList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 2
                currentIndex: 0
                highlightMoveDuration: 100

                model: ScriptModel {
                    values: {
                        const filter = root.filterText.toLowerCase().trim()
                        return DesktopEntries.applications.values
                            .filter(e => !e.noDisplay && (filter.length === 0 || (e.name || "").toLowerCase().includes(filter)))
                            .sort((a, b) => (a.name || "").localeCompare(b.name || ""))
                    }
                }

                section.property: "modelData.name"
                section.criteria: ViewSection.FirstCharacter
                section.delegate: Item {
                    required property string section
                    width: appsList.width
                    height: 32
                    WText {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: section.toUpperCase()
                        font.pixelSize: Looks.font.pixelSize.small
                        font.weight: Font.DemiBold
                        color: Looks.colors.accent
                    }
                }

                highlight: Rectangle {
                    color: Looks.colors.bg1
                    radius: Looks.radius.small
                }

                delegate: WBorderlessButton {
                    id: appItem
                    required property var modelData
                    required property int index
                    width: appsList.width
                    implicitHeight: 44
                    checked: appsList.currentIndex === index

                    onClicked: {
                        modelData.execute()
                        GlobalStates.searchOpen = false
                    }

                    onHoveredChanged: {
                        if (hovered) appsList.currentIndex = index
                    }

                    contentItem: RowLayout {
                        spacing: 12
                        Image {
                            source: Quickshell.iconPath(appItem.modelData.icon || appItem.modelData.name, "application-x-executable")
                            sourceSize: Qt.size(28, 28)
                            width: 28; height: 28
                        }
                        WText {
                            Layout.fillWidth: true
                            text: appItem.modelData.name || ""
                            elide: Text.ElideRight
                        }
                    }
                }

                WText {
                    anchors.centerIn: parent
                    visible: appsList.count === 0
                    text: Translation.tr("No apps found")
                    color: Looks.colors.fg1
                }
            }
        }
    }
}
