pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sidebarLeft
import qs.modules.sidebarRight
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    required property string edge
    property var screen: null

    readonly property bool isLeftEdge: root.edge === "left"
    readonly property string roleId: ShellLayoutController.sidebarRoleForSlot(root.edge)
    readonly property bool featureRole: root.roleId === "featureSidebar"
    readonly property bool systemRole: root.roleId === "systemSidebar"
    readonly property bool semanticRoleOpen: root.featureRole
        ? GlobalStates.sidebarLeftOpen : GlobalStates.sidebarRightOpen
    readonly property string roleTargetOutput: root.featureRole
        ? GlobalStates.sidebarLeftPresentationOutput
        : GlobalStates.sidebarRightPresentationOutput
    readonly property bool roleOpen: root.semanticRoleOpen
        && root.roleTargetOutput === root._screenName
    readonly property bool otherSemanticRoleOpen: root.featureRole
        ? GlobalStates.sidebarRightOpen : GlobalStates.sidebarLeftOpen
    readonly property string otherRoleTargetOutput: root.featureRole
        ? GlobalStates.sidebarRightPresentationOutput
        : GlobalStates.sidebarLeftPresentationOutput
    readonly property bool otherRoleOpen: root.otherSemanticRoleOpen
        && root.otherRoleTargetOutput === root._screenName
    // Temporary editor mapping is deliberately independent from
    // `_sidebarShown`. That flag belongs only to semantic open/close animation
    // state; sharing it makes the next real opening skip its configured pose.
    readonly property bool editorPresentation:
        ShellEditSession.active && !root.roleOpen
    readonly property bool presentationOpen:
        root.roleOpen || root.editorPresentation
    property string _screenName: ""
    readonly property bool fullscreenCovered: root._screenName.length > 0
        && GameMode.hasFullscreenOnOutput(root._screenName)
    readonly property bool edgeOpenEnabled: (Config.options?.sidebar?.edgeOpen?.enable ?? false)
        && !root.fullscreenCovered && !GlobalStates.screenLocked
    readonly property int edgeOpenWidth: Math.max(1,
        Config.options?.sidebar?.edgeOpen?.regionWidth ?? 2)
    property bool edgeRevealTransient: false
    readonly property bool roleHoldOpen: root.featureRole
        && GlobalStates.sidebarLeftHoldOpen
    readonly property bool roleExpanded: root.featureRole
        && GlobalStates.sidebarLeftExpanded
    readonly property var roleLayoutState: ShellLayoutController.currentState(
        root.roleId, sidebarRoot.screen?.name ?? "")
    readonly property int configuredWidth: Math.round(
        root.roleLayoutState?.width ?? Appearance.sizes.sidebarWidth)
    readonly property string sizeMode: root.roleLayoutState?.sizeMode ?? "full"
    readonly property int customHeight: Math.round(
        root.roleLayoutState?.customHeight ?? 720)
    readonly property real availableContentHeight: Math.max(0,
        sidebarRoot.height - Appearance.sizes.hyprlandGapsOut * 2)
    readonly property real reportedPreferredHeight:
        sidebarContentLoader.item?.preferredContentHeight ?? -1
    readonly property real reportedMinimumHeight:
        sidebarContentLoader.item?.minimumUsefulHeight ?? 320
    readonly property real reportedMinimumWidth:
        sidebarContentLoader.item?.minimumUsefulWidth ?? 320
    readonly property real reportedMaximumWidth:
        sidebarContentLoader.item?.maximumUsefulWidth ?? 900
    readonly property real effectiveContentHeight: {
        if (root.sizeMode === "full")
            return root.availableContentHeight
        const requested = root.heightPreview >= 0
            ? root.heightPreview
            : root.sizeMode === "custom"
                ? root.customHeight
            : root.reportedPreferredHeight > 0
                ? root.reportedPreferredHeight
                : root.availableContentHeight
        return Math.max(root.reportedMinimumHeight,
            Math.min(root.availableContentHeight, requested))
    }
    readonly property bool instantOpen: Config.options?.sidebar?.instantOpen ?? false
    readonly property string animationType: Config.options?.sidebar?.animationType ?? "slide"

    property bool pluginViewActive: false
    property real widthPreview: -1
    property real heightPreview: -1
    property real resizeBaselineWidth: -1
    property real resizeBaselineHeight: -1
    property bool _pluginTransitioning: false
    property bool _sidebarShown: false
    property bool _presentationRequested: false
    property int _presentationReadyFrames: 0
    property bool _presentationCold: false
    property bool _renderUpdatesNeeded: true
    property bool _contentResident: false
    property bool _nativeHostMapped: true
    property bool _resumeRearmPending: false
    readonly property int contentIdleUnloadMs: {
        const override = Number(Quickshell.env("INIR_SIDEBAR_IDLE_UNLOAD_MS"))
        return Number.isFinite(override) && override >= 250
            ? Math.round(override) : 300000
    }

    onRoleOpenChanged: Qt.callLater(() => {
        if (!root.roleOpen)
            root.edgeRevealTransient = false
        root.syncPresentation()
        root.reportRuntime()
    })

    onPresentationOpenChanged: {
        if (root.presentationOpen) {
            contentUnloadTimer.stop()
            root._contentResident = true
            renderSuspendTimer.stop()
            root._renderUpdatesNeeded = true
        } else {
            renderSuspendTimer.restart()
            if (root._contentResident)
                contentUnloadTimer.restart()
        }
    }

    Timer {
        id: renderSuspendTimer
        interval: Math.max(50,
            (Appearance.animation?.elementMoveExit?.duration ?? 200) + 50)
        onTriggered: {
            if (!root.presentationOpen)
                root._renderUpdatesNeeded = false
        }
    }

    Timer {
        id: contentUnloadTimer
        interval: root.contentIdleUnloadMs
        onTriggered: {
            if (root.presentationOpen)
                return
            if (sidebarContentLoader.animating) {
                restart()
                return
            }
            root._contentResident = false
            root.reportRuntime()
        }
    }

    readonly property real effectiveSidebarWidth: {
        const configuredRequest = root.widthPreview >= 0
            ? root.widthPreview : root.configuredWidth
        const requested = root.featureRole
            && (root.pluginViewActive || root.roleExpanded)
            ? Math.max(configuredRequest, Appearance.sizes.sidebarWidthExtended)
            : configuredRequest
        const screenLimit = Math.max(root.reportedMinimumWidth,
            (sidebarRoot.screen?.width ?? 1920)
                - Appearance.sizes.hyprlandGapsOut * 2)
        return Math.max(root.reportedMinimumWidth,
            Math.min(root.reportedMaximumWidth, screenLimit, requested))
    }

    onSizeModeChanged: Qt.callLater(root.reportRuntime)
    onCustomHeightChanged: Qt.callLater(root.reportRuntime)

    onPluginViewActiveChanged: {
        root._pluginTransitioning = true
        pluginTransitionTimer.restart()
    }

    onRoleIdChanged: {
        root.pluginViewActive = false
        root.widthPreview = -1
        root.heightPreview = -1
        root._presentationRequested = false
        root._presentationReadyFrames = 0
        root._presentationCold = false
        root._sidebarShown = false
        presentationTimer.stop()
        Qt.callLater(() => {
            root.syncPresentation()
            root.reportRuntime()
        })
    }

    Timer {
        id: pluginTransitionTimer
        interval: 50
        onTriggered: root._pluginTransitioning = false
    }

    function reportRuntime(): void {
        runtimeReportTimer.restart()
    }

    function scheduleResumeRearm(): void {
        root._resumeRearmPending = true
        root._nativeHostMapped = false
        root._presentationRequested = false
        presentationTimer.stop()
        resumeRemapTimer.stop()
        if (!GlobalStates.screenLocked)
            resumeRemapTimer.restart()
        root.reportRuntime()
    }

    function emitRuntimeReport(): void {
        ShellEditSession.reportHost(root.edge, {
            roleId: root.roleId,
            roleOpen: root.roleOpen,
            presentationOpen: root.presentationOpen,
            roleHoldOpen: root.roleHoldOpen,
            otherRoleOpen: root.otherRoleOpen,
            renderUpdatesNeeded: root._renderUpdatesNeeded,
            nativeHostMapped: root._nativeHostMapped,
            resumeRearmPending: root._resumeRearmPending,
            windowVisible: sidebarRoot.visible,
            loaderActive: sidebarContentLoader.active,
            loaderStatus: sidebarContentLoader.status,
            contentReady: sidebarContentLoader.item !== null,
            contentResident: root._contentResident,
            idleUnloadPending: contentUnloadTimer.running,
            animationType: root.animationType,
            animationRunning: sidebarContentLoader.animating,
            animationTranslateX: Math.round(sidebarContentLoader.animTranslateX),
            animationOpacity: Number(sidebarContentLoader.animOpacity.toFixed(3)),
            animationScale: Number(sidebarContentLoader.animScale.toFixed(3)),
            sizeMode: root.sizeMode,
            preferredHeight: Math.round(root.reportedPreferredHeight),
            minimumHeight: Math.round(root.reportedMinimumHeight),
            contentFitActive: sidebarContentLoader.item?.contentFitActive ?? false,
            bottomCollapsed: sidebarContentLoader.item?.bottomCollapsed ?? false,
            width: Math.round(sidebarContentLoader.width),
            height: Math.round(sidebarContentLoader.height)
        })
    }

    function beginResize(kind: string): void {
        const baseline = root.roleLayoutState ?? ({})
        if (!ShellEditSession.beginGesture(root.roleId, kind, baseline))
            return
        if (kind === "resize-width") {
            root.resizeBaselineWidth = root.configuredWidth
            root.widthPreview = root.resizeBaselineWidth
        } else if (kind === "resize-height") {
            root.resizeBaselineHeight = root.effectiveContentHeight
            root.heightPreview = root.resizeBaselineHeight
        }
    }

    function updateResize(kind: string, deltaX: real, deltaY: real): void {
        if (kind === "resize-width") {
            const directedDelta = root.isLeftEdge ? deltaX : -deltaX
            root.widthPreview = Math.round(Math.max(root.reportedMinimumWidth,
                Math.min(root.reportedMaximumWidth,
                    root.resizeBaselineWidth + directedDelta)))
        } else if (kind === "resize-height") {
            root.heightPreview = Math.round(Math.max(root.reportedMinimumHeight,
                Math.min(root.availableContentHeight,
                    root.resizeBaselineHeight - deltaY)))
        }
    }

    function finishResize(kind: string): void {
        if (kind === "resize-width" && root.widthPreview >= 0)
            ShellLayoutController.setProperty(root.roleId, "thickness",
                root.widthPreview, sidebarRoot.screen?.name ?? "")
        else if (kind === "resize-height" && root.heightPreview >= 0) {
            ShellLayoutController.setProperty(root.roleId, "height",
                root.heightPreview, sidebarRoot.screen?.name ?? "")
            ShellLayoutController.setProperty(root.roleId, "sizeMode",
                "custom", sidebarRoot.screen?.name ?? "")
        }
        root.widthPreview = -1
        root.heightPreview = -1
        root.resizeBaselineWidth = -1
        root.resizeBaselineHeight = -1
        ShellEditSession.finishGesture()
    }

    function cancelResize(): void {
        root.widthPreview = -1
        root.heightPreview = -1
        root.resizeBaselineWidth = -1
        root.resizeBaselineHeight = -1
        ShellEditSession.cancelPending()
    }

    Timer {
        id: runtimeReportTimer
        interval: 50
        onTriggered: root.emitRuntimeReport()
    }

    Timer {
        id: resumeRemapTimer
        interval: 140
        onTriggered: {
            if (GlobalStates.screenLocked)
                return
            root._nativeHostMapped = true
            root._resumeRearmPending = false
            root._renderUpdatesNeeded = true
            Qt.callLater(() => {
                if (root.presentationOpen)
                    root.syncPresentation()
                else
                    renderSuspendTimer.restart()
                root.reportRuntime()
            })
        }
    }

    Connections {
        target: Idle
        function onResumed(): void {
            root.scheduleResumeRearm()
        }
    }

    function setRoleOpen(open: bool): void {
        if (root.featureRole) {
            if (open)
                GlobalStates.openSidebarLeft(root._screenName)
            else
                GlobalStates.closeSidebarLeft()
        } else if (root.systemRole) {
            if (open)
                GlobalStates.openSidebarRight(root._screenName)
            else
                GlobalStates.closeSidebarRight()
        }
    }

    function clearFeatureExpansion(): void {
        if (root.featureRole)
            GlobalStates.sidebarLeftExpanded = false
    }

    function requestPresentation(): void {
        // The compositor must receive one closed frame before the open state.
        // Warm content needs one frame; a cold map keeps the historical two
        // frames required for valid Loader geometry.
        root._presentationCold = !root._contentResident
            || sidebarContentLoader.status !== Loader.Ready
        root._contentResident = true
        root._presentationRequested = true
        root._presentationReadyFrames = 0
        presentationTimer.restart()
    }

    function tryPresent(): void {
        if (!root._presentationRequested || !root.presentationOpen)
            return
        if (sidebarRoot.height <= 0 || sidebarContentLoader.height <= 0)
            return
        if (!sidebarContentLoader._everMounted)
            sidebarContentLoader._everMounted = true
        if (sidebarContentLoader.status !== Loader.Ready)
            return
        root._presentationReadyFrames++
        const requiredFrames = root._presentationCold ? 2 : 1
        if (root._presentationReadyFrames < requiredFrames)
            return
        root._presentationRequested = false
        root._presentationCold = false
        presentationTimer.stop()
        if (root.roleOpen)
            root._sidebarShown = true
    }

    function syncPresentation(): void {
        if (root.roleOpen) {
            root.requestPresentation()
        } else if (root.editorPresentation) {
            root._sidebarShown = false
            root.requestPresentation()
        } else if (!root._sidebarShown) {
            root._presentationRequested = false
            presentationTimer.stop()
        } else if (root.instantOpen || !Appearance.animationsEnabled) {
            root._presentationRequested = false
            presentationTimer.stop()
            root._sidebarShown = false
            root.clearFeatureExpansion()
        } else {
            root._presentationRequested = false
            presentationTimer.stop()
            root._sidebarShown = false
            root.clearFeatureExpansion()
        }
    }

    Timer {
        id: presentationTimer
        interval: 16
        repeat: true
        onTriggered: root.tryPresent()
    }

    Component {
        id: featureContentComponent

        SidebarLeftContent {
            outerSizeMode: root.sizeMode
            screenWidth: sidebarRoot.screen?.width ?? 1920
            screenHeight: sidebarRoot.screen?.height ?? 1080
            panelScreen: sidebarRoot.screen ?? null
            panelVisible: root.presentationOpen || sidebarContentLoader.animating
            geometryPreviewActive: root.widthPreview >= 0 || root.heightPreview >= 0
            onPluginViewActiveChanged: root.pluginViewActive = pluginViewActive
        }
    }

    Component {
        id: defaultSystemContentComponent

        SidebarRightContent {
            screenWidth: sidebarRoot.screen?.width ?? 1920
            screenHeight: sidebarRoot.screen?.height ?? 1080
            panelScreen: sidebarRoot.screen ?? null
            panelVisible: root.presentationOpen || sidebarContentLoader.animating
            geometryPreviewActive: root.widthPreview >= 0 || root.heightPreview >= 0
        }
    }

    Component {
        id: compactSystemContentComponent

        CompactSidebarRightContent {
            screenWidth: sidebarRoot.screen?.width ?? 1920
            screenHeight: sidebarRoot.screen?.height ?? 1080
            panelScreen: sidebarRoot.screen ?? null
            panelVisible: root.presentationOpen || sidebarContentLoader.animating
            geometryPreviewActive: root.widthPreview >= 0 || root.heightPreview >= 0
        }
    }

    Component {
        id: systemContentComponent

        Item {
            id: systemContentStack
            readonly property bool isCompact:
                (Config.options?.sidebar?.layout ?? "default") === "compact"
            readonly property var activeContentItem: isCompact
                ? compactSystemLoader.item : defaultSystemLoader.item
            readonly property real preferredContentHeight:
                activeContentItem?.preferredContentHeight ?? -1
            readonly property real minimumUsefulHeight:
                activeContentItem?.minimumUsefulHeight ?? 320
            readonly property real minimumUsefulWidth:
                activeContentItem?.minimumUsefulWidth ?? 320
            readonly property real maximumUsefulWidth:
                activeContentItem?.maximumUsefulWidth ?? 900
            readonly property bool contentFitActive:
                activeContentItem?.notifsCollapsed ?? false
            readonly property bool bottomCollapsed:
                activeContentItem?.bottomGroupCollapsed ?? false

            FadeLoader {
                id: defaultSystemLoader
                anchors.fill: parent
                shown: !systemContentStack.isCompact
                scale: systemContentStack.isCompact ? 0.96 : 1
                transformOrigin: Item.Center
                Behavior on scale {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation {
                        duration: Appearance.animation.elementResize.duration
                        easing.type: Appearance.animation.elementResize.type
                        easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
                    }
                }
                sourceComponent: defaultSystemContentComponent
            }

            FadeLoader {
                id: compactSystemLoader
                anchors.fill: parent
                shown: systemContentStack.isCompact
                scale: systemContentStack.isCompact ? 1 : 0.96
                transformOrigin: Item.Center
                Behavior on scale {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation {
                        duration: Appearance.animation.elementResize.duration
                        easing.type: Appearance.animation.elementResize.type
                        easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
                    }
                }
                sourceComponent: compactSystemContentComponent
            }
        }
    }

    PanelWindow {
        id: sidebarRoot
        screen: root.screen ?? Quickshell.screens[0]

        Component.onCompleted: {
            root._screenName = sidebarRoot.screen?.name ?? ""
            root._sidebarShown = false
            if (root.presentationOpen)
                root.syncPresentation()
            else
                renderSuspendTimer.restart()
            Qt.callLater(root.reportRuntime)
        }

        onVisibleChanged: Qt.callLater(root.reportRuntime)
        onScreenChanged: root._screenName = sidebarRoot.screen?.name ?? ""

        Connections {
            target: GlobalStates

            function onSidebarLeftOpenChanged(): void {
                if (!root.featureRole)
                    return
                Qt.callLater(() => {
                    root.syncPresentation()
                    root.reportRuntime()
                })
            }

            function onSidebarRightOpenChanged(): void {
                if (!root.systemRole)
                    return
                Qt.callLater(() => {
                    root.syncPresentation()
                    root.reportRuntime()
                })
            }

            function onScreenLockedChanged(): void {
                if (GlobalStates.screenLocked) {
                    root.scheduleResumeRearm()
                } else if (root._resumeRearmPending) {
                    resumeRemapTimer.restart()
                }
            }
        }

        Connections {
            target: ShellEditSession

            function onActiveChanged(): void {
                Qt.callLater(() => {
                    root.syncPresentation()
                    root.reportRuntime()
                })
            }

            function onGestureKindChanged(): void {
                if (ShellEditSession.gestureKind.length > 0)
                    return
                root.widthPreview = -1
                root.heightPreview = -1
                root.resizeBaselineWidth = -1
                root.resizeBaselineHeight = -1
            }
        }

        function hide(): void {
            root.setRoleOpen(false)
        }

        exclusiveZone: 0
        implicitWidth: Math.ceil(root.effectiveSidebarWidth)
        WlrLayershell.namespace: root.isLeftEdge
            ? "quickshell:sidebarLeft" : "quickshell:sidebarRight"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: ShellEditSession.active
            || !root.roleOpen || root.roleHoldOpen
            ? WlrKeyboardFocus.None
            : root.otherRoleOpen ? WlrKeyboardFocus.OnDemand
            : WlrKeyboardFocus.Exclusive
        color: "transparent"
        // A closed transparent Overlay surface still prevents direct scanout.
        // Keep it mapped for normal warm opens, but release it while fullscreen
        // owns this output. Manual GameMode only disables expensive rendering;
        // explicit opens and their exit animation remain usable.
        visible: root._nativeHostMapped && !GlobalStates.screenLocked
            && (!root.fullscreenCovered || root.presentationOpen
                || sidebarContentLoader.animating)
        updatesEnabled: sidebarRoot.visible && root._renderUpdatesNeeded

        anchors {
            top: true
            bottom: true
            left: root.isLeftEdge
            right: !root.isLeftEdge
        }

        Region {
            id: sidebarInputRegion
            item: sidebarContentLoader
        }

        Item {
            id: emptySidebarInputArea
            width: 0
            height: 0
        }

        Region {
            id: emptySidebarInputRegion
            item: emptySidebarInputArea
        }

        Item {
            id: sidebarEdgeOpenArea
            x: root.isLeftEdge ? 0 : sidebarRoot.width - width
            y: 0
            width: root.edgeOpenWidth
            height: sidebarRoot.height

            HoverHandler {
                enabled: root.edgeOpenEnabled && !root.roleOpen
                onHoveredChanged: {
                    if (!hovered || !enabled)
                        return
                    root.edgeRevealTransient = true
                    root.setRoleOpen(true)
                    edgeRevealCloseTimer.restart()
                }
            }
        }

        Region {
            id: sidebarEdgeOpenRegion
            item: sidebarEdgeOpenArea
        }

        Timer {
            id: edgeRevealCloseTimer
            interval: 240
            repeat: false
            onTriggered: {
                if (!root.edgeRevealTransient)
                    return
                if (GlobalStates.activeContextMenuCount > 0) {
                    edgeRevealCloseTimer.restart()
                    return
                }
                if (!sidebarPanelHover.hovered)
                    root.setRoleOpen(false)
            }
        }

        Item {
            id: sidebarPanelHoverArea
            anchors.fill: parent
        }

        HoverHandler {
            id: sidebarPanelHover
            target: sidebarPanelHoverArea
            enabled: root.edgeRevealTransient && root.roleOpen
            onHoveredChanged: {
                if (hovered)
                    edgeRevealCloseTimer.stop()
                else if (enabled)
                    edgeRevealCloseTimer.restart()
            }
        }

        Item {
            id: sidebarEditInputArea
            x: sidebarContentLoader.x - (root.isLeftEdge ? 0 : 10)
            y: sidebarContentLoader.y - 10
            width: sidebarContentLoader.width + 10
            height: sidebarContentLoader.height + 10
        }

        Region {
            id: sidebarEditInputRegion
            item: sidebarEditInputArea
        }

        mask: ShellEditSession.active
            ? sidebarEditInputRegion
            : !root.roleOpen
                ? (root.edgeOpenEnabled ? sidebarEdgeOpenRegion : emptySidebarInputRegion)
            : root.roleHoldOpen || root.otherRoleOpen
                ? sidebarInputRegion : null

        CompositorFocusGrab {
            windows: [sidebarRoot]
            active: !ShellEditSession.active && CompositorService.isHyprland
                && sidebarRoot.visible && !root.roleHoldOpen && !root.otherRoleOpen
            onCleared: () => {
                if (!active && !root.roleHoldOpen)
                    sidebarRoot.hide()
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: !ShellEditSession.active && root.roleOpen
                && !root.roleHoldOpen && !root.otherRoleOpen
            onClicked: mouse => {
                const localPos = mapToItem(sidebarContentLoader, mouse.x, mouse.y)
                if (localPos.x < 0 || localPos.x > sidebarContentLoader.width
                        || localPos.y < 0 || localPos.y > sidebarContentLoader.height)
                    sidebarRoot.hide()
            }
        }

        Loader {
            id: sidebarContentLoader

            property bool _everMounted: false
            property real animTranslateX: root.isLeftEdge
                ? -(root.effectiveSidebarWidth + Appearance.sizes.hyprlandGapsOut)
                : root.effectiveSidebarWidth + Appearance.sizes.hyprlandGapsOut
            property real animOpacity: 1
            property real animScale: 1
            property bool useClip: root.animationType === "reveal"
            property real clipWidth: Math.max(0, width)
            property real animTranslateY: 0
            property real animScaleX: 1
            property bool animating: false
            onAnimatingChanged: root.reportRuntime()

            active: root._contentResident
            width: Math.max(0, root.effectiveSidebarWidth
                - Appearance.sizes.hyprlandGapsOut
                - Appearance.sizes.elevationMargin)
            height: root.effectiveContentHeight
            onStatusChanged: {
                if (height > 0 && status === Loader.Ready)
                    _everMounted = true
                if (status === Loader.Error) {
                    console.warn("[SidebarHost] Failed to load role", root.roleId,
                        "on", root.edge)
                    ShellEditSession.reportSurfaceFailure(root.roleId,
                        "Sidebar content is temporarily unavailable")
                }
                root.tryPresent()
                Qt.callLater(root.reportRuntime)
            }
            onActiveChanged: Qt.callLater(root.reportRuntime)
            onWidthChanged: Qt.callLater(root.reportRuntime)
            onHeightChanged: {
                root.tryPresent()
                Qt.callLater(root.reportRuntime)
            }

            layer.enabled: Appearance.shouldDesaturate("sidebars")
                && (root.presentationOpen || sidebarContentLoader.animating)
            layer.effect: ShellDesaturationEffect {}

            anchors {
                bottom: parent.bottom
                left: root.isLeftEdge ? parent.left : undefined
                right: root.isLeftEdge ? undefined : parent.right
                bottomMargin: Appearance.sizes.hyprlandGapsOut
                rightMargin: root.isLeftEdge
                    ? Appearance.sizes.elevationMargin
                    : Appearance.sizes.hyprlandGapsOut
                leftMargin: root.isLeftEdge
                    ? Appearance.sizes.hyprlandGapsOut
                    : Appearance.sizes.elevationMargin
            }

            Behavior on height {
                enabled: Appearance.animationsEnabled && sidebarRoot.visible
                    && root.widthPreview < 0 && root.heightPreview < 0
                NumberAnimation {
                    duration: Appearance.animation.elementResize.duration
                    easing.type: Appearance.animation.elementResize.type
                    easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
                }
            }

            Behavior on width {
                enabled: Appearance.animationsEnabled && !root._pluginTransitioning
                    && root.widthPreview < 0 && root.heightPreview < 0
                NumberAnimation {
                    duration: Appearance.calcEffectiveDuration(250)
                    easing.type: Easing.OutCubic
                }
            }

            transform: [
                Translate {
                    x: sidebarContentLoader.animTranslateX
                    y: sidebarContentLoader.animTranslateY
                },
                Scale {
                    xScale: sidebarContentLoader.animScaleX
                    origin.x: root.isLeftEdge ? 0 : sidebarContentLoader.width
                    origin.y: sidebarContentLoader.height / 2
                }
            ]
            opacity: sidebarContentLoader.animOpacity
            scale: sidebarContentLoader.animScale

            states: [
                State {
                    name: "editor"
                    when: root.editorPresentation
                    PropertyChanges {
                        target: sidebarContentLoader
                        animTranslateX: 0
                        animOpacity: 1
                        animScale: 1
                        animTranslateY: 0
                        animScaleX: 1
                        clipWidth: sidebarContentLoader.width
                    }
                },
                State {
                    name: "open"
                    when: root.roleOpen && root._sidebarShown
                    PropertyChanges {
                        target: sidebarContentLoader
                        animTranslateX: 0
                        animOpacity: 1
                        animScale: 1
                        animTranslateY: 0
                        animScaleX: 1
                        clipWidth: sidebarContentLoader.width
                    }
                },
                State {
                    name: "closed"
                    when: !root.editorPresentation
                        && (!root.roleOpen || !root._sidebarShown)
                    PropertyChanges {
                        target: sidebarContentLoader
                        animTranslateX:
                            root.animationType === "slide"
                            ? (root.isLeftEdge
                                ? -(root.effectiveSidebarWidth + Appearance.sizes.hyprlandGapsOut)
                                : root.effectiveSidebarWidth + Appearance.sizes.hyprlandGapsOut)
                            : 0
                        animOpacity:
                            root.animationType === "slide" || root.animationType === "reveal"
                            ? 1 : 0
                        animScale:
                            root.animationType === "elastic" ? 0.88
                            : root.animationType === "pop" ? 0.94 : 1
                        animTranslateY:
                            root.animationType === "drop"
                            ? -(sidebarContentLoader.height
                                + Appearance.sizes.hyprlandGapsOut * 2)
                            : 0
                        animScaleX: root.animationType === "swing" ? 0 : 1
                        clipWidth: root.animationType === "reveal"
                            ? 0 : sidebarContentLoader.width
                    }
                }
            ]

            transitions: [
                Transition {
                    to: "open"
                    enabled: Appearance.animationsEnabled
                        && !root._pluginTransitioning && !root.instantOpen
                    ParallelAnimation {
                        NumberAnimation {
                            target: sidebarContentLoader
                            property: "animTranslateX"
                            duration: Appearance.animation?.elementMoveEnter?.duration ?? 400
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves?.emphasizedDecel
                                ?? [0.05, 0.7, 0.1, 1, 1, 1]
                        }
                        NumberAnimation {
                            target: sidebarContentLoader
                            property: "animTranslateY"
                            duration: Appearance.animation?.elementMoveEnter?.duration ?? 400
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves?.emphasizedDecel
                                ?? [0.05, 0.7, 0.1, 1, 1, 1]
                        }
                        NumberAnimation {
                            target: sidebarContentLoader
                            property: "animOpacity"
                            duration: Math.round(
                                (Appearance.animation?.elementMoveEnter?.duration ?? 400) * 0.7)
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves?.standardDecel
                                ?? [0, 0, 0, 1, 1, 1]
                        }
                        SequentialAnimation {
                            NumberAnimation {
                                target: sidebarContentLoader
                                property: "animScale"
                                from: root.animationType === "elastic" ? 0.88
                                    : root.animationType === "pop" ? 0.94 : 1
                                to: root.animationType === "elastic" ? 1.04
                                    : root.animationType === "pop" ? 1.018 : 1
                                duration: Math.round(
                                    (Appearance.animation?.elementMoveEnter?.duration ?? 400) * 0.62)
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Appearance.animationCurves?.emphasizedDecel
                                    ?? [0.05, 0.7, 0.1, 1, 1, 1]
                            }
                            NumberAnimation {
                                target: sidebarContentLoader
                                property: "animScale"
                                to: 1
                                duration: Math.round(
                                    (Appearance.animation?.elementMoveEnter?.duration ?? 400) * 0.38)
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Appearance.animationCurves?.expressiveEffects
                                    ?? [0.34, 0.80, 0.34, 1.00, 1, 1]
                            }
                        }
                        NumberAnimation {
                            target: sidebarContentLoader
                            property: "animScaleX"
                            duration: Appearance.animation?.elementMoveEnter?.duration ?? 400
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves?.emphasizedDecel
                                ?? [0.05, 0.7, 0.1, 1, 1, 1]
                        }
                        NumberAnimation {
                            target: sidebarContentLoader
                            property: "clipWidth"
                            duration: Appearance.animation?.elementMoveEnter?.duration ?? 400
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves?.emphasizedDecel
                                ?? [0.05, 0.7, 0.1, 1, 1, 1]
                        }
                    }
                    onRunningChanged: sidebarContentLoader.animating = running
                },
                Transition {
                    to: "closed"
                    enabled: Appearance.animationsEnabled
                        && !root._pluginTransitioning && !root.instantOpen
                    ParallelAnimation {
                        NumberAnimation {
                            target: sidebarContentLoader
                            property: "animTranslateX"
                            duration: Appearance.animation?.elementMoveExit?.duration ?? 200
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves?.emphasizedAccel
                                ?? [0.3, 0, 0.8, 0.15, 1, 1]
                        }
                        NumberAnimation {
                            target: sidebarContentLoader
                            property: "animTranslateY"
                            duration: Appearance.animation?.elementMoveExit?.duration ?? 200
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves?.emphasizedAccel
                                ?? [0.3, 0, 0.8, 0.15, 1, 1]
                        }
                        NumberAnimation {
                            target: sidebarContentLoader
                            property: "animOpacity"
                            duration: Math.round(
                                (Appearance.animation?.elementMoveExit?.duration ?? 200) * 0.7)
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves?.standardAccel
                                ?? [0.3, 0, 1, 1, 1, 1]
                        }
                        NumberAnimation {
                            target: sidebarContentLoader
                            property: "animScale"
                            duration: Appearance.animation?.elementMoveExit?.duration ?? 200
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves?.emphasizedAccel
                                ?? [0.3, 0, 0.8, 0.15, 1, 1]
                        }
                        NumberAnimation {
                            target: sidebarContentLoader
                            property: "animScaleX"
                            duration: Appearance.animation?.elementMoveExit?.duration ?? 200
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves?.emphasizedAccel
                                ?? [0.3, 0, 0.8, 0.15, 1, 1]
                        }
                        NumberAnimation {
                            target: sidebarContentLoader
                            property: "clipWidth"
                            duration: Appearance.animation?.elementMoveExit?.duration ?? 200
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves?.emphasizedAccel
                                ?? [0.3, 0, 0.8, 0.15, 1, 1]
                        }
                    }
                    onRunningChanged: sidebarContentLoader.animating = running
                }
            ]

            focus: root.roleOpen && !ShellEditSession.active
            Keys.onPressed: event => {
                if (event.key !== Qt.Key_Escape)
                    return
                if (ShellEditSession.active) {
                    ShellEditSession.handleEscape()
                } else {
                    const roleItem = sidebarContentLoader.item?.roleContentItem
                    const handledByContent = roleItem && typeof roleItem.handleEscape === "function"
                        ? roleItem.handleEscape() : false
                    if (!handledByContent) sidebarRoot.hide()
                }
                event.accepted = true
            }

            sourceComponent: Item {
                id: contentHost

                readonly property var roleContentItem: roleContentLoader.item
                readonly property real preferredContentHeight:
                    roleContentItem?.preferredContentHeight ?? -1
                readonly property real minimumUsefulHeight:
                    roleContentItem?.minimumUsefulHeight ?? 320
                readonly property real minimumUsefulWidth:
                    roleContentItem?.minimumUsefulWidth ?? 320
                readonly property real maximumUsefulWidth:
                    roleContentItem?.maximumUsefulWidth ?? 900
                readonly property bool contentFitActive:
                    roleContentItem?.fitToContent
                        ?? roleContentItem?.contentFitActive ?? false
                readonly property bool bottomCollapsed:
                    roleContentItem?.bottomCollapsed ?? false

                Item {
                    id: revealViewport
                    anchors {
                        top: parent.top
                        bottom: parent.bottom
                        left: root.isLeftEdge ? parent.left : undefined
                        right: root.isLeftEdge ? undefined : parent.right
                    }
                    width: sidebarContentLoader.useClip
                        ? sidebarContentLoader.clipWidth : parent.width
                    clip: sidebarContentLoader.useClip

                    Loader {
                        id: roleContentLoader
                        width: contentHost.width
                        height: contentHost.height
                        x: root.isLeftEdge ? 0 : revealViewport.width - width
                        sourceComponent: root.featureRole
                            ? featureContentComponent : systemContentComponent
                    }
                }
            }
        }

        ShellEditSurfaceFrame {
            anchors.fill: sidebarContentLoader
            surfaceId: root.roleId
            label: root.featureRole
                ? Translation.tr("Feature sidebar")
                : Translation.tr("System sidebar")
            active: root.roleId.length > 0
                && ShellEditSession.blocksNormalActions(surfaceId)
            selected: ShellEditSession.selectedSurfaceId === surfaceId
            lifted: ShellEditSession.liftedSurfaceId === surfaceId
            screenWidth: sidebarRoot.screen?.width ?? 0
            screenHeight: sidebarRoot.screen?.height ?? 0
            onDragStarted: surface => ShellEditSession.beginDrag(surface)
            onDragMoved: (surface, screenX, screenY) =>
                ShellEditSession.updateDrag(screenX, screenY)
            onDragEnded: () => ShellEditSession.endDrag()
            onDragCanceled: () => ShellEditSession.cancelDrag()
            accentColor: Appearance.colors.colPrimary
            surfaceColor: Appearance.colors.colLayer2
            textColor: Appearance.colors.colOnLayer2
            frameRadius: Appearance.rounding.large
            fontFamily: Appearance.font.family.main
            fontPixelSize: Appearance.font.pixelSize.smaller
            animationDuration: Appearance.animationsEnabled
                ? Appearance.animation.elementMoveFast.duration : 0
            onActivated: selectedId => ShellEditSession.selectSurface(selectedId)
        }

        ShellEditResizeHandle {
            z: 11000
            width: 96
            height: 20
            anchors {
                top: sidebarContentLoader.top
                horizontalCenter: sidebarContentLoader.horizontalCenter
                topMargin: -10
            }
            axis: "vertical"
            active: ShellEditSession.active
                && ShellEditSession.selectedSurfaceId === root.roleId
                && ShellEditSession.liftedSurfaceId.length === 0
            accentColor: Appearance.colors.colPrimary
            surfaceColor: Appearance.colors.colLayer2
            animationsEnabled: Appearance.animationsEnabled
            radius: Appearance.rounding.full
            onDragStarted: root.beginResize("resize-height")
            onDragged: (axis, deltaX, deltaY) =>
                root.updateResize("resize-height", deltaX, deltaY)
            onDragFinished: root.finishResize("resize-height")
            onDragCanceled: root.cancelResize()
        }

        ShellEditResizeHandle {
            z: 11000
            width: 20
            height: 96
            anchors {
                verticalCenter: sidebarContentLoader.verticalCenter
                left: root.isLeftEdge ? undefined : sidebarContentLoader.left
                right: root.isLeftEdge ? sidebarContentLoader.right : undefined
                leftMargin: root.isLeftEdge ? 0 : -10
                rightMargin: root.isLeftEdge ? -10 : 0
            }
            axis: "horizontal"
            active: ShellEditSession.active
                && ShellEditSession.selectedSurfaceId === root.roleId
                && ShellEditSession.liftedSurfaceId.length === 0
            accentColor: Appearance.colors.colPrimary
            surfaceColor: Appearance.colors.colLayer2
            animationsEnabled: Appearance.animationsEnabled
            radius: Appearance.rounding.full
            onDragStarted: root.beginResize("resize-width")
            onDragged: (axis, deltaX, deltaY) =>
                root.updateResize("resize-width", deltaX, deltaY)
            onDragFinished: root.finishResize("resize-width")
            onDragCanceled: root.cancelResize()
        }

        ShellEditSizeBadge {
            z: 12000
            anchors.centerIn: sidebarContentLoader
            active: root.widthPreview >= 0 || root.heightPreview >= 0
            valueText: Math.round(sidebarContentLoader.width) + " × "
                + Math.round(sidebarContentLoader.height)
            accentColor: Appearance.colors.colPrimary
            surfaceColor: Appearance.colors.colLayer2
            textColor: Appearance.colors.colOnLayer2
            fontFamily: Appearance.font.family.main
            fontPixelSize: Appearance.font.pixelSize.smaller
        }
    }
}
