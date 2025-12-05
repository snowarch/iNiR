pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.waffle.looks

Item {
    id: root

    signal allAppsClicked()
    property list<string> pinnedApps: Config.options.dock?.pinnedApps ?? []

    // Size preset and scale
    property string sizePreset: Config.options.waffles?.startMenu?.sizePreset ?? "normal"
    property real menuScale: Config.options.waffles?.startMenu?.scale ?? 1.0
    
    // Calculate dimensions based on preset and content
    property int pinnedCount: Math.min(pinnedApps.length, maxPinned)
    property int columns: {
        if (sizePreset === "wide") return 10
        if (sizePreset === "large") return 8
        if (sizePreset === "mini") return 3
        if (sizePreset === "compact") return 4
        return 6
    }
    
    property int iconSize: sizePreset === "mini" ? 26 : sizePreset === "compact" ? 28 : sizePreset === "large" ? 36 : 32
    property int buttonSize: iconSize + 36
    property int maxPinned: sizePreset === "mini" ? 9 : sizePreset === "compact" ? 12 : sizePreset === "large" ? 32 : sizePreset === "wide" ? 30 : 18
    property bool showRecommended: sizePreset !== "mini"
    property int maxRecent: sizePreset === "mini" ? 0 : sizePreset === "compact" ? 4 : 6
    property var recentApps: getRecentApps()

    // Explicit size calculation
    property int gridWidth: columns * buttonSize + (columns - 1) * 2
    property int gridRows: Math.ceil(pinnedCount / columns)
    property int gridHeight: gridRows * buttonSize + (gridRows - 1) * 2
    
    implicitWidth: Math.max(gridWidth + 32, showRecommended ? 320 : 0)
    implicitHeight: content.implicitHeight

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 0
        spacing: 0

        WPanelSeparator {}

        BodyRectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: bodyCol.implicitHeight + 24

            ColumnLayout {
                id: bodyCol
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    WText {
                        text: Translation.tr("Pinned")
                        font.pixelSize: Looks.font.pixelSize.large
                        font.weight: Font.DemiBold
                    }
                    Item { Layout.fillWidth: true }
                    WBorderlessButton {
                        implicitHeight: 24
                        implicitWidth: allAppsRow.implicitWidth + 10
                        contentItem: RowLayout {
                            id: allAppsRow
                            spacing: 2
                            WText { text: Translation.tr("All apps"); font.pixelSize: Math.round(10 * root.menuScale) }
                            FluentIcon { icon: "chevron-right"; implicitSize: 10 }
                        }
                        onClicked: root.allAppsClicked()
                    }
                }

                // Pinned grid
                Grid {
                    columns: root.columns
                    spacing: 2
                    Repeater {
                        model: root.pinnedApps.slice(0, root.pinnedCount)
                        delegate: AppButton {
                            required property string modelData
                            appId: modelData
                        }
                    }
                }

                // Recommended
                ColumnLayout {
                    visible: root.showRecommended && (root.recentApps?.length ?? 0) > 0
                    Layout.fillWidth: true
                    spacing: 6
                    WText {
                        text: Translation.tr("Recommended")
                        font.pixelSize: Looks.font.pixelSize.large
                        font.weight: Font.DemiBold
                    }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 4
                        Repeater {
                            model: root.recentApps
                            delegate: RecButton {
                                required property var modelData
                                appId: modelData.appId
                                appName: modelData.name
                            }
                        }
                    }
                }
            }
        }

        WPanelSeparator {}

        FooterRectangle {
            Layout.fillWidth: true
            implicitHeight: 52
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                WBorderlessButton {
                    id: userBtn
                    implicitWidth: userRow.implicitWidth + 12
                    implicitHeight: 32
                    contentItem: RowLayout {
                        id: userRow
                        spacing: 6
                        WUserAvatar { sourceSize: Qt.size(24, 24) }
                        WText { text: SystemInfo.username; font.pixelSize: Math.round(11 * root.menuScale) }
                    }
                    onClicked: userMenu.open()
                    WToolTip { text: SystemInfo.username }
                    WMenu {
                        id: userMenu
                        y: -implicitHeight - 4
                        Action { 
                            icon.name: "person"
                            text: Translation.tr("Account settings")
                            onTriggered: {
                                Quickshell.execDetached(["gnome-control-center", "user-accounts"])
                                GlobalStates.searchOpen = false
                            }
                        }
                        Action { 
                            icon.name: "lock-closed"
                            text: Translation.tr("Lock")
                            onTriggered: Session.lock()
                        }
                        Action { 
                            icon.name: "arrow-exit"
                            text: Translation.tr("Sign out")
                            onTriggered: Session.logout()
                        }
                    }
                }
                Item { Layout.fillWidth: true }
                WBorderlessButton {
                    implicitWidth: 32; implicitHeight: 32
                    contentItem: FluentIcon { anchors.centerIn: parent; icon: "power"; implicitSize: 16 }
                    onClicked: pwrMenu.open()
                    WToolTip { text: Translation.tr("Power") }
                    WMenu {
                        id: pwrMenu
                        y: -implicitHeight - 4
                        Action { icon.name: "lock-closed"; text: Translation.tr("Lock"); onTriggered: Session.lock() }
                        Action { icon.name: "weather-moon"; text: Translation.tr("Sleep"); onTriggered: Session.suspend() }
                        Action { icon.name: "power"; text: Translation.tr("Shut down"); onTriggered: Session.poweroff() }
                        Action { icon.name: "arrow-counterclockwise"; text: Translation.tr("Restart"); onTriggered: Session.reboot() }
                    }
                }
            }
        }
    }

    function getRecentApps() {
        const seen = new Set()
        const recent = []
        // Use NiriService.windows for Niri compositor
        const windowList = CompositorService.isNiri ? (NiriService.windows ?? []) : []
        for (const w of windowList) {
            const appId = w.app_id ?? ""
            if (appId && !seen.has(appId) && recent.length < root.maxRecent) {
                seen.add(appId)
                const entry = DesktopEntries.heuristicLookup(appId)
                recent.push({ appId: appId, name: entry?.name ?? appId })
            }
        }
        return recent
    }

    component AppButton: WBorderlessButton {
        id: appBtn
        required property string appId
        readonly property var de: DesktopEntries.heuristicLookup(appId)
        implicitWidth: root.buttonSize
        implicitHeight: root.buttonSize
        onClicked: { if (de) de.execute(); GlobalStates.searchOpen = false }
        contentItem: ColumnLayout {
            spacing: 2
            Image {
                Layout.alignment: Qt.AlignHCenter
                source: Quickshell.iconPath(AppSearch.guessIcon(appBtn.appId), "application-x-executable")
                sourceSize: Qt.size(root.iconSize, root.iconSize)
            }
            WText {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: root.buttonSize - 6
                text: appBtn.de?.name ?? appBtn.appId
                font.pixelSize: Math.round(9 * root.menuScale)
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.Wrap
            }
        }
        WToolTip { text: appBtn.de?.name ?? appBtn.appId }
    }

    component RecButton: WBorderlessButton {
        id: recBtn
        required property string appId
        required property string appName
        readonly property var de: DesktopEntries.heuristicLookup(appId)
        implicitWidth: 140; implicitHeight: 36
        onClicked: { if (de) de.execute(); GlobalStates.searchOpen = false }
        contentItem: RowLayout {
            spacing: 6
            Image {
                source: Quickshell.iconPath(AppSearch.guessIcon(recBtn.appId), "application-x-executable")
                sourceSize: Qt.size(20, 20)
            }
            WText { Layout.fillWidth: true; text: recBtn.appName; font.pixelSize: Math.round(10 * root.menuScale); elide: Text.ElideRight }
        }
    }
}
