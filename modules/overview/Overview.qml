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
            screen: modelData

            Component.onCompleted: visible = GlobalStates.overviewOpen

            Connections {
                target: GlobalStates
                function onOverviewOpenChanged() {
                    if (GlobalStates.overviewOpen) {
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
            // En Niri necesitamos foco explícito para que el buscador reciba input
            WlrLayershell.keyboardFocus: GlobalStates.overviewOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
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
                    const ov = Config.options.overview
                    const v = (ov && ov.scrimDim !== undefined) ? ov.scrimDim : 35
                    const clamped = Math.max(0, Math.min(100, v))
                    const a = clamped / 100
                    return ColorUtils.transparentize(Appearance.m3colors.m3background, 1 - a)
                }
                opacity: GlobalStates.overviewOpen ? 1 : 0
                visible: opacity > 0.001

                Behavior on opacity {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
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
                const ov = Config.options.overview;
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
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    top: parent.top
                    bottom: parent.bottom
                    topMargin: {
                        const ov = Config?.options?.overview;
                        const base = (ov && ov.topMargin !== undefined) ? ov.topMargin : 0;
                        const respectBar = ov && ov.respectBar !== undefined ? ov.respectBar : true;
                        if (respectBar && !Config.options.bar.bottom) {
                            const barH = Appearance.sizes.barHeight + Appearance.rounding.screenRounding;
                            return barH + base;
                        }
                        return base;
                    }
                    bottomMargin: {
                        const ov = Config?.options?.overview;
                        const base = (ov && ov.bottomMargin !== undefined) ? ov.bottomMargin : 0;
                        const respectBar = ov && ov.respectBar !== undefined ? ov.respectBar : true;
                        let margin = base;
                        
                        // Respect bar at bottom
                        if (respectBar && Config.options.bar.bottom) {
                            const barH = Appearance.sizes.barHeight + Appearance.rounding.screenRounding;
                            margin += barH;
                        }
                        
                        // Respect dock at bottom (if enabled)
                        const dock = Config.options?.dock;
                        if (dock?.enable && dock?.position === "bottom") {
                            const dockH = (dock.height ?? 60) + 16; // dock height + margin
                            margin += dockH;
                        }
                        
                        return margin;
                    }
                }
                spacing: -8

                Behavior on scale {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
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
                    onSearchingTextChanged: if (searchingText !== root.searchingText) root.searchingText = searchingText
                }

                Loader {
                    id: overviewLoader
                    anchors.horizontalCenter: parent.horizontalCenter
                    active: GlobalStates.overviewOpen && (Config?.options.overview.enable ?? true)
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
                    visible: (root.searchingText == "") && (Config.options?.overview?.dashboard?.enable ?? true)
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

    function toggleClipboard() {
        if (GlobalStates.overviewOpen && overviewScope.dontAutoCancelSearch) {
            GlobalStates.overviewOpen = false;
            return;
        }
        const focusedName = getFocusedMonitorName()
        for (let i = 0; i < overviewVariants.instances.length; i++) {
            let panelWindow = overviewVariants.instances[i];
            if (panelWindow.modelData.name == focusedName) {
                overviewScope.dontAutoCancelSearch = true;
                panelWindow.setSearchingText(Config.options.search.prefix.clipboard);
                GlobalStates.overviewOpen = true;
                return;
            }
        }
    }

    function toggleEmojis() {
        if (GlobalStates.overviewOpen && overviewScope.dontAutoCancelSearch) {
            GlobalStates.overviewOpen = false;
            return;
        }
        const focusedName = getFocusedMonitorName()
        for (let i = 0; i < overviewVariants.instances.length; i++) {
            let panelWindow = overviewVariants.instances[i];
            if (panelWindow.modelData.name == focusedName) {
                overviewScope.dontAutoCancelSearch = true;
                panelWindow.setSearchingText(Config.options.search.prefix.emojis);
                GlobalStates.overviewOpen = true;
                return;
            }
        }
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
    }
}
