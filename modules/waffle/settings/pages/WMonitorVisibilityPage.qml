pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.waffle.looks
import qs.modules.waffle.settings

WSettingsPage {
    id: root
    settingsPageIndex: 11
    pageTitle: Translation.tr("Monitors")
    pageIcon: "desktop"
    pageDescription: Translation.tr("Choose which outputs show Waffle and shared shell surfaces")

    readonly property var waffleSurfaces: [
        { title: Translation.tr("Taskbar"), description: Translation.tr("Windows 11 taskbar and its hit target"), icon: "desktop", path: "waffles.bar.screenList" }
    ]
    readonly property var sharedSurfaces: [
        { title: Translation.tr("Notification popups"), description: Translation.tr("Transient notification toasts"), icon: "alert-filled", path: "notifications.screenList" },
        { title: Translation.tr("OSD indicators"), description: Translation.tr("Volume, brightness, media, and keyboard feedback"), icon: "speaker", path: "osd.screenList" }
    ]
    readonly property var desktopWidgetSurface: ({
        title: Translation.tr("Desktop widgets"),
        description: Translation.tr("Desktop Clock"),
        icon: "widgets",
        path: "background.widgets.screenList"
    })
    readonly property var desktopWidgetDescriptors: {
        void Config.revision
        return [
            {
                key: "waffle.clock",
                title: Translation.tr("Desktop Clock"),
                icon: "timer",
                defaultOn: Boolean(Config.options?.waffles?.background?.widgets?.clock?.enable ?? false)
            }
        ]
    }

    function connectedScreenNames(): var {
        const screens = Quickshell.screens
        let names = []
        for (let i = 0; i < screens.length; i++) {
            const name = String(screens[i]?.name ?? "")
            if (name.length > 0 && !names.includes(name))
                names.push(name)
        }
        return names
    }

    function primaryScreenName(): string {
        const preferred = Config.options?.display?.primaryMonitor ?? ""
        const names = connectedScreenNames()
        if (preferred && names.includes(preferred))
            return preferred
        return names.length > 0 ? names[0] : ""
    }

    function monitorOptions(): var {
        let opts = [{ value: "", displayName: Translation.tr("Auto (first available)") }]
        const names = connectedScreenNames()
        for (let i = 0; i < names.length; i++)
            opts.push({ value: names[i], displayName: names[i] })
        return opts
    }

    function monitorResolution(screen: var): string {
        const width = screen?.width ?? 0
        const height = screen?.height ?? 0
        if (width <= 0 || height <= 0)
            return Translation.tr("Resolution unknown")
        return width + "×" + height
    }

    function desktopWidgetOutputNames(): var {
        const names = connectedScreenNames().slice()
        for (const name of DesktopWidgetLayout.savedOutputNames()) {
            if (name.length > 0 && !names.includes(name))
                names.push(name)
        }
        return names
    }

    function desktopWidgetBaseEnabled(descriptor): bool {
        return Boolean(DesktopWidgetLayout.baseValue(
            descriptor.key, "enable", descriptor.defaultOn ?? false))
    }

    function desktopWidgetEnabled(outputName: string, descriptor): bool {
        return DesktopWidgetLayout.enabled(outputName, descriptor.key,
            desktopWidgetBaseEnabled(descriptor))
    }

    function desktopWidgetHasOverrides(outputName: string, widgetKey: string): bool {
        const override = DesktopWidgetLayout.widgetOverride(outputName, widgetKey)
        return override !== null && Object.keys(override).length > 0
    }

    function configuredScreens(path: string): var {
        const raw = Config.getNestedValue(path, [])
        const names = connectedScreenNames()
        let selected = []
        for (let i = 0; i < (raw?.length ?? 0); i++) {
            const name = String(raw[i] ?? "")
            if (name.length > 0 && names.includes(name) && !selected.includes(name))
                selected.push(name)
        }
        return selected
    }

    function allScreensEnabled(path: string): bool {
        const raw = Config.getNestedValue(path, [])
        return !raw || raw.length === 0
    }

    function surfaceEnabled(path: string, screenName: string): bool {
        if (allScreensEnabled(path))
            return true
        return configuredScreens(path).includes(screenName)
    }

    function visibilitySummary(path: string): string {
        if (allScreensEnabled(path))
            return Translation.tr("All monitors")
        const selected = configuredScreens(path)
        if (selected.length === 0)
            return Translation.tr("Saved outputs missing")
        if (selected.length === 1)
            return selected[0]
        return selected.length + Translation.tr(" monitors")
    }

    function setSurfaceAll(path: string): void {
        Config.setNestedValue(path, [])
    }

    function setSurfaceScreen(path: string, screenName: string, enabled: bool): void {
        const names = connectedScreenNames()
        if (!screenName || names.length === 0)
            return

        let current = configuredScreens(path)
        if (current.length === 0 && !enabled)
            current = names.slice()

        if (enabled) {
            if (!current.includes(screenName))
                current.push(screenName)
        } else {
            if (current.length <= 1 && current.includes(screenName))
                return
            current = current.filter(name => name !== screenName)
        }

        if (names.length > 0 && names.every(name => current.includes(name)))
            current = []
        Config.setNestedValue(path, current)
    }

    function setPathsToPrimary(paths: var): void {
        const primary = primaryScreenName()
        if (!primary)
            return
        let updates = {}
        for (let i = 0; i < paths.length; i++)
            updates[paths[i]] = [primary]
        Config.setNestedValues(updates)
    }

    function setPathsToAll(paths: var): void {
        let updates = {}
        for (let i = 0; i < paths.length; i++)
            updates[paths[i]] = []
        Config.setNestedValues(updates)
    }

    function surfacePaths(surfaces: var): var {
        let paths = []
        for (let i = 0; i < surfaces.length; i++)
            paths.push(surfaces[i].path)
        return paths
    }

    component InfoBanner: Rectangle {
        property string iconName: "info"
        property string message: ""

        Layout.fillWidth: true
        Layout.leftMargin: Looks.dp(14)
        Layout.rightMargin: Looks.dp(14)
        Layout.topMargin: Looks.dp(6)
        Layout.bottomMargin: Looks.dp(6)
        implicitHeight: bannerRow.implicitHeight + Looks.dp(18)
        radius: Looks.radius.large
        color: Looks.colors.bg2Base
        border.width: 1
        border.color: Looks.colors.bg2Border

        RowLayout {
            id: bannerRow
            anchors.fill: parent
            anchors.margins: Looks.dp(9)
            spacing: Looks.dp(10)

            Rectangle {
                implicitWidth: Looks.dp(28)
                implicitHeight: Looks.dp(28)
                radius: Looks.radius.medium
                color: Qt.alpha(Looks.colors.accent, 0.12)
                Layout.alignment: Qt.AlignTop

                FluentIcon {
                    anchors.centerIn: parent
                    icon: iconName
                    implicitSize: Looks.dp(15)
                    color: Looks.colors.accent
                }
            }

            WText {
                Layout.fillWidth: true
                text: message
                font.pixelSize: Looks.font.pixelSize.small
                color: Looks.colors.fg1
                wrapMode: Text.WordWrap
                lineHeight: 1.25
            }
        }
    }

    component PresetActions: RowLayout {
        required property var paths
        Layout.fillWidth: true
        Layout.leftMargin: Looks.dp(14)
        Layout.rightMargin: Looks.dp(14)
        Layout.topMargin: Looks.dp(4)
        Layout.bottomMargin: Looks.dp(8)
        spacing: Looks.dp(8)

        WButton {
            Layout.fillWidth: true
            text: Translation.tr("Primary only")
            icon.name: "eye-off"
            onClicked: root.setPathsToPrimary(paths)
        }

        WButton {
            Layout.fillWidth: true
            text: Translation.tr("Show everywhere")
            icon.name: "eye"
            onClicked: root.setPathsToAll(paths)
        }
    }

    component SectionLabel: WText {
        Layout.fillWidth: true
        Layout.leftMargin: Looks.dp(14)
        Layout.rightMargin: Looks.dp(14)
        Layout.topMargin: Looks.dp(4)
        text: ""
        font.pixelSize: Looks.font.pixelSize.small
        font.weight: Looks.font.weight.strong
        color: Looks.colors.subfg
    }

    component MonitorInfoRow: Rectangle {
        required property var monitor
        required property int index
        readonly property string screenName: monitor?.name ?? ""
        readonly property bool primary: screenName === root.primaryScreenName()

        Layout.fillWidth: true
        Layout.leftMargin: Looks.dp(14)
        Layout.rightMargin: Looks.dp(14)
        Layout.topMargin: Looks.dp(3)
        implicitHeight: monitorRow.implicitHeight + Looks.dp(18)
        radius: Looks.radius.medium
        color: primary ? Qt.alpha(Looks.colors.accent, 0.14) : Looks.colors.bg2Base
        border.width: 1
        border.color: primary ? Looks.colors.accent : Looks.colors.bg2Border

        RowLayout {
            id: monitorRow
            anchors.fill: parent
            anchors.margins: Looks.dp(9)
            spacing: Looks.dp(10)

            Rectangle {
                implicitWidth: Looks.dp(30)
                implicitHeight: Looks.dp(30)
                radius: Looks.radius.medium
                color: primary ? Looks.colors.accent : Looks.colors.bg1
                Layout.alignment: Qt.AlignVCenter

                FluentIcon {
                    anchors.centerIn: parent
                    icon: "desktop"
                    implicitSize: Looks.dp(16)
                    color: primary ? Looks.colors.accentFg : Looks.colors.subfg
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Looks.dp(1)

                WText {
                    Layout.fillWidth: true
                    text: screenName || (Translation.tr("Monitor ") + (index + 1))
                    font.pixelSize: Looks.font.pixelSize.normal
                    font.weight: Looks.font.weight.strong
                    color: Looks.colors.fg
                    elide: Text.ElideRight
                }

                WText {
                    Layout.fillWidth: true
                    text: root.monitorResolution(monitor)
                    font.pixelSize: Looks.font.pixelSize.small
                    color: Looks.colors.subfg
                    elide: Text.ElideRight
                }
            }

            WText {
                visible: primary
                text: Translation.tr("Primary")
                font.pixelSize: Looks.font.pixelSize.small
                font.weight: Looks.font.weight.strong
                color: Looks.colors.accent
                Layout.alignment: Qt.AlignVCenter
            }

            WButton {
                visible: !primary
                text: Translation.tr("Use")
                icon.name: "checkmark"
                onClicked: if (screenName.length > 0) Config.setNestedValue("display.primaryMonitor", screenName)
            }
        }
    }

    component SurfaceVisibilityBlock: Rectangle {
        required property var surface
        readonly property bool allOutputs: root.allScreensEnabled(surface.path)
        readonly property int leadingWidth: Looks.dp(34)

        Layout.fillWidth: true
        Layout.leftMargin: Looks.dp(14)
        Layout.rightMargin: Looks.dp(14)
        Layout.topMargin: Looks.dp(5)
        implicitHeight: surfaceColumn.implicitHeight + Looks.dp(20)
        radius: Looks.radius.large
        color: Looks.colors.bg2Base
        border.width: 1
        border.color: allOutputs ? Looks.colors.bg2Border : Looks.colors.accent

        ColumnLayout {
            id: surfaceColumn
            anchors.fill: parent
            anchors.margins: Looks.dp(10)
            spacing: Looks.dp(8)

            RowLayout {
                Layout.fillWidth: true
                spacing: Looks.dp(10)

                Rectangle {
                    implicitWidth: leadingWidth
                    implicitHeight: leadingWidth
                    radius: Looks.radius.medium
                    color: allOutputs ? Looks.colors.bg1 : Looks.colors.accent
                    Layout.alignment: Qt.AlignTop

                    FluentIcon {
                        anchors.centerIn: parent
                        icon: surface.icon
                        implicitSize: Looks.dp(17)
                        color: allOutputs ? Looks.colors.subfg : Looks.colors.accentFg
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Looks.dp(2)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Looks.dp(8)

                        WText {
                            Layout.fillWidth: true
                            text: surface.title
                            font.pixelSize: Looks.font.pixelSize.normal
                            font.weight: Looks.font.weight.strong
                            color: Looks.colors.fg
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            implicitWidth: summaryText.implicitWidth + Looks.dp(16)
                            implicitHeight: summaryText.implicitHeight + Looks.dp(8)
                            radius: Looks.radius.xLarge
                            color: allOutputs ? Looks.colors.bg1 : Looks.colors.accent
                            Layout.alignment: Qt.AlignVCenter

                            WText {
                                id: summaryText
                                anchors.centerIn: parent
                                text: root.visibilitySummary(surface.path)
                                font.pixelSize: Looks.font.pixelSize.small
                                font.weight: Looks.font.weight.strong
                                color: allOutputs ? Looks.colors.fg1 : Looks.colors.accentFg
                            }
                        }
                    }

                    WText {
                        Layout.fillWidth: true
                        text: surface.description
                        font.pixelSize: Looks.font.pixelSize.small
                        color: Looks.colors.subfg
                        wrapMode: Text.WordWrap
                        lineHeight: 1.2
                    }
                }
            }

            WText {
                Layout.fillWidth: true
                Layout.leftMargin: leadingWidth + Looks.dp(10)
                text: Translation.tr("Visible on")
                font.pixelSize: Looks.font.pixelSize.small
                font.weight: Looks.font.weight.strong
                color: Looks.colors.subfg
            }

            Flow {
                Layout.fillWidth: true
                Layout.leftMargin: leadingWidth + Looks.dp(10)
                spacing: Looks.dp(5)

                WButton {
                    text: Translation.tr("All outputs")
                    icon.name: "checkmark"
                    checked: allOutputs
                    checkable: false
                    font.pixelSize: Looks.font.pixelSize.small
                    horizontalPadding: Looks.dp(10)
                    verticalPadding: Looks.dp(5)
                    onClicked: root.setSurfaceAll(surface.path)
                }

                Repeater {
                    model: root.connectedScreenNames()

                    WButton {
                        required property var modelData
                        readonly property string screenName: String(modelData ?? "")
                        text: screenName
                        icon.name: "desktop"
                        checked: root.surfaceEnabled(surface.path, screenName)
                        checkable: false
                        font.pixelSize: Looks.font.pixelSize.small
                        horizontalPadding: Looks.dp(10)
                        verticalPadding: Looks.dp(5)
                        onClicked: root.setSurfaceScreen(surface.path, screenName, !checked)
                    }
                }
            }
        }
    }

    component DesktopWidgetOutputBlock: Rectangle {
        id: outputBlock
        required property string outputName
        readonly property bool connected: root.connectedScreenNames().includes(outputName)
        readonly property bool primary: outputName === root.primaryScreenName()
        readonly property bool hasOverrides: DesktopWidgetLayout.outputRecord(outputName) !== null
        readonly property bool globallyVisible: DesktopWidgetLayout.outputAllowed(outputName)

        Layout.fillWidth: true
        Layout.leftMargin: Looks.dp(14)
        Layout.rightMargin: Looks.dp(14)
        Layout.topMargin: Looks.dp(5)
        implicitHeight: outputColumn.implicitHeight + Looks.dp(20)
        radius: Looks.radius.large
        color: Looks.colors.bg2Base
        border.width: 1
        border.color: outputBlock.primary ? Looks.colors.accent : Looks.colors.bg2Border

        ColumnLayout {
            id: outputColumn
            anchors.fill: parent
            anchors.margins: Looks.dp(10)
            spacing: Looks.dp(4)

            RowLayout {
                Layout.fillWidth: true
                spacing: Looks.dp(8)

                FluentIcon {
                    icon: "desktop"
                    implicitSize: Looks.dp(17)
                    color: outputBlock.primary ? Looks.colors.accent : Looks.colors.subfg
                }

                WText {
                    Layout.fillWidth: true
                    text: outputBlock.outputName
                    font.pixelSize: Looks.font.pixelSize.normal
                    font.weight: Looks.font.weight.strong
                    color: Looks.colors.fg
                    elide: Text.ElideRight
                }

                WText {
                    visible: !outputBlock.connected
                    text: Translation.tr("Disconnected")
                    font.pixelSize: Looks.font.pixelSize.small
                    color: Looks.colors.danger
                }

                WText {
                    visible: !outputBlock.globallyVisible
                    text: Translation.tr("Desktop widgets") + ": " + Translation.tr("Disabled")
                    font.pixelSize: Looks.font.pixelSize.small
                    color: Looks.colors.danger
                }

                WButton {
                    visible: outputBlock.hasOverrides
                    text: Translation.tr("Reset")
                    icon.name: "arrow-reset"
                    onClicked: DesktopWidgetLayout.clearOutput(outputBlock.outputName)
                }
            }

            Repeater {
                model: root.desktopWidgetDescriptors

                WSettingsRow {
                    id: widgetOutputRow
                    required property var modelData
                    enableSettingsSearch: false
                    icon: widgetOutputRow.modelData.icon
                    label: widgetOutputRow.modelData.title
                    description: outputBlock.outputName
                    clickable: false

                    control: Component {
                        RowLayout {
                            spacing: Looks.dp(5)

                            WSwitch {
                                enabled: outputBlock.globallyVisible
                                checked: root.desktopWidgetEnabled(
                                    outputBlock.outputName, widgetOutputRow.modelData)
                                onClicked: DesktopWidgetLayout.setEnabled(
                                    outputBlock.outputName, widgetOutputRow.modelData.key,
                                    !checked)
                            }

                            WButton {
                                visible: root.desktopWidgetHasOverrides(
                                    outputBlock.outputName, widgetOutputRow.modelData.key)
                                text: ""
                                icon.name: "arrow-reset"
                                onClicked: DesktopWidgetLayout.clearWidget(
                                    outputBlock.outputName, widgetOutputRow.modelData.key)
                            }
                        }
                    }
                }
            }
        }
    }

    WSettingsCard {
        title: Translation.tr("Shell visibility")
        icon: "desktop"

        InfoBanner {
            iconName: "info"
            message: Translation.tr("This page controls where iNiR shell surfaces appear. It does not change monitor resolution, scale, rotation, or physical output layout.")
        }

        WSettingsDropdown {
            label: Translation.tr("Primary monitor")
            icon: "desktop"
            description: Translation.tr("Fallback output for popups when the focused monitor is unknown")
            currentValue: Config.options?.display?.primaryMonitor ?? ""
            options: root.monitorOptions()
            onSelected: newValue => Config.setNestedValue("display.primaryMonitor", newValue)
        }

        SectionLabel {
            text: Translation.tr("Connected outputs")
        }

        Repeater {
            model: Quickshell.screens
            MonitorInfoRow {
                required property var modelData
                monitor: modelData
            }
        }
    }

    WSettingsCard {
        title: Translation.tr("Overview placement")
        icon: "multitasking"

        WSettingsSwitch {
            label: Translation.tr("Active screen only")
            icon: "desktop"
            description: Translation.tr("Open the overview on the monitor where it was invoked")
            checked: Config.options?.overview?.activeScreenOnly ?? true
            onCheckedChanged: Config.setNestedValue("overview.activeScreenOnly", checked)
        }
    }

    WSettingsCard {
        title: Translation.tr("Waffle shell surfaces")
        icon: "desktop"

        InfoBanner {
            iconName: "apps"
            message: Translation.tr("These controls only affect the Waffle family: the Windows 11 taskbar and its activation area.")
        }

        PresetActions {
            paths: root.surfacePaths(root.waffleSurfaces)
        }

        Repeater {
            model: root.waffleSurfaces
            SurfaceVisibilityBlock {
                required property var modelData
                surface: modelData
            }
        }
    }

    WSettingsCard {
        title: Translation.tr("Desktop widgets")
        icon: "widgets"
        collapsible: true
        expanded: false

        InfoBanner {
            iconName: "desktop"
            message: Translation.tr("Desktop Clock")
        }

        SurfaceVisibilityBlock {
            surface: root.desktopWidgetSurface
        }

        Repeater {
            model: root.desktopWidgetOutputNames()

            DesktopWidgetOutputBlock {
                required property var modelData
                outputName: String(modelData ?? "")
            }
        }
    }

    WSettingsCard {
        title: Translation.tr("Popups")
        icon: "alert"

        InfoBanner {
            iconName: "info"
            message: Translation.tr("These surfaces are shared by both families, so the same monitor choices apply in Material and Waffle.")
        }

        PresetActions {
            paths: root.surfacePaths(root.sharedSurfaces)
        }

        Repeater {
            model: root.sharedSurfaces
            SurfaceVisibilityBlock {
                required property var modelData
                surface: modelData
            }
        }
    }
}
