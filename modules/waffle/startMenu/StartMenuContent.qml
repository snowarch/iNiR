pragma ComponentBehavior: Bound
import Qt.labs.synchronizer
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.waffle.looks

WBarAttachedPanelContent {
    id: root

    property bool searching: false
    property string searchText: LauncherSearch.query
    property bool showAllApps: false

    StartMenuContext { id: context }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) return;

        if (event.key === Qt.Key_Backspace) {
            searchBar.forceFocus();
            const text = searchBar.text;
            const pos = searchBar.searchInput?.cursorPosition ?? text.length;
            if (pos > 0) {
                if (event.modifiers & Qt.ControlModifier) {
                    const left = text.slice(0, pos);
                    const match = left.match(/(\s*\S+)\s*$/);
                    const deleteLen = match ? match[0].length : 1;
                    searchBar.text = text.slice(0, pos - deleteLen) + text.slice(pos);
                } else {
                    searchBar.text = text.slice(0, pos - 1) + text.slice(pos);
                }
            }
            event.accepted = true;
            return;
        }

        if (event.text && event.text.length === 1 && 
            event.key !== Qt.Key_Enter && event.key !== Qt.Key_Return && 
            event.key !== Qt.Key_Delete && event.text.charCodeAt(0) >= 0x20) {
            if (!searchBar.searchInput?.activeFocus) {
                searchBar.forceFocus();
                searchBar.text += event.text;
                event.accepted = true;
                context.setCurrentIndex(0);
            }
        }

        if (event.key === Qt.Key_Down) {
            const maxIndex = Math.max(0, LauncherSearch.results.length - 1);
            context.setCurrentIndex(Math.min(context.currentIndex + 1, maxIndex));
            event.accepted = true;
        } else if (event.key === Qt.Key_Up) {
            context.setCurrentIndex(Math.max(context.currentIndex - 1, 0));
            event.accepted = true;
        }
    }

    contentItem: WPane {
        contentItem: WPanelPageColumn {
            SearchBar {
                id: searchBar
                Layout.fillWidth: true
                implicitWidth: 600
                horizontalPadding: root.searching ? 16 : 24
                Synchronizer on searching { property alias target: root.searching }
                focus: true
                text: root.searchText
                onTextChanged: LauncherSearch.query = text
                onAccepted: context.accepted()
            }
            
            Item {
                implicitHeight: 520
                implicitWidth: 600
                Layout.fillWidth: true
                clip: true

                Loader {
                    id: startPageLoader
                    anchors.fill: parent
                    active: !root.searching && !root.showAllApps
                    opacity: active ? 1 : 0
                    visible: opacity > 0
                    sourceComponent: StartPageContent {
                        onAllAppsClicked: root.showAllApps = true
                    }
                    Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
                }

                Loader {
                    id: searchPageLoader
                    anchors.fill: parent
                    active: root.searching
                    opacity: active ? 1 : 0
                    visible: opacity > 0
                    sourceComponent: SearchPageContent { context: context }
                    Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
                }

                Loader {
                    id: allAppsLoader
                    anchors.fill: parent
                    active: root.showAllApps
                    opacity: active ? 1 : 0
                    visible: opacity > 0
                    sourceComponent: AllAppsContent { onBack: root.showAllApps = false }
                    Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
                }
            }
        }
    }

    Keys.onEscapePressed: root.close()
}
