pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services

Item {
    id: root

    // Which plugin is currently open (set by parent SidebarLeftContent)
    property string activePluginId: ""

    // Discovered plugins from filesystem
    property var plugins: []
    property bool pluginsLoaded: false

    // Add form state
    property bool showAddForm: false
    property bool addingInProgress: false

    // Signals to parent — parent owns the WebAppView lifecycle
    signal pluginRequested(string id, string url, string name, string icon, var userscriptSources)
    signal pluginCloseRequested()
    signal pluginRemoved(string id)

    // Style tokens
    readonly property color colText: Appearance.angelEverywhere ? Appearance.angel.colText
        : Appearance.inirEverywhere ? Appearance.inir.colText
        : Appearance.colors.colOnLayer1
    readonly property color colTextSecondary: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary
        : Appearance.colors.colSubtext
    readonly property color colBg: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.inirEverywhere ? Appearance.inir.colLayer1
        : Appearance.auroraEverywhere ? "transparent"
        : Appearance.colors.colLayer1
    readonly property color colBgHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
        : Appearance.inirEverywhere ? Appearance.inir.colLayer1Hover
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
        : Appearance.colors.colLayer1Hover
    readonly property color colBorder: Appearance.angelEverywhere ? Appearance.angel.colCardBorder
        : Appearance.inirEverywhere ? Appearance.inir.colBorder
        : Appearance.colors.colLayer0Border
    readonly property real rounding: Appearance.rounding.small

    function scanPlugins(): void {
        scanProcess.running = true
    }

    function _parsePluginList(jsonStr: string): void {
        try {
            const parsed = JSON.parse(jsonStr)
            root.plugins = parsed
            root.pluginsLoaded = true
        } catch (e) {
            console.warn("[Plugins] Failed to parse plugin list:", e)
            root.plugins = []
            root.pluginsLoaded = true
        }
    }

    function addPlugin(url: string): void {
        if (!url || root.addingInProgress) return
        root.addingInProgress = true
        addProcess.command = ["/usr/bin/python3", Quickshell.shellPath("scripts/add-plugin.py"), "--url", url]
        addProcess.running = true
    }

    function removePlugin(id: string): void {
        root.pluginRemoved(id)
        removeProcess.command = ["/usr/bin/rm", "-rf",
            FileUtils.trimFileProtocol(`${Directories.config}/illogical-impulse/plugins/${id}`)]
        removeProcess.running = true
    }

    // ─── Processes ───────────────────────────────────────────────────
    Process {
        id: scanProcess
        command: ["/usr/bin/python3", Quickshell.shellPath("scripts/scan-plugins.py")]
        stdout: SplitParser {
            onRead: data => root._parsePluginList(data)
        }
        onExited: (code, status) => {
            if (code !== 0 && !root.pluginsLoaded) {
                root.plugins = []
                root.pluginsLoaded = true
            }
        }
    }

    Process {
        id: addProcess
        stdout: SplitParser {
            onRead: data => { if (Quickshell.env("QS_DEBUG") === "1") console.log("[Plugins] Added:", data) }
        }
        stderr: SplitParser {
            onRead: data => { if (Quickshell.env("QS_DEBUG") === "1") console.log("[Plugins:add]", data) }
        }
        onExited: (code, status) => {
            root.addingInProgress = false
            root.showAddForm = false
            root.scanPlugins()
        }
    }

    Process {
        id: removeProcess
        onExited: (code, status) => root.scanPlugins()
    }

    Component.onCompleted: scanPlugins()

    Timer {
        id: rescanTimer
        interval: 30000
        repeat: true
        running: true
        onTriggered: root.scanPlugins()
    }

    // ─── Plugin list UI ──────────────────────────────────────────────
    Flickable {
        anchors.fill: parent
        anchors.margins: 8
        contentHeight: listColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: listColumn
            width: parent.width
            spacing: 8

            // Header
            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 4
                spacing: 8

                MaterialSymbol {
                    text: "extension"
                    iconSize: 20
                    color: root.colText
                }
                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Web Apps")
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.weight: Font.Medium
                    color: root.colText
                }
                // Refresh
                RippleButton {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    buttonRadius: root.rounding
                    colBackground: "transparent"
                    colBackgroundHover: root.colBgHover
                    onClicked: root.scanPlugins()
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "refresh"
                        iconSize: 16
                        color: root.colTextSecondary
                    }
                }
                // Add button
                RippleButton {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    buttonRadius: root.rounding
                    colBackground: "transparent"
                    colBackgroundHover: root.colBgHover
                    onClicked: root.showAddForm = !root.showAddForm
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: root.showAddForm ? "close" : "add"
                        iconSize: 18
                        color: root.showAddForm ? root.colTextSecondary : Appearance.colors.colPrimary
                    }
                }
            }

            // ── Add form ─────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: addFormCol.implicitHeight + 20
                radius: root.rounding
                color: root.colBg
                border.width: Appearance.inirEverywhere || Appearance.angelEverywhere ? 1 : 0
                border.color: root.colBorder
                visible: root.showAddForm
                clip: true

                ColumnLayout {
                    id: addFormCol
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    StyledText {
                        text: Translation.tr("Add Web App")
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.Medium
                        color: root.colText
                    }

                    StyledText {
                        text: Translation.tr("Paste a URL — name and icon are fetched automatically")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: root.colTextSecondary
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 36
                            radius: root.rounding
                            color: Appearance.angelEverywhere ? Qt.rgba(0,0,0,0.15)
                                 : Appearance.inirEverywhere ? Appearance.inir.colLayer0
                                 : Appearance.colors.colLayer0
                            border.width: urlInput.activeFocus ? 2 : 1
                            border.color: urlInput.activeFocus ? Appearance.colors.colPrimary : root.colBorder

                            TextInput {
                                id: urlInput
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                verticalAlignment: Text.AlignVCenter
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.family: Appearance.font.family.monospace
                                color: root.colText
                                selectionColor: Appearance.colors.colPrimary
                                clip: true
                                Keys.onReturnPressed: {
                                    if (text.trim())
                                        root.addPlugin(text.trim())
                                }

                                StyledText {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    text: "https://example.com"
                                    font: urlInput.font
                                    color: root.colTextSecondary
                                    opacity: 0.5
                                    visible: !urlInput.text && !urlInput.activeFocus
                                }
                            }
                        }

                        RippleButton {
                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 36
                            buttonRadius: root.rounding
                            colBackground: Appearance.colors.colPrimary
                            colBackgroundHover: Qt.lighter(Appearance.colors.colPrimary, 1.15)
                            enabled: urlInput.text.trim() !== "" && !root.addingInProgress
                            opacity: enabled ? 1 : 0.5
                            onClicked: root.addPlugin(urlInput.text.trim())

                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                text: root.addingInProgress ? "hourglass_empty" : "add"
                                iconSize: 18
                                color: Appearance.colors.colOnPrimary
                            }
                        }
                    }
                }
            }

            // ── Plugin cards ─────────────────────────────────────
            Repeater {
                model: root.plugins

                delegate: RippleButton {
                    id: pluginCard
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    implicitHeight: 56
                    buttonRadius: root.rounding
                    colBackground: (pluginCard.modelData.id ?? "") === root.activePluginId
                        ? root.colBgHover : root.colBg
                    colBackgroundHover: root.colBgHover

                    onClicked: root.pluginRequested(
                        modelData.id ?? "",
                        modelData.url ?? "",
                        modelData.name ?? modelData.id ?? "Plugin",
                        modelData.icon ?? "language",
                        modelData.userscriptSources ?? []
                    )

                    contentItem: RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12

                        // Favicon or MaterialSymbol
                        Loader {
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                            active: true
                            sourceComponent: (pluginCard.modelData.faviconPath ?? "") !== ""
                                ? faviconComp : symbolComp

                            Component {
                                id: faviconComp
                                Image {
                                    source: "file://" + (pluginCard.modelData.faviconPath ?? "")
                                    sourceSize: Qt.size(24, 24)
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                }
                            }
                            Component {
                                id: symbolComp
                                MaterialSymbol {
                                    text: pluginCard.modelData.icon ?? "language"
                                    iconSize: 22
                                    color: Appearance.colors.colPrimary
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            StyledText {
                                Layout.fillWidth: true
                                text: pluginCard.modelData.name ?? pluginCard.modelData.id ?? "Plugin"
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.weight: Font.Medium
                                color: root.colText
                                elide: Text.ElideRight
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: {
                                    const url = pluginCard.modelData.url ?? ""
                                    try { return new URL(url).hostname } catch(e) { return url }
                                }
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: root.colTextSecondary
                                elide: Text.ElideRight
                            }
                        }

                        // Delete button
                        RippleButton {
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                            buttonRadius: Appearance.rounding.verysmall
                            colBackground: "transparent"
                            colBackgroundHover: root.colBgHover
                            onClicked: root.removePlugin(pluginCard.modelData.id ?? "")
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                text: "delete"
                                iconSize: 14
                                color: root.colTextSecondary
                            }
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: 8 }
        }
    }

    // ── Empty state ──────────────────────────────────────────────
    ColumnLayout {
        anchors.centerIn: parent
        spacing: 12
        visible: root.pluginsLoaded && root.plugins.length === 0 && !root.showAddForm

        MaterialSymbol {
            Layout.alignment: Qt.AlignHCenter
            text: "extension_off"
            iconSize: 48
            color: root.colTextSecondary
        }
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Translation.tr("No web apps installed")
            font.pixelSize: Appearance.font.pixelSize.normal
            color: root.colText
        }
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Translation.tr("Tap + to add one")
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: root.colTextSecondary
        }
    }
}
