pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

ContentPage {
    id: root
    settingsPageIndex: 17
    settingsPageName: Translation.tr("Autostart")

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

    // Sorted + filtered app list: on first, then alphabetical, filtered by search.
    // "On" means either a managed entry or an external spawn line matches.
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
            const aOn = Autostart.isAppOn(a)
            const bOn = Autostart.isAppOn(b)
            if (aOn !== bOn)
                return aOn ? -1 : 1
            return (a.name || "").localeCompare(b.name || "")
        })
        return result
    }

    // ── Non-niri / missing-file guard ────────────────────────────────────

    SettingsCardSection {
        expanded: true
        icon: "block"
        title: Translation.tr("Autostart needs niri")
        visible: !Autostart.isNiri

        StyledText {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: Translation.tr("App autostart is managed through niri's startup config, which only applies when niri is the active compositor.")
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnSurface
        }
    }

    SettingsCardSection {
        expanded: true
        icon: "folder_off"
        title: Translation.tr("Startup file not found")
        visible: Autostart.isNiri && Autostart.status === "missing"

        StyledText {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: Autostart.startupFilePath.length > 0
                ? Translation.tr("iNiR couldn't find %1. Re-run the installer to restore it.").arg(Autostart.startupFilePath)
                : Translation.tr("iNiR couldn't locate your niri startup config.")
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnSurface
        }
    }

    // ── Info banner ──────────────────────────────────────────────────────

    SettingsCardSection {
        expanded: true
        icon: "info"
        title: Translation.tr("How autostart works")
        visible: Autostart.isNiri

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            StyledText {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: Translation.tr("Apps and commands here are written to niri's startup file and launched by niri at login — iNiR doesn't start them itself, so they keep running even if the shell restarts.")
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnSurface
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                MaterialSymbol {
                    text: "folder"
                    iconSize: 16
                    color: Appearance.colors.colSubtext
                }

                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideMiddle
                    text: Autostart.startupFilePath ?? ""
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.family: Appearance.font.family.monospace
                    color: Appearance.colors.colSubtext
                }

                RippleButton {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    buttonRadius: Appearance.rounding.full
                    enabled: Autostart.startupFilePath.length > 0
                    onClicked: ShellExec.execDetachedArgs(["xdg-open", Autostart.startupFilePath], "Open autostart file")
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "open_in_new"
                        iconSize: 16
                        color: Appearance.colors.colOnSurfaceVariant
                    }
                }

                RippleButton {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    buttonRadius: Appearance.rounding.full
                    onClicked: Autostart.reload()
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "refresh"
                        iconSize: 16
                        color: Appearance.colors.colOnSurfaceVariant
                    }
                }
            }
        }
    }

    // ── Applications ─────────────────────────────────────────────────────

    SettingsCardSection {
        expanded: true
        icon: "apps"
        title: Translation.tr("Applications")
        visible: Autostart.isNiri

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            StyledText {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: Translation.tr("Toggle an app to launch it at login via niri's spawn-at-startup. Apps already in your startup file outside iNiR's control are shown as \"External\" — edit the file below to change those.")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }

            MaterialTextField {
                id: appSearchField
                Layout.fillWidth: true
                placeholderText: Translation.tr("Search applications...")
                font.pixelSize: Appearance.font.pixelSize.small
            }

            ListView {
                id: appListView
                Layout.fillWidth: true
                implicitHeight: Math.min(420, appListView.contentHeight)
                clip: true
                model: root.getFilteredApps()
                boundsBehavior: Flickable.StopAtBounds

                // No apps match the filter
                PagePlaceholder {
                    shown: appSearchField.text.length > 0 && appListView.count === 0
                    icon: "search_off"
                    title: Translation.tr("No matching apps")
                    description: Translation.tr("Try a different search term.")
                    anchors.fill: parent
                }

                delegate: Item {
                    id: appDelegate
                    required property var modelData
                    required property int index
                    width: appListView.width
                    // Fixed height so every switch sits on the same line.
                    implicitHeight: 48
                    height: 48

                    readonly property bool isExternal: Autostart.appEntrySource(appDelegate.modelData) === "external"
                    readonly property bool isOn: Autostart.isAppOn(appDelegate.modelData)

                    Rectangle {
                        anchors.fill: parent
                        anchors.leftMargin: 4
                        anchors.rightMargin: 4
                        radius: Appearance.rounding.small
                        color: rowHover.hovered
                            ? (Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
                               : Appearance.inirEverywhere ? Appearance.inir.colLayer1Hover
                               : Appearance.zzzEverywhere ? Appearance.zzz.bg1
                               : Appearance.colors.colLayer1Hover)
                            : "transparent"
                        Behavior on color {
                            enabled: Appearance.animationsEnabled
                            animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }
                    }

                    HoverHandler { id: rowHover }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        Item {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            Layout.alignment: Qt.AlignVCenter

                            Image {
                                anchors.fill: parent
                                source: AppSearch.getIconSource(appDelegate.modelData.icon, appDelegate.modelData.name)
                                sourceSize.width: 64
                                sourceSize.height: 64
                                fillMode: Image.PreserveAspectFit
                                visible: status === Image.Ready
                            }

                            MaterialSymbol {
                                anchors.fill: parent
                                text: "apps"
                                iconSize: 22
                                color: Appearance.colors.colOnSurface
                                visible: !(AppSearch.getIconSource(appDelegate.modelData.icon, appDelegate.modelData.name).length > 0)
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 0

                            StyledText {
                                Layout.fillWidth: true
                                text: appDelegate.modelData.name
                                font.pixelSize: Appearance.font.pixelSize.normal
                                color: Appearance.colors.colOnSurface
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: appDelegate.modelData.comment ?? ""
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colSubtext
                                elide: Text.ElideRight
                                visible: (text ?? "").length > 0
                            }
                        }

                        // External badge: app is launched by a hand-written /
                        // default line outside iNiR's managed section. No switch —
                        // a disabled toggle looks broken, and the badge already
                        // communicates "not managed here".
                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            visible: appDelegate.isExternal
                            Layout.preferredHeight: 22
                            Layout.preferredWidth: extBadgeRow.implicitWidth + 16
                            radius: Appearance.rounding.full
                            color: Appearance.colors.colPrimaryContainer
                            opacity: 0.85

                            RowLayout {
                                id: extBadgeRow
                                anchors.centerIn: parent
                                spacing: 4

                                MaterialSymbol {
                                    text: "link"
                                    iconSize: 13
                                    color: Appearance.colors.colOnPrimaryContainer
                                }

                                StyledText {
                                    text: Translation.tr("External")
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colOnPrimaryContainer
                                }
                            }
                        }

                        // Managed apps get a clean toggle at its natural size.
                        // External apps show only the badge above (no toggle).
                        StyledSwitch {
                            Layout.alignment: Qt.AlignVCenter
                            visible: !appDelegate.isExternal
                            checked: appDelegate.isOn
                            onCheckedChanged: Autostart.setAppEnabled(appDelegate.modelData.id, checked)
                        }
                    }
                }
            }
        }
    }

    // ── Custom Commands ──────────────────────────────────────────────────

    SettingsCardSection {
        expanded: true
        icon: "terminal"
        title: Translation.tr("Custom Commands")
        visible: Autostart.isNiri

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            StyledText {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: Translation.tr("Shell commands run through niri's spawn-sh-at-startup, so pipes, env vars, and && work.")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MaterialTextField {
                    id: commandInput
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("e.g. telegram-desktop --start-minimized")
                    font.pixelSize: Appearance.font.pixelSize.small
                    onAccepted: {
                        Autostart.addCommand(commandInput.text)
                        commandInput.text = ""
                    }
                }

                RippleButton {
                    buttonText: Translation.tr("Add")
                    implicitHeight: 36
                    buttonRadius: Appearance.rounding.small
                    onClicked: {
                        Autostart.addCommand(commandInput.text)
                        commandInput.text = ""
                    }
                }
            }

            ListView {
                id: commandListView
                Layout.fillWidth: true
                implicitHeight: Math.min(240, commandListView.contentHeight)
                clip: true
                model: root.getCommandEntries()
                boundsBehavior: Flickable.StopAtBounds

                PagePlaceholder {
                    shown: commandListView.count === 0
                    icon: "terminal"
                    mascotPose: "salute-ready"
                    title: Translation.tr("No custom commands")
                    description: Translation.tr("Add a shell command above to run it at login.")
                    anchors.fill: parent
                }

                delegate: Item {
                    id: cmdDelegate
                    required property var modelData
                    required property int index
                    width: commandListView.width
                    implicitHeight: 44
                    height: 44

                    Rectangle {
                        anchors.fill: parent
                        anchors.leftMargin: 4
                        anchors.rightMargin: 4
                        radius: Appearance.rounding.small
                        color: cmdHover.hovered
                            ? (Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
                               : Appearance.inirEverywhere ? Appearance.inir.colLayer1Hover
                               : Appearance.zzzEverywhere ? Appearance.zzz.bg1
                               : Appearance.colors.colLayer1Hover)
                            : "transparent"
                        Behavior on color {
                            enabled: Appearance.animationsEnabled
                            animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }
                    }

                    HoverHandler { id: cmdHover }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        MaterialSymbol {
                            Layout.preferredWidth: 24
                            Layout.alignment: Qt.AlignVCenter
                            text: "terminal"
                            iconSize: 22
                            color: Appearance.colors.colOnSurface
                        }

                        StyledText {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            text: cmdDelegate.modelData.entry.command
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.family: Appearance.font.family.monospace
                            color: Appearance.colors.colOnSurface
                            elide: Text.ElideRight
                        }

                        StyledSwitch {
                            Layout.alignment: Qt.AlignVCenter
                            checked: cmdDelegate.modelData.entry.enabled
                            onCheckedChanged: Autostart.setEntryEnabled(cmdDelegate.modelData.originalIndex, checked)
                        }

                        RippleButton {
                            Layout.alignment: Qt.AlignVCenter
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            buttonRadius: Appearance.rounding.full
                            onClicked: Autostart.removeEntry(cmdDelegate.modelData.originalIndex)
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                text: "close"
                                iconSize: 18
                                color: Appearance.colors.colOnSurfaceVariant
                            }
                        }
                    }
                }
            }
        }
    }
}
