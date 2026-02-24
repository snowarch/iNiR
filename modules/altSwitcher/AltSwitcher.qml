import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Widgets

Scope {
    id: root
    property int panelWidth: 380
    property string searchText: ""
    // Animation and visibility control
    readonly property var altSwitcherOptions: Config.options?.altSwitcher ?? {}
    readonly property string altPreset: altSwitcherOptions.preset ?? "default"
    readonly property bool altNoVisualUi: altSwitcherOptions.noVisualUi ?? false
    readonly property bool altMonochromeIcons: altSwitcherOptions.monochromeIcons ?? false
    readonly property bool altEnableAnimation: altSwitcherOptions.enableAnimation ?? true
    readonly property int altAnimationDurationMs: altSwitcherOptions.animationDurationMs ?? 200
    readonly property bool altUseMostRecentFirst: altSwitcherOptions.useMostRecentFirst ?? true
    readonly property bool altEnableBlurGlass: altSwitcherOptions.enableBlurGlass ?? true
    readonly property real altBackgroundOpacity: altSwitcherOptions.backgroundOpacity ?? 0.9
    readonly property real altBlurAmount: altSwitcherOptions.blurAmount ?? 0.4
    readonly property int altScrimDim: altSwitcherOptions.scrimDim ?? 35
    readonly property string altPanelAlignment: altSwitcherOptions.panelAlignment ?? "right"
    readonly property bool altUseM3Layout: altSwitcherOptions.useM3Layout ?? false
    readonly property bool altCompactStyle: altSwitcherOptions.compactStyle ?? false
    readonly property bool altShowOverviewWhileSwitching: altSwitcherOptions.showOverviewWhileSwitching ?? false
    readonly property int altAutoHideDelayMs: altSwitcherOptions.autoHideDelayMs ?? 500

    property bool animationsEnabled: root.effectiveEnableAnimation
    property bool panelVisible: false
    property real panelRightMargin: -panelWidth
    // Snapshot actual de ventanas ordenadas que se usa mientras el panel está abierto
    property var itemSnapshot: []
    // Cache de iconos resueltos para evitar lookups repetidos
    property var iconCache: ({})
    property var iconCacheKeys: []
    readonly property int maxIconCacheSize: 100
    property bool useM3Layout: root.altUseM3Layout
    property bool centerPanel: root.altPanelAlignment === "center"
    property bool compactStyle: root.altCompactStyle
    property bool listStyle: root.altPreset === "list"
    property bool showOverviewWhileSwitching: root.altShowOverviewWhileSwitching
    property bool overviewOpenedByAltSwitcher: false
    // Pre-warm flag para evitar lag en primera apertura
    property bool _warmedUp: false
    
    readonly property int windowCount: itemSnapshot ? itemSnapshot.length : 0
    readonly property bool isHighLoad: windowCount > 15
    readonly property bool effectiveEnableBlurGlass: root.altEnableBlurGlass && !isHighLoad
    readonly property bool effectiveEnableAnimation: root.altEnableAnimation && !isHighLoad

    property bool quickSwitchDone: false
    property var noUiSnapshot: []
    property int noUiIndex: 0

    property var _pendingWindowsUpdate: null
    Timer {
        id: windowsUpdateDebounce
        interval: 50
        repeat: false
        onTriggered: {
            if (root._pendingWindowsUpdate) {
                root._pendingWindowsUpdate()
                root._pendingWindowsUpdate = null
            }
        }
    }

    Timer {
        id: quickSwitchResetTimer
        interval: 800
        repeat: false
        onTriggered: {
            if (!GlobalStates.altSwitcherOpen) {
                root.quickSwitchDone = false
                root.noUiSnapshot = []
                root.noUiIndex = 0
            }
        }
    }



    onUseM3LayoutChanged: {
        // Al cambiar de layout normal 
        // a Material 3 (y viceversa), reseteamos la visibilidad
        // interna si el switcher está cerrado para que se
        // vuelva a construir limpio en el próximo Alt+Tab.
        if (!GlobalStates.altSwitcherOpen) {
            panelVisible = false
        }
    }

    function toTitleCase(name) {
        if (!name)
            return ""
        let s = name.replace(/[._-]+/g, " ")
        const parts = s.split(/\s+/)
        for (let i = 0; i < parts.length; i++) {
            const p = parts[i]
            if (!p)
                continue
            parts[i] = p.charAt(0).toUpperCase() + p.slice(1)
        }
        return parts.join(" ")
    }

    function getCachedIcon(appId, appName, title) {
        const key = appId || appName || title || ""
        if (iconCache[key] !== undefined) {
            const idx = iconCacheKeys.indexOf(key)
            if (idx >= 0) {
                iconCacheKeys.splice(idx, 1)
                iconCacheKeys.push(key)
            }
            return iconCache[key]
        }
        
        if (iconCacheKeys.length >= maxIconCacheSize) {
            const oldestKey = iconCacheKeys.shift()
            delete iconCache[oldestKey]
        }
        
        const icon = AppSearch.getIconSource(key)
        iconCache[key] = icon
        iconCacheKeys.push(key)
        return icon
    }

    function buildItemsFrom(windows, workspaces, mruIds) {
        if (!windows || !windows.length)
            return []

        const items = []
        const itemsById = {}

        for (let i = 0; i < windows.length; i++) {
            const w = windows[i]
            const appId = w.app_id || ""
            let appName = appId
            if (appName && appName.indexOf(".") !== -1) {
                const parts = appName.split(".")
                appName = parts[parts.length - 1]
            }
            if (!appName && w.title)
                appName = w.title

            appName = toTitleCase(appName)
            const ws = workspaces[w.workspace_id]
            const wsIdx = ws && ws.idx !== undefined ? ws.idx : 0

            const item = {
                id: w.id,
                appId: appId,
                appName: appName,
                title: w.title || "",
                workspaceId: w.workspace_id,
                workspaceIdx: wsIdx,
                // Pre-resolver icono durante build para evitar lag en render
                icon: root.getCachedIcon(appId, appName, w.title)
            }
            items.push(item)
            itemsById[item.id] = item
        }

        items.sort(function (a, b) {
            const wa = workspaces[a.workspaceId]
            const wb = workspaces[b.workspaceId]
            const ia = wa ? wa.idx : 0
            const ib = wb ? wb.idx : 0
            if (ia !== ib)
                return ia - ib

            const an = (a.appName || a.title || "").toString()
            const bn = (b.appName || b.title || "").toString()
            const cmp = an.localeCompare(bn)
            if (cmp !== 0)
                return cmp

            return a.id - b.id
        })

        const useMostRecentFirst = root.altUseMostRecentFirst

        if (useMostRecentFirst && mruIds && mruIds.length > 0) {
            const ordered = []
            const used = {}

            for (let i = 0; i < mruIds.length; i++) {
                const id = mruIds[i]
                const it = itemsById[id]
                if (it) {
                    ordered.push(it)
                    used[id] = true
                }
            }

            for (let i = 0; i < items.length; i++) {
                const it = items[i]
                if (!used[it.id])
                    ordered.push(it)
            }

            return ordered
        }

        return items
    }

    property bool _rebuildPending: false
    
    function rebuildSnapshot() {
        if (_rebuildPending) return
        _rebuildPending = true
        
        Qt.callLater(function() {
            _rebuildPending = false
            const windows = NiriService.windows || []
            const workspaces = NiriService.workspaces || {}
            const mruIds = NiriService.mruWindowIds || []
            itemSnapshot = buildItemsFrom(windows, workspaces, mruIds)
        })
    }

    property bool _noUiRebuildPending: false
    
    // Synchronous version for immediate use in noVisualUi mode
    function rebuildNoUiSnapshotSync() {
        const windows = NiriService.windows || []
        const workspaces = NiriService.workspaces || {}
        const mruIds = NiriService.mruWindowIds || []
        root.noUiSnapshot = buildItemsFrom(windows, workspaces, mruIds)
        root.noUiIndex = 0
    }
    
    function rebuildNoUiSnapshot() {
        if (_noUiRebuildPending) return
        _noUiRebuildPending = true
        
        Qt.callLater(function() {
            _noUiRebuildPending = false
            rebuildNoUiSnapshotSync()
        })
    }

    function focusNoUiIndex() {
        const len = root.noUiSnapshot?.length ?? 0
        if (len <= 0)
            return
        const idx = Math.max(0, Math.min(len - 1, root.noUiIndex))
        const id = root.noUiSnapshot[idx]?.id
        if (id !== undefined)
            NiriService.focusWindow(id)
    }

    function ensureSnapshot() {
        if (!itemSnapshot || itemSnapshot.length === 0)
            rebuildSnapshot()
    }

    function maybeOpenOverview() {
        if (!CompositorService.isNiri)
            return
        if (!root.altShowOverviewWhileSwitching)
            return
        if (!NiriService.inOverview) {
            overviewOpenedByAltSwitcher = true
            NiriService.toggleOverview()
        } else {
            overviewOpenedByAltSwitcher = false
        }
    }

    function maybeCloseOverview() {
        if (!CompositorService.isNiri)
            return
        if (!root.altShowOverviewWhileSwitching)
            return
        if (overviewOpenedByAltSwitcher && NiriService.inOverview) {
            NiriService.toggleOverview()
        }
        overviewOpenedByAltSwitcher = false
    }

    // Fullscreen scrim on all screens: same pattern as Overview, controlled by GlobalStates.altSwitcherOpen.
    Variants {
        id: altSwitcherScrimVariants
        model: Quickshell.screens
        PanelWindow {
            id: scrimRoot
            required property var modelData
            screen: modelData
            visible: GlobalStates.altSwitcherOpen
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.namespace: "quickshell:altSwitcherScrim"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            Rectangle {
                anchors.fill: parent
                z: -1
                color: {
                    const clamped = Math.max(0, Math.min(100, root.altScrimDim))
                    const a = clamped / 100
                    return Qt.rgba(0, 0, 0, a)
                }
                visible: GlobalStates.altSwitcherOpen
            }

            MouseArea {
                anchors.fill: parent
                onClicked: GlobalStates.altSwitcherOpen = false
            }
        }
    }

    PanelWindow {
        id: window
        visible: root.panelVisible
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "quickshell:altSwitcher"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        MouseArea {
            id: windowMouseArea
            anchors.fill: parent
            onClicked: function (mouse) {
                // mouse.x/mouse.y están en coordenadas del PanelWindow.
                // Cerramos el AltSwitcher solo si el click cae fuera del rectángulo visual del panel.
                if (mouse.x < panel.x || mouse.x > panel.x + panel.width
                        || mouse.y < panel.y || mouse.y > panel.y + panel.height) {
                    GlobalStates.altSwitcherOpen = false
                }
            }
        }

        Item {
            id: keyHandler
            anchors.fill: parent
            focus: GlobalStates.altSwitcherOpen

            Keys.onPressed: function (event) {
                if (!GlobalStates.altSwitcherOpen)
                    return
                if (event.key === Qt.Key_Escape) {
                    GlobalStates.altSwitcherOpen = false
                    event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.activateCurrent()
                    event.accepted = true
                } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                    root.nextItem()
                    event.accepted = true
                } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                    root.previousItem()
                    event.accepted = true
                }
            }
        }

        Rectangle {
            id: panel
            width: root.listStyle ? 420 : (root.compactStyle ? compactRow.implicitWidth + 40 : root.panelWidth)
            height: root.compactStyle ? 100 : undefined
            color: "transparent"
            border.width: 0

            states: [
                State {
                    name: "right"
                    when: !root.centerPanel && !root.compactStyle && !root.listStyle
                    AnchorChanges {
                        target: panel
                        anchors.right: parent.right
                        anchors.horizontalCenter: undefined
                    }
                    PropertyChanges {
                        target: panel
                        anchors.rightMargin: root.panelRightMargin
                    }
                },
                State {
                    name: "center"
                    when: root.centerPanel || root.compactStyle || root.listStyle
                    AnchorChanges {
                        target: panel
                        anchors.right: undefined
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    PropertyChanges {
                        target: panel
                        anchors.rightMargin: 0
                    }
                }
            ]
            
            anchors.verticalCenter: parent.verticalCenter

            implicitHeight: root.listStyle 
                ? Math.min(listContent.implicitHeight, parent.height - Appearance.sizes.hyprlandGapsOut * 2)
                : (root.compactStyle ? 100 : Math.min(contentColumn.implicitHeight + Appearance.sizes.hyprlandGapsOut * 2,
                                      parent.height - Appearance.sizes.hyprlandGapsOut * 2))

            Rectangle {
                id: panelBackground
                visible: !root.compactStyle && !root.listStyle
                z: 0
                anchors.fill: parent
                radius: Appearance.angelEverywhere ? Appearance.angel.roundingLarge
                    : Appearance.inirEverywhere ? Appearance.inir.roundingLarge
                    : (Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut + 1)
                color: {
                    if (Appearance.angelEverywhere)
                        return Appearance.angel.colGlassPopup
                    if (Appearance.inirEverywhere)
                        return Appearance.inir.colLayer0
                    if (Appearance.auroraEverywhere)
                        return Appearance.colors.colLayer0Base
                    if (root.altUseM3Layout)
                        return Appearance.colors.colLayer0
                    const base = ColorUtils.mix(Appearance.colors.colLayer0, Qt.rgba(0, 0, 0, 1), 0.35)
                    return ColorUtils.applyAlpha(base, root.altBackgroundOpacity)
                }
                border.width: Appearance.angelEverywhere ? Appearance.angel.panelBorderWidth
                    : Appearance.inirEverywhere || Appearance.auroraEverywhere ? 1 : (root.altUseM3Layout ? 1 : 0)
                border.color: Appearance.angelEverywhere ? Appearance.angel.colPanelBorder
                    : Appearance.inirEverywhere ? Appearance.inir.colBorder 
                    : Appearance.auroraEverywhere ? Appearance.colors.colLayer0Border 
                    : Appearance.colors.colLayer0Border
            }

            Rectangle {
                id: compactBackground
                visible: root.compactStyle
                anchors.fill: parent
                radius: Appearance.angelEverywhere ? Appearance.angel.roundingLarge
                    : Appearance.inirEverywhere ? Appearance.inir.roundingLarge : Appearance.rounding.large
                color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                    : Appearance.inirEverywhere ? Appearance.inir.colLayer2 
                    : Appearance.auroraEverywhere ? Appearance.colors.colLayer1Base 
                    : Appearance.m3colors.m3surfaceContainerHigh
                border.width: Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth
                    : Appearance.inirEverywhere || Appearance.auroraEverywhere ? 1 : 0
                border.color: Appearance.angelEverywhere ? Appearance.angel.colCardBorder
                    : Appearance.inirEverywhere ? Appearance.inir.colBorder 
                    : Appearance.auroraEverywhere ? Appearance.colors.colLayer0Border 
                    : "transparent"
            }

            StyledRectangularShadow {
                target: root.compactStyle ? compactBackground : panelBackground
                visible: !root.listStyle && (Appearance.angelEverywhere || (!Appearance.inirEverywhere && !Appearance.auroraEverywhere))
            }

            MultiEffect {
                z: 0.5
                anchors.fill: panelBackground
                source: panelBackground
                visible: !root.compactStyle && !root.listStyle && !root.altUseM3Layout && Appearance.effectsEnabled && root.effectiveEnableBlurGlass && root.altBlurAmount > 0 && !root.isHighLoad
                blurEnabled: true
                blur: root.altBlurAmount
                blurMax: 64
                saturation: 1.0
            }

            Row {
                id: compactRow
                visible: root.compactStyle
                z: 1
                anchors.centerIn: parent
                spacing: 4
                
                Repeater {
                    model: ScriptModel { values: root.itemSnapshot }
                    
                    Item {
                        required property var modelData
                        required property int index
                        width: 64
                        height: 64
                        
                        Rectangle {
                            id: compactTile
                            anchors.centerIn: parent
                            width: parent.width
                            height: parent.height
                            radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
                                : Appearance.inirEverywhere ? Appearance.inir.roundingNormal 
                                : Appearance.auroraEverywhere ? Appearance.rounding.normal 
                                : Appearance.rounding.normal
                            color: listView.currentIndex === index 
                                   ? (Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
                                       : Appearance.inirEverywhere ? Appearance.inir.colPrimary 
                                       : Appearance.auroraEverywhere ? Appearance.colors.colPrimaryContainer 
                                       : Appearance.m3colors.m3primaryContainer)
                                   : (Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                                       : Appearance.inirEverywhere ? Appearance.inir.colLayer3 
                                       : Appearance.auroraEverywhere ? Appearance.colors.colLayer2Base 
                                       : Appearance.m3colors.m3surfaceContainerHighest)
                            scale: compactMouseArea.pressed ? 0.92 : (compactMouseArea.containsMouse && !root.isHighLoad ? 1.05 : 1.0)
                            
                            Behavior on color { 
                                enabled: !root.isHighLoad
                                ColorAnimation { 
                                    duration: 200
                                    easing.type: Easing.OutCubic
                                } 
                            }
                            Behavior on scale { 
                                enabled: !root.isHighLoad
                                NumberAnimation { 
                                    duration: 200
                                    easing.type: Easing.OutCubic
                                } 
                            }
                            
                            IconImage {
                                id: compactIcon
                                anchors.centerIn: parent
                                width: 40
                                height: 40
                                source: modelData.icon || ""
                            }
                            
                            Loader {
                                active: root.altMonochromeIcons && !root.isHighLoad
                                anchors.fill: compactIcon
                                sourceComponent: Item {
                                    Desaturate {
                                        id: desaturatedCompactIcon
                                        visible: false
                                        anchors.fill: parent
                                        source: compactIcon
                                        desaturation: 0.8
                                    }
                                    ColorOverlay {
                                        anchors.fill: desaturatedCompactIcon
                                        source: desaturatedCompactIcon
                                        color: ColorUtils.transparentize(Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary, 0.9)
                                    }
                                }
                            }
                            
                            Rectangle {
                                visible: listView.currentIndex === index
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottomMargin: 6
                                width: 24
                                height: 3
                                radius: height / 2
                                color: Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.m3colors.m3primary
                            }
                        }
                        
                        MouseArea {
                            id: compactMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                listView.currentIndex = index
                                if (modelData && modelData.id !== undefined) {
                                    NiriService.focusWindow(modelData.id)
                                }
                            }
                        }
                    }
                }
            }

            // List mode content
            Rectangle {
                id: listContent
                visible: root.listStyle
                z: 1
                anchors.centerIn: parent
                width: 400
                implicitHeight: listHeader.height + listSeparator.height + listColumn.height
                radius: Appearance.angelEverywhere ? Appearance.angel.roundingLarge
                    : Appearance.inirEverywhere ? Appearance.inir.roundingLarge : Appearance.rounding.large
                color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                    : Appearance.inirEverywhere ? Appearance.inir.colLayer1 
                    : Appearance.auroraEverywhere ? Appearance.colors.colLayer1Base 
                    : Appearance.colors.colSurfaceContainer
                border.width: Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth
                    : Appearance.auroraEverywhere ? 1 : 0
                border.color: Appearance.angelEverywhere ? Appearance.angel.colCardBorder
                    : Appearance.auroraEverywhere ? Appearance.colors.colLayer0Border : "transparent"

                StyledRectangularShadow {
                    target: listContent
                    blur: 0.5 * Appearance.sizes.elevationMargin
                    spread: 0
                    visible: Appearance.angelEverywhere || (!Appearance.inirEverywhere && !Appearance.auroraEverywhere)
                }

                Column {
                    anchors.fill: parent
                    spacing: 0

                    RowLayout {
                        id: listHeader
                        width: parent.width
                        height: 44

                        Item { width: 16 }
                        StyledText {
                            text: Translation.tr("Switch windows")
                            font.pixelSize: Appearance.font.pixelSize.larger
                            font.weight: Font.DemiBold
                            color: Appearance.inirEverywhere ? Appearance.inir.colText 
                                : Appearance.auroraEverywhere ? Appearance.colors.colOnLayer1 
                                : Appearance.colors.colOnLayer1
                        }
                        Item { Layout.fillWidth: true }
                        StyledText {
                            text: (root.itemSnapshot?.length ?? 0) + " " + Translation.tr("windows")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary 
                                : Appearance.auroraEverywhere ? Appearance.colors.colSubtext 
                                : Appearance.colors.colSubtext
                        }
                        Item { width: 16 }
                    }

                    Rectangle {
                        id: listSeparator
                        width: parent.width
                        height: 1
                        color: Appearance.inirEverywhere ? Appearance.inir.colBorderSubtle 
                            : Appearance.auroraEverywhere ? Appearance.colors.colLayer0Border 
                            : Appearance.colors.colLayer0Border
                    }

                    Column {
                        id: listColumn
                        width: parent.width
                        topPadding: 8
                        bottomPadding: 8
                        leftPadding: 8
                        rightPadding: 8
                        spacing: 4

                        Repeater {
                            model: ScriptModel { values: root.itemSnapshot }

                            RippleButton {
                                id: listTile
                                required property var modelData
                                required property int index

                                width: listColumn.width - listColumn.leftPadding - listColumn.rightPadding
                                implicitHeight: 52
                                buttonRadius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
                                    : Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
                                toggled: listView.currentIndex === index

                                colBackground: "transparent"
                                colBackgroundHover: Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover 
                                    : Appearance.auroraEverywhere ? Appearance.colors.colLayer2Hover 
                                    : ColorUtils.transparentize(Appearance.colors.colPrimary, 0.88)
                                colBackgroundToggled: Appearance.inirEverywhere ? Appearance.inir.colPrimary 
                                    : Appearance.auroraEverywhere ? Appearance.colors.colPrimaryContainer 
                                    : Appearance.colors.colPrimaryContainer
                                colBackgroundToggledHover: Appearance.inirEverywhere ? Appearance.inir.colPrimaryHover 
                                    : Appearance.auroraEverywhere ? Appearance.colors.colPrimaryContainerHover 
                                    : ColorUtils.mix(Appearance.colors.colPrimaryContainer, Appearance.colors.colPrimary, 0.9)
                                colRipple: Appearance.inirEverywhere ? Appearance.inir.colLayer2Active 
                                    : Appearance.auroraEverywhere ? Appearance.colors.colLayer2Active 
                                    : ColorUtils.transparentize(Appearance.colors.colPrimary, 0.7)
                                colRippleToggled: Appearance.inirEverywhere ? Appearance.inir.colPrimaryActive 
                                    : Appearance.auroraEverywhere ? Appearance.colors.colPrimaryContainerActive 
                                    : ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.7)

                                onClicked: {
                                    listView.currentIndex = index
                                    if (modelData?.id !== undefined) {
                                        NiriService.focusWindow(modelData.id)
                                    }
                                }

                                contentItem: RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 16
                                    anchors.rightMargin: 16
                                    spacing: 12

                                    Rectangle {
                                        Layout.alignment: Qt.AlignVCenter
                                        width: 6
                                        height: 6
                                        radius: 3
                                        color: Appearance.inirEverywhere ? Appearance.inir.colOnPrimary 
                                            : Appearance.auroraEverywhere ? Appearance.colors.colOnPrimaryContainer 
                                            : Appearance.colors.colOnPrimaryContainer
                                        visible: listTile.toggled
                                    }

                                    IconImage {
                                        Layout.alignment: Qt.AlignVCenter
                                        width: 32
                                        height: 32
                                        source: listTile.modelData?.icon ?? ""
                                        implicitSize: 32
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: 2

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: listTile.modelData?.appName ?? listTile.modelData?.title ?? "Window"
                                            font.pixelSize: Appearance.font.pixelSize.normal
                                            font.weight: listTile.toggled ? Font.DemiBold : Font.Normal
                                            color: listTile.toggled 
                                                ? (Appearance.inirEverywhere ? Appearance.inir.colOnPrimary 
                                                    : Appearance.auroraEverywhere ? Appearance.colors.colOnPrimaryContainer 
                                                    : Appearance.colors.colOnPrimaryContainer)
                                                : (Appearance.inirEverywhere ? Appearance.inir.colText 
                                                    : Appearance.auroraEverywhere ? Appearance.colors.colOnLayer1 
                                                    : Appearance.colors.colOnLayer1)
                                            elide: Text.ElideRight
                                        }

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: {
                                                const wsIdx = listTile.modelData?.workspaceIdx
                                                const title = listTile.modelData?.title
                                                if (wsIdx && wsIdx > 0 && title && title !== listTile.modelData?.appName)
                                                    return "WS " + wsIdx + " · " + title
                                                if (wsIdx && wsIdx > 0)
                                                    return "WS " + wsIdx
                                                if (title && title !== listTile.modelData?.appName)
                                                    return title
                                                return ""
                                            }
                                            visible: text !== ""
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            color: listTile.toggled 
                                                ? ColorUtils.transparentize(
                                                    Appearance.inirEverywhere ? Appearance.inir.colOnPrimary 
                                                        : Appearance.auroraEverywhere ? Appearance.colors.colOnPrimaryContainer 
                                                        : Appearance.colors.colOnPrimaryContainer, 0.3)
                                                : (Appearance.inirEverywhere ? Appearance.inir.colTextSecondary 
                                                    : Appearance.auroraEverywhere ? Appearance.colors.colSubtext 
                                                    : Appearance.colors.colSubtext)
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Rectangle {
                                        Layout.alignment: Qt.AlignVCenter
                                        visible: (listTile.modelData?.workspaceIdx ?? 0) > 0
                                        width: wsText.implicitWidth + 12
                                        height: 22
                                        radius: Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.small
                                        color: listTile.toggled 
                                            ? ColorUtils.transparentize(
                                                Appearance.inirEverywhere ? Appearance.inir.colOnPrimary 
                                                    : Appearance.auroraEverywhere ? Appearance.colors.colOnPrimaryContainer 
                                                    : Appearance.colors.colOnPrimaryContainer, 0.85)
                                            : (Appearance.inirEverywhere ? Appearance.inir.colLayer3 
                                                : Appearance.auroraEverywhere ? Appearance.colors.colLayer2 
                                                : Appearance.colors.colLayer2)

                                        StyledText {
                                            id: wsText
                                            anchors.centerIn: parent
                                            text: listTile.modelData?.workspaceIdx ?? ""
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            font.weight: Font.DemiBold
                                            color: listTile.toggled 
                                                ? (Appearance.inirEverywhere ? Appearance.inir.colOnPrimary 
                                                    : Appearance.auroraEverywhere ? Appearance.colors.colOnPrimaryContainer 
                                                    : Appearance.colors.colOnPrimaryContainer)
                                                : (Appearance.inirEverywhere ? Appearance.inir.colTextSecondary 
                                                    : Appearance.auroraEverywhere ? Appearance.colors.colSubtext 
                                                    : Appearance.colors.colSubtext)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                id: contentColumn
                visible: !root.compactStyle && !root.listStyle
                z: 1
                anchors.fill: parent
                anchors.margins: Appearance.sizes.hyprlandGapsOut
                spacing: Appearance.sizes.spacingSmall

                ListView {
                    id: listView
                    Layout.fillWidth: true
                    Layout.fillHeight: false
                    Layout.minimumHeight: 0
                    clip: true
                    spacing: Appearance.sizes.spacingSmall
                    cacheBuffer: 600  // Pre-cargar items fuera de vista
                    property int rowHeight: (count <= 6
                                              ? 60
                                              : (count <= 10 ? 52 : 44))
                    property int maxVisibleRows: 8
                    implicitHeight: {
                        const minRows = 3
                        const rows = count > 0 ? count : 0
                        const visibleRows = Math.min(rows, maxVisibleRows)
                        const baseRows = visibleRows > 0 ? visibleRows : minRows
                        const base = rowHeight * baseRows + spacing * Math.max(0, baseRows - 1)
                        return base
                    }
                    model: ScriptModel {
                        values: root.itemSnapshot
                    }
                    delegate: Item {
                        id: row
                        required property var modelData
                        width: listView.width
                        height: listView.rowHeight
                        property bool selected: ListView.isCurrentItem

                        // Base highlight for the currently cycled window
                        Rectangle {
                            id: highlightBase
                            anchors.fill: parent
                            radius: Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut
                            visible: selected
                            color: root.altUseM3Layout
                                   ? Appearance.m3colors.m3primaryContainer
                                   : Appearance.colors.colLayer1
                        }

                        // Dark gradient towards the left edge inside the highlight
                        Rectangle {
                            anchors.fill: parent
                            radius: highlightBase.radius
                            visible: selected
                            color: "transparent"
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.35) }
                                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.0) }
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            // Left dot indicator for the currently selected window
                            Item {
                                Layout.alignment: Qt.AlignVCenter
                                width: 12
                                height: 12

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 8
                                    height: 8
                                    radius: width / 2
                                    color: Appearance.colors.colOnLayer1
                                    visible: selected
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true

                                StyledText {
                                    text: modelData.appName || modelData.title || "Window"
                                    color: {
                                        const selected = row.selected
                                        const useM3 = root.altUseM3Layout
                                        if (useM3 && selected)
                                            return Appearance.m3colors.m3onPrimaryContainer
                                        if (useM3)
                                            return Appearance.m3colors.m3onSurface
                                        return Appearance.colors.colOnLayer1
                                    }
                                    font.pixelSize: Appearance.font.pixelSize.large
                                    elide: Text.ElideRight
                                }

                                Item {
                                    Layout.fillWidth: true
                                    height: Appearance.font.pixelSize.small * 1.6

                                    StyledText {
                                        id: subtitleText
                                        anchors.fill: parent
                                        text: {
                                            const wsIdx = modelData.workspaceIdx
                                            const title = modelData.title
                                            if (wsIdx && wsIdx > 0 && title)
                                                return "WS " + wsIdx + " · " + title
                                            if (wsIdx && wsIdx > 0)
                                                return "WS " + wsIdx
                                            return title
                                        }
                                        color: {
                                            const selected = row.selected
                                            const useM3 = root.altUseM3Layout
                                            if (useM3 && selected)
                                                return Appearance.m3colors.m3onPrimaryContainer
                                            if (useM3)
                                                return Appearance.colors.colSubtext
                                            return ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.6)
                                        }
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            // App icon on the right, resolved via AppSearch like Overview
                            Item {
                                Layout.alignment: Qt.AlignVCenter
                                width: listView.rowHeight * 0.6
                                height: listView.rowHeight * 0.6

                                IconImage {
                                    id: altSwitcherIcon
                                    anchors.fill: parent
                                    source: modelData.icon || ""
                                    implicitSize: parent.height
                                }

                                // Optional monochrome tint, same pattern as dock/workspaces
                                Loader {
                                    active: root.altMonochromeIcons
                                    anchors.fill: altSwitcherIcon
                                    sourceComponent: Item {
                                        Desaturate {
                                            id: desaturatedAltSwitcherIcon
                                            visible: false // ColorOverlay handles final output
                                            anchors.fill: parent
                                            source: altSwitcherIcon
                                            desaturation: 0.8
                                        }
                                        ColorOverlay {
                                            anchors.fill: desaturatedAltSwitcherIcon
                                            source: desaturatedAltSwitcherIcon
                                            color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.9)
                                        }
                                    }
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: function () {
                                listView.currentIndex = index
                                row.activate()
                            }
                        }

                        function activate() {
                            if (modelData && modelData.id !== undefined) {
                                NiriService.focusWindow(modelData.id)
                            }
                        }
                    }
                }
            }
        }

        Timer {
            id: autoHideTimer
            interval: root.altAutoHideDelayMs
            repeat: false
            onTriggered: GlobalStates.altSwitcherOpen = false
        }

        Connections {
            target: GlobalStates
            function onAltSwitcherOpenChanged() {
                if (GlobalStates.altSwitcherOpen) {
                    root.showPanel()
                    root.maybeOpenOverview()
                } else {
                    root.hidePanel()
                    root.maybeCloseOverview()
                }
            }
        }

        Connections {
            target: NiriService
            function onWindowsChanged() {
                if (GameMode.active) {
                    return
                }
                
                if (!GlobalStates.altSwitcherOpen || !root.itemSnapshot || root.itemSnapshot.length === 0)
                    return

                root._pendingWindowsUpdate = function() {
                    const wins = NiriService.windows || []
                    if (!wins.length) {
                        root.itemSnapshot = []
                        listView.currentIndex = -1
                        GlobalStates.altSwitcherOpen = false
                        return
                    }

                    const alive = {}
                    for (let i = 0; i < wins.length; i++) {
                        alive[wins[i].id] = true
                    }

                    const filtered = []
                    for (let i = 0; i < root.itemSnapshot.length; i++) {
                        const it = root.itemSnapshot[i]
                        if (alive[it.id])
                            filtered.push(it)
                    }

                    if (filtered.length === 0) {
                        GlobalStates.altSwitcherOpen = false
                        return
                    }

                    if (filtered.length !== root.itemSnapshot.length) {
                        root.itemSnapshot = filtered
                    }

                    if (listView.currentIndex >= filtered.length) {
                        listView.currentIndex = filtered.length - 1
                    }
                }
                windowsUpdateDebounce.restart()
            }
        }

        NumberAnimation {
            id: slideInAnim
            target: root
            property: "panelRightMargin"
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            id: slideOutAnim
            target: root
            property: "panelRightMargin"
            easing.type: Easing.InCubic
            onFinished: {
                if (!GlobalStates.altSwitcherOpen) {
                    root.panelVisible = false
                }
            }
        }
    }

    function currentAnimDuration() {
        return root.altAnimationDurationMs
    }

    function showPanel() {
        rebuildSnapshot()
        panelVisible = true
        if (animationsEnabled && !centerPanel && !compactStyle) {
            const dur = currentAnimDuration()
            slideOutAnim.stop()
            root.panelRightMargin = -panelWidth
            slideInAnim.from = -panelWidth
            slideInAnim.to = 0
            slideInAnim.duration = dur
            slideInAnim.restart()
        } else {
            panelRightMargin = 0
        }
    }

    function hidePanel() {
        if (!panelVisible)
            return
        if (animationsEnabled && !centerPanel) {
            const dur = currentAnimDuration()
            slideInAnim.stop()
            slideOutAnim.from = panelRightMargin
            slideOutAnim.to = -panelWidth
            slideOutAnim.duration = dur
            slideOutAnim.restart()
        } else {
            panelRightMargin = -panelWidth
            panelVisible = false
        }
    }

    function hasItems() {
        ensureSnapshot()
        return itemSnapshot && itemSnapshot.length > 0
    }

    function ensureOpen() {
        if (!GlobalStates.altSwitcherOpen) {
            GlobalStates.altSwitcherOpen = true
        }
    }

    function nextItem() {
        ensureSnapshot()
        const total = itemSnapshot ? itemSnapshot.length : 0
        if (total === 0)
            return
        if (listView.currentIndex < 0)
            listView.currentIndex = 0
        else
            listView.currentIndex = (listView.currentIndex + 1) % total
        listView.positionViewAtIndex(listView.currentIndex, ListView.Visible)
    }

    function previousItem() {
        ensureSnapshot()
        const total = itemSnapshot ? itemSnapshot.length : 0
        if (total === 0)
            return
        if (listView.currentIndex < 0)
            listView.currentIndex = total - 1
        else
            listView.currentIndex = (listView.currentIndex - 1 + total) % total
        listView.positionViewAtIndex(listView.currentIndex, ListView.Visible)
    }

    function activateCurrent() {
        if (listView.currentItem && listView.currentItem.activate) {
            listView.currentItem.activate()
        }
    }

    // Pre-warm: construir snapshot en background después de que el shell inicie
    // para evitar lag en la primera apertura
    Timer {
        id: warmUpTimer
        interval: 2000  // 2 segundos después del inicio
        running: !root._warmedUp && (NiriService.windows?.length ?? 0) > 0
        onTriggered: {
            root.rebuildSnapshot()
            root._warmedUp = true
            // Limpiar snapshot después de warm-up (se reconstruye al abrir)
            Qt.callLater(function() {
                if (!GlobalStates.altSwitcherOpen)
                    root.itemSnapshot = []
            })
        }
    }

    // Re-warm cuando cambian las ventanas (solo si no está abierto)
    Connections {
        target: NiriService
        enabled: root._warmedUp && !GlobalStates.altSwitcherOpen
        function onWindowsChanged() {
            if (GameMode.active) return
            
            const wins = NiriService.windows || []
            for (let i = 0; i < wins.length; i++) {
                const w = wins[i]
                const key = w.app_id || ""
                if (key && root.iconCache[key] === undefined) {
                    root.getCachedIcon(w.app_id, "", w.title)
                }
            }
        }
    }
    
    Timer {
        id: noUiSnapshotUpdateTimer
        interval: GameMode.active ? 10000 : 3000
        repeat: true
        running: root.altNoVisualUi && !GlobalStates.altSwitcherOpen
        onTriggered: {
            if (GameMode.active) return
            
            if (NiriService.windows?.length > 0) {
                Qt.callLater(function() {
                    const windows = NiriService.windows || []
                    const workspaces = NiriService.workspaces || {}
                    const mruIds = NiriService.mruWindowIds || []
                    root.noUiSnapshot = buildItemsFrom(windows, workspaces, mruIds)
                })
            }
        }
    }

    // Only handle IPC when Material ii family is active
    property bool isActive: Config.options?.panelFamily !== "waffle"

    IpcHandler {
        target: "altSwitcher"
        enabled: root.isActive

        function open(): void {
            ensureOpen()
            autoHideTimer.restart()
        }

        function close(): void {
            GlobalStates.altSwitcherOpen = false
        }

        function toggle(): void {
            GlobalStates.altSwitcherOpen = !GlobalStates.altSwitcherOpen
            if (GlobalStates.altSwitcherOpen)
                autoHideTimer.restart()
        }

        function next(): void {
            if (root.altNoVisualUi) {
                autoHideTimer.stop()
                GlobalStates.altSwitcherOpen = false

                const len = root.noUiSnapshot?.length ?? 0
                if (!root.quickSwitchDone || len === 0) {
                    root.rebuildNoUiSnapshotSync()  // Use sync version for immediate response
                }

                const newLen = root.noUiSnapshot?.length ?? 0
                if (newLen === 0)
                    return

                if (!root.quickSwitchDone) {
                    root.quickSwitchDone = true
                    root.noUiIndex = newLen > 1 ? 1 : 0
                } else {
                    root.noUiIndex = (root.noUiIndex + 1) % newLen
                }

                root.focusNoUiIndex()
                quickSwitchResetTimer.restart()
                return
            }

            ensureOpen()
            nextItem()
            activateCurrent()
            autoHideTimer.restart()
        }

        function previous(): void {
            if (root.altNoVisualUi) {
                autoHideTimer.stop()
                GlobalStates.altSwitcherOpen = false

                const len = root.noUiSnapshot?.length ?? 0
                if (!root.quickSwitchDone || len === 0) {
                    root.rebuildNoUiSnapshotSync()  // Use sync version for immediate response
                }

                const newLen = root.noUiSnapshot?.length ?? 0
                if (newLen === 0)
                    return

                if (!root.quickSwitchDone) {
                    root.quickSwitchDone = true
                    root.noUiIndex = newLen > 1 ? (newLen - 1) : 0
                } else {
                    root.noUiIndex = (root.noUiIndex - 1 + newLen) % newLen
                }

                root.focusNoUiIndex()
                quickSwitchResetTimer.restart()
                return
            }

            ensureOpen()
            previousItem()
            activateCurrent()
            autoHideTimer.restart()
        }
    }
}
