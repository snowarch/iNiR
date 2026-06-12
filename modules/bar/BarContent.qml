import qs.modules.bar.weather
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import qs
import qs.services
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE

Item { // Bar content region
    id: root

    // Shell desaturation effect
    layer.enabled: Appearance.shouldDesaturate("bar") && root.visible
    layer.effect: ShellDesaturationEffect {}

    property var screen: root.QsWindow.window?.screen
    property var brightnessMonitor: Brightness.getMonitorForScreen(screen)
    property alias backgroundItem: barBackground

    // Right-click context menu anchor (invisible, positioned at click)
    Item {
        id: barContextMenuAnchor
        width: 1
        height: 1
    }

    function openBarContextMenu(clickX, clickY, mouseArea) {
        // Position anchor at bar edge for correct popup positioning
        // For bar top: anchor at bottom edge (y = height), popup appears below
        // For bar bottom: anchor at top edge (y = 0), popupAbove makes it appear above
        const mapped = mouseArea.mapToItem(root, clickX, clickY)
        barContextMenuAnchor.x = mapped.x
        barContextMenuAnchor.y = (Config.options?.bar?.bottom ?? false) ? 0 : root.height
        barContextMenu.active = true
    }

    ContextMenu {
        id: barContextMenu
        anchorItem: barContextMenuAnchor
        popupAbove: Config.options?.bar?.bottom ?? false
        closeOnFocusLost: true
        closeOnHoverLost: true

        model: [
            {
                iconName: "browse_activity",
                monochromeIcon: true,
                text: Translation.tr("Mission Center"),
                action: () => {
                    Session.launchTaskManager()
                },
            },
            { type: "separator" },
            {
                iconName: "settings",
                monochromeIcon: true,
                text: Translation.tr("Settings"),
                action: () => {
                    Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "settings"])
                },
            },
        ]
    }
    readonly property bool taskbarEnabled: Config.options?.bar?.modules?.taskbar ?? false

    property real useShortenedForm: (Appearance.sizes.barHellaShortenScreenWidthThreshold >= screen?.width) ? 2 : (Appearance.sizes.barShortenScreenWidthThreshold >= screen?.width) ? 1 : 0
    readonly property int baseCenterSideModuleWidth: (useShortenedForm == 2) ? Appearance.sizes.barCenterSideModuleWidthHellaShortened : (useShortenedForm == 1) ? Appearance.sizes.barCenterSideModuleWidthShortened : Appearance.sizes.barCenterSideModuleWidth
    // Max width a side pill may take before it would collide with an edge
    // section. Pure outer geometry (screen width, edge sections, workspaces) so
    // there is no binding loop with the pills' own content width. A pill takes
    // its NATURAL content width, clamped to this — its modules elide/clip to fit
    // instead of inflating the pill or pushing into the edges.
    readonly property real centerSideMaxWidth: {
        const total = root.width
        if (!(total > 0)) return root.baseCenterSideModuleWidth
        const edge = Math.max(barLeftSideMouseArea.implicitWidth, barRightSideMouseArea.implicitWidth)
        const wsHalf = middleCenterGroup.width / 2
        return Math.max(0, total / 2 - edge - wsHalf - 12)
    }
    // Both centre pills share one width = the larger of the two non-empty
    // content widths (clamped to centerSideMaxWidth). This keeps the cluster
    // balanced around the workspaces pivot; each BarGroup centres its content,
    // so the narrower side doesn't look stuck to one edge. An empty zone
    // contributes 0 and collapses entirely.
    function _pillWidth(cw) {
        const lw = leftCenterGroup.empty ? 0 : leftCenterGroup.contentWidth
        const rw = rightCenterGroupPill.empty ? 0 : rightCenterGroupPill.contentWidth
        const raw = Math.max(lw, rw)
        return raw <= 0 ? 0 : Math.min(raw, root.centerSideMaxWidth)
    }
    readonly property bool cardStyleEverywhere: (Config.options?.dock?.cardStyle ?? false) && (Config.options?.sidebar?.cardStyle ?? false) && (Config.options?.bar?.cornerStyle === 3)
    readonly property color separatorColor: Appearance.colors.colOutlineVariant

    // Per-monitor wallpaper URL for Aurora blur — uses the actual wallpaper on this screen
    readonly property string wallpaperUrl: {
        const _dep1 = WallpaperListener.multiMonitorEnabled
        const _dep2 = WallpaperListener.effectivePerMonitor
        const _dep3 = Wallpapers.effectiveWallpaperUrl
        return WallpaperListener.wallpaperUrlForScreen(root.screen)
    }

    readonly property bool _useGlobalQuantizer: root.wallpaperUrl === Wallpapers.effectiveWallpaperUrl
    ColorQuantizer {
        id: wallpaperColorQuantizer
        source: (Appearance.auroraEverywhere || Appearance.angelEverywhere)
            ? (root._useGlobalQuantizer ? "" : root.wallpaperUrl)
            : ""
        depth: 0 // 2^0 = 1 color
        rescaleSize: 10
    }

    readonly property color wallpaperDominantColor: root._useGlobalQuantizer
        ? Appearance.wallpaperDominantColor
        : (wallpaperColorQuantizer?.colors?.[0] ?? Appearance.colors.colPrimary)
    AdaptedMaterialScheme {
        id: _localBlendedColors
        color: ColorUtils.mix(root.wallpaperDominantColor, Appearance.colors.colPrimaryContainer, 0.8) || Appearance.m3colors.m3secondaryContainer
    }
    readonly property QtObject blendedColors: root._useGlobalQuantizer
        ? Appearance.wallpaperBlendedColors : _localBlendedColors

    readonly property bool inirEverywhere: Appearance.inirEverywhere
    readonly property bool angelEverywhere: Appearance.angelEverywhere
    readonly property string leftAction: Config.options?.bar?.leftScrollAction ?? "brightness"
    readonly property string rightAction: Config.options?.bar?.rightScrollAction ?? "volume"

    function performScrollAction(action: string, isUp: bool): void {
        if (action === "brightness") {
            const step = 0.05;
            root.brightnessMonitor.setBrightness(root.brightnessMonitor.brightness + (isUp ? step : -step));
        } else if (action === "volume") {
            if (isUp) Audio.incrementVolume();
            else Audio.decrementVolume();
        } else if (action === "workspace") {
            let up = isUp;
            if (Config.options?.bar?.workspaces?.invertScroll ?? false) up = !up;

            if (CompositorService.isNiri) {
                if (up) NiriService.focusWorkspaceUp();
                else NiriService.focusWorkspaceDown();
            } else if (CompositorService.isHyprland) {
                Hyprland.dispatch(up ? "workspace r-1" : "workspace r+1");
            }
        }
    }

    function closeOSD(action: string): void {
        if (action === "brightness") GlobalStates.osdBrightnessOpen = false;
        else if (action === "volume") GlobalStates.osdVolumeOpen = false;
    }

    function getScrollIcon(action: string): string {
        if (action === "brightness") return "light_mode";
        if (action === "volume") return "volume_up";
        if (action === "workspace") return "workspaces";
        return "";
    }

    function getScrollTooltip(action: string): string {
        if (action === "brightness") return Translation.tr("Scroll to change brightness");
        if (action === "volume") return Translation.tr("Scroll to change volume");
        if (action === "workspace") return Translation.tr("Scroll to switch workspaces");
        return "";
    }

    component VerticalBarSeparator: Rectangle {
        Layout.topMargin: Appearance.sizes.baseBarHeight / 3
        Layout.bottomMargin: Appearance.sizes.baseBarHeight / 3
        Layout.fillHeight: true
        implicitWidth: 1
        color: root.inirEverywhere ? Appearance.inir.colBorderSubtle : root.separatorColor
    }

    // ═══ Modular layout engine ══════════════════════════════════════════
    // Five zones map 1:1 to the bar's real structure. Pills size to their
    // natural content; workspaces stays screen-centered; side pills grow
    // outward and clamp so they never collide with the edge sections.
    // Visibility still comes from Config.options.bar.modules.*; the arrays only
    // define order/zone. Falls back to the classic layout until migrated.
    readonly property bool _layoutMigrated: Config.options?.bar?.layout?.migrated === true
    readonly property real _spacerMinimumWidth: Math.max(0, Config.options?.bar?.layout?.spacerWidth ?? 0) * Appearance.fontSizeScale
    function _zone(name, fallback) {
        const a = Config.options?.bar?.layout?.[name]
        return (root._layoutMigrated && a && a.length >= 0) ? a : fallback
    }
    readonly property var _leftIds:        root._zone("left",        ["leftSidebarButton", "activeWindow"])
    readonly property var _centerLeftIds:  root._zone("centerLeft",  ["resources", "media"])
    readonly property var _centerIds:      root._zone("center",      ["workspaces"])
    readonly property var _centerRightIds: root._zone("centerRight", ["clock", "utilButtons", "battery"])
    readonly property var _rightIds:       root._zone("right",       ["rightSidebarButton", "tray", "timer", "shellUpdate", "spacer", "weather"])

    function _moduleVisible(id) { return Config.options?.bar?.modules?.[id] ?? true }

    // Unified id→Component map. Every zone uses this same map so ANY module can
    // live in ANY zone (the editor allows cross-zone moves). Layout sizing hints
    // are applied on the Loader (the real layout child) via _fillWidth/_fillHeight
    // below — hints set inside a loaded item are ignored by the parent layout.
    readonly property var _allComponents: ({
        "leftSidebarButton": leftSidebarButtonComponent,
        "activeWindow": activeWindowComponent,
        "resources": resourcesModuleComponent,
        "media": mediaModuleComponent,
        "workspaces": workspacesModuleComponent,
        "clock": clockModuleComponent,
        "utilButtons": utilButtonsModuleComponent,
        "battery": batteryModuleComponent,
        "rightSidebarButton": rightSidebarButtonComponent,
        "tray": trayComponent,
        "timer": timerComponent,
        "shellUpdate": shellUpdateComponent,
        "weather": weatherComponent,
        "spacer": spacerComponent,
    })
    // Edge zones (left/right) are RowLayouts with real slack; the centre zones
    // are content-sized pills with none. `activeWindow` only fills where there
    // is slack — in a centre pill it instead reports a clamped intrinsic width
    // (see _fillSlot below) so it stays visible there.
    readonly property var _edgeZones: ["left", "right"]
    function _fillSlot(zone) { return root._edgeZones.indexOf(zone) !== -1 }

    // Which ids stretch along the bar axis. `spacer` is a pure gap;
    // activeWindow/taskbar fill the edge section; resources fills only on the
    // tightest screens. Centre pills size tightly to content, so clock/media do
    // NOT fill — they sit at natural width with no leftover space.
    readonly property string _spacerMode: Config.options?.bar?.layout?.spacerMode ?? "auto"
    function _fillWidth(id, zone) {
        if (id === "spacer") {
            // "auto": only stretch where the layout actually has slack (edge
            // zones); inside content-sized centre pills a greedy spacer fights
            // the pill sizing and breaks the look — fall back to a fixed gap.
            if (root._spacerMode === "fixed") return false
            if (root._spacerMode === "fill") return true
            return root._fillSlot(zone)
        }
        if (id === "activeWindow") return root._fillSlot(zone)
        if (id === "resources") return root.useShortenedForm === 2
        return false
    }
    function _fillHeight(id) {
        return id === "spacer" || id === "tray" || id === "workspaces" || id === "activeWindow"
    }

    Component {
        id: resourcesModuleComponent
        Resources {
            visible: root._moduleVisible("resources")
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: root.useShortenedForm === 2
            alwaysShowAllResources: root.useShortenedForm === 2
        }
    }
    Component {
        id: mediaModuleComponent
        Media {
            visible: root._moduleVisible("media") && root.useShortenedForm < 2
        }
    }
    Component {
        id: workspacesModuleComponent
        Workspaces {
            visible: root._moduleVisible("workspaces")
            Layout.fillHeight: true
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                onPressed: event => {
                    if (event.button === Qt.RightButton)
                        GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
                }
            }
        }
    }
    Component {
        id: clockModuleComponent
        ClockWidget {
            visible: root._moduleVisible("clock")
            showDate: ((Config.options?.bar?.verbose ?? true) && root.useShortenedForm < 2)
        }
    }
    Component {
        id: utilButtonsModuleComponent
        UtilButtons {
            visible: root._moduleVisible("utilButtons") && ((Config.options?.bar?.verbose ?? true) && root.useShortenedForm === 0)
            Layout.alignment: Qt.AlignVCenter
        }
    }
    Component {
        id: batteryModuleComponent
        BatteryIndicator {
            visible: root._moduleVisible("battery") && (root.useShortenedForm < 2 && Battery.available)
            Layout.alignment: Qt.AlignVCenter
        }
    }

    // id → Component for the left edge zone.
    Component {
        id: leftSidebarButtonComponent
        LeftSidebarButton {
            visible: root._moduleVisible("leftSidebarButton")
            Layout.alignment: Qt.AlignVCenter
            colBackground: buttonHovered
                ? (Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceHover : Appearance.colors.colLayer1Hover)
                : "transparent"
        }
    }
    // activeWindow covers the title display and the optional taskbar (mutually
    // exclusive: taskbar replaces the active window title).
    // The wrapper deliberately reports implicitWidth: 0 so neither a long title
    // nor extra taskbar items inflate the edge section (which would shrink
    // centerSideMaxWidth and shuffle the centre pills on every change). The
    // Loader's Layout.fillWidth (see root._fillWidth) gives this item the
    // leftover horizontal space inside the section, and the inner content
    // elides / clips to fit instead of pushing the bar around.
    Component {
        id: activeWindowComponent
        Item {
            id: awWrapper
            // Set by the host Loader: true in edge zones (gets fill slack →
            // width 0 + fillWidth), false in centre pills (no slack → adopt a
            // clamped intrinsic width so the title is actually visible).
            property bool fillSlot: true
            implicitWidth: fillSlot ? 0 : Math.min(_awItem.contentImplicitWidth, 220)
            implicitHeight: Appearance.sizes.baseBarHeight
            clip: true
            ActiveWindow {
                id: _awItem
                anchors.fill: parent
                visible: root._moduleVisible("activeWindow") && root.useShortenedForm === 0 && !root.taskbarEnabled
            }
            Loader {
                id: _tbLoader
                anchors.fill: parent
                active: root.taskbarEnabled
                visible: active
                sourceComponent: BarTaskbar { parentWindow: root.QsWindow.window }
            }
        }
    }

    // Background shadow
    Loader {
        active: !root.inirEverywhere
            && (Appearance.angelEverywhere || !Appearance.auroraEverywhere)
            && !Appearance.gameModeMinimal
            && (Config.options?.bar?.showBackground ?? true)
            && (Appearance.angelEverywhere || (((Config.options?.bar?.cornerStyle ?? 0) === 1 || (Config.options?.bar?.cornerStyle ?? 0) === 3)
            && (Config.options?.bar?.floatStyleShadow ?? true)))
        anchors.fill: barBackground
        sourceComponent: StyledRectangularShadow {
            anchors.fill: undefined // The loader's anchors act on this, and this should not have any anchor
            target: barBackground
        }
    }
    // Background
    Rectangle {
        id: barBackground
        readonly property bool auroraEverywhere: Appearance.auroraEverywhere
        readonly property bool gameModeMinimal: Appearance.gameModeMinimal
        readonly property int cornerStyle: Config.options?.bar?.cornerStyle ?? 0
        // Float (1) and Card (3) are floating; Aurora makes everything floating except Hug and Rect
        readonly property bool floatingStyle: (cornerStyle === 1 || cornerStyle === 3) || (auroraEverywhere && cornerStyle !== 0 && cornerStyle !== 2)

        anchors {
            fill: parent
            margins: floatingStyle ? Appearance.sizes.hyprlandGapsOut : 0
        }
        readonly property real barMargin: floatingStyle ? Appearance.sizes.hyprlandGapsOut : 0
        readonly property bool isBottom: Config.options?.bar?.bottom ?? false

        readonly property QtObject blendedColors: root.blendedColors

        visible: (Config.options?.bar?.showBackground ?? true) && !gameModeMinimal
        // User-configurable background opacity (lets you make the bar translucent
        // without changing the global style). Applied as Item.opacity so border,
        // blurredWallpaper, inset glow and partial borders all fade together.
        // Widgets sit OUTSIDE this Rectangle so they stay fully opaque.
        opacity: Math.max(0, Math.min(1, Config.options?.bar?.opacity ?? 1))
        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }

        // Color logic per global style and corner style
        color: {
            if (root.angelEverywhere) {
                const base = blendedColors?.colLayer0 ?? Appearance.colors.colLayer0
                if (Appearance.compositorBlurActive)
                    return ColorUtils.transparentize(base, Appearance.angel.compositorPanelTransparentize)
                return ColorUtils.applyAlpha(base, 1)
            }
            if (root.inirEverywhere) {
                return Appearance.inir.colLayer0
            }
            if (auroraEverywhere) {
                const base = blendedColors?.colLayer0 ?? Appearance.colors.colLayer0
                if (Appearance.compositorBlurActive)
                    return ColorUtils.transparentize(base, Appearance.aurora.compositorOverlayTransparentize)
                return ColorUtils.applyAlpha(base, 1)
            }
            // Material/Cards
            if (root.cardStyleEverywhere || cornerStyle === 3) {
                return Appearance.colors.colLayer1
            }
            return Appearance.colors.colLayer0
        }

        // Radius logic per global style and corner style
        radius: {
            // Custom rounding override (-1 means use theme default)
            const customRounding = Config.options?.bar?.customRounding ?? -1
            if (customRounding >= 0) {
                return customRounding
            }
            if (root.angelEverywhere) {
                return (cornerStyle === 1 || cornerStyle === 3) ? Appearance.angel.roundingNormal : 0
            }
            if (root.inirEverywhere) {
                // Inir: use inir rounding for Float/Card, 0 for Hug/Rect
                if (cornerStyle === 1 || cornerStyle === 3) {
                    return Appearance.inir.roundingNormal
                }
                return 0
            }
            if (floatingStyle) {
                // Float or Card floating
                return cornerStyle === 3 ? Appearance.rounding.normal : Appearance.rounding.windowRounding
            }
            return 0
        }

        // Border logic per global style
        border.width: {
            if (root.angelEverywhere) return Appearance.angel.panelBorderWidth
            if (root.inirEverywhere) {
                return (cornerStyle === 1 || cornerStyle === 3) ? 1 : 0
            }
            if (auroraEverywhere) {
                return floatingStyle ? 1 : 0
            }
            return floatingStyle ? 1 : 0
        }
        border.color: {
            if (root.angelEverywhere) return Appearance.angel.colPanelBorder
            if (root.inirEverywhere) {
                return Appearance.inir.colBorder
            }
            if (auroraEverywhere) {
                return Appearance.aurora.colTooltipBorder
            }
            return Appearance.colors.colLayer0Border
        }

        clip: true

        layer.enabled: auroraEverywhere && !root.inirEverywhere && !gameModeMinimal
        layer.effect: GE.OpacityMask {
            maskSource: Rectangle {
                width: barBackground.width
                height: barBackground.height
                radius: barBackground.radius
            }
        }

        Image {
            id: blurredWallpaper
            x: -barBackground.barMargin
            y: barBackground.isBottom ? -(root.screen?.height ?? 1080) + barBackground.height + barBackground.barMargin : -barBackground.barMargin
            width: root.screen?.width ?? 1920
            height: root.screen?.height ?? 1080
            visible: barBackground.auroraEverywhere && !root.inirEverywhere && !barBackground.gameModeMinimal && !Appearance.compositorBlurActive
            source: Appearance.compositorBlurActive ? "" : root.wallpaperUrl
            fillMode: Image.PreserveAspectCrop
            cache: true
            sourceSize.width: root.screen?.width ?? 1920
            sourceSize.height: root.screen?.height ?? 1080
            asynchronous: true

            // Skip QML blur when the compositor is already blurring this layer
            // (avoids double-blur and the FBO cost). See #159.
            layer.enabled: Appearance.effectsEnabled && barBackground.auroraEverywhere && !root.inirEverywhere && !Appearance.compositorBlurActive
            layer.effect: MultiEffect {
                source: blurredWallpaper
                anchors.fill: source
                saturation: root.angelEverywhere
                    ? (Appearance.angel.blurSaturation * Appearance.angel.colorStrength)
                    : (Appearance.effectsEnabled ? 0.2 : 0)
                blurEnabled: Appearance.effectsEnabled
                blurMax: 64
                blur: Appearance.effectsEnabled
                    ? (root.angelEverywhere ? Appearance.angel.blurIntensity : 1)
                    : 0
            }

            Rectangle {
                anchors.fill: parent
                color: root.angelEverywhere
                    ? ColorUtils.transparentize((barBackground.blendedColors?.colLayer0 ?? Appearance.colors.colLayer0Base), Appearance.angel.overlayOpacity * Appearance.angel.panelTransparentize)
                    : ColorUtils.transparentize((barBackground.blendedColors?.colLayer0 ?? Appearance.colors.colLayer0Base), Appearance.aurora.overlayTransparentize)
            }
        }

        // Angel inset glow — top edge
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: Appearance.angel.insetGlowHeight
            visible: root.angelEverywhere
            color: Appearance.angel.colInsetGlow
        }

        // Angel partial border — elegant half-borders
        AngelPartialBorder {
            targetRadius: barBackground.radius
        }
    }

    FocusedScrollMouseArea { // Left side | scroll to change brightness
        id: barLeftSideMouseArea

        anchors {
            top: parent.top
            bottom: parent.bottom
            left: parent.left
        }
        // Extend up to the left pill's inner edge but keep at least the natural
        // content width so the sidebar button / active window are never clipped.
        width: Math.max(implicitWidth, middleSection.leftPillX)
        implicitWidth: leftSectionRowLayout.implicitWidth
        implicitHeight: Appearance.sizes.baseBarHeight

        onScrollDown: root.performScrollAction(root.leftAction, false)
        onScrollUp: root.performScrollAction(root.leftAction, true)
        onMovedAway: root.closeOSD(root.leftAction)
        onPressed: event => {
            if (event.button === Qt.LeftButton)
                GlobalStates.sidebarLeftOpen = !GlobalStates.sidebarLeftOpen;
            else if (event.button === Qt.RightButton)
                root.openBarContextMenu(event.x, event.y, barLeftSideMouseArea)
        }

        // ScrollHint as overlay - at the inner edge of the margin space
        ScrollHint {
            id: leftScrollHint
            reveal: barLeftSideMouseArea.hovered && (Config.options?.bar?.showScrollHints ?? true) && root.leftAction !== "none"
            icon: root.getScrollIcon(root.leftAction)
            tooltipText: root.getScrollTooltip(root.leftAction)
            side: "left"
            x: Appearance.rounding.screenRounding - implicitWidth - Appearance.sizes.spacingSmall
            anchors.verticalCenter: parent.verticalCenter
            z: 1
        }

        RowLayout {
            id: leftSectionRowLayout
            anchors.fill: parent
            anchors.leftMargin: Appearance.rounding.screenRounding
            anchors.rightMargin: Appearance.rounding.screenRounding
            spacing: 10

            Repeater {
                model: root._leftIds
                delegate: Loader {
                    required property string modelData
                    Layout.alignment: Qt.AlignVCenter
                    Layout.fillWidth: root._fillWidth(modelData, "left")
                    Layout.fillHeight: root._fillHeight(modelData)
                    sourceComponent: root._allComponents[modelData] ?? null
                    onLoaded: if (modelData === "activeWindow" && item) item.fillSlot = true
                }
            }
        }
    }

    Item { // Middle section — workspaces stays screen-centered; the side pills
           // size to their natural content and grow outward from it, clamped so
           // they never collide with the edge sections.
        id: middleSection
        anchors {
            top: parent.top
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }

        // Inner X edges of the side pills (BarContent coords) so the edge
        // sections can extend up to — but never into — the center cluster.
        readonly property real leftPillX: leftCenterGroup.width > 0 ? leftCenterGroup.x : middleCenterGroup.x
        readonly property real rightPillEndX: rightCenterGroup.width > 0
            ? (rightCenterGroup.x + rightCenterGroup.width)
            : (middleCenterGroup.x + middleCenterGroup.width)

        BarGroup {
            id: middleCenterGroup
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
            padding: 4
            // Collapse the pivot pill background when workspaces (its only
            // default content) is hidden — leaves a tiny centred gap instead of
            // a ghost pill. Width stays minimal so side pills still flank it.
            visible: !empty

            Repeater {
                model: root._centerIds
                delegate: Loader {
                    required property string modelData
                    Layout.alignment: Qt.AlignVCenter
                    Layout.fillWidth: root._fillWidth(modelData, "center")
                    Layout.fillHeight: root._fillHeight(modelData)
                    sourceComponent: root._allComponents[modelData] ?? null
                    onLoaded: if (modelData === "activeWindow" && item) item.fillSlot = false
                }
            }
        }

        VerticalBarSeparator {
            id: leftSeparator
            visible: (Config.options?.bar.borderless ?? false) && !leftCenterGroup.empty && !middleCenterGroup.empty
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: middleCenterGroup.left
            anchors.rightMargin: 4
            height: Appearance.sizes.baseBarHeight / 3
        }

        BarGroup {
            id: leftCenterGroup
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: (Config.options?.bar.borderless ?? false) ? leftSeparator.left : middleCenterGroup.left
            anchors.rightMargin: 4
            // Collapse to nothing when this zone has no visible modules;
            // otherwise take the symmetric target width. Modules elide/clip.
            visible: !empty
            implicitWidth: empty ? 0 : root._pillWidth(contentWidth)
            clip: true

            Repeater {
                model: root._centerLeftIds
                delegate: Loader {
                    required property string modelData
                    Layout.alignment: Qt.AlignVCenter
                    Layout.fillWidth: root._fillWidth(modelData, "centerLeft")
                    Layout.fillHeight: root._fillHeight(modelData)
                    sourceComponent: root._allComponents[modelData] ?? null
                    onLoaded: if (modelData === "activeWindow" && item) item.fillSlot = false
                }
            }
        }

        VerticalBarSeparator {
            id: rightSeparator
            visible: (Config.options?.bar.borderless ?? false) && !rightCenterGroupPill.empty && !middleCenterGroup.empty
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: middleCenterGroup.right
            anchors.leftMargin: 4
            height: Appearance.sizes.baseBarHeight / 3
        }

        Item {
            id: rightCenterGroup
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: (Config.options?.bar.borderless ?? false) ? rightSeparator.right : middleCenterGroup.right
            anchors.leftMargin: 4
            visible: !rightCenterGroupPill.empty
            implicitWidth: rightCenterGroupPill.empty ? 0 : rightCenterGroupPill.width
            implicitHeight: rightCenterGroupPill.height
            readonly property real contentWidth: rightCenterGroupPill.contentWidth

            // Gesture sequence tracking for multi-tap detection
            property int _tapSeq: 0
            property bool _confirmFx: false
            Timer { id: _tapSeqTimer; interval: 500; onTriggered: rightCenterGroup._tapSeq = 0 }
            Timer { id: _fxResetTimer; interval: 2000; onTriggered: rightCenterGroup._confirmFx = false }

            // Pill + content — structurally identical to leftCenterGroup so it
            // sizes to natural content and centers it the same way.
            BarGroup {
                id: rightCenterGroupPill
                anchors.verticalCenter: parent.verticalCenter
                visible: !empty
                implicitWidth: empty ? 0 : root._pillWidth(contentWidth)
                clip: true

                Repeater {
                    model: root._centerRightIds
                    delegate: Loader {
                        required property string modelData
                        Layout.alignment: Qt.AlignVCenter
                        Layout.fillWidth: root._fillWidth(modelData, "centerRight")
                        Layout.fillHeight: root._fillHeight(modelData)
                        sourceComponent: root._allComponents[modelData] ?? null
                        onLoaded: if (modelData === "activeWindow" && item) item.fillSlot = false
                    }
                }
            }

            // Interaction overlay (sidebar toggle / control panel / triple-tap fx)
            MouseArea {
                anchors.fill: rightCenterGroupPill
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                z: -1
                onPressed: event => {
                    if (event.button === Qt.RightButton) {
                        GlobalStates.controlPanelOpen = !GlobalStates.controlPanelOpen;
                    } else {
                        GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
                        rightCenterGroup._tapSeq++; _tapSeqTimer.restart()
                        if (rightCenterGroup._tapSeq >= 3) { rightCenterGroup._confirmFx = true; rightCenterGroup._tapSeq = 0; _fxResetTimer.restart() }
                    }
                }
            }

            // Tap-sequence visual confirmation overlay
            Repeater {
                model: rightCenterGroup._confirmFx ? 3 : 0
                Text {
                    property int _delay: index * 120
                    text: "\ud83e\udec3\ud83c\udffb"
                    font.pixelSize: 22
                    x: (rightCenterGroup.width - implicitWidth) / 2 + (index - 1) * 28
                    y: rightCenterGroup.height / 2
                    z: 10
                    scale: 0
                    opacity: 0
                    SequentialAnimation on y {
                        PauseAnimation { duration: _delay }
                        NumberAnimation { to: -20; duration: 1200; easing.type: Easing.OutCubic }
                    }
                    SequentialAnimation on scale {
                        PauseAnimation { duration: _delay }
                        NumberAnimation { to: 1.3; duration: 250; easing.type: Easing.OutBack }
                        NumberAnimation { to: 1.0; duration: 200 }
                        PauseAnimation { duration: 500 }
                        NumberAnimation { to: 0; duration: 300; easing.type: Easing.InBack }
                    }
                    SequentialAnimation on opacity {
                        PauseAnimation { duration: _delay }
                        NumberAnimation { to: 1; duration: 200 }
                        PauseAnimation { duration: 700 }
                        NumberAnimation { to: 0; duration: 350 }
                    }
                }
            }
        }
    }

    FocusedScrollMouseArea { // Right side | scroll to change volume
        id: barRightSideMouseArea

        anchors {
            top: parent.top
            bottom: parent.bottom
            right: parent.right
        }
        width: Math.max(implicitWidth, root.width - middleSection.rightPillEndX)
        implicitWidth: rightSectionRowLayout.implicitWidth
        implicitHeight: Appearance.sizes.baseBarHeight

        onScrollDown: root.performScrollAction(root.rightAction, false)
        onScrollUp: root.performScrollAction(root.rightAction, true)
        onMovedAway: root.closeOSD(root.rightAction)
        onPressed: event => {
            if (event.button === Qt.LeftButton) {
                GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
            } else if (event.button === Qt.RightButton) {
                root.openBarContextMenu(event.x, event.y, barRightSideMouseArea)
            }
        }

        // ScrollHint as overlay - at the inner edge of the margin space
        ScrollHint {
            id: rightScrollHint
            reveal: barRightSideMouseArea.hovered && (Config.options?.bar?.showScrollHints ?? true) && root.rightAction !== "none"
            icon: root.getScrollIcon(root.rightAction)
            tooltipText: root.getScrollTooltip(root.rightAction)
            side: "right"
            x: parent.width - Appearance.rounding.screenRounding + Appearance.sizes.spacingSmall
            anchors.verticalCenter: parent.verticalCenter
            z: 1
        }

        RowLayout {
            id: rightSectionRowLayout
            anchors.fill: parent
            anchors.leftMargin: Appearance.rounding.screenRounding
            anchors.rightMargin: Appearance.rounding.screenRounding
            spacing: 5
            layoutDirection: Qt.RightToLeft

            Repeater {
                model: root._rightIds
                delegate: Loader {
                    required property string modelData
                    Layout.alignment: Qt.AlignVCenter
                    Layout.fillWidth: root._fillWidth(modelData, "right")
                    Layout.fillHeight: root._fillHeight(modelData)
                    Layout.leftMargin: modelData === "weather" ? 4 : 0
                    sourceComponent: root._allComponents[modelData] ?? null
                    onLoaded: if (modelData === "activeWindow" && item) item.fillSlot = true
                }
            }
        }
    }

    // id → Component for the right edge zone. The RowLayout is RTL: the first id
    // renders nearest the screen edge. `spacer` is a flexible gap.
    // The right edge zone renders RTL: the first id sits nearest the screen
    // edge. `spacer` is a flexible gap.
    Component { id: timerComponent; TimerIndicator { Layout.alignment: Qt.AlignVCenter } }
    Component { id: shellUpdateComponent; ShellUpdateIndicator { Layout.alignment: Qt.AlignVCenter } }
    Component {
        id: spacerComponent
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: root._spacerMinimumWidth
            // When the spacer is a fixed gap (no fill slack), an unset width
            // would make it invisible — keep a sensible minimum gap.
            implicitWidth: Math.max(root._spacerMinimumWidth, 12)
            Behavior on implicitWidth {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: Appearance.animation.elementResize.duration
                    easing.type: Appearance.animation.elementResize.type
                    easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
                }
            }
        }
    }
    Component {
        id: trayComponent
        SysTray {
            visible: root._moduleVisible("sysTray") && root.useShortenedForm === 0
            Layout.fillWidth: false
            Layout.fillHeight: true
            invertSide: Config.options?.bar?.bottom ?? false
        }
    }
    Component {
        id: weatherComponent
        Loader {
            active: root._moduleVisible("weather") && (Config.options?.bar?.weather?.enable ?? false)
            visible: active
            sourceComponent: BarGroup { WeatherBar {} }
        }
    }
    Component {
        id: rightSidebarButtonComponent
        RippleButton { // Right sidebar button
            id: rightSidebarButton
            visible: root._moduleVisible("rightSidebarButton")

            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            Layout.fillWidth: false

            implicitWidth: indicatorsRowLayout.implicitWidth + 10 * 2
            implicitHeight: indicatorsRowLayout.implicitHeight + 5 * 2

            buttonRadius: Appearance.rounding.full

            colBackground: buttonHovered
                ? (Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceHover : Appearance.colors.colLayer1Hover)
                : "transparent"
            colBackgroundHover: Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceHover : Appearance.colors.colLayer1Hover
            colRipple: Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive : Appearance.colors.colLayer1Active
            colBackgroundToggled: Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurface : Appearance.colors.colSecondaryContainer
            colBackgroundToggledHover: Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurfaceHover : Appearance.colors.colSecondaryContainerHover
            colRippleToggled: Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive : Appearance.colors.colSecondaryContainerActive

            toggled: GlobalStates.sidebarRightOpen
            property color colText: toggled ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colOnLayer0

            Behavior on colText {
                animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }

            onPressed: {
                GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
            }

            RowLayout {
                id: indicatorsRowLayout
                anchors.centerIn: parent
                property real realSpacing: 15
                spacing: 0

                Revealer {
                    reveal: Audio.sink?.audio?.muted ?? false
                    Layout.fillHeight: true
                    Layout.rightMargin: reveal ? indicatorsRowLayout.realSpacing : 0
                    Behavior on Layout.rightMargin {
                        animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                    }
                    MaterialSymbol {
                        text: "volume_off"
                        iconSize: Appearance.font.pixelSize.larger
                        color: rightSidebarButton.colText
                    }
                }
                Revealer {
                    reveal: Audio.micMuted
                    Layout.fillHeight: true
                    Layout.rightMargin: reveal ? indicatorsRowLayout.realSpacing : 0
                    Behavior on Layout.rightMargin {
                        animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                    }
                    MaterialSymbol {
                        text: "mic_off"
                        iconSize: Appearance.font.pixelSize.larger
                        color: rightSidebarButton.colText
                    }
                }
                HyprlandXkbIndicator {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.rightMargin: KeyboardIndicators.hasPanelIndicators ? indicatorsRowLayout.realSpacing : 0
                    color: rightSidebarButton.colText
                }
                Revealer {
                    reveal: Notifications.silent || Notifications.unread > 0
                    Layout.fillHeight: true
                    Layout.rightMargin: reveal ? indicatorsRowLayout.realSpacing : 0
                    implicitHeight: reveal ? notificationUnreadCount.implicitHeight : 0
                    implicitWidth: reveal ? notificationUnreadCount.implicitWidth : 0
                    Behavior on Layout.rightMargin {
                        enabled: Appearance.animationsEnabled
                        animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                    }
                    NotificationUnreadCount {
                        id: notificationUnreadCount
                    }
                }
                MaterialSymbol {
                    text: Network.materialSymbol
                    iconSize: Appearance.font.pixelSize.larger
                    color: rightSidebarButton.colText
                    Layout.rightMargin: BluetoothStatus.available ? indicatorsRowLayout.realSpacing : 0

                    HoverHandler {
                        id: wifiHover
                    }

                    StyledToolTip {
                        extraVisibleCondition: wifiHover.hovered
                        text: {
                            if (!Network.wifiEnabled) return Translation.tr("Wi-Fi is disabled");
                            if (Network.ethernet) return Translation.tr("Ethernet connected");
                            if (!Network.networkName) return Translation.tr("Not connected");
                            let lines = [Translation.tr("Connected to %1").arg(Network.networkName)];
                            if (Network.active) {
                                lines.push(Network.networkStrength + "%");
                                if (Network.active.frequency) {
                                    let ghz = Network.active.frequency > 4000 ? "5 GHz" : "2.4 GHz";
                                    lines.push(ghz + " (" + Network.active.frequency + " MHz)");
                                }
                                if (Network.active.rate) {
                                    lines.push(Network.active.rate);
                                }
                                if (Network.active.bssid) {
                                    lines.push(Network.active.bssid);
                                }
                            }
                            return lines.join(" | ");
                        }
                    }
                }
                Revealer {
                    reveal: BluetoothStatus.available
                    Layout.rightMargin: indicatorsRowLayout.realSpacing
                    MaterialSymbol {
                        text: BluetoothStatus.activeIcon
                        iconSize: Appearance.font.pixelSize.larger
                        color: rightSidebarButton.colText
                    }
                }
            }
        }
    }
}
