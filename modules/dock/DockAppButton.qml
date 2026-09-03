import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.pill
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import Quickshell.Wayland

DockButton {
    id: root
    property var appToplevel
    property var appListRoot
    property int listIndex: -1       // set by the DockApps delegate (required property int index)
    property int lastFocused: -1
    property real iconSize: Config.options?.dock?.iconSize ?? 35
    property real countDotWidth: 10
    property real countDotHeight: 4
    // Toplevels come from the dock-wide reactive map so window-list
    // updates (focus reorder, new/closed windows of an existing app)
    // refresh without forcing a ScriptModel rebuild and spurious
    // ListView add/remove/move animations. Fallback to modelData for
    // the brief window before the map is populated.
    readonly property var toplevels: (appListRoot?.toplevelsByUniqueId?.[appToplevel?.uniqueId] ?? appToplevel?.toplevels ?? [])
    readonly property var activeToplevel: ToplevelManager.activeToplevel
    readonly property var niriFocusedWindow: CompositorService.isNiri
        ? (NiriService.windows?.find(window => window.is_focused)
            ?? NiriService.activeWindow
            ?? null)
        : null
    readonly property int niriFocusedWindowId:
        Number(root.niriFocusedWindow?.id ?? -1)
    readonly property string activeWindowKey: {
        if (CompositorService.isNiri)
            return root.niriFocusedWindowId >= 0
                ? "niri:" + root.niriFocusedWindowId
                : ""
        const active = activeToplevel
        if (!active)
            return ""
        if (active.niriWindowId !== undefined && active.niriWindowId !== null)
            return "niri:" + active.niriWindowId
        if (active.address !== undefined && active.address !== null && String(active.address).length > 0)
            return "addr:" + active.address
        if (active.wayland?.appId !== undefined && active.wayland?.appId !== null && active.activated)
            return "app:" + active.wayland.appId + ":" + (active.title ?? "")
        return ""
    }
    function _toplevelKey(toplevel) {
        if (!toplevel)
            return ""
        if (toplevel.niriWindowId !== undefined && toplevel.niriWindowId !== null)
            return "niri:" + toplevel.niriWindowId
        if (toplevel.address !== undefined && toplevel.address !== null && String(toplevel.address).length > 0)
            return "addr:" + toplevel.address
        if (toplevel.wayland?.appId !== undefined && toplevel.wayland?.appId !== null)
            return "app:" + toplevel.wayland.appId + ":" + (toplevel.title ?? "")
        return ""
    }
    function _toplevelIsActive(toplevel): bool {
        if (!toplevel)
            return false
        if (CompositorService.isNiri) {
            if (root.niriFocusedWindowId < 0)
                return false
            if (Number(toplevel.niriWindowId ?? -1) === root.niriFocusedWindowId)
                return true
            const focusedAppId = String(root.niriFocusedWindow?.app_id ?? "").toLowerCase()
            const toplevelAppId = String(toplevel.appId ?? "").toLowerCase()
            if (focusedAppId.length === 0 || toplevelAppId !== focusedAppId)
                return false
            if (root.toplevels.length <= 1)
                return true
            return String(toplevel.title ?? "")
                === String(root.niriFocusedWindow?.title ?? "")
        }
        if (toplevel.activated)
            return true
        const activeKey = root.activeWindowKey
        return activeKey.length > 0 && root._toplevelKey(toplevel) === activeKey
    }
    property bool appIsActive: {
        for (let i = 0; i < toplevels.length; i++) {
            if (root._toplevelIsActive(toplevels[i]))
                return true
        }
        return false
    }
    property bool hasWindows: toplevels.length > 0
    surfaceDialect: Appearance.surfaceDialectFor(
        Config.options?.dock?.style === "island" ? "island" : "")
    property bool pillStyle: Config.options?.dock?.style === "pill" && !root.zzzStyle
    property bool islandStyle: root.surfaceDialect === "island"
    property bool macosStyle: Config.options?.dock?.style === "macos" && !root.zzzStyle

    readonly property int notificationCount: {
        if (root.isSeparator || (Config.options?.dock?.notificationBadge ?? true) === false)
            return 0
        return Notifications.countForApp([
            appToplevel?.originalAppId ?? appToplevel?.appId,
            root.desktopEntry?.name
        ])
    }

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

    // Determine focused window index for smart indicator.
    // toplevels is already sorted by layout (thanks to CompositorService.sortedToplevels in DockApps)
    // so we just need to find the active toplevel index.
    property int focusedWindowIndex: {
        if (!root.appIsActive || toplevels.length <= 1)
            return 0;

        for (let i = 0; i < toplevels.length; i++) {
            if (root._toplevelIsActive(toplevels[i]))
                return i
        }
        return 0;
    }

    // Subtle highlight for active app (disabled in macOS and pill modes —
    // macOS uses magnify, pill uses its own background highlight)
    scale: (!macosStyle && !pillStyle && appIsActive)
        ? (root.regaliaStyle ? 1.0 : root.zzzStyle ? 1.02 : 1.05) : 1.0
    Behavior on scale {
        enabled: Appearance.animationsEnabled
        animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }

    transform: Translate {
        y: (root.zzzStyle || root.islandStyle) && !root.macosStyle && !root.pillStyle && root.buttonHovered && !root.vertical ? -3 : 0
        x: (root.zzzStyle || root.islandStyle) && !root.macosStyle && !root.pillStyle && root.buttonHovered && root.vertical ? -3 : 0
        Behavior on y {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
        }
        Behavior on x {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
        }
    }

    property bool isSeparator: appToplevel.appId === "SEPARATOR"
    // Use originalAppId (preserves case) for desktop entry lookup, fallback to appId for backwards compat
    // AppSearch.lookupDesktopEntry adds StartupWMClass, exec-basename, and desktop-id-stem matching
    // which covers AppImages and other apps where heuristicLookup alone fails.
    property var desktopEntry: AppSearch.lookupDesktopEntry(appToplevel.originalAppId ?? appToplevel.appId)
    enabled: !isSeparator

    readonly property var appTrayItem: {
        const appKeys = [
            appToplevel.originalAppId,
            appToplevel.appId,
            root.desktopEntry?.id,
            root.desktopEntry?.startupClass
        ].map(value => root.normalizedAppKey(value)).filter(value => value.length >= 3)

        return SystemTray.items.values.find(item => {
            // SNI id is application identity; title is descriptive/localizable
            // and must not be used to associate an unrelated tray item.
            const trayKeys = [root.normalizedTrayKey(item?.id)]
                .filter(value => value.length >= 3)
            return trayKeys.some(trayKey => appKeys.some(appKey => {
                if (trayKey === appKey)
                    return true
                // Reverse-domain desktop ids often end in the short tray id.
                // Require enough entropy to avoid collisions such as code/vscode.
                return Math.min(trayKey.length, appKey.length) >= 5
                    && (trayKey.endsWith(appKey) || appKey.endsWith(trayKey))
            }))
        }) ?? null
    }

    QsMenuOpener {
        id: appTrayMenuOpener
        menu: root.appTrayItem?.menu ?? null
    }

    readonly property real dockHeight: Config.options?.dock?.height ?? 70
    readonly property real separatorSize: dockHeight - 50

    implicitWidth: isSeparator ? (vertical ? separatorSize : 8) : (vertical ? 50 : (implicitHeight - topInset - bottomInset))
    implicitHeight: isSeparator ? (vertical ? 8 : separatorSize) : 50

    // In pill mode, hide the default RippleButton hover background — DockPillItem provides its own.
    // In macOS mode, also hide it — DockMacItem provides visual feedback via magnify.
    background.visible: !isSeparator && !pillStyle && !macosStyle

    // Suppress ripple/hover bg in macOS mode so no colored rect appears under icon
    // Island mode hovers like a Ricelin row: a faint cream frame fill with a
    // vermilion-tinted press, instead of the global style's hover chain.
    colBackgroundHover: macosStyle ? "transparent" : root.islandStyle ? PillTheme.frameBg
        : (root.regaliaStyle ? Appearance.regalia.hoverPlate
        : root.zzzStyle ? "transparent"
        : root.angelStyle ? Appearance.angel.colGlassCard
        : root.inirStyle ? Appearance.inir.colLayer1Hover
        : root.auroraStyle ? Appearance.aurora.colSubSurface
        : Appearance.colors.colLayer0Hover)
    colRipple: macosStyle ? "transparent" : root.islandStyle ? Qt.alpha(PillTheme.vermLit, 0.18)
        : (root.regaliaStyle ? Appearance.regalia.pressPlate
        : root.zzzStyle ? ColorUtils.applyAlpha(Appearance.zzz.accent, 0.22)
        : root.angelStyle ? Appearance.angel.colGlassCardActive
        : root.inirStyle ? Appearance.inir.colLayer1Active
        : root.auroraStyle ? Appearance.aurora.colSubSurfaceActive
        : Appearance.colors.colLayer0Active)

    // Tune the inherited zzz tile (DockButton owns the only ZzzPlate).
    // Hover lifts the tile with a fuller cut; active keeps a moderate chamfer so
    // the focused read differs from hover. Whisper-thin console lift: a very
    // faint paper tint so the icon stays the hero, edged with a soft stroke.
    zzzPlateVisible: root.zzzStyle && !root.isSeparator && !root.islandStyle
    zzzPlateChamfer: Appearance.zzz.cutCorner * (root.buttonHovered ? 0.85 : root.appIsActive ? 0.6 : 0.45)
    zzzPlateFill: root.buttonHovered ? ColorUtils.applyAlpha(Appearance.zzz.paper, 0.14)
        : root.appIsActive ? ColorUtils.applyAlpha(Appearance.zzz.sticker, 0.08)
        : "transparent"
    zzzPlateStroke: root.buttonHovered ? ColorUtils.applyAlpha(Appearance.zzz.accent, 0.55)
        : root.appIsActive ? ColorUtils.applyAlpha(Appearance.zzz.sticker, 0.65)
        : "transparent"

    // Pill background (replaces shared panel for this item)
    DockPillItem {
        id: pillBackground
        anchors.fill: parent
        visible: pillStyle && !isSeparator && !Appearance.gameModeMinimal
        surfaceDialect: root.surfaceDialect
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
        surfaceDialect: root.surfaceDialect
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
        visible: !root.angelStyle && !root.zzzStyle && !root.macosStyle
        opacity: root.buttonHovered && !root.isSeparator
            ? (Appearance.m3colors.darkmode ? 0.18 : 0.35) : 0
        spread: 0
        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
    }

    Loader {
        active: isSeparator
        anchors.centerIn: parent
        sourceComponent: Rectangle {
            width: root.vertical ? root.separatorSize : 1
            height: root.vertical ? 1 : root.separatorSize
            color: root.inirStyle ? Appearance.inir.colBorderSubtle
                 : root.zzzStyle ? Appearance.zzz.hairlineStrong
                 : root.auroraStyle ? ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.7)
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
        // Caso especial: YouTube Music
        if (id === "com.github.th_ch.youtube_music") {
            id = "youtube-music";
        }
        // Caso especial: Spotify launcher
        if (id === "spotify" || id === "spotify-launcher") {
            id = "spotify-launcher";
        }
        if (!root.hasWindows) {
            const restoreEntry = root.findTrayMenuEntry(["library", "open", "show"])
            if (restoreEntry) {
                restoreEntry.triggered()
                return true
            }
        }
        if (id && id !== "" && id !== "SEPARATOR") {
            const entry = root.desktopEntry ?? AppSearch.lookupDesktopEntry(id);
            if (entry && AppSearch.launchEntry(entry))
                return true;
            // Only use SNI activation as a last resort when there is no usable
            // desktop entry. activate() has no success signal and some clients
            // accept it without ever restoring a window.
            if (!entry && root.appTrayItem?.onlyMenu === false) {
                root.appTrayItem.activate()
                return true
            }
            ShellExec.execCmd(id);
            return true;
        }
        return false;
    }

    function focusToplevelAt(index: int): void {
        const toplevel = toplevels[index]
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

    // Rotate focus through this app's windows. step +1 forward, -1 backward.
    function cycleWindows(step: int): void {
        const total = toplevels.length
        if (total === 0) return
        // Start from whatever is focused now, so scrolling continues from what
        // the user sees rather than from this button's own stale counter.
        const base = root.appIsActive ? root.focusedWindowIndex : lastFocused
        lastFocused = ((base + step) % total + total) % total
        focusToplevelAt(lastFocused)
    }

    onClicked: {
        // A dock click is navigation, not a request to refresh screenshots. Stop
        // the pending hover preview before focus changes so screenshot-window can
        // never race the first Ctrl+V in the destination app.
        hoverDelayTimer.stop()
        root.hoverPreviewDismissed()

        // Suppress the click that RippleButton fires after a drag-release
        if (appListRoot?._suppressNextClick) {
            appListRoot._suppressNextClick = false
            return
        }
        if (root.notificationCount > 0) {
            Notifications.markReadForApp([
                appToplevel?.originalAppId ?? appToplevel?.appId,
                root.desktopEntry?.name
            ])
        }
        // macOS click micro-pulse
        if (macosStyle) macItem.clickPulse()
        // Sin ventanas abiertas: lanzar nueva instancia desde desktop entry o fallbacks
        if (toplevels.length === 0) {
            launchFromDesktopEntry();
            return;
        }
        // Con ventanas: continuar desde la instancia realmente enfocada.
        // Thumbnail, keyboard and other shell actions can change focus without
        // updating this button's local counter.
        cycleWindows(1)
    }

    // Scroll over an icon to walk through that app's windows.
    WheelHandler {
        enabled: root.toplevels.length > 1 && !root.isSeparator
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        property real _accumulated: 0
        onWheel: event => {
            // Touchpads emit many small deltas; one notch is 120 units.
            _accumulated += event.angleDelta.y
            while (Math.abs(_accumulated) >= 120) {
                const direction = _accumulated > 0 ? 1 : -1
                _accumulated -= direction * 120
                // Scrolling up walks backwards through the window list.
                root.cycleWindows(-direction)
            }
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
        // Snapshot the entries. A live binding on `toplevels` re-evaluates on
        // every window/title event, which resets the menu's Repeater and kills
        // the hover state of the item under the cursor.
        contextMenu.model = root.buildContextMenuModel()
        contextMenu.requestOpen()
    }

    function desktopActionIcon(action): var {
        const explicitIcon = String(action?.icon ?? "").trim()
        if (explicitIcon.length > 0) {
            return {
                iconName: IconThemeService.smartIconName(explicitIcon,
                    appToplevel.originalAppId ?? appToplevel.appId),
                monochrome: false
            }
        }

        const label = String(action?.name ?? "").toLowerCase()
        const semanticIcons = [
            { words: ["new window", "nueva ventana", "nouvelle fenêtre"], icon: "open_in_new" },
            { words: ["private", "incognito", "privada", "privado"], icon: "visibility_off" },
            { words: ["store", "tienda", "boutique"], icon: "storefront" },
            { words: ["community", "comunidad", "communauté"], icon: "groups" },
            { words: ["library", "biblioteca", "bibliothèque"], icon: "video_library" },
            { words: ["server", "servidor", "serveur"], icon: "dns" },
            { words: ["screenshot", "capture", "captura"], icon: "screenshot" },
            { words: ["news", "noticias", "actualités"], icon: "newspaper" },
            { words: ["setting", "preference", "parámetro", "ajuste", "paramètre"], icon: "settings" },
            { words: ["big picture", "fullscreen", "pantalla completa"], icon: "fullscreen" },
            { words: ["friend", "amigo", "amis"], icon: "group" },
            { words: ["compose", "redactar", "write", "escribir"], icon: "edit_square" },
            { words: ["quit", "exit", "salir", "cerrar"], icon: "logout" }
        ]

        for (const rule of semanticIcons) {
            if (rule.words.some(word => label.includes(word)))
                return { iconName: rule.icon, monochrome: true }
        }

        return {
            iconName: IconThemeService.smartIconName(root.desktopEntry?.icon ?? "",
                appToplevel.originalAppId ?? appToplevel.appId),
            monochrome: false
        }
    }

    function normalizedAppKey(value): string {
        return String(value ?? "")
            .toLowerCase()
            .replace(/\.desktop$/, "")
            .replace(/[^a-z0-9]/g, "")
    }

    function normalizedTrayKey(value): string {
        // Some SNI implementations decorate their otherwise stable app id with
        // an instance suffix. Strip only that transport suffix, never app ids.
        return root.normalizedAppKey(String(value ?? "")
            .replace(/(?:[_.-]?status[_.-]?icon[_.-]?\d+)$/i, ""))
    }

    function normalizedActionKey(value): string {
        return String(value ?? "")
            .toLowerCase()
            .replace(/[&_.…\s-]/g, "")
    }

    function findTrayMenuEntry(labels): var {
        const wanted = labels.map(label => root.normalizedActionKey(label))
            .filter(label => label.length > 0)
        const entries = appTrayMenuOpener.children?.values ?? []
        return entries.find(entry => entry?.enabled !== false
            && wanted.includes(root.normalizedActionKey(entry?.text))) ?? null
    }

    function executeDesktopAction(action): void {
        // The desktop entry owns desktop actions. Tray-menu text is only a
        // compatibility fallback: using it first can silently redirect a dock
        // context-menu action to a similarly named resident-menu command.
        if (AppSearch.launchDesktopAction(root.desktopEntry, action))
            return

        const trayEntry = root.findTrayMenuEntry([action?.id, action?.name])
        if (trayEntry)
            trayEntry.triggered()
    }

    function buildContextMenuModel(): var {
        return [
            // Desktop actions (if available)
            ...((root.desktopEntry?.actions?.length > 0) ? root.desktopEntry.actions.map(action => {
                const resolvedIcon = root.desktopActionIcon(action)
                return {
                    iconName: resolvedIcon.iconName,
                    text: action.name,
                    monochromeIcon: resolvedIcon.monochrome,
                    action: () => root.executeDesktopAction(action)
                }
            }).concat({ type: "separator" }) : []),
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
                    text: root.toplevels.length > 1 ? Translation.tr("Close all windows") : Translation.tr("Close window"),
                    monochromeIcon: true,
                    action: () => {
                        for (let toplevel of root.toplevels) {
                            if (CompositorService.isNiri && toplevel?.niriWindowId) {
                                NiriService.closeWindow(toplevel.niriWindowId)
                            } else {
                                toplevel?.close()
                            }
                        }
                    }
                }
            ] : [])
        ]
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
    }

      contentItem: Loader {
          active: !isSeparator
          sourceComponent: Item {
              id: contentRoot
              anchors.centerIn: parent

              // Cache the item into an FBO layer if shaders are present AND animating.
              // This completely eliminates the horrific 100% CPU/GPU spike when macOS
              // hover magnify continually rescales the Desaturate and ColorOverlay shaders.
              layer.enabled: root.macosStyle && (Config.options?.dock?.monochromeIcons ?? false)
              layer.smooth: true

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
                        const resolved = IconThemeService.smartIconName(icon, appId);
                        return resolved;
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
                        color: ColorUtils.transparentize(root.inirStyle ? Appearance.inir.colPrimary
                            : root.zzzStyle ? Appearance.zzz.accent
                            : Appearance.colors.colPrimary, 0.9)
                    }
                }
            }

              // Unread notification badge, anchored to the icon's top-right corner
              Loader {
                  active: root.notificationCount > 0
                  anchors {
                      right: iconImageLoader.right
                      top: iconImageLoader.top
                      rightMargin: -4
                      topMargin: -2
                  }
                  sourceComponent: Rectangle {
                      implicitWidth: Math.max(16, badgeText.implicitWidth + 8)
                      implicitHeight: 16
                      radius: root.zzzStyle ? Appearance.zzz.controlRadius : height / 2
                      color: root.zzzStyle ? Appearance.zzz.signal
                          : root.inirStyle ? Appearance.inir.colError : Appearance.colors.colError
                      border.width: 1
                      border.color: root.zzzStyle ? Appearance.zzz.paper
                          : root.inirStyle ? Appearance.inir.colLayer1 : Appearance.colors.colLayer1

                      Behavior on implicitWidth {
                          enabled: Appearance.animationsEnabled
                          NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                      }
                      Behavior on color {
                          enabled: Appearance.animationsEnabled
                          ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                      }

                      StyledText {
                          id: badgeText
                          anchors.centerIn: parent
                          text: root.notificationCount > 99 ? "99+" : root.notificationCount
                          font.pixelSize: Appearance.font.pixelSize.smallest
                          font.weight: Font.Bold
                          color: root.zzzStyle ? Appearance.zzz.onSignal
                              : root.inirStyle ? Appearance.inir.colOnError : Appearance.colors.colOnError
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

                            // ZZZ indicators are thin signal pills: accent for the
                            // focused window, whispered ink for siblings.
                            radius: root.zzzStyle ? Math.min(width, height) / 2
                                : root.angelStyle ? 0 : Math.min(width, height) / 2
                            Behavior on radius { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                            implicitWidth: (root.islandStyle || root.zzzStyle)
                                ? (isFocusedWindow ? 16 : 5)
                                : root.angelStyle
                                ? (isFocusedWindow ? 14 : 6)
                                : (isFocusedWindow ? root.countDotWidth : root.countDotHeight)
                            implicitHeight: (root.islandStyle || root.zzzStyle) ? 3
                                : root.angelStyle ? 2 : root.countDotHeight
                            // Island indicators are Ricelin filaments: a lit vermilion
                            // thread for the focused window, whispered cream siblings.
                            // Island opt-in outranks the zzz accent chain.
                            color: isFocusedWindow
                                   ? (root.islandStyle ? PillTheme.vermLit
                                   : root.zzzStyle ? Appearance.zzz.accent
                                   : root.angelStyle ? Appearance.angel.colPrimary
                                   : root.inirStyle ? Appearance.inir.colPrimary : Appearance.colors.colPrimary)
                                   : root.islandStyle ? Qt.alpha(PillTheme.cream, 0.25)
                                   : ColorUtils.transparentize(root.zzzStyle ? Appearance.zzz.ink
                                   : root.angelStyle ? Appearance.angel.colTextSecondary
                                   : root.inirStyle ? Appearance.inir.colText : Appearance.colors.colOnLayer0, 0.65)

                            Behavior on implicitWidth {
                                enabled: Appearance.animationsEnabled
                                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                            }
                            Behavior on implicitHeight {
                                enabled: Appearance.animationsEnabled
                                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                            }
                            Behavior on color {
                                enabled: Appearance.animationsEnabled
                                animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                            }
                        }
                    }

                    // Fallback: single indicator when showAllDots is off and app is inactive
                    Rectangle {
                        opacity: (!root.appIsActive && root.hasWindows && Config.options?.dock?.showAllWindowDots === false) ? 1 : 0
                        visible: opacity > 0
                        width: (root.zzzStyle || root.islandStyle) ? 5 : (root.angelStyle ? 6 : 5)
                        height: (root.zzzStyle || root.islandStyle) ? 3 : (root.angelStyle ? 2 : 5)
                        radius: root.zzzStyle ? Math.min(width, height) / 2
                            : root.angelStyle ? 0 : Math.min(width, height) / 2
                        color: root.islandStyle ? Qt.alpha(PillTheme.cream, 0.25)
                            : ColorUtils.transparentize(root.zzzStyle ? Appearance.zzz.ink
                            : root.angelStyle ? Appearance.angel.colTextSecondary
                            : root.inirStyle ? Appearance.inir.colText : Appearance.colors.colOnLayer0,
                            root.zzzStyle ? 0.65 : 0.5)
                        Behavior on radius { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animationCurves.zzzOvershoot } }
                        Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }

                        Behavior on opacity {
                            enabled: Appearance.animationsEnabled
                            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }
                    }
                }
            }
        }
    }
}
