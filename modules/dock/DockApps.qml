import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland

Item {
    id: root
    property real maxWindowPreviewHeight: 200
    property real maxWindowPreviewWidth: 300
    property real windowControlsHeight: 30
    property real buttonPadding: 5
    property bool vertical: false
    property string dockPosition: "bottom"

    property Item lastHoveredButton
    property bool buttonHovered: false
    property bool contextMenuOpen: false
    property bool requestDockShow: previewPopup.show || contextMenuOpen
    
    // Signal to close any open context menu before opening a new one
    signal closeAllContextMenus()

    Layout.fillHeight: !vertical
    Layout.fillWidth: vertical
    implicitWidth: listView.contentWidth
    implicitHeight: listView.contentHeight
    
    property var dockItems: []
    
    // Cache compiled regexes - only recompile when config changes
    property var _cachedIgnoredRegexes: []
    property var _lastIgnoredRegexStrings: []
    
    function _getIgnoredRegexes(): list<var> {
        const ignoredRegexStrings = Config.options?.dock?.ignoredAppRegexes ?? [];
        // Check if we need to recompile
        if (JSON.stringify(ignoredRegexStrings) !== JSON.stringify(_lastIgnoredRegexStrings)) {
            const systemIgnored = ["^$", "^portal$", "^x-run-dialog$", "^kdialog$", "^org.freedesktop.impl.portal.*"];
            const allIgnored = ignoredRegexStrings.concat(systemIgnored);
            _cachedIgnoredRegexes = allIgnored.map(pattern => new RegExp(pattern, "i"));
            _lastIgnoredRegexStrings = ignoredRegexStrings.slice();
        }
        return _cachedIgnoredRegexes;
    }
    
    function rebuildDockItems() {
        const pinnedApps = Config.options?.dock?.pinnedApps ?? [];
        const ignoredRegexes = _getIgnoredRegexes();
        const separatePinnedFromRunning = Config.options?.dock?.separatePinnedFromRunning ?? true;

        // Get all open windows
        const allToplevels = CompositorService.sortedToplevels && CompositorService.sortedToplevels.length
                ? CompositorService.sortedToplevels
                : ToplevelManager.toplevels.values;
        
        // Build map of running apps (apps with open windows)
        const runningAppsMap = new Map();
        for (const toplevel of allToplevels) {
            if (!toplevel.appId) continue;
            if (toplevel.appId === "" || toplevel.appId === "null") continue;

            if (ignoredRegexes.some(re => re.test(toplevel.appId))) {
                continue;
            }

            const lowerAppId = toplevel.appId.toLowerCase();
            if (!runningAppsMap.has(lowerAppId)) {
                runningAppsMap.set(lowerAppId, {
                    appId: toplevel.appId,
                    toplevels: [],
                    pinned: false
                });
            }
            runningAppsMap.get(lowerAppId).toplevels.push(toplevel);
        }

        const values = [];
        let order = 0;
        
        // If separation is disabled, use legacy behavior: combine pinned with their running windows
        if (!separatePinnedFromRunning) {
            // Add all pinned apps (with or without windows)
            for (const appId of pinnedApps) {
                const lowerAppId = appId.toLowerCase();
                const runningEntry = runningAppsMap.get(lowerAppId);
                values.push({
                    uniqueId: "app-" + lowerAppId,
                    appId: lowerAppId,
                    toplevels: runningEntry?.toplevels ?? [],
                    pinned: true,
                    originalAppId: appId,
                    section: "pinned",
                    order: order++
                });
                // Remove from running map so we don't add it again
                runningAppsMap.delete(lowerAppId);
            }
            
            // Add separator if there are both pinned and unpinned running apps
            if (values.length > 0 && runningAppsMap.size > 0) {
                values.push({
                    uniqueId: "separator",
                    appId: "SEPARATOR",
                    toplevels: [],
                    pinned: false,
                    originalAppId: "SEPARATOR",
                    section: "separator",
                    order: order++
                });
            }
            
            // Add unpinned running apps
            for (const [lowerAppId, entry] of runningAppsMap) {
                values.push({
                    uniqueId: "app-" + lowerAppId,
                    appId: lowerAppId,
                    toplevels: entry.toplevels,
                    pinned: false,
                    originalAppId: entry.appId,
                    section: "open",
                    order: order++
                });
            }
        } else {
            // NEW BEHAVIOR: Separate pinned-only from running apps
            // 1) Add ONLY pinned apps (without running windows) - left section
            for (const appId of pinnedApps) {
                const lowerAppId = appId.toLowerCase();
                // Only show pinned apps that don't have running windows
                if (!runningAppsMap.has(lowerAppId)) {
                    values.push({
                        uniqueId: "app-" + lowerAppId,
                        appId: lowerAppId,
                        toplevels: [],
                        pinned: true,
                        originalAppId: appId,
                        section: "pinned",
                        order: order++
                    });
                }
            }
            
            // 2) Add separator if there are both pinned-only apps and running apps
            const hasPinnedOnly = values.length > 0;
            const hasRunning = runningAppsMap.size > 0;
            
            if (hasPinnedOnly && hasRunning) {
                values.push({
                    uniqueId: "separator",
                    appId: "SEPARATOR",
                    toplevels: [],
                    pinned: false,
                    originalAppId: "SEPARATOR",
                    section: "separator",
                    order: order++
                });
            }
            
            // 3) Add running apps (right section) - includes pinned apps that are also running
            const sortedRunningApps = [];
            for (const [lowerAppId, entry] of runningAppsMap) {
                sortedRunningApps.push({
                    lowerAppId: lowerAppId,
                    entry: entry
                });
            }
            // Sort to keep consistency: pinned+running apps first (by pinned order), then unpinned
            sortedRunningApps.sort((a, b) => {
                const aIndex = pinnedApps.findIndex(p => p.toLowerCase() === a.lowerAppId);
                const bIndex = pinnedApps.findIndex(p => p.toLowerCase() === b.lowerAppId);
                
                const aIsPinned = aIndex !== -1;
                const bIsPinned = bIndex !== -1;
                
                // Pinned apps first (in their pinned order)
                if (aIsPinned && bIsPinned) return aIndex - bIndex;
                if (aIsPinned) return -1;
                if (bIsPinned) return 1;
                
                // Unpinned apps maintain their order
                return 0;
            });
            
            for (const {lowerAppId, entry} of sortedRunningApps) {
                values.push({
                    uniqueId: "app-" + lowerAppId,
                    appId: lowerAppId,
                    toplevels: entry.toplevels,
                    pinned: pinnedApps.some(p => p.toLowerCase() === lowerAppId),
                    originalAppId: entry.appId,
                    section: "running",
                    order: order++
                });
            }
        }

        dockItems = values
    }
    
    Connections {
        target: ToplevelManager.toplevels
        function onValuesChanged() {
            root.rebuildDockItems()
        }
    }
    
    Connections {
        target: CompositorService
        function onSortedToplevelsChanged() {
            root.rebuildDockItems()
        }
    }
    
    Connections {
        target: Config.options?.dock
        function onPinnedAppsChanged() {
            root.rebuildDockItems()
        }
        function onIgnoredAppRegexesChanged() {
            root.rebuildDockItems()
        }
        function onSeparatePinnedFromRunningChanged() {
            root.rebuildDockItems()
        }
    }
    
    Component.onCompleted: rebuildDockItems()
    
    StyledListView {
        id: listView
        spacing: 2
        orientation: root.vertical ? ListView.Vertical : ListView.Horizontal
        anchors {
            top: root.vertical ? undefined : parent.top
            bottom: root.vertical ? undefined : parent.bottom
            left: root.vertical ? parent.left : undefined
            right: root.vertical ? parent.right : undefined
        }
        implicitWidth: contentWidth
        implicitHeight: contentHeight

        Behavior on implicitWidth {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
        Behavior on implicitHeight {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }

        model: ScriptModel {
            objectProp: "uniqueId"
            values: root.dockItems
        }
        
        delegate: DockAppButton {
            required property var modelData
            appToplevel: modelData
            appListRoot: root
            vertical: root.vertical
            dockPosition: root.dockPosition
            
            anchors.verticalCenter: !root.vertical ? parent?.verticalCenter : undefined
            anchors.horizontalCenter: root.vertical ? parent?.horizontalCenter : undefined

            // Sin insets - el tamaño viene del DockButton
            topInset: 0
            bottomInset: 0
            leftInset: 0
            rightInset: 0
        }
    }

    PopupWindow {
        id: previewPopup
        property var appTopLevel: root.lastHoveredButton?.appToplevel
        property bool allPreviewsReady: false
        Connections {
            target: root
            function onLastHoveredButtonChanged() {
                previewPopup.allPreviewsReady = false; // Reset readiness when the hovered button changes
            } 
        }
        function updatePreviewReadiness() {
            for(var i = 0; i < previewRowLayout.children.length; i++) {
                const view = previewRowLayout.children[i];
                if (view.hasContent === false) {
                    allPreviewsReady = false;
                    return;
                }
            }
            allPreviewsReady = true;
        }
        property bool shouldShow: {
            const hoverConditions = (popupMouseArea.containsMouse || root.buttonHovered)
            return hoverConditions && allPreviewsReady;
        }
        property bool show: false

        onShouldShowChanged: {
            if (shouldShow) {
                // show = true;
                updateTimer.restart();
            } else {
                updateTimer.restart();
            }
        }
        Timer {
            id: updateTimer
            interval: 100
            onTriggered: {
                previewPopup.show = previewPopup.shouldShow
            }
        }
        anchor {
            window: root.QsWindow.window
            adjustment: PopupAdjustment.None
            gravity: Edges.Top | Edges.Right
            edges: Edges.Top | Edges.Left

        }
        visible: popupBackground.visible
        color: "transparent"
        implicitWidth: root.QsWindow.window?.width ?? 1
        implicitHeight: popupMouseArea.implicitHeight + root.windowControlsHeight + Appearance.sizes.elevationMargin * 2

        MouseArea {
            id: popupMouseArea
            anchors.bottom: parent.bottom
            implicitWidth: popupBackground.implicitWidth + Appearance.sizes.elevationMargin * 2
            implicitHeight: root.maxWindowPreviewHeight + root.windowControlsHeight + Appearance.sizes.elevationMargin * 2
            hoverEnabled: true
            x: {
                if (root.QsWindow && root.lastHoveredButton && root.lastHoveredButton.width > 0) {
                    const itemCenter = root.QsWindow.mapFromItem(root.lastHoveredButton, root.lastHoveredButton.width / 2, 0);
                    return itemCenter.x - width / 2;
                }
                return 0;
            }
            StyledRectangularShadow {
                target: popupBackground
                opacity: previewPopup.show ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
            }
            Rectangle {
                id: popupBackground
                property real padding: 5
                opacity: previewPopup.show ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
                clip: true
                color: Appearance.auroraEverywhere ? Appearance.aurora.colPopupSurface : Appearance.colors.colSurfaceContainer
                radius: Appearance.rounding.normal
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Appearance.sizes.elevationMargin
                anchors.horizontalCenter: parent.horizontalCenter
                implicitHeight: previewRowLayout.implicitHeight + padding * 2
                implicitWidth: previewRowLayout.implicitWidth + padding * 2
                Behavior on implicitWidth {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
                Behavior on implicitHeight {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }

                RowLayout {
                    id: previewRowLayout
                    anchors.centerIn: parent
                    Repeater {
                        model: ScriptModel {
                            values: previewPopup.appTopLevel?.toplevels ?? []
                        }
                        RippleButton {
                            id: windowButton
                            required property var modelData
                            padding: 0
                            middleClickAction: () => {
                                windowButton.modelData?.close();
                            }
                            onClicked: {
                                if (CompositorService.isNiri) {
                                    if (windowButton.modelData?.niriWindowId) {
                                        NiriService.focusWindow(windowButton.modelData.niriWindowId)
                                    } else if (windowButton.modelData?.activate) {
                                        windowButton.modelData.activate()
                                    }
                                } else {
                                    windowButton.modelData?.activate();
                                }
                            }
                            contentItem: ColumnLayout {
                                implicitWidth: screencopyView.implicitWidth
                                implicitHeight: screencopyView.implicitHeight

                                ButtonGroup {
                                    contentWidth: parent.width - anchors.margins * 2
                                    WrapperRectangle {
                                        Layout.fillWidth: true
                                        color: Appearance.auroraEverywhere ? "transparent" : ColorUtils.transparentize(Appearance.colors.colSurfaceContainer)
                                        radius: Appearance.rounding.small
                                        margin: 5
                                        StyledText {
                                            Layout.fillWidth: true
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            text: windowButton.modelData?.title
                                            elide: Text.ElideRight
                                            color: Appearance.m3colors.m3onSurface
                                        }
                                    }
                                    GroupButton {
                                        id: closeButton
                                        colBackground: Appearance.auroraEverywhere ? "transparent" : ColorUtils.transparentize(Appearance.colors.colSurfaceContainer)
                                        baseWidth: windowControlsHeight
                                        baseHeight: windowControlsHeight
                                        buttonRadius: Appearance.rounding.full
                                        contentItem: MaterialSymbol {
                                            anchors.centerIn: parent
                                            horizontalAlignment: Text.AlignHCenter
                                            text: "close"
                                            iconSize: Appearance.font.pixelSize.normal
                                            color: Appearance.m3colors.m3onSurface
                                        }
                                        onClicked: {
                                            windowButton.modelData?.close();
                                        }
                                    }
                                }
                                ScreencopyView {
                                    id: screencopyView
                                    // Evitar warnings cuando el compositor no soporta screencopy (ej. Niri)
                                    captureSource: (CompositorService.isHyprland && previewPopup.show)
                                                  ? windowButton.modelData
                                                  : null
                                    live: true
                                    paintCursor: true
                                    constraintSize: Qt.size(root.maxWindowPreviewWidth, root.maxWindowPreviewHeight)
                                    onHasContentChanged: {
                                        previewPopup.updatePreviewReadiness();
                                    }
                                    layer.enabled: true
                                    layer.effect: OpacityMask {
                                        maskSource: Rectangle {
                                            width: screencopyView.width
                                            height: screencopyView.height
                                            radius: Appearance.rounding.small
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
