import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    id: root
    settingsPageIndex: 15
    settingsPageName: Translation.tr("Monitors")

    property string activeSection: "outputs"

    readonly property string niriConfigScript: Quickshell.shellPath("scripts/niri-config.py")
    property bool monitorLayoutBusy: false
    property string monitorLayoutError: ""
    property string monitorLayoutInfo: ""
    property string monitorLayoutWarning: ""
    property string draggingLayoutOutput: ""
    property var monitorLayoutSnapshot: ({})
    property var monitorLayoutViewportBounds: ({})
    property bool monitorLayoutPreserveViewport: false
    property bool monitorLayoutAwaitingReload: false
    property int monitorLayoutReloadAttempts: 0
    property string pendingLayoutOutput: ""
    property int pendingLayoutNewX: 0
    property int pendingLayoutNewY: 0

    signal monitorPositionFinished(string outputName, bool success)

    SettingsTaskNavigator {
        icon: "settings_input_component"
        title: Translation.tr("Monitors")
        description: Translation.tr("Choose which monitor shows each shell surface: outputs, ii surfaces, desktop widgets and shared popups.")
        summary: Translation.tr("Outputs · Surfaces · Widgets · Popups")
        currentValue: root.activeSection
        onSelected: value => root.activeSection = value
        options: [
            { displayName: Translation.tr("Outputs"), icon: "monitor", value: "outputs" },
            { displayName: Translation.tr("ii surfaces"), icon: "web_asset", value: "surfaces" },
            { displayName: Translation.tr("Desktop widgets"), icon: "widgets", value: "widgets" },
            { displayName: Translation.tr("Popups"), icon: "notifications", value: "popups" }
        ]
    }

    readonly property var iiSurfaces: [
        { title: Translation.tr("Bar"), description: Translation.tr("Top workspace bar, or the vertical bar when that mode is enabled"), icon: "web_asset", path: "bar.screenList" },
        { title: Translation.tr("Dock"), description: Translation.tr("Application dock and its hover reveal area"), icon: "call_to_action", path: "dock.screenList" },
        { title: Translation.tr("Sidebars"), description: Translation.tr("Feature and system sidebars on each screen edge"), icon: "side_navigation", path: "sidebar.screenList" },
        { title: Translation.tr("Media controls"), description: Translation.tr("Floating player popup opened from the bar or IPC"), selectionLabel: Translation.tr("Enabled outputs"), icon: "music_note", path: "media.screenList" }
    ]
    readonly property var sharedSurfaces: [
        { title: Translation.tr("Notification popups"), description: Translation.tr("Transient notification toasts"), icon: "notifications", path: "notifications.screenList" },
        { title: Translation.tr("OSD indicators"), description: Translation.tr("Volume, brightness, media, and keyboard feedback"), icon: "volume_up", path: "osd.screenList" }
    ]
    readonly property var desktopWidgetSurface: ({
        title: Translation.tr("Desktop widgets"),
        description: Translation.tr("Clock, weather, media, visualizer, and custom widgets"),
        icon: "widgets",
        path: "background.widgets.screenList"
    })
    readonly property var desktopWidgetDescriptors: {
        void Config.revision
        void CustomWidgets.ready
        const widgets = [
            { key: "clock", title: Translation.tr("Clock"), icon: "schedule", defaultOn: true },
            { key: "weather", title: Translation.tr("Weather"), icon: "cloud", defaultOn: false },
            { key: "mediaControls", title: Translation.tr("Media controls"), icon: "album", defaultOn: false },
            { key: "visualizer", title: Translation.tr("Visualizer"), icon: "graphic_eq", defaultOn: false },
            { key: "systemMonitor", title: Translation.tr("System monitor"), icon: "monitor_heart", defaultOn: false },
            { key: "battery", title: Translation.tr("Battery"), icon: "battery_full", defaultOn: false },
            { key: "notes", title: Translation.tr("Notes"), icon: "sticky_note_2", defaultOn: false },
            { key: "calendarUpcoming", title: Translation.tr("Upcoming Events"), icon: "event", defaultOn: false },
            { key: "monthCalendar", title: Translation.tr("Month Calendar"), icon: "calendar_month", defaultOn: false },
            { key: "todo", title: Translation.tr("Todo"), icon: "checklist", defaultOn: false },
            { key: "timers", title: Translation.tr("Timers"), icon: "timer", defaultOn: false },
            { key: "uptime", title: Translation.tr("System uptime"), icon: "avg_pace", defaultOn: false },
            { key: "worldClock", title: Translation.tr("World clock"), icon: "public", defaultOn: false },
            { key: "userCard", title: Translation.tr("User card"), icon: "account_circle", defaultOn: false },
            { key: "newsTicker", title: Translation.tr("News Ticker"), icon: "newspaper", defaultOn: false },
            { key: "japaneseTypography", title: Translation.tr("Japanese Typography"), icon: "translate", defaultOn: false },
            { key: "customImage", title: Translation.tr("Custom image"), icon: "add_photo_alternate", defaultOn: false },
            { key: "imageConverter", title: Translation.tr("Image converter"), icon: "transform", defaultOn: false },
            { key: "mascot", title: Translation.tr("Mascot"), icon: "pets", defaultOn: false }
        ]
        const instances = Config.getNestedValue("background.widgets.mascotInstances", {}) ?? {}
        let mascotIndex = 1
        for (const id of Object.keys(instances).sort()) {
            widgets.push({
                key: "mascotInstances." + id,
                title: Translation.tr("Mascot") + " " + mascotIndex++,
                icon: "pets",
                defaultOn: Boolean(instances[id]?.enable)
            })
        }
        if (CustomWidgets.ready) {
            for (const widget of CustomWidgets.widgets) {
                widgets.push({
                    key: "custom." + widget.id,
                    title: String(widget.name ?? widget.id),
                    icon: String(widget.icon ?? "widgets"),
                    defaultOn: Boolean(Config.getNestedValue(
                        "background.widgets.custom." + widget.id + ".enable", false))
                })
            }
        }
        return widgets
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
        let opts = [{ displayName: Translation.tr("Auto (first available)"), icon: "auto_mode", value: "" }]
        const names = connectedScreenNames()
        for (let i = 0; i < names.length; i++)
            opts.push({ displayName: names[i], icon: "monitor", value: names[i] })
        return opts
    }

    function monitorResolution(screen: var): string {
        const width = screen?.width ?? 0
        const height = screen?.height ?? 0
        if (width <= 0 || height <= 0)
            return Translation.tr("Resolution unknown")
        return width + "×" + height
    }

    function niriOutputNames(): var {
        const source = Object.keys(monitorLayoutSnapshot).length > 0
            ? monitorLayoutSnapshot : (NiriService.outputs ?? ({}))
        return Object.keys(source).filter(name => {
            const entry = source[name]
            return entry?.logical !== undefined || entry?.width !== undefined
        })
            .sort((a, b) => {
                const ao = niriLogicalRect(a)
                const bo = niriLogicalRect(b)
                if (ao.x !== bo.x) return ao.x - bo.x
                if (ao.y !== bo.y) return ao.y - bo.y
                return a.localeCompare(b)
            })
    }

    function liveNiriOutputNames(): var {
        const outputs = NiriService.outputs ?? ({})
        return Object.keys(outputs).filter(name => outputs[name]?.logical).sort()
    }

    function boundsForLayout(layout: var): var {
        const names = Object.keys(layout ?? ({}))
        if (names.length === 0)
            return { minX: 0, minY: 0, width: 1920, height: 1080 }

        let minX = Infinity
        let minY = Infinity
        let maxX = -Infinity
        let maxY = -Infinity
        for (const name of names) {
            const rect = layout[name]
            minX = Math.min(minX, Number(rect.x ?? 0))
            minY = Math.min(minY, Number(rect.y ?? 0))
            maxX = Math.max(maxX, Number(rect.x ?? 0) + Number(rect.width ?? 1))
            maxY = Math.max(maxY, Number(rect.y ?? 0) + Number(rect.height ?? 1))
        }
        return {
            minX: minX,
            minY: minY,
            width: Math.max(1, maxX - minX),
            height: Math.max(1, maxY - minY)
        }
    }

    function syncMonitorLayoutSnapshot(force: bool): void {
        if (!force && (draggingLayoutOutput.length > 0 || monitorLayoutBusy))
            return

        const outputs = NiriService.outputs ?? ({})
        const snapshot = {}
        for (const name of Object.keys(outputs)) {
            const logical = outputs[name]?.logical
            if (!logical)
                continue
            snapshot[name] = {
                x: Number(logical.x ?? 0),
                y: Number(logical.y ?? 0),
                width: Math.max(1, Number(logical.width ?? 1920)),
                height: Math.max(1, Number(logical.height ?? 1080))
            }
        }
        monitorLayoutSnapshot = snapshot
        if (!monitorLayoutPreserveViewport || !monitorLayoutViewportBounds?.width)
            monitorLayoutViewportBounds = boundsForLayout(snapshot)
        monitorLayoutPreserveViewport = false
    }

    function pendingMonitorPositionIsLive(): bool {
        if (!pendingLayoutOutput.length)
            return false
        const logical = NiriService.outputs?.[pendingLayoutOutput]?.logical
        if (!logical)
            return false
        return Math.round(Number(logical.x ?? 0)) === pendingLayoutNewX
            && Math.round(Number(logical.y ?? 0)) === pendingLayoutNewY
    }

    function niriLogicalRect(outputName: string): var {
        const staged = monitorLayoutSnapshot?.[outputName]
        if (staged)
            return staged
        const logical = NiriService.outputs?.[outputName]?.logical
        if (!logical)
            return { x: 0, y: 0, width: 1920, height: 1080 }
        return {
            x: Number(logical.x ?? 0),
            y: Number(logical.y ?? 0),
            width: Math.max(1, Number(logical.width ?? 1920)),
            height: Math.max(1, Number(logical.height ?? 1080))
        }
    }

    function monitorLayoutBounds(): var {
        if (monitorLayoutViewportBounds?.width > 0)
            return monitorLayoutViewportBounds
        const names = niriOutputNames()
        if (names.length === 0)
            return { minX: 0, minY: 0, width: 1920, height: 1080 }

        let minX = Infinity
        let minY = Infinity
        let maxX = -Infinity
        let maxY = -Infinity
        for (const name of names) {
            const rect = niriLogicalRect(name)
            minX = Math.min(minX, rect.x)
            minY = Math.min(minY, rect.y)
            maxX = Math.max(maxX, rect.x + rect.width)
            maxY = Math.max(maxY, rect.y + rect.height)
        }
        return {
            minX: minX,
            minY: minY,
            width: Math.max(1, maxX - minX),
            height: Math.max(1, maxY - minY)
        }
    }

    function monitorPositionOverlaps(outputName: string, x: real, y: real, width: real, height: real): bool {
        for (const name of niriOutputNames()) {
            if (name === outputName)
                continue
            const other = niriLogicalRect(name)
            if (!(x + width <= other.x || x >= other.x + other.width
                    || y + height <= other.y || y >= other.y + other.height))
                return true
        }
        return false
    }

    function placementCandidates(outputName: string, x: real, y: real, width: real, height: real): var {
        const result = []
        for (const name of niriOutputNames()) {
            if (name === outputName)
                continue
            const other = niriLogicalRect(name)
            const minEdgeY = other.y - height + 1
            const maxEdgeY = other.y + other.height - 1
            const minEdgeX = other.x - width + 1
            const maxEdgeX = other.x + other.width - 1
            const freeEdgeY = Math.max(minEdgeY, Math.min(maxEdgeY, y))
            const freeEdgeX = Math.max(minEdgeX, Math.min(maxEdgeX, x))
            const alignY = [
                freeEdgeY,
                other.y,
                other.y + other.height - height,
                Math.round(other.y + (other.height - height) / 2)
            ]
            const alignX = [
                freeEdgeX,
                other.x,
                other.x + other.width - width,
                Math.round(other.x + (other.width - width) / 2)
            ]

            for (const y of alignY) {
                result.push(Qt.point(other.x - width, y))
                result.push(Qt.point(other.x + other.width, y))
            }
            for (const x of alignX) {
                result.push(Qt.point(x, other.y - height))
                result.push(Qt.point(x, other.y + other.height))
            }
        }
        return result
    }

    function nearestValidPlacement(outputName: string, x: real, y: real, width: real, height: real, threshold: real, force: bool): point {
        let best = Qt.point(x, y)
        let bestDistance = force ? Infinity : threshold
        for (const candidate of placementCandidates(outputName, x, y, width, height)) {
            if (monitorPositionOverlaps(outputName, candidate.x, candidate.y, width, height))
                continue
            const distance = Math.hypot(candidate.x - x, candidate.y - y)
            if (distance < bestDistance) {
                bestDistance = distance
                best = candidate
            }
        }
        return best
    }

    function monitorTouchesLayout(outputName: string, x: real, y: real, width: real, height: real): bool {
        const right = x + width
        const bottom = y + height
        for (const name of niriOutputNames()) {
            if (name === outputName)
                continue
            const other = niriLogicalRect(name)
            const otherRight = other.x + other.width
            const otherBottom = other.y + other.height
            const verticalOverlap = Math.min(bottom, otherBottom) - Math.max(y, other.y)
            const horizontalOverlap = Math.min(right, otherRight) - Math.max(x, other.x)
            if ((right === other.x || x === otherRight) && verticalOverlap > 0)
                return true
            if ((bottom === other.y || y === otherBottom) && horizontalOverlap > 0)
                return true
        }
        return false
    }

    function commitMonitorPosition(outputName: string, x: int, y: int, oldX: int, oldY: int): void {
        if (monitorLayoutBusy || !CompositorService.isNiri || !outputName.length)
            return
        if (x === oldX && y === oldY) {
            monitorPositionFinished(outputName, true)
            return
        }

        const stagedNames = niriOutputNames().slice().sort()
        const liveNames = liveNiriOutputNames()
        if (stagedNames.length !== liveNames.length
                || stagedNames.some((name, index) => name !== liveNames[index])) {
            monitorLayoutError = Translation.tr("The connected displays changed while you were arranging them. The layout was refreshed; drag again to apply a position.")
            syncMonitorLayoutSnapshot(true)
            monitorPositionFinished(outputName, false)
            return
        }

        monitorLayoutBusy = true
        monitorLayoutPreserveViewport = true
        monitorLayoutError = ""
        monitorLayoutWarning = monitorTouchesLayout(outputName, x, y,
            niriLogicalRect(outputName).width, niriLogicalRect(outputName).height)
            ? ""
            : Translation.tr("This output has a gap from the others. Niri allows it, but the pointer cannot cross that gap directly.")
        monitorLayoutInfo = Translation.tr("Saving monitor layout…")
        pendingLayoutOutput = outputName
        pendingLayoutNewX = x
        pendingLayoutNewY = y

        const layout = {}
        for (const name of niriOutputNames()) {
            const rect = niriLogicalRect(name)
            layout[name] = {
                x: name === outputName ? x : Math.round(rect.x),
                y: name === outputName ? y : Math.round(rect.y)
            }
        }
        monitorLayoutPersist.command = ["python3", niriConfigScript, "persist-layout", JSON.stringify(layout)]
        monitorLayoutPersist.running = true
    }

    function finishMonitorPositionTransaction(success: bool): void {
        const outputName = pendingLayoutOutput
        pendingLayoutOutput = ""
        monitorLayoutAwaitingReload = false
        monitorLayoutBusy = false
        if (!success)
            monitorLayoutPreserveViewport = false
        syncMonitorLayoutSnapshot(true)
        monitorPositionFinished(outputName, success)
    }

    Process {
        id: monitorLayoutPersist
        stdout: StdioCollector { id: monitorLayoutPersistOut }
        stderr: StdioCollector { id: monitorLayoutPersistErr }
        onExited: exitCode => {
            if (exitCode === 0) {
                root.monitorLayoutError = ""
                root.monitorLayoutInfo = Translation.tr("Applying monitor layout…")
                root.monitorLayoutAwaitingReload = true
                root.monitorLayoutReloadAttempts = 0
                NiriService.fetchOutputs()
                monitorLayoutRefresh.restart()
                return
            }

            root.monitorLayoutError = (monitorLayoutPersistErr.text || monitorLayoutPersistOut.text || Translation.tr("Could not save the monitor layout.")).trim()
            root.monitorLayoutInfo = ""
            root.finishMonitorPositionTransaction(false)
        }
    }

    Timer {
        id: monitorLayoutRefresh
        interval: 350
        repeat: false
        onTriggered: {
            if (!root.monitorLayoutAwaitingReload)
                return
            if (root.pendingMonitorPositionIsLive()) {
                root.monitorLayoutInfo = Translation.tr("Monitor layout saved.")
                root.finishMonitorPositionTransaction(true)
                return
            }

            root.monitorLayoutReloadAttempts++
            if (root.monitorLayoutReloadAttempts < 6) {
                root.monitorLayoutInfo = Translation.tr("Saved layout is waiting for Niri to refresh…")
                NiriService.fetchOutputs()
                monitorLayoutRefresh.restart()
                return
            }

            root.monitorLayoutError = Translation.tr("The layout was saved, but Niri did not report the new position in time. The editor was resynced with the compositor.")
            root.monitorLayoutInfo = ""
            root.finishMonitorPositionTransaction(false)
        }
    }

    Connections {
        target: NiriService
        function onOutputsChanged(): void {
            if (root.monitorLayoutAwaitingReload && root.pendingMonitorPositionIsLive()) {
                root.monitorLayoutInfo = Translation.tr("Monitor layout saved.")
                root.finishMonitorPositionTransaction(true)
                return
            }
            if (root.draggingLayoutOutput.length === 0 && !root.monitorLayoutBusy)
                Qt.callLater(() => root.syncMonitorLayoutSnapshot(false))
        }
    }

    Component.onCompleted: Qt.callLater(() => root.syncMonitorLayoutSnapshot(false))

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

    component PresetActions: RowLayout {
        required property var paths
        Layout.fillWidth: true
        spacing: Appearance.sizes.spacingSmall

        RippleButtonWithIcon {
            Layout.fillWidth: true
            materialIcon: "filter_1"
            mainText: Translation.tr("Primary only")
            onClicked: root.setPathsToPrimary(paths)
            StyledToolTip {
                text: Translation.tr("Restrict this whole group to the primary monitor.")
            }
        }

        RippleButtonWithIcon {
            Layout.fillWidth: true
            materialIcon: "select_all"
            mainText: Translation.tr("Show everywhere")
            onClicked: root.setPathsToAll(paths)
            StyledToolTip {
                text: Translation.tr("Clear monitor restrictions for this whole group.")
            }
        }
    }

    component MonitorInfoRow: Rectangle {
        required property var monitor
        required property int index
        readonly property string screenName: monitor?.name ?? ""
        readonly property bool primary: screenName === root.primaryScreenName()

        Layout.fillWidth: true
        implicitHeight: rowLayout.implicitHeight + Appearance.sizes.spacingMedium
        radius: Appearance.rounding.small
        color: primary ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer1
        border.width: 1
        border.color: primary ? Appearance.colors.colPrimary : SettingsMaterialPreset.groupBorderColor

        RowLayout {
            id: rowLayout
            anchors.fill: parent
            anchors.margins: Appearance.sizes.spacingSmall
            spacing: Appearance.sizes.spacingMedium

            MaterialSymbol {
                text: "monitor"
                iconSize: Appearance.font.pixelSize.hugeass
                color: primary ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colPrimary
                Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                StyledText {
                    Layout.fillWidth: true
                    text: screenName || (Translation.tr("Monitor ") + (index + 1))
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.Medium
                    color: primary ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer1
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.monitorResolution(monitor)
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: primary ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                    opacity: primary ? 0.78 : 1
                    elide: Text.ElideRight
                }
            }

            StyledText {
                visible: primary
                text: Translation.tr("Primary")
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.Medium
                color: Appearance.colors.colOnPrimaryContainer
                Layout.alignment: Qt.AlignVCenter
            }

            RippleButtonWithIcon {
                visible: !primary
                materialIcon: "low_priority"
                mainText: Translation.tr("Make primary")
                onClicked: if (screenName.length > 0) Config.setNestedValue("display.primaryMonitor", screenName)
            }
        }
    }

    component MonitorLayoutRect: Rectangle {
        id: monitorRect
        required property string outputName
        required property real canvasScale
        required property point canvasOffset

        readonly property var logical: root.niriLogicalRect(outputName)
        readonly property real logicalWidth: Math.max(1, Number(logical.width ?? 1920))
        readonly property real logicalHeight: Math.max(1, Number(logical.height ?? 1080))
        readonly property bool primary: outputName === root.primaryScreenName()
        property bool dragging: false
        property bool awaitingCommit: false
        property bool validPosition: true
        property point originalLogical: Qt.point(0, 0)
        property point rawLogical: Qt.point(0, 0)
        property point snappedLogical: Qt.point(0, 0)
        property real dragOriginCanvasX: 0
        property real dragOriginCanvasY: 0
        property real heldX: 0
        property real heldY: 0
        readonly property real baseCanvasX: Number(logical.x ?? 0) * canvasScale + canvasOffset.x
        readonly property real baseCanvasY: Number(logical.y ?? 0) * canvasScale + canvasOffset.y
        readonly property real snappedCanvasX: snappedLogical.x * canvasScale + canvasOffset.x
        readonly property real snappedCanvasY: snappedLogical.y * canvasScale + canvasOffset.y
        readonly property bool snapPreviewVisible: dragging && validPosition
            && (Math.abs(snappedLogical.x - rawLogical.x) > 0.5 || Math.abs(snappedLogical.y - rawLogical.y) > 0.5)

        x: (dragging || awaitingCommit) ? heldX : baseCanvasX
        y: (dragging || awaitingCommit) ? heldY : baseCanvasY
        width: Math.max(1, logicalWidth * canvasScale)
        height: Math.max(1, logicalHeight * canvasScale)
        radius: Appearance.rounding.normal
        z: dragging ? 20 : 1
        scale: dragging ? 1.025 : 1
        opacity: root.draggingLayoutOutput.length > 0 && root.draggingLayoutOutput !== outputName ? 0.72 : 1
        color: !validPosition
            ? Appearance.colors.colErrorContainer
            : dragging
                ? Appearance.colors.colPrimaryContainer
                : monitorHover.hovered
                    ? Appearance.colors.colLayer1Hover
                : primary
                    ? Appearance.colors.colSecondaryContainer
                    : Appearance.colors.colLayer1
        border.width: dragging || awaitingCommit ? 2 : 1
        border.color: !validPosition
            ? Appearance.colors.colError
            : dragging || awaitingCommit || primary
                ? Appearance.colors.colPrimary
                : SettingsMaterialPreset.groupBorderColor

        Behavior on color { ColorAnimation { duration: Appearance.animation.elementMoveFast.duration } }
        Behavior on border.color { ColorAnimation { duration: Appearance.animation.elementMoveFast.duration } }
        Behavior on scale {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }
        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: 100 }
        }

        StyledRectangularShadow {
            target: monitorRect.dragging ? monitorRect : null
            visible: monitorRect.dragging
            z: -1
        }

        Rectangle {
            visible: monitorRect.snapPreviewVisible
            x: monitorRect.snappedCanvasX - monitorRect.x
            y: monitorRect.snappedCanvasY - monitorRect.y
            width: monitorRect.width
            height: monitorRect.height
            radius: monitorRect.radius
            color: Appearance.colors.colPrimaryContainer
            border.width: 2
            border.color: Appearance.colors.colPrimary
            opacity: 0.78
            z: -2
        }

        Rectangle {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: Appearance.sizes.spacingSmall / 2
            visible: monitorRect.width >= 100
            implicitWidth: dragHandleRow.implicitWidth + Appearance.sizes.spacingSmall * 2
            implicitHeight: dragHandleRow.implicitHeight + 2
            radius: Appearance.rounding.full
            color: monitorRect.dragging
                ? Appearance.colors.colPrimaryContainer
                : "transparent"
            opacity: monitorRect.dragging ? 0.74 : 1

            RowLayout {
                id: dragHandleRow
                anchors.centerIn: parent
                spacing: 2

                MaterialSymbol {
                    text: "drag_indicator"
                    iconSize: Appearance.font.pixelSize.smallest
                    color: monitorRect.dragging ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                }
            }
        }

        Connections {
            target: root
            function onMonitorPositionFinished(name, success): void {
                if (name !== monitorRect.outputName)
                    return
                monitorRect.awaitingCommit = false
                monitorRect.validPosition = true
                if (!success) {
                    monitorRect.heldX = monitorRect.baseCanvasX
                    monitorRect.heldY = monitorRect.baseCanvasY
                }
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            width: Math.max(0, parent.width - Appearance.sizes.spacingMedium * 2)
            spacing: 1

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Appearance.sizes.spacingSmall / 2

                MaterialSymbol {
                    text: primary ? "star" : "monitor"
                    iconSize: Appearance.font.pixelSize.normal
                    color: !monitorRect.validPosition
                        ? Appearance.colors.colOnErrorContainer
                        : primary ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colPrimary
                }

                StyledText {
                    text: monitorRect.outputName
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.Medium
                    color: !monitorRect.validPosition
                        ? Appearance.colors.colOnErrorContainer
                        : primary ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
                    elide: Text.ElideMiddle
                    Layout.maximumWidth: Math.max(24, monitorRect.width - 42)
                }
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                visible: monitorRect.height >= 62
                text: Math.round(monitorRect.logicalWidth) + "×" + Math.round(monitorRect.logicalHeight)
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: !monitorRect.validPosition
                    ? Appearance.colors.colOnErrorContainer
                    : primary ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colSubtext
            }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                visible: monitorRect.dragging && monitorRect.width >= 116 && monitorRect.height >= 82
                implicitWidth: positionLabel.implicitWidth + Appearance.sizes.spacingMedium
                implicitHeight: positionLabel.implicitHeight + Appearance.sizes.spacingSmall / 2
                radius: Appearance.rounding.full
                color: monitorRect.validPosition
                    ? Appearance.colors.colPrimaryContainer
                    : Appearance.colors.colErrorContainer

                StyledText {
                    id: positionLabel
                    anchors.centerIn: parent
                    text: monitorRect.validPosition
                        ? Math.round(monitorRect.snappedLogical.x) + ", " + Math.round(monitorRect.snappedLogical.y)
                        : Translation.tr("Invalid placement")
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.weight: Font.Medium
                    color: monitorRect.validPosition ? Appearance.colors.colPrimary : Appearance.colors.colOnErrorContainer
                }
            }
        }

        HoverHandler {
            id: monitorHover
            enabled: !root.monitorLayoutBusy && root.niriOutputNames().length > 1
            cursorShape: monitorDrag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        }

        DragHandler {
            id: monitorDrag
            target: null
            enabled: !root.monitorLayoutBusy && root.niriOutputNames().length > 1
            acceptedButtons: Qt.LeftButton
            grabPermissions: PointerHandler.CanTakeOverFromAnything

            onActiveChanged: {
                if (active) {
                    monitorRect.dragging = true
                    root.draggingLayoutOutput = monitorRect.outputName
                    monitorRect.awaitingCommit = false
                    monitorRect.originalLogical = Qt.point(Number(monitorRect.logical.x ?? 0), Number(monitorRect.logical.y ?? 0))
                    monitorRect.rawLogical = monitorRect.originalLogical
                    monitorRect.snappedLogical = monitorRect.originalLogical
                    monitorRect.dragOriginCanvasX = monitorRect.baseCanvasX
                    monitorRect.dragOriginCanvasY = monitorRect.baseCanvasY
                    monitorRect.heldX = monitorRect.dragOriginCanvasX
                    monitorRect.heldY = monitorRect.dragOriginCanvasY
                    monitorRect.validPosition = true
                    root.monitorLayoutError = ""
                    root.monitorLayoutInfo = ""
                    root.monitorLayoutWarning = ""
                    return
                }

                if (!monitorRect.dragging)
                    return

                const rawX = monitorRect.rawLogical.x
                const rawY = monitorRect.rawLogical.y
                let finalPosition = monitorRect.snappedLogical
                const finalIsValid = !root.monitorPositionOverlaps(
                        monitorRect.outputName, finalPosition.x, finalPosition.y,
                        monitorRect.logicalWidth, monitorRect.logicalHeight)

                if (!finalIsValid) {
                    finalPosition = root.nearestValidPlacement(
                        monitorRect.outputName, rawX, rawY,
                        monitorRect.logicalWidth, monitorRect.logicalHeight,
                        Infinity, true)
                }

                const validFinal = !root.monitorPositionOverlaps(
                        monitorRect.outputName, finalPosition.x, finalPosition.y,
                        monitorRect.logicalWidth, monitorRect.logicalHeight)

                monitorRect.dragging = false
                root.draggingLayoutOutput = ""
                if (!validFinal) {
                    monitorRect.awaitingCommit = false
                    monitorRect.heldX = monitorRect.baseCanvasX
                    monitorRect.heldY = monitorRect.baseCanvasY
                    monitorRect.validPosition = true
                    root.monitorLayoutError = Translation.tr("Monitors cannot overlap. Move this display beside or away from the others.")
                    return
                }

                const newX = Math.round(finalPosition.x)
                const newY = Math.round(finalPosition.y)
                monitorRect.snappedLogical = Qt.point(newX, newY)
                monitorRect.heldX = newX * monitorRect.canvasScale + monitorRect.canvasOffset.x
                monitorRect.heldY = newY * monitorRect.canvasScale + monitorRect.canvasOffset.y
                monitorRect.awaitingCommit = newX !== monitorRect.originalLogical.x || newY !== monitorRect.originalLogical.y
                root.commitMonitorPosition(monitorRect.outputName, newX, newY,
                    monitorRect.originalLogical.x, monitorRect.originalLogical.y)
            }

            onTranslationChanged: {
                if (!active || monitorRect.canvasScale <= 0)
                    return

                const margin = Appearance.sizes.spacingSmall
                const maxX = Math.max(margin, monitorRect.parent.width - monitorRect.width - margin)
                const maxY = Math.max(margin, monitorRect.parent.height - monitorRect.height - margin)
                monitorRect.heldX = Math.max(margin, Math.min(maxX, monitorRect.dragOriginCanvasX + translation.x))
                monitorRect.heldY = Math.max(margin, Math.min(maxY, monitorRect.dragOriginCanvasY + translation.y))

                const rawX = Math.round((monitorRect.heldX - monitorRect.canvasOffset.x) / monitorRect.canvasScale)
                const rawY = Math.round((monitorRect.heldY - monitorRect.canvasOffset.y) / monitorRect.canvasScale)
                monitorRect.rawLogical = Qt.point(rawX, rawY)

                const snapThreshold = Math.max(96, 22 / monitorRect.canvasScale)
                const candidate = root.nearestValidPlacement(
                    monitorRect.outputName, rawX, rawY,
                    monitorRect.logicalWidth, monitorRect.logicalHeight,
                    snapThreshold, false)
                monitorRect.snappedLogical = candidate
                monitorRect.validPosition = !root.monitorPositionOverlaps(
                    monitorRect.outputName, candidate.x, candidate.y,
                    monitorRect.logicalWidth, monitorRect.logicalHeight)
            }

            onCanceled: {
                monitorRect.dragging = false
                root.draggingLayoutOutput = ""
                monitorRect.awaitingCommit = false
                monitorRect.validPosition = true
                monitorRect.heldX = monitorRect.baseCanvasX
                monitorRect.heldY = monitorRect.baseCanvasY
            }
        }
    }

    component SurfaceVisibilityBlock: Rectangle {
        required property var surface
        readonly property real leadingWidth: Appearance.font.pixelSize.hugeass + Appearance.sizes.spacingLarge
        readonly property bool allOutputs: root.allScreensEnabled(surface.path)

        Layout.fillWidth: true
        implicitHeight: surfaceLayout.implicitHeight + Appearance.sizes.spacingLarge * 2
        radius: Appearance.rounding.small
        color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
            : Appearance.inirEverywhere ? Appearance.inir.colLayer1
            : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
            : Appearance.colors.colLayer1
        border.width: Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth : 1
        border.color: SettingsMaterialPreset.groupBorderColor

        ColumnLayout {
            id: surfaceLayout
            anchors.fill: parent
            anchors.margins: Appearance.sizes.spacingLarge
            spacing: Appearance.sizes.spacingSmall

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.sizes.spacingMedium

                Rectangle {
                    implicitWidth: leadingWidth
                    implicitHeight: leadingWidth
                    radius: Appearance.rounding.small
                    color: allOutputs ? Appearance.colors.colSecondaryContainer : Appearance.colors.colPrimaryContainer
                    Layout.alignment: Qt.AlignTop

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: surface.icon
                        iconSize: Appearance.font.pixelSize.hugeass
                        color: allOutputs ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnPrimaryContainer
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.sizes.spacingSmall

                        StyledText {
                            Layout.fillWidth: true
                            text: surface.title
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnLayer1
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            implicitWidth: summaryText.implicitWidth + Appearance.sizes.spacingMedium
                            implicitHeight: summaryText.implicitHeight + Appearance.sizes.spacingSmall
                            radius: Appearance.rounding.full
                            color: allOutputs ? Appearance.colors.colSecondaryContainer : Appearance.colors.colPrimaryContainer
                            Layout.alignment: Qt.AlignVCenter

                            StyledText {
                                id: summaryText
                                anchors.centerIn: parent
                                text: root.visibilitySummary(surface.path)
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: allOutputs ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnPrimaryContainer
                            }
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: surface.description
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                        wrapMode: Text.WordWrap
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                Layout.leftMargin: leadingWidth + Appearance.sizes.spacingMedium
                text: surface.selectionLabel ?? Translation.tr("Visible on")
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.Medium
                color: Appearance.colors.colSubtext
            }

            Flow {
                Layout.fillWidth: true
                Layout.leftMargin: leadingWidth + Appearance.sizes.spacingMedium
                spacing: Appearance.sizes.spacingSmall / 2

                SelectionGroupButton {
                    leftmost: true
                    rightmost: true
                    buttonIcon: "select_all"
                    buttonText: Translation.tr("All outputs")
                    toggled: allOutputs
                    onClicked: root.setSurfaceAll(surface.path)
                }

                Repeater {
                    model: root.connectedScreenNames()

                    SelectionGroupButton {
                        required property var modelData
                        readonly property string screenName: String(modelData ?? "")
                        leftmost: true
                        rightmost: true
                        buttonIcon: "monitor"
                        buttonText: screenName
                        toggled: root.surfaceEnabled(surface.path, screenName)
                        onClicked: root.setSurfaceScreen(surface.path, screenName, !toggled)
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
        implicitHeight: outputColumn.implicitHeight + Appearance.sizes.spacingLarge * 2
        radius: Appearance.rounding.small
        color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
            : Appearance.inirEverywhere ? Appearance.inir.colLayer1
            : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
            : Appearance.colors.colLayer1
        border.width: 1
        border.color: outputBlock.primary
            ? Appearance.colors.colPrimary : SettingsMaterialPreset.groupBorderColor

        ColumnLayout {
            id: outputColumn
            anchors.fill: parent
            anchors.margins: Appearance.sizes.spacingLarge
            spacing: Appearance.sizes.spacingSmall / 2

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.sizes.spacingSmall

                MaterialSymbol {
                    text: "monitor"
                    iconSize: Appearance.font.pixelSize.large
                    color: outputBlock.primary
                        ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
                }

                StyledText {
                    Layout.fillWidth: true
                    text: outputBlock.outputName
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.Medium
                    color: Appearance.colors.colOnLayer1
                    elide: Text.ElideRight
                }

                StyledText {
                    visible: !outputBlock.connected
                    text: Translation.tr("Disconnected")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colError
                }

                StyledText {
                    visible: !outputBlock.globallyVisible
                    text: Translation.tr("Desktop widgets") + ": " + Translation.tr("Disabled")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colError
                }

                RippleButtonWithIcon {
                    visible: outputBlock.hasOverrides
                    materialIcon: "restart_alt"
                    mainText: Translation.tr("Reset")
                    onClicked: DesktopWidgetLayout.clearOutput(outputBlock.outputName)
                }
            }

            Repeater {
                model: root.desktopWidgetDescriptors

                RowLayout {
                    id: widgetOutputRow
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: Appearance.sizes.spacingSmall

                    SettingsSwitch {
                        Layout.fillWidth: true
                        enabled: outputBlock.globallyVisible
                        enableSettingsSearch: false
                        autoToggle: false
                        buttonIcon: widgetOutputRow.modelData.icon
                        text: widgetOutputRow.modelData.title
                        description: outputBlock.outputName
                        checked: root.desktopWidgetEnabled(
                            outputBlock.outputName, widgetOutputRow.modelData)
                        onToggledByUser: checked => DesktopWidgetLayout.setEnabled(
                            outputBlock.outputName, widgetOutputRow.modelData.key, checked)
                    }

                    RippleButton {
                        visible: root.desktopWidgetHasOverrides(
                            outputBlock.outputName, widgetOutputRow.modelData.key)
                        implicitWidth: 36
                        implicitHeight: 36
                        buttonRadius: Appearance.rounding.full
                        colBackground: "transparent"
                        colBackgroundHover: Appearance.colors.colLayer2Hover
                        colRipple: Appearance.colors.colLayer2Active
                        onClicked: DesktopWidgetLayout.clearWidget(
                            outputBlock.outputName, widgetOutputRow.modelData.key)
                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: "undo"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnLayer1
                        }
                        StyledToolTip { text: Translation.tr("Reset") }
                    }
                }
            }
        }
    }

    SettingsCardSection {
        settingsTaskSection: "outputs"
        visible: root.activeSection === "outputs" && CompositorService.isNiri
        expanded: true
        icon: "screen_rotation_alt"
        title: Translation.tr("Monitor arrangement")

        SettingsGroup {
            NoticeBox {
                Layout.fillWidth: true
                materialIcon: "drag_pan"
                text: root.niriOutputNames().length > 1
                    ? Translation.tr("Drag displays to match your desk. Nearby edges and alignments snap automatically. Gaps are allowed, but Niri's pointer only crosses directly adjacent outputs.")
                    : Translation.tr("Connect another display to arrange monitor positions.")
            }

            Rectangle {
                id: monitorLayoutCanvas
                Layout.fillWidth: true
                implicitHeight: 292
                radius: Appearance.rounding.normal
                color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                    : Appearance.inirEverywhere ? Appearance.inir.colLayer1
                    : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                    : Appearance.colors.colLayer1
                border.width: 1
                border.color: SettingsMaterialPreset.groupBorderColor
                clip: true

                readonly property var layoutBounds: root.monitorLayoutBounds()
                readonly property real worldPaddingX: Math.max(240, layoutBounds.width * 0.12)
                readonly property real worldPaddingY: Math.max(180, layoutBounds.height * 0.28)
                readonly property var bounds: ({
                    minX: layoutBounds.minX - worldPaddingX,
                    minY: layoutBounds.minY - worldPaddingY,
                    width: layoutBounds.width + worldPaddingX * 2,
                    height: layoutBounds.height + worldPaddingY * 2
                })
                readonly property real innerPadding: Appearance.sizes.spacingLarge
                readonly property real fitScale: {
                    const usableWidth = Math.max(1, width - innerPadding * 2)
                    const usableHeight = Math.max(1, height - innerPadding * 2)
                    return Math.min(usableWidth / Math.max(1, bounds.width), usableHeight / Math.max(1, bounds.height))
                }
                readonly property real canvasScale: Math.max(0.025, fitScale)
                readonly property point canvasOffset: Qt.point(
                    (width - bounds.width * canvasScale) / 2 - bounds.minX * canvasScale,
                    (height - bounds.height * canvasScale) / 2 - bounds.minY * canvasScale)

                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.width: 0

                    Repeater {
                        model: 5
                        Rectangle {
                            required property int index
                            x: (index + 1) * parent.width / 6
                            width: 1
                            height: parent.height
                            color: Appearance.colors.colOutlineVariant
                            opacity: 0.08
                        }
                    }

                    Repeater {
                        model: 3
                        Rectangle {
                            required property int index
                            y: (index + 1) * parent.height / 4
                            height: 1
                            width: parent.width
                            color: Appearance.colors.colOutlineVariant
                            opacity: 0.08
                        }
                    }
                }

                Repeater {
                    model: root.niriOutputNames()

                    MonitorLayoutRect {
                        required property var modelData
                        outputName: String(modelData)
                        canvasScale: monitorLayoutCanvas.canvasScale
                        canvasOffset: monitorLayoutCanvas.canvasOffset
                    }
                }

                RippleButton {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: Appearance.sizes.spacingSmall
                    implicitWidth: 34
                    implicitHeight: 34
                    buttonRadius: Appearance.rounding.full
                    colBackground: Appearance.colors.colLayer1
                    colBackgroundHover: Appearance.colors.colLayer1Hover
                    colRipple: Appearance.colors.colLayer1Active
                    onClicked: root.monitorLayoutViewportBounds = root.boundsForLayout(root.monitorLayoutSnapshot)

                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "fit_screen"
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colOnLayer1
                    }
                    StyledToolTip { text: Translation.tr("Recenter monitor layout") }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.margins: Appearance.sizes.spacingSmall
                    visible: root.monitorLayoutBusy
                    implicitWidth: busyRow.implicitWidth + Appearance.sizes.spacingMedium * 2
                    implicitHeight: busyRow.implicitHeight + Appearance.sizes.spacingSmall
                    radius: Appearance.rounding.full
                    color: Appearance.colors.colPrimaryContainer

                    RowLayout {
                        id: busyRow
                        anchors.centerIn: parent
                        spacing: Appearance.sizes.spacingSmall / 2

                        MaterialSymbol {
                            text: "sync"
                            iconSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnPrimaryContainer
                        }

                        StyledText {
                            text: root.monitorLayoutInfo
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                    }
                }
            }

            SettingsNote {
                visible: root.monitorLayoutError.length > 0
                warning: true
                icon: "error"
                text: root.monitorLayoutError
            }

            SettingsNote {
                visible: root.monitorLayoutWarning.length > 0
                warning: true
                icon: "link_off"
                text: root.monitorLayoutWarning
            }

            SettingsNote {
                visible: !root.monitorLayoutBusy && root.monitorLayoutError.length === 0 && root.monitorLayoutInfo.length > 0
                icon: "check_circle"
                text: root.monitorLayoutInfo
            }
        }
    }

    SettingsCardSection {
        settingsTaskSection: "outputs"
        visible: root.activeSection === "outputs"
        expanded: true
        icon: "settings_input_component"
        title: Translation.tr("Shell visibility")

        SettingsGroup {
            NoticeBox {
                Layout.fillWidth: true
                materialIcon: "info"
                text: Translation.tr("Primary monitor controls iNiR's fallback output. Resolution, scale, rotation and advanced display options remain available in Compositor settings.")
            }

            ContentSubsection {
                title: Translation.tr("Primary monitor")
                tooltip: Translation.tr("Used as the default output when a popup cannot infer the focused monitor.")

                ConfigSelectionArray {
                    currentValue: Config.options?.display?.primaryMonitor ?? ""
                    options: root.monitorOptions()
                    onSelected: newValue => Config.setNestedValue("display.primaryMonitor", newValue)
                }
            }

            ContentSubsection {
                title: Translation.tr("Connected outputs")

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.sizes.spacingSmall / 2

                    Repeater {
                        model: Quickshell.screens

                        MonitorInfoRow {
                            required property var modelData
                            monitor: modelData
                        }
                    }
                }
            }
        }
    }

    SettingsCardSection {
        settingsTaskSection: "outputs"
        visible: root.activeSection === "outputs"
        expanded: true
        icon: "preview"
        title: Translation.tr("Overview placement")

        SettingsGroup {
            SettingsSwitch {
                buttonIcon: "screen_share"
                text: Translation.tr("Active screen only")
                checked: Config.options?.overview?.activeScreenOnly ?? true
                onCheckedChanged: Config.setNestedValue("overview.activeScreenOnly", checked)
                StyledToolTip {
                    text: Translation.tr("Open the overview on the monitor where it was invoked")
                }
            }
        }
    }

    SettingsCardSection {
        settingsTaskSection: "surfaces"
        visible: root.activeSection === "surfaces"
        expanded: true
        icon: "web_asset"
        title: Translation.tr("Material shell surfaces")

        SettingsGroup {
            NoticeBox {
                Layout.fillWidth: true
                materialIcon: "apps"
                text: Translation.tr("These controls only affect the Material family: the ii bar, dock, and floating media controls.")
            }

            PresetActions {
                paths: root.surfacePaths(root.iiSurfaces)
            }

            Repeater {
                model: root.iiSurfaces
                SurfaceVisibilityBlock {
                    required property var modelData
                    surface: modelData
                }
            }
        }
    }

    SettingsCardSection {
        settingsTaskSection: "widgets"
        visible: root.activeSection === "widgets"
        expanded: true
        icon: "widgets"
        title: Translation.tr("Desktop widgets")

        SettingsGroup {
            NoticeBox {
                Layout.fillWidth: true
                materialIcon: "monitor"
                text: Translation.tr("Clock, weather, media, visualizer, and custom widgets")
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
    }

    SettingsCardSection {
        settingsTaskSection: "popups"
        visible: root.activeSection === "popups"
        expanded: true
        icon: "notifications"
        title: Translation.tr("Popups")

        SettingsGroup {
            NoticeBox {
                Layout.fillWidth: true
                materialIcon: "merge"
                text: Translation.tr("These surfaces are shared by both families, so the same monitor choices apply in Material and Waffle.")
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
}
