import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

DockButton {
    id: root
    property var appToplevel
    property var appListRoot
    property int listIndex: -1       // set by the DockApps delegate (required property int index)
    property int lastFocused: -1
    property real iconSize: Config.options?.dock?.iconSize ?? 35
    property real countDotWidth: 10
    property real countDotHeight: 4
    readonly property var toplevels: appToplevel?.toplevels ?? []
    property bool appIsActive: toplevels.find(t => (t.activated == true)) !== undefined
    property bool hasWindows: toplevels.length > 0
    property bool pillStyle:  Config.options?.dock?.style === "pill"
    property bool macosStyle: Config.options?.dock?.style === "macos"

    // Hover preview signals
    signal hoverPreviewRequested()
    signal hoverPreviewDismissed()

    // Timer for hover delay before showing preview
    property alias hoverTimer: hoverDelayTimer
    Timer {
        id: hoverDelayTimer
        interval: Config.options?.dock?.hoverPreviewDelay ?? 400
        onTriggered: {
            if (root.hasWindows && root.buttonHovered) {
                root.hoverPreviewRequested()
            }
        }
    }

    // Determine focused window index for smart indicator (Niri only)
    // Returns the index (0-based) of the focused window sorted by column position
    property int focusedWindowIndex: {
        if (!root.appIsActive || toplevels.length <= 1)
            return 0;

        // Find the focused toplevel
        const focusedToplevel = toplevels.find(t => t.activated === true);
        if (!focusedToplevel)
            return 0;

        // For Niri: use column position to determine order
        if (CompositorService.isNiri && focusedToplevel.niriWindowId) {
            const niriWindows = NiriService.windows;

            // Build array of {toplevelIdx, column} for sorting
            const windowPositions = [];
            for (let i = 0; i < toplevels.length; i++) {
                const tl = toplevels[i];
                let col = 999999;
                if (tl.niriWindowId) {
                    const niriWin = niriWindows.find(w => w.id === tl.niriWindowId);
                    if (niriWin && niriWin.layout && niriWin.layout.pos_in_scrolling_layout) {
                        col = niriWin.layout.pos_in_scrolling_layout[0];
                    }
                }
                windowPositions.push({ idx: i, col: col, activated: tl.activated });
            }

            // Sort by column
            windowPositions.sort((a, b) => a.col - b.col);

            // Find the focused one's position in sorted array
            for (let i = 0; i < windowPositions.length; i++) {
                if (windowPositions[i].activated) return i;
            }
        }

        // Fallback: find by activated flag in original order
        for (let i = 0; i < toplevels.length; i++) {
            if (toplevels[i].activated) return i;
        }
        return 0;
    }

    // Subtle highlight for active app (disabled in macOS and pill modes —
    // macOS uses magnify, pill uses its own background highlight)
    scale: (!macosStyle && !pillStyle && appIsActive) ? 1.05 : 1.0
    Behavior on scale {
        enabled: Appearance.animationsEnabled
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }

    property bool isSeparator: appToplevel.appId === "SEPARATOR"
    // Use originalAppId (preserves case) for desktop entry lookup, fallback to appId for backwards compat
    property var desktopEntry: DesktopEntries.heuristicLookup(appToplevel.originalAppId ?? appToplevel.appId)
    enabled: !isSeparator

    readonly property real dockHeight: Config.options?.dock?.height ?? 70
    readonly property real separatorSize: dockHeight - 50

    implicitWidth: isSeparator ? (vertical ? separatorSize : 8) : (vertical ? 50 : (implicitHeight - topInset - bottomInset))
    implicitHeight: isSeparator ? (vertical ? 8 : separatorSize) : 50

    // In pill mode, hide the default RippleButton hover background — DockPillItem provides its own.
    // In macOS mode, also hide it — DockMacItem provides visual feedback via magnify.
    background.visible: !isSeparator && !pillStyle && !macosStyle

    // Suppress ripple/hover bg in macOS mode so no colored rect appears under icon
    colBackgroundHover: macosStyle ? "transparent" : (Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.inirEverywhere ? Appearance.inir.colLayer1Hover
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
        : Appearance.colors.colLayer0Hover)
    colRipple: macosStyle ? "transparent" : (Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
        : Appearance.inirEverywhere ? Appearance.inir.colLayer1Active
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive
        : Appearance.colors.colLayer0Active)

    // Pill background (replaces shared panel for this item)
    DockPillItem {
        id: pillBackground
        anchors.fill: parent
        visible: pillStyle && !isSeparator && !Appearance.gameModeMinimal
        appIsActive: root.appIsActive
        hasWindows: root.hasWindows
        windowCount: toplevels.length
        focusedWindowIndex: root.focusedWindowIndex
        vertical: root.vertical
        countDotWidth: root.countDotWidth
        countDotHeight: root.countDotHeight
    }

    // macOS-style icon wrapper: magnify effect + multi-window indicator dots
    DockMacItem {
        id: macItem
        anchors.fill: parent
        visible: macosStyle && !isSeparator && !Appearance.gameModeMinimal
        appIsActive: root.appIsActive
        hasWindows: root.hasWindows
        buttonHovered: root.buttonHovered
        previewVisible: root.appListRoot?.previewAnchorItem === root
        vertical: root.vertical
        neighborDistance: {
            const hi = root.appListRoot?.macHoveredIndex ?? -1
            return (hi < 0 || root.listIndex < 0) ? 99 : Math.abs(root.listIndex - hi)
        }
        windowCount: toplevels.length
        focusedWindowIndex: root.focusedWindowIndex
    }

    // Hover shadow (disabled for angel — whole dock already has escalonado)
    StyledRectangularShadow {
        target: root.pillStyle ? pillBackground : root.background
        visible: !Appearance.angelEverywhere && !root.macosStyle
        opacity: root.buttonHovered && !root.isSeparator ? 0.6 : 0
        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
    }

    Loader {
        active: isSeparator
        anchors.centerIn: parent
        sourceComponent: Rectangle {
            width: root.vertical ? root.separatorSize : 1
            height: root.vertical ? 1 : root.separatorSize
            color: Appearance.inirEverywhere ? Appearance.inir.colBorderSubtle
                 : Appearance.auroraEverywhere ? ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.7)
                 : Appearance.colors.colOutlineVariant
        }
    }

    // Use RippleButton's built-in buttonHovered instead of separate MouseArea
    onButtonHoveredChanged: {
        if (toplevels.length > 0) {
            if (buttonHovered) {
                appListRoot.lastHoveredButton = root
                appListRoot.buttonHovered = true
                // Start hover timer for preview
                if (Config.options?.dock?.hoverPreview !== false) {
                    hoverDelayTimer.restart()
                }
            } else {
                if (appListRoot.lastHoveredButton === root) {
                    appListRoot.buttonHovered = false
                }
                hoverDelayTimer.stop()
                // Don't dismiss preview here - let the popup's timer handle it
                // This allows mouse to move from button to popup without closing
            }
        } else {
            hoverDelayTimer.stop()
        }
    }

    function launchFromDesktopEntry(): bool {
        // Intentar siempre vía gtk-launch y, si falla, ejecutar appId directamente
        var id = appToplevel.originalAppId ?? appToplevel.appId;
        // Caso especial: YouTube Music (pear)
        if (id === "com.github.th_ch.youtube_music") {
            id = "pear-desktop";
        }
        // Caso especial: Spotify launcher
        if (id === "spotify" || id === "spotify-launcher") {
            id = "spotify-launcher";
        }
        if (id && id !== "" && id !== "SEPARATOR") {
            const cmd = "/usr/bin/gtk-launch \"" + id + "\" || \"" + id + "\" &";
            Quickshell.execDetached(["/usr/bin/bash", "-lc", cmd]);
            return true;
        }
        return false;
    }

    onClicked: {
        // Suppress the click that RippleButton fires after a drag-release
        if (appListRoot?._suppressNextClick) {
            appListRoot._suppressNextClick = false
            return
        }
        // macOS click micro-pulse
        if (macosStyle) macItem.clickPulse()
        // Sin ventanas abiertas: lanzar nueva instancia desde desktop entry o fallbacks
        if (toplevels.length === 0) {
            launchFromDesktopEntry();
            return;
        }
        // Con ventanas: rotar foco entre instancias abiertas
        const total = toplevels.length
        lastFocused = (lastFocused + 1) % total
        const toplevel = toplevels[lastFocused]
        if (CompositorService.isNiri) {
            if (toplevel?.niriWindowId) {
                NiriService.focusWindow(toplevel.niriWindowId)
            } else if (toplevel?.activate) {
                toplevel.activate()
            }
        } else {
            toplevel?.activate()
        }
    }

    middleClickAction: () => {
        launchFromDesktopEntry();
    }

    altAction: () => {
        showContextMenu()
    }

    function showContextMenu(): void {
        root.appListRoot.closeAllContextMenus()
        root.appListRoot.contextMenuOpen = true
        root.hoverPreviewDismissed()
        hoverDelayTimer.stop()
        contextMenu.active = true
    }

    Connections {
        target: root.appListRoot
        function onCloseAllContextMenus() {
            contextMenu.close()
        }
    }

    DockContextMenu {
        id: contextMenu
        anchorItem: root
        anchorHovered: root.buttonHovered

        onActiveChanged: {
            if (!active && root.appListRoot) root.appListRoot.contextMenuOpen = false
        }

        model: [
            // Desktop actions (if available)
            ...((root.desktopEntry?.actions?.length > 0) ? root.desktopEntry.actions.map(action => ({
                iconName: action.icon ?? "",
                text: action.name,
                action: () => action.execute()
            })).concat({ type: "separator" }) : []),
            // Launch new instance
            {
                iconName: IconThemeService.smartIconName(root.desktopEntry?.icon ?? "", appToplevel.originalAppId ?? appToplevel.appId),
                text: root.desktopEntry?.name ?? StringUtils.toTitleCase(appToplevel.originalAppId ?? appToplevel.appId),
                monochromeIcon: false,
                action: () => root.launchFromDesktopEntry()
            },
            // Pin/Unpin
            {
                iconName: appToplevel.pinned ? "keep_off" : "keep",
                text: appToplevel.pinned ? Translation.tr("Unpin from dock") : Translation.tr("Pin to dock"),
                monochromeIcon: true,
                action: () => {
                    const appId = appToplevel.originalAppId ?? appToplevel.appId;
                    if (Config.options?.dock?.pinnedApps?.indexOf(appId) !== -1) {
                        Config.setNestedValue("dock.pinnedApps", (Config.options?.dock?.pinnedApps ?? []).filter(id => id !== appId))
                    } else {
                        Config.setNestedValue("dock.pinnedApps", (Config.options?.dock?.pinnedApps ?? []).concat([appId]))
                    }
                }
            },
            // Close window(s) - only if has windows
            ...(root.hasWindows ? [
                { type: "separator" },
                {
                    iconName: "close",
                    text: toplevels.length > 1 ? Translation.tr("Close all windows") : Translation.tr("Close window"),
                    monochromeIcon: true,
                    action: () => {
                        for (let toplevel of toplevels) {
                            toplevel.close()
                        }
                    }
                }
            ] : [])
        ]
    }

      contentItem: Loader {
          active: !isSeparator
          sourceComponent: Item {
              id: contentRoot
              anchors.centerIn: parent

              // macOS magnify: scale around the bottom centre so icons grow upward.
              // Animation is driven by DockMacItem's own Behavior on _magnifyScale —
              // no extra Behavior needed here.
              scale:           root.macosStyle ? macItem.iconScale : 1.0
              transformOrigin: root.vertical ? Item.Right : Item.Bottom

            Loader {
                id: iconImageLoader
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                active: !root.isSeparator
                sourceComponent: IconImage {
                    id: dockIcon
                    property string iconName: {
                        const appId = appToplevel.originalAppId ?? appToplevel.appId;
                        let icon = "";
                        if (appId === "Spotify" || appId === "spotify" || appId === "spotify-launcher") {
                            icon = "spotify";
                        } else {
                            icon = root.desktopEntry?.icon || AppSearch.guessIcon(appId);
                        }
                        return IconThemeService.smartIconName(icon, appId);
                    }
                    property bool isAbsolutePath: iconName.startsWith("/") || iconName.startsWith("file://")
                    property var candidates: isAbsolutePath ? [] : IconThemeService.dockIconCandidates(iconName)

                    // Reactive fallback state — NEVER set `source` imperatively (destroys binding on delegate recycle)
                    property int _candidateIdx: 0
                    property bool _useSystemFallback: false
                    property string _systemFallbackName: ""

                    // Reset fallback state whenever iconName changes (delegate recycled for different app)
                    onIconNameChanged: {
                        _candidateIdx = 0;
                        _useSystemFallback = false;
                        _systemFallbackName = "";
                    }

                    // Pure reactive binding — never broken by imperative assignment
                    source: {
                        if (_useSystemFallback && _systemFallbackName) {
                            return Quickshell.iconPath(_systemFallbackName, "image-missing");
                        }
                        if (isAbsolutePath) {
                            return iconName.startsWith("file://") ? iconName : `file://${iconName}`;
                        }
                        if (candidates.length > 0 && _candidateIdx < candidates.length) {
                            return candidates[_candidateIdx];
                        }
                        return Quickshell.iconPath(iconName, "image-missing");
                    }
                    implicitSize: root.iconSize

                    onStatusChanged: {
                        if (status === Image.Error) {
                            // Defer state changes to break binding loop:
                            // source → status → onStatusChanged → state → source
                            Qt.callLater(() => {
                                if (isAbsolutePath && !_useSystemFallback) {
                                    const path = iconName.startsWith("file://") ? iconName.substring(7) : iconName;
                                    const fileName = path.split("/").pop();
                                    let baseName = fileName;
                                    if (baseName.includes(".")) {
                                        baseName = baseName.split(".").slice(0, -1).join(".");
                                    }
                                    _systemFallbackName = baseName;
                                    _useSystemFallback = true;
                                    return;
                                }
                                if (candidates.length > 0 && _candidateIdx < candidates.length - 1) {
                                    _candidateIdx++;
                                } else if (!_useSystemFallback) {
                                    _systemFallbackName = iconName;
                                    _useSystemFallback = true;
                                }
                            });
                        }
                    }
                }
            }

            Loader {
                active: Config.options?.dock?.monochromeIcons ?? false
                anchors.fill: iconImageLoader
                sourceComponent: Item {
                    Desaturate {
                        id: desaturatedIcon
                        visible: false // There's already color overlay
                        anchors.fill: parent
                        source: iconImageLoader
                        desaturation: 0.8
                    }
                    ColorOverlay {
                        anchors.fill: desaturatedIcon
                        source: desaturatedIcon
                        color: ColorUtils.transparentize(Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary, 0.9)
                    }
                }
            }

              // Smart indicator: shows window count and which is focused
              // Hidden in macOS and pill modes — those render their own indicators
              Loader {
                  active: root.hasWindows && !root.isSeparator && !root.macosStyle && !root.pillStyle
                anchors {
                    top: iconImageLoader.bottom
                    topMargin: 2
                    horizontalCenter: parent.horizontalCenter
                }

                // Config options
                property bool smartIndicator: Config.options?.dock?.smartIndicator !== false
                property bool showAllDots: Config.options?.dock?.showAllWindowDots !== false
                property int maxDots: Config.options?.dock?.maxIndicatorDots ?? 5

                sourceComponent: Row {
                    spacing: 3

                    Repeater {
                        // Show dots for all windows if enabled, otherwise just for active apps
                        model: {
                            const showAll = Config.options?.dock?.showAllWindowDots !== false;
                            const max = Config.options?.dock?.maxIndicatorDots ?? 5;
                            if (root.appIsActive || showAll) {
                                return Math.min(toplevels.length, max);
                            }
                            return 0;
                        }

                        delegate: Rectangle {
                            required property int index

                            property bool smartMode: Config.options?.dock?.smartIndicator !== false

                            // Determine if this indicator corresponds to the focused window
                            property bool isFocusedWindow: {
                                if (!root.appIsActive) return false;
                                if (!smartMode) return true; // All indicators same when smart mode off
                                if (toplevels.length <= 1) return true;
                                return index === root.focusedWindowIndex;
                            }

                            radius: Appearance.angelEverywhere ? 0 : Appearance.rounding.full
                            implicitWidth: Appearance.angelEverywhere
                                ? (isFocusedWindow ? 14 : 6)
                                : (isFocusedWindow ? root.countDotWidth : root.countDotHeight)
                            implicitHeight: Appearance.angelEverywhere ? 2 : root.countDotHeight
                            color: isFocusedWindow
                                   ? (Appearance.angelEverywhere ? Appearance.angel.colPrimary
                                   : Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary)
                                   : ColorUtils.transparentize(Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
                                   : Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer0, 0.5)

                            Behavior on implicitWidth {
                                NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                            }
                        }
                    }

                    // Fallback: single indicator when showAllDots is off and app is inactive
                    Rectangle {
                        visible: !root.appIsActive && root.hasWindows && Config.options?.dock?.showAllWindowDots === false
                        width: Appearance.angelEverywhere ? 6 : 5
                        height: Appearance.angelEverywhere ? 2 : 5
                        radius: Appearance.angelEverywhere ? 0 : 2.5
                        color: ColorUtils.transparentize(Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
                            : Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer0, 0.5)
                    }
                }
            }
        }
    }
}
