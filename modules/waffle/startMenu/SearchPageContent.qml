pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.waffle.looks

BodyRectangle {
    id: root

    required property string searchText
    property real menuScale: Config.options.waffles?.startMenu?.scale ?? 1.0

    // Sync search text to LauncherSearch service
    onSearchTextChanged: LauncherSearch.query = searchText

    function navigateUp() {
        if (resultsView.currentIndex > 0) {
            resultsView.currentIndex--
        }
    }

    function navigateDown() {
        if (resultsView.currentIndex < resultsView.count - 1) {
            resultsView.currentIndex++
        }
    }

    function activateCurrent() {
        if (resultsView.currentItem) {
            resultsView.currentItem.clicked()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        TagStrip {
            Layout.fillWidth: true
        }

        ListView {
            id: resultsView
            Layout.fillWidth: true
            Layout.fillHeight: true
        clip: true
        spacing: 4
        highlightMoveDuration: 100
        focus: true
        currentIndex: 0
        keyNavigationEnabled: true

        Connections {
            target: LauncherSearch
            function onResultsChanged() {
                if (resultsView.count > 0) resultsView.currentIndex = 0
            }
        }

        Keys.onUpPressed: if (currentIndex > 0) currentIndex--
        Keys.onDownPressed: if (currentIndex < count - 1) currentIndex++
        Keys.onReturnPressed: if (currentItem) currentItem.clicked()
        Keys.onEnterPressed: if (currentItem) currentItem.clicked()

        model: ScriptModel {
            values: LauncherSearch.results.slice(0, 10)
        }

        highlight: Rectangle {
            color: Looks.colors.bg1
            radius: Looks.radius.small
        }

        delegate: WBorderlessButton {
            id: resultItem
            required property var modelData
            required property int index

            width: resultsView.width
            implicitHeight: 56
            checked: resultsView.currentIndex === index

            onClicked: {
                modelData.execute()
                GlobalStates.searchOpen = false
            }

            Keys.onReturnPressed: clicked()
            Keys.onEnterPressed: clicked()

            contentItem: RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 16

                // Icon based on iconType
                Loader {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    sourceComponent: {
                        switch (resultItem.modelData.iconType) {
                            case LauncherSearchResult.IconType.System:
                                return systemIconComp
                            case LauncherSearchResult.IconType.Material:
                                return materialIconComp
                            case LauncherSearchResult.IconType.Text:
                                return textIconComp
                            default:
                                return systemIconComp
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    WText {
                        Layout.fillWidth: true
                        text: resultItem.modelData.name
                        font.pixelSize: Looks.font.pixelSize.large
                        font.family: resultItem.modelData.fontType === LauncherSearchResult.FontType.Monospace 
                            ? "monospace" : Looks.font.family.ui
                        elide: Text.ElideRight
                    }

                    WText {
                        Layout.fillWidth: true
                        visible: resultItem.modelData.comment.length > 0
                        text: resultItem.modelData.comment
                        color: Looks.colors.fg1
                        font.pixelSize: Looks.font.pixelSize.small
                        elide: Text.ElideRight
                    }
                }

                WText {
                    text: resultItem.modelData.type
                    color: Looks.colors.fg1
                    font.pixelSize: Looks.font.pixelSize.small
                }
            }

            Component {
                id: systemIconComp
                Image {
                    source: Quickshell.iconPath(resultItem.modelData.iconName, "application-x-executable")
                    sourceSize: Qt.size(32, 32)
                    fillMode: Image.PreserveAspectFit
                }
            }

            Component {
                id: materialIconComp
                MaterialSymbol {
                    text: resultItem.modelData.iconName
                    iconSize: 28
                    color: Looks.colors.fg
                }
            }

            Component {
                id: textIconComp
                WText {
                    text: resultItem.modelData.iconName
                    font.pixelSize: Math.round(28 * root.menuScale)
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

            // Empty state
            WText {
                anchors.centerIn: parent
                visible: resultsView.count === 0 && root.searchText.length > 0
                text: Translation.tr("No results found")
                color: Looks.colors.fg1
            }
        }
    }
}
