pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.waffle.looks
import qs.modules.waffle.settings

WSettingsPage {
    id: root
    settingsPageIndex: 12
    pageTitle: Translation.tr("Autostart")
    pageIcon: "power"
    pageDescription: Translation.tr("Apps that start with iNiR")

    // ── Helpers ──────────────────────────────────────────────────────────

    function getCommandEntries(): var {
        const cmds = []
        const entries = Autostart.entries ?? []
        for (let i = 0; i < entries.length; ++i) {
            if (entries[i].type === "command")
                cmds.push({ entry: entries[i], originalIndex: i })
        }
        return cmds
    }

    function getFilteredApps(): var {
        const search = appSearchField.text.toLowerCase().trim()
        const apps = AppSearch.list ?? []
        const result = []
        for (let i = 0; i < apps.length; ++i) {
            const app = apps[i]
            const name = (app.name || "").toLowerCase()
            const generic = (app.genericName || "").toLowerCase()
            if (search && !name.includes(search) && !generic.includes(search))
                continue
            result.push(app)
        }
        result.sort((a, b) => {
            const aEnabled = Autostart.isAppOn(a)
            const bEnabled = Autostart.isAppOn(b)
            if (aEnabled !== bEnabled)
                return aEnabled ? -1 : 1
            return (a.name || "").localeCompare(b.name || "")
        })
        return result
    }

    // ── Non-niri / missing-file guard ────────────────────────────────────

    WSettingsCard {
        title: Translation.tr("Autostart needs niri")
        icon: "alert"
        visible: !Autostart.isNiri

        WText {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: Translation.tr("App autostart is managed through niri's startup config, which only applies when niri is the active compositor.")
            font.pixelSize: Looks.font.pixelSize.small
            color: Looks.colors.subfg
        }
    }

    WSettingsCard {
        title: Translation.tr("Startup file not found")
        icon: "dismiss"
        visible: Autostart.isNiri && Autostart.status === "missing"

        WText {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: Autostart.startupFilePath.length > 0
                ? Translation.tr("iNiR couldn't find %1. Re-run the installer to restore it.").arg(Autostart.startupFilePath)
                : Translation.tr("iNiR couldn't locate your niri startup config.")
            font.pixelSize: Looks.font.pixelSize.small
            color: Looks.colors.subfg
        }
    }

    // ── Info banner ──────────────────────────────────────────────────────

    WSettingsCard {
        title: Translation.tr("How autostart works")
        icon: "info"
        visible: Autostart.isNiri

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            WText {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: Translation.tr("Apps and commands here are written to niri's startup file and launched by niri at login — iNiR doesn't start them itself, so they keep running even if the shell restarts.")
                font.pixelSize: Looks.font.pixelSize.small
                color: Looks.colors.fg
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                FluentIcon {
                    icon: "folder"
                    implicitSize: 16
                    color: Looks.colors.subfg
                }

                WText {
                    Layout.fillWidth: true
                    elide: Text.ElideMiddle
                    text: Autostart.startupFilePath
                    font.pixelSize: Looks.font.pixelSize.small
                    color: Looks.colors.subfg
                }

                WSettingsButton {
                    buttonText: Translation.tr("Reload")
                    buttonIcon: "arrow-clockwise"
                    onButtonClicked: Autostart.reload()
                }
            }
        }
    }

    // ── Applications ─────────────────────────────────────────────────────

    WSettingsCard {
        title: Translation.tr("Applications")
        icon: "apps"
        visible: Autostart.isNiri

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            TextField {
                id: appSearchField
                Layout.fillWidth: true
                placeholderText: Translation.tr("Search applications...")
                font.pixelSize: Looks.font.pixelSize.small
                color: Looks.colors.fg
                placeholderTextColor: Looks.colors.subfg
                background: Rectangle {
                    color: Looks.colors.bg1
                    radius: Looks.dp(4)
                    border.width: appSearchField.activeFocus ? 2 : 1
                    border.color: appSearchField.activeFocus
                        ? Looks.colors.accent
                        : Looks.colors.bg1Border
                }
            }

            ListView {
                id: appListView
                Layout.fillWidth: true
                implicitHeight: Math.min(400, appListView.contentHeight)
                clip: true
                model: root.getFilteredApps()

                WText {
                    anchors.fill: parent
                    visible: appSearchField.text.length > 0 && appListView.count === 0
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: Translation.tr("No matching apps")
                    font.pixelSize: Looks.font.pixelSize.small
                    color: Looks.colors.subfg
                }

                delegate: Item {
                    id: appDelegate
                    required property var modelData
                    required property int index
                    width: appListView.width
                    implicitHeight: 44
                    height: 44

                    readonly property bool isExternal: Autostart.appEntrySource(appDelegate.modelData) === "external"
                    readonly property bool isOn: Autostart.isAppOn(appDelegate.modelData)

                    Rectangle {
                        anchors.fill: parent
                        anchors.leftMargin: 4
                        anchors.rightMargin: 4
                        radius: Looks.radius.small
                        color: rowHover.hovered ? Looks.colors.controlBgHover : "transparent"
                        Behavior on color { enabled: Looks.transition.enabled; ColorAnimation { duration: Looks.transition.duration.fast } }
                    }

                    HoverHandler { id: rowHover }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        Item {
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                            Layout.alignment: Qt.AlignVCenter

                            Image {
                                anchors.fill: parent
                                source: AppSearch.getIconSource(appDelegate.modelData.icon, appDelegate.modelData.name)
                                sourceSize.width: 48
                                sourceSize.height: 48
                                fillMode: Image.PreserveAspectFit
                                visible: status === Image.Ready
                            }

                            FluentIcon {
                                anchors.fill: parent
                                icon: "apps"
                                implicitSize: 20
                                color: Looks.colors.fg
                                visible: !(AppSearch.getIconSource(appDelegate.modelData.icon, appDelegate.modelData.name).length > 0)
                            }
                        }

                        WText {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            text: appDelegate.modelData.name
                            font.pixelSize: Looks.font.pixelSize.normal
                        }

                        // External badge — no switch (a disabled toggle looks broken).
                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            visible: appDelegate.isExternal
                            Layout.preferredHeight: 20
                            Layout.preferredWidth: extBadgeRow.implicitWidth + 14
                            radius: height / 2
                            color: Looks.colors.accent
                            opacity: 0.85

                            RowLayout {
                                id: extBadgeRow
                                anchors.centerIn: parent
                                spacing: 4

                                FluentIcon {
                                    icon: "link"
                                    implicitSize: 12
                                    color: Looks.colors.accentFg
                                }

                                WText {
                                    text: Translation.tr("External")
                                    font.pixelSize: Looks.font.pixelSize.small
                                    color: Looks.colors.accentFg
                                }
                            }
                        }

                        WSwitch {
                            Layout.alignment: Qt.AlignVCenter
                            visible: !appDelegate.isExternal
                            checked: appDelegate.isOn
                            onClicked: Autostart.setAppEnabled(appDelegate.modelData.id, !checked)
                        }
                    }
                }
            }
        }
    }

    // ── Custom Commands ──────────────────────────────────────────────────

    WSettingsCard {
        title: Translation.tr("Custom Commands")
        icon: "terminal"
        visible: Autostart.isNiri

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            WText {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: Translation.tr("Shell commands run through niri's spawn-sh-at-startup, so pipes, env vars, and && work.")
                font.pixelSize: Looks.font.pixelSize.small
                color: Looks.colors.subfg
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                WSettingsTextField {
                    id: commandInput
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("e.g. telegram-desktop --start-minimized")
                    onTextEdited: (newText) => { commandInput.text = newText }
                }

                WSettingsButton {
                    buttonText: Translation.tr("Add")
                    buttonIcon: "add"
                    onButtonClicked: {
                        Autostart.addCommand(commandInput.text)
                        commandInput.text = ""
                    }
                }
            }

            ListView {
                id: commandListView
                Layout.fillWidth: true
                implicitHeight: Math.min(200, commandListView.contentHeight)
                clip: true
                model: root.getCommandEntries()

                WText {
                    anchors.fill: parent
                    visible: commandListView.count === 0
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: Translation.tr("No custom commands")
                    font.pixelSize: Looks.font.pixelSize.small
                    color: Looks.colors.subfg
                }

                delegate: RowLayout {
                    id: cmdDelegate
                    required property var modelData
                    required property int index
                    width: commandListView.width
                    spacing: 10

                    FluentIcon {
                        icon: "terminal"
                        implicitSize: 20
                        color: Looks.colors.fg
                    }

                    WText {
                        Layout.fillWidth: true
                        text: cmdDelegate.modelData.entry.command
                        font.pixelSize: Looks.font.pixelSize.normal
                        elide: Text.ElideRight
                    }

                    WSwitch {
                        checked: cmdDelegate.modelData.entry.enabled
                        onClicked: Autostart.setEntryEnabled(cmdDelegate.modelData.originalIndex, !checked)
                    }

                    WSettingsButton {
                        buttonText: Translation.tr("Remove")
                        buttonIcon: "delete"
                        onButtonClicked: Autostart.removeEntry(cmdDelegate.modelData.originalIndex)
                    }
                }
            }
        }
    }
}
