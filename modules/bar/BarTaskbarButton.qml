pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// Compact app button for bar-embedded taskbar.
// Supports horizontal and vertical orientations.
RippleButton {
    id: root

    property var appEntry
    property var taskbarRoot
    property real iconSize: 24
    property bool vertical: false
    // "top", "bottom", "left", "right"
    property string barPosition: "top"

    readonly property var toplevels: appEntry?.toplevels ?? []
    readonly property var activeToplevel: ToplevelManager.activeToplevel
    readonly property string activeWindowKey: {
        const active = activeToplevel
        if (!active) return ""
        if (active.niriWindowId !== undefined && active.niriWindowId !== null)
            return "niri:" + active.niriWindowId
        if (active.address !== undefined && active.address !== null && String(active.address).length > 0)
            return "addr:" + active.address
        if (active.wayland?.appId !== undefined && active.wayland?.appId !== null && active.activated)
            return "app:" + active.wayland.appId + ":" + (active.title ?? "")
        return ""
    }

    function _toplevelKey(toplevel: var): string {
        if (!toplevel) return ""
        if (toplevel.niriWindowId !== undefined && toplevel.niriWindowId !== null)
            return "niri:" + toplevel.niriWindowId
        if (toplevel.address !== undefined && toplevel.address !== null && String(toplevel.address).length > 0)
            return "addr:" + toplevel.address
        if (toplevel.wayland?.appId !== undefined && toplevel.wayland?.appId !== null)
            return "app:" + toplevel.wayland.appId + ":" + (toplevel.title ?? "")
        return ""
    }

    property bool appIsActive: {
        const active = activeToplevel
        if (!active || !active.activated) return false
        const activeKey = activeWindowKey
        for (let i = 0; i < toplevels.length; i++) {
            const toplevel = toplevels[i]
            if (!toplevel) continue
            if (toplevel.activated) return true
            if (activeKey.length > 0 && _toplevelKey(toplevel) === activeKey) return true
        }
        return false
    }
    property bool hasWindows: toplevels.length > 0
    property bool isSeparator: appEntry?.appId === "SEPARATOR"
    property var desktopEntry: isSeparator ? null : AppSearch.lookupDesktopEntry(appEntry?.originalAppId ?? appEntry?.appId ?? "")
    property int lastFocused: -1

    // Focused window index for smart indicator
    property int focusedWindowIndex: {
        if (!appIsActive || toplevels.length <= 1) return 0
        const active = activeToplevel
        if (!active) return 0
        const activeKey = activeWindowKey
        for (let i = 0; i < toplevels.length; i++) {
            const toplevel = toplevels[i]
            if (!toplevel) continue
            if (toplevel.activated) return i
            if (activeKey.length > 0 && _toplevelKey(toplevel) === activeKey) return i
        }
        return 0
    }

    // ─── Layout sizing ──────────────────────────────────────────────
    readonly property real barSize: vertical ? Appearance.sizes.baseVerticalBarWidth : Appearance.sizes.baseBarHeight
    readonly property real buttonSize: barSize - 4

    enabled: !isSeparator
    Layout.fillHeight: !vertical
    Layout.fillWidth: vertical

    implicitWidth: vertical
        ? (isSeparator ? buttonSize : buttonSize)
        : (isSeparator ? 10 : buttonSize)
    implicitHeight: vertical
        ? (isSeparator ? 10 : buttonSize)
        : (isSeparator ? buttonSize : buttonSize)

    topInset: 2
    bottomInset: 2
    leftInset: 2
    rightInset: 2

    buttonRadius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
        : Appearance.inirEverywhere ? Appearance.inir.roundingSmall
        : Appearance.rounding.small

    colBackground: "transparent"
    colBackgroundHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.inirEverywhere ? Appearance.inir.colLayer1Hover
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
        : Appearance.colors.colLayer1Hover
    colRipple: Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
        : Appearance.inirEverywhere ? Appearance.inir.colLayer1Active
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive
        : Appearance.colors.colLayer1Active

    // Active app gets a subtle background tint
    colBackgroundToggled: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
        : Appearance.colors.colSecondaryContainer
    colBackgroundToggledHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive
        : Appearance.colors.colSecondaryContainerHover
    colRippleToggled: Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive
        : Appearance.colors.colSecondaryContainerActive

    toggled: appIsActive

    // Hover preview
    Timer {
        id: hoverDelayTimer
        interval: Config.options?.dock?.hoverPreviewDelay ?? 400
        onTriggered: {
            if (root.hasWindows && root.buttonHovered) {
                root.taskbarRoot?.showPreviewPopup(root.appEntry, root)
            }
        }
    }

    onButtonHoveredChanged: {
        if (toplevels.length > 0) {
            if (buttonHovered) {
                taskbarRoot.lastHoveredButton = root
                taskbarRoot.buttonHovered = true
                if (Config.options?.dock?.hoverPreview !== false) {
                    hoverDelayTimer.restart()
                }
            } else {
                if (taskbarRoot.lastHoveredButton === root) {
                    taskbarRoot.buttonHovered = false
                }
                hoverDelayTimer.stop()
            }
        } else {
            hoverDelayTimer.stop()
        }
    }

    function launchFromDesktopEntry(): bool {
        var id = appEntry?.originalAppId ?? appEntry?.appId ?? "";
        if (id === "com.github.th_ch.youtube_music") id = "pear-desktop";
        if (id === "spotify" || id === "spotify-launcher") id = "spotify-launcher";
        if (id && id !== "" && id !== "SEPARATOR") {
            const cmd = "/usr/bin/gtk-launch \"" + id + "\" || \"" + id + "\" &";
            Quickshell.execDetached(["/usr/bin/bash", "-lc", cmd]);
            return true;
        }
        return false;
    }

    onClicked: {
        if (toplevels.length === 0) {
            launchFromDesktopEntry();
            return;
        }
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
        root.launchFromDesktopEntry()
    }

    altAction: () => {
        root.showContextMenu()
    }

    function showContextMenu(): void {
        taskbarRoot.closeAllContextMenus()
        taskbarRoot.contextMenuOpen = true
        hoverDelayTimer.stop()
        contextMenu.active = true
    }

    Connections {
        target: root.taskbarRoot
        function onCloseAllContextMenus() {
            contextMenu.close()
        }
    }

    // Context menu direction depends on bar position
    ContextMenu {
        id: contextMenu
        anchorItem: root
        anchorHovered: root.buttonHovered
        // Horizontal bar: top → popup below, bottom → popup above
        popupAbove: root.barPosition === "bottom"
        // Vertical bar: left → popup right, right → popup left
        popupSide: root.vertical
            ? (root.barPosition === "right" ? Edges.Left : Edges.Right)
            : 0

        onActiveChanged: {
            if (!active && root.taskbarRoot) root.taskbarRoot.contextMenuOpen = false
        }

        model: [
            // Desktop actions
            ...((root.desktopEntry?.actions?.length > 0) ? root.desktopEntry.actions.map(action => ({
                iconName: action.icon ?? "",
                text: action.name,
                action: () => action.execute()
            })).concat({ type: "separator" }) : []),
            // Launch
            {
                iconName: IconThemeService.smartIconName(root.desktopEntry?.icon ?? "", appEntry?.originalAppId ?? appEntry?.appId ?? ""),
                text: root.desktopEntry?.name ?? StringUtils.toTitleCase(appEntry?.originalAppId ?? appEntry?.appId ?? ""),
                monochromeIcon: false,
                action: () => root.launchFromDesktopEntry()
            },
            // Pin/Unpin
            {
                iconName: appEntry?.pinned ? "keep_off" : "keep",
                text: appEntry?.pinned ? Translation.tr("Unpin from dock") : Translation.tr("Pin to dock"),
                monochromeIcon: true,
                action: () => {
                    const appId = appEntry?.originalAppId ?? appEntry?.appId ?? "";
                    if (Config.options?.dock?.pinnedApps?.indexOf(appId) !== -1) {
                        Config.setNestedValue("dock.pinnedApps", (Config.options?.dock?.pinnedApps ?? []).filter(id => id !== appId))
                    } else {
                        Config.setNestedValue("dock.pinnedApps", (Config.options?.dock?.pinnedApps ?? []).concat([appId]))
                    }
                }
            },
            // Close
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

    // ─── Visual content ─────────────────────────────────────────────
    contentItem: Loader {
        active: !root.isSeparator
        sourceComponent: Item {
            id: contentRoot
            anchors.fill: parent

            // Icon
            Loader {
                id: iconLoader
                anchors.centerIn: parent
                active: !root.isSeparator
                sourceComponent: IconImage {
                    id: taskbarIcon
                    property string iconName: {
                        const appId = root.appEntry?.originalAppId ?? root.appEntry?.appId ?? "";
                        let icon = "";
                        if (appId.toLowerCase() === "spotify" || appId === "spotify-launcher") {
                            icon = "spotify";
                        } else {
                            icon = root.desktopEntry?.icon || AppSearch.guessIcon(appId);
                        }
                        return IconThemeService.smartIconName(icon, appId);
                    }
                    property bool isAbsolutePath: iconName.startsWith("/") || iconName.startsWith("file://")
                    property var candidates: isAbsolutePath ? [] : IconThemeService.dockIconCandidates(iconName)

                    property int _candidateIdx: 0
                    property bool _useSystemFallback: false
                    property string _systemFallbackName: ""

                    onIconNameChanged: {
                        _candidateIdx = 0;
                        _useSystemFallback = false;
                        _systemFallbackName = "";
                    }

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
                            Qt.callLater(() => {
                                if (isAbsolutePath && !_useSystemFallback) {
                                    const path = iconName.startsWith("file://") ? iconName.substring(7) : iconName;
                                    const fileName = path.split("/").pop();
                                    let baseName = fileName;
                                    if (baseName.includes(".")) baseName = baseName.split(".").slice(0, -1).join(".");
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

            // Monochrome overlay
            Loader {
                active: Config.options?.dock?.monochromeIcons ?? false
                anchors.fill: iconLoader
                sourceComponent: Item {
                    Desaturate {
                        id: desat
                        visible: false
                        anchors.fill: parent
                        source: iconLoader
                        desaturation: 0.8
                    }
                    ColorOverlay {
                        anchors.fill: desat
                        source: desat
                        color: ColorUtils.transparentize(
                            Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary, 0.9)
                    }
                }
            }

            // Window indicator dots — overlaid at edge, doesn't shift icon
            Loader {
                active: root.hasWindows && !root.isSeparator

                // Horizontal bar: dots at bottom center
                anchors.bottom: !root.vertical ? parent.bottom : undefined
                anchors.bottomMargin: !root.vertical ? 2 : 0
                anchors.horizontalCenter: !root.vertical ? parent.horizontalCenter : undefined
                // Vertical bar: dots at right center
                anchors.right: root.vertical ? parent.right : undefined
                anchors.rightMargin: root.vertical ? 2 : 0
                anchors.verticalCenter: root.vertical ? parent.verticalCenter : undefined

                sourceComponent: Grid {
                    // Horizontal: row of dots. Vertical: column of dots.
                    columns: root.vertical ? 1 : -1
                    rows: root.vertical ? -1 : 1
                    spacing: 2

                    Repeater {
                        model: {
                            const showAll = Config.options?.dock?.showAllWindowDots !== false;
                            const max = Config.options?.dock?.maxIndicatorDots ?? 5;
                            if (root.appIsActive || showAll) {
                                return Math.min(root.toplevels.length, max);
                            }
                            return 0;
                        }

                        delegate: Rectangle {
                            required property int index
                            property bool isFocused: {
                                if (!root.appIsActive) return false;
                                if (root.toplevels.length <= 1) return true;
                                return index === root.focusedWindowIndex;
                            }

                            radius: Appearance.angelEverywhere ? 0 : Appearance.rounding.full
                            // Horizontal: wider when focused. Vertical: taller when focused.
                            implicitWidth: root.vertical ? 2 : (isFocused ? 8 : 3)
                            implicitHeight: root.vertical ? (isFocused ? 8 : 3) : 2
                            color: isFocused
                                ? (Appearance.angelEverywhere ? Appearance.angel.colPrimary
                                : Appearance.inirEverywhere ? Appearance.inir.colPrimary
                                : Appearance.colors.colPrimary)
                                : ColorUtils.transparentize(
                                    Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
                                    : Appearance.inirEverywhere ? Appearance.inir.colText
                                    : Appearance.colors.colOnLayer0, 0.5)

                            Behavior on implicitWidth {
                                NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                            }
                            Behavior on implicitHeight {
                                NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                            }
                        }
                    }

                    // Fallback single dot
                    Rectangle {
                        visible: !root.appIsActive && root.hasWindows && Config.options?.dock?.showAllWindowDots === false
                        width: root.vertical ? 2 : 3
                        height: root.vertical ? 3 : 2
                        radius: 1
                        color: ColorUtils.transparentize(
                            Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
                            : Appearance.inirEverywhere ? Appearance.inir.colText
                            : Appearance.colors.colOnLayer0, 0.5)
                    }
                }
            }
        }
    }

    // Separator visual — adapts to orientation
    Loader {
        active: root.isSeparator
        anchors.centerIn: parent
        sourceComponent: Rectangle {
            width: root.vertical ? (root.barSize / 2.5) : 1
            height: root.vertical ? 1 : (root.barSize / 2.5)
            color: Appearance.inirEverywhere ? Appearance.inir.colBorderSubtle
                 : Appearance.auroraEverywhere ? ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.7)
                 : Appearance.colors.colOutlineVariant
        }
    }
}
