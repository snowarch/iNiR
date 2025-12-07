pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.waffle.looks
import qs.modules.common.functions
import qs.modules.common.models
import Quickshell
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick

RowLayout {
    id: root

    property int maxResultsPerCategory: 4
    property StartMenuContext context
    property int currentIndex: context.currentIndex
    
    function focusFirstItem() {
        context.currentIndex = 0;
    }

    Connections {
        target: context
        function onAccepted() {
            resultList.currentItem?.execute();
        }
    }

    ResultList {
        id: resultList
        Layout.fillHeight: true
        Layout.fillWidth: true
    }
    
    ResultPreview {
        Layout.preferredWidth: 260
        Layout.leftMargin: 1
        Layout.rightMargin: 1
        entry: resultList.model[resultList.currentIndex] ?? searchResultComp.createObject()
    }

    component ResultList: WListView {
        id: resultListView
        section {
            criteria: ViewSection.FullString
            property: "category"
            labelPositioning: ViewSection.InlineLabels
            delegate: Item {
                id: sectionButton
                required property string section
                implicitHeight: sectionChoiceButton.implicitHeight + resultListView.spacing
                width: ListView.view?.width
                WChoiceButton {
                    id: sectionChoiceButton
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                    }
                    implicitHeight: 38
                    contentItem: WText {
                        text: sectionButton.section
                        font.pixelSize: Looks.font.pixelSize.large
                        font.weight: Looks.font.weight.strong
                    }
                    onClicked: {
                        root.context.selectCategory(sectionButton.section);
                    }
                }
            }
        }
        clip: true
        spacing: 4
        currentIndex: root.context.currentIndex
        highlightFollowsCurrentItem: true
        highlightMoveDuration: 100

        model: {
            const allResults = LauncherSearch.results;
            if (allResults.length === 0) return [];
            
            // Use Map to preserve insertion order and count per category
            const categoryCount = new Map();
            const categorizedResults = [];
            
            for (let i = 0; i < allResults.length; i++) {
                const entry = allResults[i];
                const type = entry.type;
                const count = categoryCount.get(type) ?? 0;
                
                if (count >= root.maxResultsPerCategory) continue;
                
                // Reuse entry directly, just set category
                entry.category = categorizedResults.length === 0 ? Translation.tr("Best match") : type;
                categorizedResults.push(entry);
                categoryCount.set(type, count + 1);
            }
            return categorizedResults;
        }
        onModelChanged: {
            root.focusFirstItem();
        }
        delegate: WSearchResultButton {
            required property int index
            required property var modelData
            entry: modelData
            firstEntry: index === 0
            width: ListView.view?.width
        }
    }


    component ResultPreview: Rectangle {
        id: resultPreview

        property LauncherSearchResult entry

        Layout.fillHeight: true
        color: Looks.colors.bg1
        radius: Looks.radius.normal

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 8

            ColumnLayout {
                id: mainInfoColumn
                Layout.alignment: Qt.AlignHCenter
                spacing: 4
                SearchEntryIcon {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 8
                    Layout.bottomMargin: 6
                    entry: resultPreview.entry
                    iconSize: 48
                }
                WText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    text: resultPreview.entry?.name ?? ""
                    font.pixelSize: Looks.font.pixelSize.large
                }
                WText {
                    Layout.alignment: Qt.AlignHCenter
                    text: resultPreview.entry?.type ?? ""
                    color: Looks.colors.accentUnfocused
                    font.pixelSize: Looks.font.pixelSize.small
                }
            }
            Rectangle {
                id: resultSeparator
                implicitHeight: 1
                Layout.topMargin: 8
                Layout.fillWidth: true
                color: Looks.colors.bg2Hover
            }
            WListView {
                id: actionsColumn
                Layout.fillHeight: true
                Layout.fillWidth: true
                clip: true
                spacing: 1
                model: {
                    const isAppEntry = resultPreview.entry?.type === Translation.tr("App");
                    const appId = isAppEntry ? (resultPreview.entry?.id ?? "") : "";
                    const pinned = isAppEntry ? (Config.options.dock?.pinnedApps?.includes(appId) ?? false) : false;
                    var result = [
                        searchResultComp.createObject(null, {
                            name: resultPreview.entry?.verb ?? Translation.tr("Open"),
                            iconName: isAppEntry ? "open_in_new" : "keyboard_return",
                            iconType: LauncherSearchResult.IconType.Material,
                            execute: () => {
                                resultPreview.entry?.execute();
                            }
                        }),
                        ...(isAppEntry ? [
                            searchResultComp.createObject(null, {
                                name: pinned ? Translation.tr("Unpin from taskbar") : Translation.tr("Pin to taskbar"),
                                iconName: pinned ? "keep_off" : "keep",
                                iconType: LauncherSearchResult.IconType.Material,
                                execute: () => {
                                    TaskbarApps.togglePin(appId);
                                }
                            })
                        ] : [])
                    ];
                    if (resultPreview.entry?.actions) {
                        result = result.concat(resultPreview.entry.actions);
                    }
                    return result;
                }
                delegate: WButton {
                    id: actionButton
                    required property var modelData
                    width: ListView.view?.width
                    implicitHeight: 32
                    icon.name: modelData.iconName
                    text: modelData.name
                    onClicked: modelData.execute();

                    contentItem: RowLayout {
                        spacing: 8
                        SearchEntryIcon {
                            entry: actionButton.modelData
                            iconSize: 14
                        }
                        WText {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignLeft
                            text: actionButton.text
                            font.pixelSize: Looks.font.pixelSize.small
                        }
                    }
                }
            }
        }
    }

    Component {
        id: searchResultComp
        LauncherSearchResult {}
    }
}
