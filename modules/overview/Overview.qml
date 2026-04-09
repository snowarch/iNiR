import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: overviewScope
    property bool dontAutoCancelSearch: false

    Component.onCompleted: CompositorService.setSortingConsumer("overview", GlobalStates.overviewOpen)
    Variants {
        id: overviewVariants
        model: Quickshell.screens
        PanelWindow {
            id: root
            required property var modelData
            property string searchingText: ""
            readonly property HyprlandMonitor monitor: CompositorService.isHyprland ? Hyprland.monitorFor(root.screen) : null
            property bool monitorIsFocused: CompositorService.isHyprland 
                ? (Hyprland.focusedMonitor?.id == monitor?.id)
                : (NiriService.currentOutput === root.screen?.name)
            readonly property bool activeScreenOnly: Config.options?.overview?.activeScreenOnly ?? false
            readonly property bool shouldShow: GlobalStates.overviewOpen && (!activeScreenOnly || monitorIsFocused)
            screen: modelData

            Component.onCompleted: visible = root.shouldShow

            Connections {
                target: root
                function onShouldShowChanged() {
                    if (root.shouldShow) {
                        _overviewCloseTimer.stop()
                        root.visible = true
                    } else {
                        _overviewCloseTimer.restart()
                    }
                }
            }

            Timer {
                id: _overviewCloseTimer
                interval: 250
                onTriggered: root.visible = false
            }

            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.namespace: "quickshell:overview"
            WlrLayershell.layer: WlrLayer.Overlay
            // Keyboard focus only on the monitor that should show
            WlrLayershell.keyboardFocus: root.shouldShow ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            color: "transparent"

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            // Scrim de fondo: oscurece todo detrás del overview mientras está activo
            Rectangle {
                anchors.fill: parent
                z: -1
                color: {
                    const ov = Config.options?.overview ?? null
                    const v = (ov && ov.scrimDim !== undefined) ? ov.scrimDim : 35
                    const clamped = Math.max(0, Math.min(100, v))
                    const a = clamped / 100
                    return ColorUtils.transparentize(Appearance.colors.colLayer0Base, 1 - a)
                }
                opacity: GlobalStates.overviewOpen ? 1 : 0
                visible: opacity > 0.001

                Behavior on opacity {
                    animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }
            }

            MouseArea {
                id: backdropClickArea
                anchors.fill: parent
                onClicked: mouse => {
                    // Cierra solo si el click es fuera del contenido visible
                    // Check against searchWidget and overviewLoader, not columnLayout
                    // because columnLayout fills the whole window height
                    const searchPos = mapToItem(searchWidget, mouse.x, mouse.y)
                    const inSearch = searchPos.x >= 0 && searchPos.x <= searchWidget.width &&
                                     searchPos.y >= 0 && searchPos.y <= searchWidget.height
                    
                    const overviewPos = overviewLoader.item ? mapToItem(overviewLoader.item, mouse.x, mouse.y) : null
                    const inOverview = overviewLoader.item && overviewPos &&
                                       overviewPos.x >= 0 && overviewPos.x <= overviewLoader.item.width &&
                                       overviewPos.y >= 0 && overviewPos.y <= overviewLoader.item.height

                    const dashPos = dashboardPanel.visible ? mapToItem(dashboardPanel, mouse.x, mouse.y) : null
                    const inDashboard = dashboardPanel.visible && dashPos &&
                                        dashPos.x >= 0 && dashPos.x <= dashboardPanel.width &&
                                        dashPos.y >= 0 && dashPos.y <= dashboardPanel.height
                    
                    if (!inSearch && !inOverview && !inDashboard) {
                        GlobalStates.overviewOpen = false
                    }
                }
            }

            // Focus grab for Hyprland (doesn't work on Niri)
            CompositorFocusGrab {
                id: grab
                windows: [root]
                property bool canBeActive: root.monitorIsFocused
                active: false
                onCleared: () => {
                    if (!active)
                        GlobalStates.overviewOpen = false;
                }
            }
            
            // For Niri: detect window focus changes to close overview (if configured)
            Connections {
                target: CompositorService.isNiri ? NiriService : null
                enabled: CompositorService.isNiri
                function onActiveWindowChanged() {
                    // Respect keepOverviewOpenOnWindowClick setting
                    const keepOpen = Config.options?.overview?.keepOverviewOpenOnWindowClick ?? true;
                    // If a window gets focus while overview is open, close it only if not configured to keep open
                    if (GlobalStates.overviewOpen && NiriService.activeWindow && !keepOpen) {
                        GlobalStates.overviewOpen = false;
                    }
                }
            }

            Connections {
                target: GlobalStates
                function onOverviewOpenChanged() {
                    CompositorService.setSortingConsumer("overview", GlobalStates.overviewOpen)
                    if (!GlobalStates.overviewOpen) {
                        // Al cerrar, limpiar completamente la búsqueda
                        searchWidget.cancelSearch();
                        searchWidget.disableExpandAnimation();
                        overviewScope.dontAutoCancelSearch = false;
                    } else {
                        if (!overviewScope.dontAutoCancelSearch) {
                            searchWidget.cancelSearch();
                        }
                        // Al abrir, garantizar foco en el campo de búsqueda
                        Qt.callLater(() => searchWidget.focusSearchInput());
                        root.maybeSwitchWorkspaceOnOpen();
                        delayedGrabTimer.start();
                    }
                }
            }

            Timer {
                id: delayedGrabTimer
                interval: Config.options.hacks.arbitraryRaceConditionDelay
                repeat: false
                onTriggered: {
                    if (!grab.canBeActive)
                        return;
                    grab.active = GlobalStates.overviewOpen;
                }
            }

            implicitWidth: columnLayout.implicitWidth
            implicitHeight: columnLayout.implicitHeight

            function setSearchingText(text) {
                searchWidget.setSearchingText(text);
                searchWidget.focusFirstItem();
            }

            function maybeSwitchWorkspaceOnOpen() {
                const ov = Config.options?.overview ?? null;
                if (!ov || !ov.switchToWorkspaceOnOpen || !ov.switchWorkspaceIndex || ov.switchWorkspaceIndex <= 0)
                    return;

                if (CompositorService.isNiri) {
                    const screenName = root.modelData && root.modelData.name;
                    if (!screenName || screenName !== NiriService.currentOutput)
                        return;
                    const targetIdx = ov.switchWorkspaceIndex;
                    if (!targetIdx || targetIdx <= 0)
                        return;
                    NiriService.switchToWorkspace(targetIdx);
                } else if (CompositorService.isHyprland) {
                    if (!root.monitorIsFocused)
                        return;
                    const wsNumber = ov.switchWorkspaceIndex;
                    Hyprland.dispatch(`workspace ${wsNumber}`);
                }
            }

            Column {
                id: columnLayout
                visible: GlobalStates.overviewOpen
                transformOrigin: Item.Top
                scale: GlobalStates.overviewOpen ? 1.0 : 0.97
                
                // Always center the overview vertically - this is the default behavior.
                // Never use verticalCenter anchor with dynamic Column - causes blur and erratic positioning.
                // Use top anchor with calculated topMargin to center instead.
                
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    top: parent.top
                    topMargin: {
                        const ov = Config?.options?.overview;
                        const respectBar = ov && ov.respectBar !== undefined ? ov.respectBar : true;
                        
                        // Calculate bar/dock offset at top
                        let barOffset = 0;
                        if (respectBar && !(Config.options?.bar?.bottom ?? false)) {
                            barOffset = Appearance.sizes.barHeight + Appearance.rounding.screenRounding;
                        }
                        const dock = Config.options?.dock;
                        if (dock?.enable && dock?.position === "top") {
                            barOffset += (dock.height ?? 60) + 20;
                        }
                        
                        // Calculate bar/dock offset at bottom
                        let bottomOffset = 8;
                        if (respectBar && (Config.options?.bar?.bottom ?? false)) {
                            bottomOffset += Appearance.sizes.barHeight + Appearance.rounding.screenRounding;
                        }
                        if (dock?.enable && dock?.position === "bottom") {
                            bottomOffset += (dock.height ?? 60) + 20;
                        }
                        
                        // Center the content vertically in available space
                        const availableHeight = root.height - barOffset - bottomOffset;
                        const contentHeight = columnLayout.implicitHeight;
                        // Round to avoid subpixel positioning that causes blur
                        const centeredMargin = barOffset + Math.round(Math.max(0, (availableHeight - contentHeight) / 2));
                        return centeredMargin;
                    }
                }
                spacing: -8

                Behavior on scale {
                    animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        GlobalStates.overviewOpen = false;
                    } else if (event.key === Qt.Key_Left) {
                        if (!root.searchingText) {
                            if (CompositorService.isNiri) {
                                // Niri uses a 1-based idx for workspaces on the monitor.
                                const currentIdx = NiriService.getCurrentWorkspaceNumber();
                                const targetIdx = currentIdx - 1;
                                if (targetIdx >= 1)
                                    NiriService.switchToWorkspace(targetIdx);
                            } else {
                                Hyprland.dispatch("workspace r-1");
                            }
                        }
                    } else if (event.key === Qt.Key_Right) {
                        if (!root.searchingText) {
                            if (CompositorService.isNiri) {
                                const currentIdx = NiriService.getCurrentWorkspaceNumber();
                                const targetIdx = currentIdx + 1;
                                NiriService.switchToWorkspace(targetIdx);
                            } else {
                                Hyprland.dispatch("workspace r+1");
                            }
                        }
                    }
                }

                SearchWidget {
                    id: searchWidget
                    anchors.horizontalCenter: parent.horizontalCenter
                    searchingText: root.searchingText
                    // Centered mode: limit search results to 60% of screen height
                    availableHeight: Math.max(220, root.height * 0.6)
                    onSearchingTextChanged: if (searchingText !== root.searchingText) root.searchingText = searchingText
                }

                Loader {
                    id: overviewLoader
                    anchors.horizontalCenter: parent.horizontalCenter
                    readonly property bool dashboardMode: Config.options?.overview?.dashboard?.enable ?? false
                    active: GlobalStates.overviewOpen && !dashboardMode && (Config.options?.overview?.enable ?? true)
                    visible: active
                    sourceComponent: CompositorService.isNiri ? niriComponent : hyprComponent
                }

                Component {
                    id: hyprComponent
                    OverviewWidget {
                        panelWindow: root
                        visible: (root.searchingText == "")
                    }
                }

                Component {
                    id: niriComponent
                    OverviewNiriWidget {
                        panelWindow: root
                        visible: (root.searchingText == "")
                    }
                }

                // Dashboard panel below workspace thumbnails
                OverviewDashboard {
                    id: dashboardPanel
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: (root.searchingText == "") && (Config.options?.overview?.dashboard?.enable ?? false)
                    opacity: GlobalStates.overviewOpen ? 1 : 0

                    Behavior on opacity {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation {
                            duration: Appearance.animation?.elementMoveEnter?.duration ?? 400
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves?.emphasizedDecel ?? [0.05, 0.7, 0.1, 1, 1, 1]
                        }
                    }
                }
            }
        }
    }

    function getFocusedMonitorName() {
        if (CompositorService.isNiri) return NiriService.currentOutput
        if (CompositorService.isHyprland && Hyprland.focusedMonitor) return Hyprland.focusedMonitor.name
        return ""
    }

    function openWithPrefix(prefix) {
        const focusedName = getFocusedMonitorName()
        for (let i = 0; i < overviewVariants.instances.length; i++) {
            let panelWindow = overviewVariants.instances[i];
            if (panelWindow.modelData.name == focusedName) {
                overviewScope.dontAutoCancelSearch = true;
                panelWindow.setSearchingText(prefix);
                GlobalStates.overviewOpen = true;
                return true;
            }
        }
        return false;
    }

    function toggleClipboard() {
        if (GlobalStates.overviewOpen && overviewScope.dontAutoCancelSearch) {
            GlobalStates.overviewOpen = false;
            return;
        }
        overviewScope.openWithPrefix(Config.options?.search?.prefix?.clipboard ?? ";");
    }

    function toggleEmojis() {
        if (GlobalStates.overviewOpen && overviewScope.dontAutoCancelSearch) {
            GlobalStates.overviewOpen = false;
            return;
        }
        overviewScope.openWithPrefix(Config.options?.search?.prefix?.emojis ?? ":");
    }

    IpcHandler {
        target: "overview"

        function toggle(): void {
            // In Waffle mode, open Start Menu instead
            if (Config.options?.panelFamily === "waffle") {
                GlobalStates.searchOpen = !GlobalStates.searchOpen;
            } else {
                GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
            }
        }
        function close(): void {
            if (Config.options?.panelFamily === "waffle") {
                GlobalStates.searchOpen = false;
            } else {
                GlobalStates.overviewOpen = false;
            }
        }
        function open(): void {
            if (Config.options?.panelFamily === "waffle") {
                GlobalStates.searchOpen = true;
            } else {
                GlobalStates.overviewOpen = true;
            }
        }
        function toggleReleaseInterrupt(): void {
            GlobalStates.superReleaseMightTrigger = false;
        }
        function clipboardToggle(): void {
            overviewScope.toggleClipboard();
        }
        function actionOpen(): void {
            if (Config.options?.panelFamily === "waffle") {
                LauncherSearch.ensurePrefix(Config.options?.search?.prefix?.action ?? "/")
                GlobalStates.searchOpen = true;
            } else {
                overviewScope.openWithPrefix(Config.options?.search?.prefix?.action ?? "/");
            }
        }
    }
}
