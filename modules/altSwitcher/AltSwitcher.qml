import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes
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
    readonly property bool effectiveNoVisualUi: altNoVisualUi && altPreset !== "skew"
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
    property bool compactStyle: root.altCompactStyle && !root.listStyle && !root.skewStyle
    property bool listStyle: root.altPreset === "list"
    property bool skewStyle: root.altPreset === "skew"
    property bool showOverviewWhileSwitching: root.altShowOverviewWhileSwitching
    property bool overviewOpenedByAltSwitcher: false
    // Pre-warm flag para evitar lag en primera apertura
    property bool _warmedUp: false
    // Slice geometry base values and responsive scaling
    readonly property int baseSkewSliceWidth: 135
    readonly property int baseSkewExpandedWidth: 924
    readonly property int baseSkewSliceHeight: 520
    readonly property int baseSkewOffset: 35
    readonly property int baseSkewSliceSpacing: -22
    readonly property int skewVisibleCount: 12

    readonly property real skewScale: Math.max(0.58, Math.min(1.0,
        (window.height - 120) / baseSkewSliceHeight,
        (window.width - 96) / baseSkewExpandedWidth
    ))

    readonly property int skewSliceWidth: Math.round(baseSkewSliceWidth * skewScale)
    readonly property int skewExpandedWidth: Math.round(baseSkewExpandedWidth * skewScale)
    readonly property int skewSliceHeight: Math.round(baseSkewSliceHeight * skewScale)
    readonly property int skewOffset: Math.round(baseSkewOffset * skewScale)
    readonly property int skewSliceSpacing: Math.round(baseSkewSliceSpacing * skewScale)
    readonly property int skewCardWidth: skewExpandedWidth + (skewVisibleCount - 1) * (skewSliceWidth + skewSliceSpacing)
    readonly property int skewCardHeight: skewSliceHeight + Math.round(40 * skewScale)
    readonly property int skewPanelWidth: skewCardWidth
    property bool skewCardVisible: false

    property bool _rapidNavigation: false
    property int _rapidNavSteps: 0

    Timer {
        id: skewRapidNavCooldown
        interval: 350
        onTriggered: {
            root._rapidNavigation = false
            root._rapidNavSteps = 0
        }
    }

    function _trackSkewNavStep(): void {
        _rapidNavSteps++
        if (_rapidNavSteps >= 3)
            _rapidNavigation = true
        skewRapidNavCooldown.restart()
    }
    
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

    Timer {
        id: skewCardShowTimer
        interval: 30
        repeat: false
        onTriggered: root.skewCardVisible = GlobalStates.altSwitcherOpen && root.skewStyle
    }

    Timer {
        id: skewFocusTimer
        interval: 30
        running: root.skewStyle && GlobalStates.altSwitcherOpen
        repeat: true
        onTriggered: {
            if (GlobalStates.altSwitcherOpen)
                altReleaseDetector.forceActiveFocus()
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
                isFocused: w.is_focused ?? false,
                isFloating: w.is_floating ?? false,
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

    function rebuildSnapshotSync() {
        const windows = NiriService.windows || []
        const workspaces = NiriService.workspaces || {}
        const mruIds = NiriService.mruWindowIds || []
        itemSnapshot = buildItemsFrom(windows, workspaces, mruIds)
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
        if (!itemSnapshot || itemSnapshot.length === 0) {
            if (root.skewStyle)
                rebuildSnapshotSync()
            else
                rebuildSnapshot()
        }
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
        WlrLayershell.keyboardFocus: root.panelVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
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

        FocusScope {
            id: altReleaseDetector
            anchors.fill: parent
            focus: GlobalStates.altSwitcherOpen
            activeFocusOnTab: false

            Keys.onReleased: function (event) {
                if (!GlobalStates.altSwitcherOpen)
                    return
                if (root.skewStyle && event.key === Qt.Key_Alt) {
                    root.confirmCurrentSelection()
                    event.accepted = true
                }
            }

            Keys.onPressed: function (event) {
                if (!GlobalStates.altSwitcherOpen)
                    return
                if (event.key === Qt.Key_Escape) {
                    GlobalStates.altSwitcherOpen = false
                    event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (root.skewStyle)
                        root.confirmCurrentSelection()
                    else
                        root.activateCurrent()
                    event.accepted = true
                } else if (event.key === Qt.Key_Tab) {
                    if (event.modifiers & Qt.ShiftModifier)
                        root.previousItem()
                    else
                        root.nextItem()
                    event.accepted = true
                } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                    root.nextItem()
                    event.accepted = true
                } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                    root.previousItem()
                    event.accepted = true
                } else if (event.key === Qt.Key_C || event.key === Qt.Key_Delete) {
                    if (root.skewStyle)
                        root.closeSelectedWindow()
                    event.accepted = true
                }
            }
        }

        Rectangle {
            id: panel
            width: root.skewStyle ? Math.min(root.skewPanelWidth, parent.width - Appearance.sizes.hyprlandGapsOut * 2)
                : (root.listStyle ? 420 : (root.compactStyle ? compactRow.implicitWidth + 40 : root.panelWidth))
            height: root.compactStyle ? 100 : undefined
            color: "transparent"
            border.width: 0

            states: [
                State {
                    name: "right"
                    when: !root.centerPanel && !root.compactStyle && !root.listStyle && !root.skewStyle
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
                    when: root.centerPanel || root.compactStyle || root.listStyle || root.skewStyle
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

            implicitHeight: root.skewStyle
                ? Math.min(cardContainer.height + Appearance.sizes.hyprlandGapsOut * 2, parent.height - Appearance.sizes.hyprlandGapsOut * 2)
                : (root.listStyle 
                ? Math.min(listContent.implicitHeight, parent.height - Appearance.sizes.hyprlandGapsOut * 2)
                : (root.compactStyle ? 100 : Math.min(contentColumn.implicitHeight + Appearance.sizes.hyprlandGapsOut * 2,
                                      parent.height - Appearance.sizes.hyprlandGapsOut * 2)))

            Rectangle {
                id: panelBackground
                visible: !root.compactStyle && !root.listStyle && !root.skewStyle
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
                visible: !root.listStyle && !root.skewStyle && (Appearance.angelEverywhere || (!Appearance.inirEverywhere && !Appearance.auroraEverywhere))
            }

            MultiEffect {
                z: 0.5
                anchors.fill: panelBackground
                source: panelBackground
                visible: !root.compactStyle && !root.listStyle && !root.skewStyle && !root.altUseM3Layout && Appearance.effectsEnabled && root.effectiveEnableBlurGlass && root.altBlurAmount > 0 && !root.isHighLoad
                blurEnabled: true
                blur: root.altBlurAmount
                blurMax: 64
                saturation: 1.0
            }

            // Card container with fade-in (matching piixident structure)
            Item {
                id: cardContainer
                width: root.skewCardWidth
                height: root.skewCardHeight
                anchors.centerIn: parent
                visible: root.skewStyle && root.skewCardVisible

                opacity: 0
                property bool animateIn: root.skewCardVisible

                onAnimateInChanged: {
                    fadeInAnim.stop()
                    if (animateIn) {
                        opacity = 0
                        fadeInAnim.start()
                    }
                }

                NumberAnimation {
                    id: fadeInAnim
                    target: cardContainer
                    property: "opacity"
                    from: 0; to: 1
                    duration: Appearance.calcEffectiveDuration(400)
                    easing.type: Easing.OutCubic
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {}
                }

                Item {
                    id: backgroundRect
                    anchors.fill: parent
                }
            }

            // Horizontal parallelogram slice list view (matching piixident)
            ListView {
                id: skewDeck
                anchors.top: cardContainer.top
                anchors.topMargin: 15
                anchors.bottom: cardContainer.bottom
                anchors.bottomMargin: 20
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.skewExpandedWidth + (root.skewVisibleCount - 1) * (root.skewSliceWidth + root.skewSliceSpacing)

                currentIndex: listView.currentIndex
                orientation: ListView.Horizontal
                model: ScriptModel { values: root.itemSnapshot }
                clip: false
                spacing: root.skewSliceSpacing
                interactive: false
                flickDeceleration: 1500
                maximumFlickVelocity: 3000
                boundsBehavior: Flickable.StopAtBounds
                cacheBuffer: root.skewExpandedWidth * 2
                visible: root.skewStyle && root.skewCardVisible

                highlightFollowsCurrentItem: true
                highlightMoveDuration: Appearance.calcEffectiveDuration(root._rapidNavigation ? 150 : 240)
                highlight: Item {}
                preferredHighlightBegin: (width - root.skewExpandedWidth) / 2
                preferredHighlightEnd: (width + root.skewExpandedWidth) / 2
                highlightRangeMode: ListView.StrictlyEnforceRange
                header: Item { width: (skewDeck.width - root.skewExpandedWidth) / 2; height: 1 }
                footer: Item { width: (skewDeck.width - root.skewExpandedWidth) / 2; height: 1 }

                Text {
                    anchors.centerIn: parent
                    visible: root.windowCount === 0
                    text: "NO WINDOWS"
                    font.family: Appearance.font.family.main
                    font.weight: Font.Bold
                    font.pixelSize: 18
                    font.letterSpacing: 2
                    color: Appearance.colors.colOutline
                }

                delegate: Item {
                    id: skewSlice
                    required property var modelData
                    required property int index
                    property bool isCurrent: ListView.isCurrentItem
                    readonly property real _distFromCenter: {
                        const midX = skewDeck.contentX + skewDeck.width / 2
                        const itemMidX = x + width / 2
                        return Math.abs(midX - itemMidX)
                    }
                    readonly property real edgeOpacity: isCurrent ? 1.0
                        : Math.max(0.25, 1.0 - (_distFromCenter / (skewDeck.width * 0.55)) * 0.65)
                    property string previewUrl: ""
                    width: isCurrent ? root.skewExpandedWidth : root.skewSliceWidth
                    height: skewDeck.height
                    y: isCurrent ? -8 : 0
                    scale: isCurrent ? 1.018 : 1.0
                    z: isCurrent ? 100 : 50 - Math.min(Math.abs(index - listView.currentIndex), 50)
                    opacity: edgeOpacity

                    containmentMask: Item {
                        function contains(point: point): bool {
                            const w = skewSlice.width
                            const h = skewSlice.height
                            const sk = root.skewOffset
                            if (h <= 0 || w <= 0)
                                return false
                            const leftX = sk * (1.0 - point.y / h)
                            const rightX = w - sk * (point.y / h)
                            return point.x >= leftX && point.x <= rightX && point.y >= 0 && point.y <= h
                        }
                    }

                    function refreshPreview(): void {
                        if (modelData?.id === undefined)
                            return
                        const url = WindowPreviewService.getPreviewUrl(modelData.id)
                        if (url && url.length > 0)
                            previewUrl = url
                    }

                    Behavior on width {
                        enabled: root.effectiveEnableAnimation
                        NumberAnimation {
                            duration: Appearance.calcEffectiveDuration(root._rapidNavigation ? 120 : 180)
                            easing.type: Easing.OutQuad
                        }
                    }

                    Behavior on y {
                        enabled: root.effectiveEnableAnimation
                        NumberAnimation {
                            duration: Appearance.calcEffectiveDuration(200)
                            easing.type: Easing.OutQuad
                        }
                    }

                    Behavior on scale {
                        enabled: root.effectiveEnableAnimation
                        NumberAnimation {
                            duration: Appearance.calcEffectiveDuration(200)
                            easing.type: Easing.OutQuad
                        }
                    }

                    Behavior on opacity {
                        enabled: root.effectiveEnableAnimation
                        NumberAnimation {
                            duration: Appearance.calcEffectiveDuration(150)
                            easing.type: Easing.OutQuad
                        }
                    }

                    Component.onCompleted: Qt.callLater(() => skewSlice.refreshPreview())

                    Connections {
                        target: WindowPreviewService
                        function onPreviewUpdated(updatedId: int): void {
                            if (updatedId === skewSlice.modelData?.id)
                                skewSlice.previewUrl = WindowPreviewService.getPreviewUrl(updatedId)
                        }
                        function onCaptureComplete(): void {
                            skewSlice.refreshPreview()
                        }
                    }

                    // Shadow (current delegate only)
                    Item {
                        visible: skewSlice.isCurrent
                        anchors.fill: parent
                        anchors.margins: -24
                        layer.enabled: visible
                        layer.smooth: true
                        opacity: 0.45

                        Shape {
                            x: 24 + 3
                            y: 24 + 8
                            width: skewSlice.width
                            height: skewSlice.height
                            antialiasing: true

                            ShapePath {
                                fillColor: Appearance.colors.colShadow
                                strokeColor: "transparent"
                                startX: root.skewOffset; startY: 0
                                PathLine { x: skewSlice.width; y: 0 }
                                PathLine { x: skewSlice.width - root.skewOffset; y: skewSlice.height }
                                PathLine { x: 0; y: skewSlice.height }
                                PathLine { x: root.skewOffset; y: 0 }
                            }
                        }

                        layer.effect: MultiEffect {
                            blurEnabled: true
                            blur: 0.5
                            blurMax: 24
                        }
                    }

                    Item {
                        id: skewImageContainer
                        anchors.fill: parent
                        layer.enabled: true
                        layer.smooth: true
                        layer.samples: 4
                        layer.effect: MultiEffect {
                                maskEnabled: true
                                maskSource: ShaderEffectSource {
                                    sourceItem: Item {
                                        width: skewImageContainer.width
                                        height: skewImageContainer.height
                                        layer.enabled: true
                                        layer.smooth: true
                                        layer.samples: 4

                                        Shape {
                                            anchors.fill: parent
                                            antialiasing: true
                                            preferredRendererType: Shape.CurveRenderer

                                            ShapePath {
                                                fillColor: "white"
                                                strokeColor: "transparent"
                                                startX: root.skewOffset
                                                startY: 0
                                                PathLine { x: skewSlice.width; y: 0 }
                                                PathLine { x: skewSlice.width - root.skewOffset; y: skewSlice.height }
                                                PathLine { x: 0; y: skewSlice.height }
                                                PathLine { x: root.skewOffset; y: 0 }
                                            }
                                        }
                                    }
                                }
                                maskThresholdMin: 0.3
                                maskSpreadAtMin: 0.3
                            }

                            Rectangle {
                                anchors.fill: parent
                                gradient: Gradient {
                                    GradientStop {
                                        position: 0.0
                                        color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                                            : Appearance.inirEverywhere ? Appearance.inir.colLayer1
                                            : Appearance.auroraEverywhere ? Appearance.colors.colLayer1Base
                                            : Appearance.colors.colLayer1
                                    }
                                    GradientStop {
                                        position: 1.0
                                        color: Appearance.angelEverywhere ? Appearance.angel.colGlassPanel
                                            : Appearance.inirEverywhere ? Appearance.inir.colLayer0
                                            : Appearance.auroraEverywhere ? Appearance.colors.colLayer0Base
                                            : Appearance.colors.colLayer0
                                    }
                                }
                            }

                            Image {
                                id: previewImage
                                anchors.fill: parent
                                source: skewSlice.previewUrl
                                fillMode: Image.PreserveAspectCrop
                                smooth: true
                                asynchronous: true
                                cache: false
                                visible: status === Image.Ready && source.toString().length > 0
                                sourceSize.width: root.skewExpandedWidth
                                sourceSize.height: root.skewSliceHeight
                            }

                            Rectangle {
                                anchors.fill: parent
                                color: Qt.rgba(0, 0, 0, skewSlice.isCurrent ? 0.0 : 0.4)
                                Behavior on color {
                                    ColorAnimation {
                                        duration: Appearance.calcEffectiveDuration(200)
                                    }
                                }
                            }

                            // Big icon (matching piixident structure)
                            Text {
                                id: bigIcon
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: -20
                                text: skewSlice.modelData?.icon ? "" : "?"
                                property int iconSize: skewSlice.isCurrent ? 96 : 48
                                font.pixelSize: iconSize
                                font.family: Appearance.font.family.monospace
                                opacity: previewImage.visible ? 0.7 : 1.0
                                Behavior on opacity { NumberAnimation { duration: Appearance.calcEffectiveDuration(200) } }
                                color: skewSlice.isCurrent ? Appearance.colors.colPrimary : Qt.rgba(Appearance.colors.colTertiary.r, Appearance.colors.colTertiary.g, Appearance.colors.colTertiary.b, 0.5)
                                Behavior on iconSize { NumberAnimation { duration: Appearance.calcEffectiveDuration(200); easing.type: Easing.OutQuad } }
                                Behavior on color { ColorAnimation { duration: Appearance.calcEffectiveDuration(200) } }
                                visible: !skewSlice.modelData?.icon
                            }
                            
                            IconImage {
                                id: bigIconImage
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: -20
                                width: skewSlice.isCurrent ? 96 : 48
                                height: width
                                source: skewSlice.modelData?.icon || ""
                                opacity: previewImage.visible ? 0.7 : 1.0
                                visible: !!skewSlice.modelData?.icon
                                Behavior on width { NumberAnimation { duration: Appearance.calcEffectiveDuration(200); easing.type: Easing.OutQuad } }
                                Behavior on opacity { NumberAnimation { duration: Appearance.calcEffectiveDuration(200) } }
                            }
                        }

                        // Glow border with color animation (matching piixident)
                        Shape {
                            id: glowBorder
                            anchors.fill: parent
                            antialiasing: true
                            preferredRendererType: Shape.CurveRenderer

                            ShapePath {
                                fillColor: "transparent"
                                strokeColor: skewSlice.isCurrent ? Appearance.colors.colPrimary : Qt.rgba(0, 0, 0, 0.6)
                                Behavior on strokeColor { ColorAnimation { duration: Appearance.calcEffectiveDuration(200) } }
                                strokeWidth: skewSlice.isCurrent ? 3 : 1
                                startX: root.skewOffset
                                startY: 0
                                PathLine { x: skewSlice.width; y: 0 }
                                PathLine { x: skewSlice.width - root.skewOffset; y: skewSlice.height }
                                PathLine { x: 0; y: skewSlice.height }
                                PathLine { x: root.skewOffset; y: 0 }
                            }
                        }

                        Rectangle {
                            anchors.top: parent.top
                            anchors.topMargin: 10
                            anchors.left: parent.left
                            anchors.leftMargin: root.skewOffset + 6
                            width: focusedLabel.width + 12
                            height: 20
                            radius: 10
                            color: Appearance.colors.colPrimary
                            visible: skewSlice.modelData?.isFocused ?? false
                            z: 10

                            Text {
                                id: focusedLabel
                                anchors.centerIn: parent
                                text: "FOCUSED"
                                font.family: Appearance.font.family.main
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                font.letterSpacing: 0.5
                                color: Appearance.colors.colOnPrimary
                            }
                        }

                        Rectangle {
                            id: nameLabel
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 40
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: nameLabelCol.width + 24
                            height: nameLabelCol.height + 16
                            radius: 6
                            color: Qt.rgba(0, 0, 0, 0.75)
                            border.width: 1
                            border.color: Qt.rgba(Appearance.colors.colPrimary.r, Appearance.colors.colPrimary.g, Appearance.colors.colPrimary.b, 0.5)
                            visible: skewSlice.isCurrent
                            opacity: skewSlice.isCurrent ? 1 : 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Appearance.calcEffectiveDuration(200)
                                }
                            }

                            Column {
                                id: nameLabelCol
                                anchors.centerIn: parent
                                spacing: 4

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: (skewSlice.modelData?.appName ?? "Window").toUpperCase()
                                    font.family: Appearance.font.family.main
                                    font.pixelSize: 13
                                    font.weight: Font.Bold
                                    font.letterSpacing: 0.5
                                    color: Appearance.colors.colPrimary
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: {
                                        const title = skewSlice.modelData?.title ?? ""
                                        return title.length > 60 ? title.substring(0, 60) + "…" : title
                                    }
                                    font.family: Appearance.font.family.main
                                    font.pixelSize: 11
                                    color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.6)
                                    width: Math.min(implicitWidth, skewSlice.width - 80)
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 8
                            anchors.right: parent.right
                            anchors.rightMargin: root.skewOffset + 8
                            width: wsBadgeText.width + 8
                            height: 16
                            radius: 4
                            color: Qt.rgba(0, 0, 0, 0.75)
                            border.width: 1
                            border.color: Qt.rgba(Appearance.colors.colPrimary.r, Appearance.colors.colPrimary.g, Appearance.colors.colPrimary.b, 0.4)
                            visible: (skewSlice.modelData?.workspaceIdx ?? 0) > 0
                            z: 10

                            Text {
                                id: wsBadgeText
                                anchors.centerIn: parent
                                text: "WS " + (skewSlice.modelData?.workspaceIdx ?? "")
                                font.family: Appearance.font.family.main
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                font.letterSpacing: 0.5
                                color: Appearance.colors.colSecondary
                            }
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 8
                            anchors.left: parent.left
                            anchors.leftMargin: root.skewOffset + 8
                            width: floatLabel.width + 8
                            height: 16
                            radius: 4
                            color: Qt.rgba(0, 0, 0, 0.75)
                            border.width: 1
                            border.color: Qt.rgba(Appearance.colors.colPrimary.r, Appearance.colors.colPrimary.g, Appearance.colors.colPrimary.b, 0.4)
                            visible: skewSlice.modelData?.isFloating ?? false
                            z: 10

                            Text {
                                id: floatLabel
                                anchors.centerIn: parent
                                text: "FLOAT"
                                font.family: Appearance.font.family.main
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                font.letterSpacing: 0.5
                                color: Appearance.colors.colSecondary
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (skewSlice.isCurrent)
                                    root.confirmCurrentSelection()
                                else
                                    listView.currentIndex = skewSlice.index
                            }
                        }
                    }
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
                visible: !root.compactStyle && !root.listStyle && !root.skewStyle
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
        if (root.skewStyle) {
            rebuildSnapshotSync()
            root.skewCardVisible = false
            if (listView.currentIndex < 0 || listView.currentIndex >= (itemSnapshot?.length ?? 0))
                listView.currentIndex = root.defaultSkewIndex()
            skewCardShowTimer.restart()
        } else {
            rebuildSnapshot()
        }
        if (CompositorService.isNiri && root.skewStyle)
            Qt.callLater(() => WindowPreviewService.captureForTaskView())
        panelVisible = true
        if (animationsEnabled && !centerPanel && !compactStyle && !root.listStyle && !root.skewStyle) {
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
        skewCardShowTimer.stop()
        root.skewCardVisible = false
        if (animationsEnabled && !centerPanel && !root.listStyle && !root.skewStyle) {
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

    function defaultSkewIndex() {
        const total = itemSnapshot?.length ?? 0
        if (total <= 0)
            return -1
        return total > 1 ? 1 : 0
    }

    function openSkewSwitcher() {
        autoHideTimer.stop()
        rebuildSnapshotSync()
        if ((itemSnapshot?.length ?? 0) === 0)
            return
        ensureOpen()
        listView.currentIndex = defaultSkewIndex()
    }

    function closeSelectedWindow(): void {
        if (!itemSnapshot || itemSnapshot.length === 0)
            return
        const idx = listView.currentIndex
        if (idx < 0 || idx >= itemSnapshot.length)
            return
        const win = itemSnapshot[idx]
        if (win?.id !== undefined)
            NiriService.closeWindow(win.id)
    }

    function confirmCurrentSelection() {
        root.activateCurrent()
        GlobalStates.altSwitcherOpen = false
    }

    function nextItem() {
        if (root.skewStyle)
            root._trackSkewNavStep()
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
        if (root.skewStyle)
            root._trackSkewNavStep()
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
        if (root.skewStyle) {
            const idx = listView.currentIndex
            if (idx >= 0 && idx < (itemSnapshot?.length ?? 0)) {
                const item = itemSnapshot[idx]
                if (item?.id !== undefined)
                    NiriService.focusWindow(item.id)
            }
            return
        }
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
        running: root.effectiveNoVisualUi && !GlobalStates.altSwitcherOpen
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

    readonly property bool waffleFamilyActive: (Config.options?.panelFamily ?? "ii") === "waffle"

    function routeToWaffle(functionName: string): void {
        Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "waffleAltSwitcher", functionName])
    }

    IpcHandler {
        target: "altSwitcher"

        function open(): void {
            if (root.waffleFamilyActive) {
                root.routeToWaffle("open")
                return
            }
            if (root.skewStyle) {
                root.openSkewSwitcher()
                return
            }
            ensureOpen()
            autoHideTimer.restart()
        }

        function close(): void {
            if (root.waffleFamilyActive) {
                root.routeToWaffle("close")
                return
            }
            GlobalStates.altSwitcherOpen = false
        }

        function toggle(): void {
            if (root.waffleFamilyActive) {
                root.routeToWaffle("toggle")
                return
            }
            if (root.skewStyle) {
                if (GlobalStates.altSwitcherOpen)
                    GlobalStates.altSwitcherOpen = false
                else
                    root.openSkewSwitcher()
                return
            }
            GlobalStates.altSwitcherOpen = !GlobalStates.altSwitcherOpen
            if (GlobalStates.altSwitcherOpen)
                autoHideTimer.restart()
        }

        function next(): void {
            if (root.waffleFamilyActive) {
                root.routeToWaffle("next")
                return
            }
            if (root.effectiveNoVisualUi) {
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

            if (root.skewStyle) {
                if (!GlobalStates.altSwitcherOpen) {
                    root.openSkewSwitcher()
                    return
                }
                nextItem()
                return
            }

            ensureOpen()
            nextItem()
            activateCurrent()
            autoHideTimer.restart()
        }

        function previous(): void {
            if (root.waffleFamilyActive) {
                root.routeToWaffle("previous")
                return
            }
            if (root.effectiveNoVisualUi) {
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

            if (root.skewStyle) {
                if (!GlobalStates.altSwitcherOpen) {
                    root.openSkewSwitcher()
                    return
                }
                previousItem()
                return
            }

            ensureOpen()
            previousItem()
            activateCurrent()
            autoHideTimer.restart()
        }
    }
}
