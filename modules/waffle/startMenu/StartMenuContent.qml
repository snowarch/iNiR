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
        screenX: root.panelScreenX + root.visualMargin
        screenY: root.panelScreenY + root.visualMargin
        screenWidth: root._screenW
        screenHeight: root._screenH
        contentItem: WPanelPageColumn {
            SearchBar {
                id: searchBar
                Layout.fillWidth: true
                implicitWidth: Looks.dp(600)
                horizontalPadding: root.searching ? Looks.dp(16) : Looks.dp(24)
                // searching is read-only in SearchBar (bound to text length), so we only listen to changes
                onSearchingChanged: if (searching !== root.searching) root.searching = searching
                focus: true
                text: root.searchText
                onTextChanged: LauncherSearch.query = text
                onAccepted: context.accepted()
            }
            
            Item {
                implicitHeight: Looks.dp(520)
                implicitWidth: Looks.dp(600)
                Layout.fillWidth: true
                clip: true

                WPageLoader {
                    id: startPageLoader
                    anchors.fill: parent
                    shown: !root.searching && !root.showAllApps
                    sourceComponent: StartPageContent {
                        onAllAppsClicked: root.showAllApps = true
                    }
                }

                WPageLoader {
                    id: searchPageLoader
                    anchors.fill: parent
                    shown: root.searching
                    sourceComponent: SearchPageContent { context: context }
                }

                WPageLoader {
                    id: allAppsLoader
                    anchors.fill: parent
                    shown: root.showAllApps
                    sourceComponent: AllAppsContent { onBack: root.showAllApps = false }
                }
            }
        }
    }

    Keys.onEscapePressed: root.close()
}
