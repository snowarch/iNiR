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

WPanelPageColumn {
    id: root

    signal allAppsClicked()
    
    property list<string> pinnedApps: Config.options.dock?.pinnedApps ?? []
    property var recentApps: getRecentApps()

    WPanelSeparator {}

    BodyRectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // Pinned header
            RowLayout {
                Layout.fillWidth: true
                WText {
                    text: Translation.tr("Pinned")
                    font.pixelSize: Looks.font.pixelSize.large
                    font.weight: Font.DemiBold
                }
                Item { Layout.fillWidth: true }
                WBorderlessButton {
                    implicitHeight: 28
                    implicitWidth: allAppsRow.implicitWidth + 16
                    contentItem: RowLayout {
                        id: allAppsRow
                        spacing: 4
                        WText { text: Translation.tr("All apps"); font.pixelSize: Looks.font.pixelSize.normal }
                        FluentIcon { icon: "chevron-right"; implicitSize: 12 }
                    }
                    onClicked: root.allAppsClicked()
                }
            }

            // Pinned grid - 6 columns like Windows 11
            Grid {
                Layout.fillWidth: true
                columns: 6
                rowSpacing: 4
                columnSpacing: 4
                
                Repeater {
                    model: root.pinnedApps.slice(0, 18)
                    delegate: AppButton {
                        required property string modelData
                        appId: modelData
                    }
                }
            }

            Item { Layout.fillHeight: true }

            // Recommended section
            ColumnLayout {
                Layout.fillWidth: true
                visible: (root.recentApps?.length ?? 0) > 0
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    WText {
                        text: Translation.tr("Recommended")
                        font.pixelSize: Looks.font.pixelSize.large
                        font.weight: Font.DemiBold
                    }
                    Item { Layout.fillWidth: true }
                }

                Grid {
                    Layout.fillWidth: true
                    columns: 2
                    rowSpacing: 4
                    columnSpacing: 16

                    Repeater {
                        model: root.recentApps.slice(0, 6)
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

    StartFooter { Layout.fillWidth: true }

    function getRecentApps() {
        const seen = new Set()
        const recent = []
        const windowList = CompositorService.isNiri ? (NiriService.windows ?? []) : []
        for (const w of windowList) {
            const appId = w.app_id ?? ""
            if (appId && !seen.has(appId) && recent.length < 6) {
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
        implicitWidth: 88
        implicitHeight: 76
        onClicked: { if (de) de.execute(); GlobalStates.searchOpen = false }
        
        contentItem: ColumnLayout {
            spacing: 4
            Image {
                Layout.alignment: Qt.AlignHCenter
                source: Quickshell.iconPath(AppSearch.guessIcon(appBtn.appId), "application-x-executable")
                sourceSize: Qt.size(32, 32)
            }
            WText {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 80
                text: appBtn.de?.name ?? appBtn.appId
                font.pixelSize: Looks.font.pixelSize.small
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
        implicitWidth: 260
        implicitHeight: 44
        onClicked: { if (de) de.execute(); GlobalStates.searchOpen = false }
        
        contentItem: RowLayout {
            spacing: 10
            Image {
                source: Quickshell.iconPath(AppSearch.guessIcon(recBtn.appId), "application-x-executable")
                sourceSize: Qt.size(28, 28)
            }
            WText {
                Layout.fillWidth: true
                text: recBtn.appName
                font.pixelSize: Looks.font.pixelSize.normal
                elide: Text.ElideRight
            }
        }
    }


    component StartFooter: FooterRectangle {
        implicitHeight: 63

        UserButton {
            anchors {
                left: parent.left
                leftMargin: 52
                bottom: parent.bottom
                bottomMargin: 12
            }
        }

        PowerButton {
            anchors {
                right: parent.right
                rightMargin: 52
                bottom: parent.bottom
                bottomMargin: 12
            }
        }
    }

    component UserButton: WBorderlessButton {
        id: userButton
        implicitWidth: userButtonRow.implicitWidth + 24
        implicitHeight: 40

        contentItem: RowLayout {
            id: userButtonRow
            anchors.centerIn: parent
            spacing: 12
            WUserAvatar { sourceSize: Qt.size(32, 32) }
            WText {
                Layout.alignment: Qt.AlignVCenter
                text: SystemInfo.username
            }
        }

        onClicked: userMenu.open()
        WToolTip { text: SystemInfo.username }

        Popup {
            id: userMenu
            x: -51
            y: -userMenu.implicitHeight + userButton.implicitHeight / 2 - 10
            background: null
            
            WToolTipContent {
                id: popupContent
                horizontalPadding: 10
                verticalPadding: 7
                radius: Looks.radius.large
                realContentItem: Item {
                    implicitWidth: userMenuContentLayout.implicitWidth
                    implicitHeight: userMenuContentLayout.implicitHeight
                    
                    ColumnLayout {
                        id: userMenuContentLayout
                        anchors {
                            fill: parent
                            leftMargin: popupContent.horizontalPadding
                            rightMargin: popupContent.horizontalPadding
                            topMargin: popupContent.verticalPadding
                            bottomMargin: popupContent.verticalPadding
                        }
                        spacing: 5

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 6
                            FluentIcon {
                                Layout.alignment: Qt.AlignVCenter
                                implicitSize: 22
                                icon: "corporation"
                                monochrome: false
                            }
                            WText {
                                Layout.alignment: Qt.AlignVCenter
                                text: SystemInfo.hostname ?? "Computer"
                                font.pixelSize: Looks.font.pixelSize.large
                                font.weight: Looks.font.weight.strong
                            }
                            Item { Layout.fillWidth: true }
                            WBorderlessButton {
                                Layout.alignment: Qt.AlignVCenter
                                implicitHeight: 36
                                implicitWidth: signOutText.implicitWidth + 20
                                contentItem: WText {
                                    id: signOutText
                                    text: Translation.tr("Sign out")
                                    font.pixelSize: Looks.font.pixelSize.large
                                }
                                onClicked: Session.logout()
                            }
                        }
                        
                        Item { implicitWidth: 334 }
                        
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.bottomMargin: 7
                            Layout.leftMargin: 6
                            spacing: 12
                            WUserAvatar { sourceSize: Qt.size(58, 58) }
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 2
                                WText {
                                    text: SystemInfo.username
                                    font.pixelSize: Looks.font.pixelSize.larger
                                    font.weight: Looks.font.weight.strong
                                }
                                WText {
                                    color: Looks.colors.fg1
                                    text: Translation.tr("Local account")
                                }
                                WText {
                                    color: Looks.colors.accent
                                    text: Translation.tr("Manage my account")
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            Quickshell.execDetached(["bash", "-c", Config.options.apps?.manageUser ?? "kcmshell6 kcm_users"])
                                            GlobalStates.searchOpen = false
                                            userMenu.close()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component PowerButton: WBorderlessButton {
        id: powerButton
        implicitWidth: 40
        implicitHeight: 40

        contentItem: FluentIcon {
            anchors.centerIn: parent
            icon: "power"
            implicitSize: 20
        }

        WToolTip { text: Translation.tr("Power") }
        onClicked: powerMenu.open()

        WMenu {
            id: powerMenu
            x: -powerMenu.implicitWidth / 2 + powerButton.implicitWidth / 2
            y: -powerMenu.implicitHeight - 4
            Action { icon.name: "lock-closed"; text: Translation.tr("Lock"); onTriggered: Session.lock() }
            Action { icon.name: "weather-moon"; text: Translation.tr("Sleep"); onTriggered: Session.suspend() }
            Action { icon.name: "power"; text: Translation.tr("Shut down"); onTriggered: Session.poweroff() }
            Action { icon.name: "arrow-counterclockwise"; text: Translation.tr("Restart"); onTriggered: Session.reboot() }
        }
    }
}
