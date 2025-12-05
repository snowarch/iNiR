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
import qs.modules.waffle.looks

BodyRectangle {
    id: root

    required property string searchText

    onSearchTextChanged: LauncherSearch.query = searchText

    function navigateUp() {
        if (resultsView.currentIndex > 0) resultsView.currentIndex--
    }

    function navigateDown() {
        if (resultsView.currentIndex < resultsView.count - 1) resultsView.currentIndex++
    }

    function activateCurrent() {
        if (resultsView.currentItem) resultsView.currentItem.clicked()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        TagStrip { Layout.fillWidth: true }

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

            delegate: WSearchResultButton {
                required property var modelData
                required property int index

                width: resultsView.width
                entry: modelData
                showType: index === 0
                checked: resultsView.currentIndex === index
            }

            WText {
                anchors.centerIn: parent
                visible: resultsView.count === 0 && root.searchText.length > 0
                text: Translation.tr("No results found")
                color: Looks.colors.fg1
            }
        }
    }
}
