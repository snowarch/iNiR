pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects as GE
import Quickshell.Io
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import qs.modules.pill

Scope {
    id: root
    // pinnedOnStartup pins the dock for the whole session, which conflicts
    // with hover-reveal (a pinned dock can never hide). Let hover-reveal win
    // so the dock actually hides when the user asks it to; pinnedOnStartup
    // only applies when reveal mode is "Empty workspace".
    property bool pinned: (Config.options?.dock?.pinnedOnStartup ?? false)
        && !(Config.options?.dock?.hoverToReveal ?? false)
    readonly property string position: Config.options?.dock?.position ?? "bottom"
    readonly property bool isVertical: root.position === "left" || root.position === "right"
    readonly property bool isTop: root.position === "top"
    readonly property bool isLeft: root.position === "left"
    readonly property bool isPillStyle:   Config.options?.dock?.style === "pill"
    readonly property bool isMacosStyle:  Config.options?.dock?.style === "macos"
    readonly property bool isIslandStyle: Config.options?.dock?.style === "island"
    readonly property bool isM3Style:     Config.options?.dock?.style === "m3"
    // Island is a complete Ricelin material. Pill and macOS are layout modes
    // that still inherit the selected global worldview (except ZZZ, whose shelf
    // intentionally wins as before).
    readonly property string surfaceDialect: Appearance.surfaceDialectFor(
        root.isIslandStyle ? "island" : "")
    readonly property bool zzzEverywhere: !root.isM3Style && root.surfaceDialect === "zzz"

    // Track bar position to force dock recreation when bar changes
    readonly property bool barIsVertical: Config.options?.bar?.bottom !== undefined
    // Key to force panel recreation when dock OR bar position changes
    property string _positionKey: `${root.position}_${barIsVertical}`

    Variants {
        model: {
            const screens = Quickshell.screens;
            const list = Config.options?.dock?.screenList ?? [];
            if (!list || list.length === 0)
                return screens;
            const matchedScreens = screens.filter(screen => {
                const screenName = screen?.name ?? "";
                return screenName.length > 0 && list.includes(screenName);
            });
            // Fallback safety: stale monitor names (e.g. output re-enumeration after VRR changes)
            // should never hide the dock on every screen.
            return matchedScreens.length > 0 ? matchedScreens : screens;
        }

        Loader {
            id: panelLoader
            required property var modelData
            active: true

            // Recrear cuando cambie la posición del dock o de la barra
            property string posKey: root._positionKey
            onPosKeyChanged: {
                active = false
                reloadTimer.start()
            }

            Timer {
                id: reloadTimer
                interval: 50
                onTriggered: panelLoader.active = true
            }

            sourceComponent: PanelWindow {
                id: dockRoot
                screen: panelLoader.modelData
                visible: !GlobalStates.screenLocked
                    && !GlobalStates.widgetEditMode

                property bool reveal: !GlobalStates.coverflowSelectorOpen
                    && !(GlobalStates.wallpaperLauncherOpen && root.position === "bottom")
                    && GlobalStates.shellEntryReady
                    && (ShellEditSession.active || root.pinned
                        || (Config.options?.dock?.hoverToReveal && dockMouseArea.containsMouse)
                        || (dockApps?.requestDockShow || dockAppsVertical?.requestDockShow)
                        || (Config.options?.dock?.showOnDesktop !== false
                            && !ToplevelManager.activeToplevel?.activated))

                // Shell edit resize previews locally and persists once on release.
                property real editThicknessPreview: -1
                property real _editResizeBaseline: -1
                readonly property real dockHeight: editThicknessPreview >= 0
                    ? editThicknessPreview
                    : (Config.options?.dock?.height ?? 70)

                function beginDockResize(): void {
                    const baseline = Config.options?.dock?.height ?? 70
                    if (!ShellEditSession.beginGesture("iiDock", "resize-thickness",
                            { thickness: baseline }))
                        return
                    dockRoot._editResizeBaseline = baseline
                    dockRoot.editThicknessPreview = baseline
                }

                function updateDockResize(deltaX: real, deltaY: real): void {
                    if (dockRoot._editResizeBaseline < 0)
                        return
                    const towardScreen = root.position === "bottom" ? -deltaY
                        : root.isTop ? deltaY
                        : root.isLeft ? deltaX : -deltaX
                    dockRoot.editThicknessPreview = Math.max(40, Math.min(200,
                        dockRoot._editResizeBaseline + towardScreen))
                }

                function finishDockResize(): void {
                    if (dockRoot.editThicknessPreview >= 0)
                        ShellLayoutController.setProperty("iiDock", "thickness",
                            dockRoot.editThicknessPreview, dockRoot.screen?.name ?? "")
                    dockRoot.editThicknessPreview = -1
                    dockRoot._editResizeBaseline = -1
                    ShellEditSession.finishGesture()
                }

                function cancelDockResize(): void {
                    dockRoot.editThicknessPreview = -1
                    dockRoot._editResizeBaseline = -1
                    ShellEditSession.cancelPending()
                }

                Connections {
                    target: ShellEditSession

                    function onGestureKindChanged(): void {
                        if (ShellEditSession.gestureKind.length > 0)
                            return
                        dockRoot.editThicknessPreview = -1
                        dockRoot._editResizeBaseline = -1
                    }
                }

                anchors {
                    top: root.isTop || root.isVertical
                    bottom: !root.isTop || root.isVertical
                    left: root.isLeft || !root.isVertical
                    right: !root.isLeft || !root.isVertical
                }

                exclusiveZone: root.pinned ? (dockHeight + Appearance.sizes.elevationMargin) : 0

                implicitWidth: root.isVertical ? (dockHeight + Appearance.sizes.elevationMargin + Appearance.sizes.hyprlandGapsOut) : dockBackground.implicitWidth
                implicitHeight: root.isVertical ? dockBackground.implicitHeight : (dockHeight + Appearance.sizes.elevationMargin + Appearance.sizes.hyprlandGapsOut)

                WlrLayershell.namespace: "quickshell:dock"
                color: "transparent"

                // The dock publishes one concrete Region item. Standard, macOS and
                // island capsules are exact rounded rectangles; the morphing pill and
                // sharp/chamfered ZZZ silhouettes keep their wallpaper material.
                readonly property string nativeBlurTopology: !root.isPillStyle
                    && !(root.zzzEverywhere && !Appearance.zzz.round)
                    ? Appearance.blurTopology.roundedRectangle
                    : Appearance.blurTopology.unsupported
                readonly property bool nativeBlurGeometryExact: Appearance.blurTopologyExact(
                    dockRoot.nativeBlurTopology)
                readonly property bool nativeBlurActive: Appearance.useCompositorBlur(
                        root.isIslandStyle ? "islands" : "dock", dockRoot.nativeBlurTopology)
                    && (Config.options?.dock?.showBackground ?? true)
                    && !Appearance.gameModeMinimal
                readonly property Item nativeBlurItem: root.isMacosStyle ? macBackground
                    : root.isIslandStyle ? dockIslandBackground : dockVisualBackground

                BackgroundEffect.blurRegion: Region {
                    item: dockRoot.nativeBlurActive ? dockRoot.nativeBlurItem : null
                    radius: dockRoot.nativeBlurItem?.radius ?? 0
                }

                mask: Region {
                    item: dockMouseArea
                }

                MouseArea {
                    id: dockMouseArea
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton

                    width: root.isVertical
                        ? parent.width
                        : (dockBackground.implicitWidth + Appearance.sizes.elevationMargin * 2)
                    height: root.isVertical
                        ? (dockBackground.implicitHeight + Appearance.sizes.elevationMargin * 2)
                        : parent.height

                    anchors {
                        top: root.position === "bottom" ? parent.top : undefined
                        bottom: root.isTop ? parent.bottom : undefined
                        left: root.position === "right" ? parent.left : undefined
                        right: root.isLeft ? parent.right : undefined
                        horizontalCenter: !root.isVertical ? parent.horizontalCenter : undefined
                        verticalCenter: root.isVertical ? parent.verticalCenter : undefined
                    }

                    property real hideOffset: dockRoot.reveal ? 0 : Config.options?.dock?.hoverToReveal ? (dockRoot.implicitHeight - (Config.options?.dock?.hoverRegionHeight ?? 5)) : (dockRoot.implicitHeight + 1)
                    property real hideOffsetV: dockRoot.reveal ? 0 : Config.options?.dock?.hoverToReveal ? (dockRoot.implicitWidth - (Config.options?.dock?.hoverRegionHeight ?? 5)) : (dockRoot.implicitWidth + 1)
                    
                    // Positive margins push content off-screen
                    anchors.topMargin: root.position === "bottom" ? hideOffset : 0
                    anchors.bottomMargin: root.isTop ? hideOffset : 0
                    anchors.leftMargin: root.position === "right" ? hideOffsetV : 0
                    anchors.rightMargin: root.isLeft ? hideOffsetV : 0

                    Behavior on anchors.topMargin { enabled: Appearance.animationsEnabled; animation: NumberAnimation { duration: Appearance.animation.elementMoveEnter.duration; easing.type: Appearance.animation.elementMoveEnter.type; easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve } }
                    Behavior on anchors.bottomMargin { enabled: Appearance.animationsEnabled; animation: NumberAnimation { duration: Appearance.animation.elementMoveEnter.duration; easing.type: Appearance.animation.elementMoveEnter.type; easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve } }
                    Behavior on anchors.leftMargin { enabled: Appearance.animationsEnabled; animation: NumberAnimation { duration: Appearance.animation.elementMoveEnter.duration; easing.type: Appearance.animation.elementMoveEnter.type; easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve } }
                    Behavior on anchors.rightMargin { enabled: Appearance.animationsEnabled; animation: NumberAnimation { duration: Appearance.animation.elementMoveEnter.duration; easing.type: Appearance.animation.elementMoveEnter.type; easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve } }

                    Item {
                        id: dockHoverRegion
                        anchors.fill: parent
                        // Remove binding loop - use dockRoot dimensions directly
                        // implicitWidth: dockBackground.implicitWidth
                        // implicitHeight: dockBackground.implicitHeight

                        // Mascot chaos: quakes and kicks rattle the dock too
                        property real _quakeY: 0
                        property real _quakeScale: 1
                        transform: Translate { y: dockHoverRegion._quakeY }
                        SequentialAnimation {
                            id: _dockQuakeAnim
                            NumberAnimation { target: dockHoverRegion; property: "_quakeY"; to: -6 * dockHoverRegion._quakeScale; duration: 60; easing.type: Easing.OutQuad }
                            NumberAnimation { target: dockHoverRegion; property: "_quakeY"; to: 4 * dockHoverRegion._quakeScale; duration: 70; easing.type: Easing.InOutQuad }
                            NumberAnimation { target: dockHoverRegion; property: "_quakeY"; to: -2 * dockHoverRegion._quakeScale; duration: 70; easing.type: Easing.InOutQuad }
                            NumberAnimation { target: dockHoverRegion; property: "_quakeY"; to: 0; duration: 90; easing.type: Easing.OutBack }
                        }
                        Connections {
                            target: MascotChaos
                            enabled: MascotChaos.enabled
                            function onPanelShake(intensity) {
                                dockHoverRegion._quakeScale = Math.max(1, intensity)
                                if (Appearance.animationsEnabled) _dockQuakeAnim.restart()
                            }
                        }

                        Item {
                            id: dockBackground

                            // Shell desaturation effect
                            layer.enabled: Appearance.shouldDesaturate("dock") && dockBackground.visible
                            layer.effect: ShellDesaturationEffect {}

                            anchors {
                                top: !root.isVertical ? parent.top : undefined
                                bottom: !root.isVertical ? parent.bottom : undefined
                                left: root.isVertical ? parent.left : undefined
                                right: root.isVertical ? parent.right : undefined
                                horizontalCenter: !root.isVertical ? parent.horizontalCenter : undefined
                                verticalCenter: root.isVertical ? parent.verticalCenter : undefined
                            }

                            // Use dockRoot dimensions to avoid binding loop
                            implicitWidth: root.isVertical ? (dockRoot.width - Appearance.sizes.elevationMargin - Appearance.sizes.hyprlandGapsOut) : (dockRow.implicitWidth + 10)
                            implicitHeight: root.isVertical ? (dockColumn.implicitHeight + 10) : (dockRoot.height - Appearance.sizes.elevationMargin - Appearance.sizes.hyprlandGapsOut)
                            width: implicitWidth
                            height: implicitHeight

                            StyledRectangularShadow {
                                target: dockVisualBackground
                                visible: (Config.options?.dock?.showBackground ?? true) && !Appearance.gameModeMinimal && !root.zzzEverywhere && !root.isPillStyle && !root.isMacosStyle && !root.isIslandStyle
                            }

                            // Island style carries its own surface (gradient card,
                            // hairline, top sheen) and its own shadow, exactly like
                            // the island bar. It replaces dockVisualBackground.
                            IslandPanel {
                                id: dockIslandBackground
                                anchors.fill: parent
                                anchors.topMargin: root.isTop ? Appearance.sizes.hyprlandGapsOut : (root.isVertical ? 0 : Appearance.sizes.elevationMargin)
                                anchors.bottomMargin: root.position === "bottom" ? Appearance.sizes.hyprlandGapsOut : (root.isVertical ? 0 : Appearance.sizes.elevationMargin)
                                anchors.leftMargin: root.isLeft ? Appearance.sizes.hyprlandGapsOut : (root.isVertical ? Appearance.sizes.elevationMargin : 0)
                                anchors.rightMargin: root.position === "right" ? Appearance.sizes.hyprlandGapsOut : (root.isVertical ? Appearance.sizes.elevationMargin : 0)
                                visible: (Config.options?.dock?.showBackground ?? true) && !Appearance.gameModeMinimal && root.isIslandStyle
                                glassEnabled: true
                                nativeBlurActive: dockRoot.nativeBlurActive
                                glassScreenWidth: dockRoot.screen?.width ?? 1920
                                glassScreenHeight: dockRoot.screen?.height ?? 1080
                                glassScreenX: root.isVertical
                                    ? (root.isLeft ? Appearance.sizes.hyprlandGapsOut : glassScreenWidth - width - Appearance.sizes.hyprlandGapsOut)
                                    : (glassScreenWidth - width) / 2
                                glassScreenY: root.isVertical
                                    ? (glassScreenHeight - height) / 2
                                    : (root.isTop ? Appearance.sizes.hyprlandGapsOut : glassScreenHeight - height - Appearance.sizes.hyprlandGapsOut)
                                // Docked panels round a touch harder than the bar;
                                // still follows the shared island skin knob.
                                radius: (Config.options?.appearance?.island?.radius ?? 18) + 4
                            }

                                Rectangle {
                                    id: dockVisualBackground
                                    property bool cardStyle: Config.options?.dock?.cardStyle ?? false
                                    readonly property bool zzzGlassActive: root.zzzEverywhere
                                        && Appearance.effectsEnabled
                                        && (Config.options?.appearance?.zzz?.glass ?? true)
                                    readonly property bool angelEverywhere: !root.isM3Style && root.surfaceDialect === "angel"
                                    readonly property bool auroraEverywhere: !root.isM3Style && (root.surfaceDialect === "aurora" || angelEverywhere)
                                    readonly property bool inirEverywhere: !root.isM3Style && root.surfaceDialect === "inir"
                                    readonly property bool gameModeMinimal: Appearance.gameModeMinimal
                                    readonly property string wallpaperUrl: {
                                        const _dep1 = WallpaperListener.multiMonitorEnabled
                                        const _dep2 = WallpaperListener.effectivePerMonitor
                                        const _dep3 = Wallpapers.effectiveWallpaperUrl
                                        return WallpaperListener.wallpaperUrlForScreen(dockRoot.screen)
                                    }

                                    ColorQuantizer {
                                        id: dockWallpaperQuantizer
                                        source: dockVisualBackground.auroraEverywhere ? dockVisualBackground.wallpaperUrl : ""
                                        depth: 0
                                        rescaleSize: 10
                                    }

                                    readonly property color wallpaperDominantColor: dockWallpaperQuantizer?.colors?.[0] ?? Appearance.colors.colPrimary
                                    readonly property QtObject blendedColors: AdaptedMaterialScheme {
                                        color: ColorUtils.mix(dockVisualBackground.wallpaperDominantColor, Appearance.colors.colPrimaryContainer, 0.8) || Appearance.colors.colSecondaryContainer
                                    }

                                    anchors.fill: parent
                                    anchors.topMargin: root.isTop ? Appearance.sizes.hyprlandGapsOut : (root.isVertical ? 0 : Appearance.sizes.elevationMargin)
                                    anchors.bottomMargin: root.position === "bottom" ? Appearance.sizes.hyprlandGapsOut : (root.isVertical ? 0 : Appearance.sizes.elevationMargin)
                                    anchors.leftMargin: root.isLeft ? Appearance.sizes.hyprlandGapsOut : (root.isVertical ? Appearance.sizes.elevationMargin : 0)
                                    anchors.rightMargin: root.position === "right" ? Appearance.sizes.hyprlandGapsOut : (root.isVertical ? Appearance.sizes.elevationMargin : 0)

                                // Hide shared background in pill mode — each pill is its own background
                                // Hide in macOS mode — DockMacBackground is the unified shelf
                                // Island is an explicit opt-in to the Ricelin dialect,
                                // so it replaces the zzz surface too (same rule as the
                                // islands bar).
                                visible: (Config.options?.dock?.showBackground ?? true) && !gameModeMinimal && ((root.zzzEverywhere && !root.isIslandStyle) || (!root.isPillStyle && !root.isMacosStyle && !root.isIslandStyle))
                                // ZZZ: the visible shelf is the chamfered ZzzPlate below.
                                color: root.isM3Style ? Appearance.colors.colLayer0
                                    : root.zzzEverywhere ? "transparent"
                                    : auroraEverywhere ? ColorUtils.applyAlpha(
                                        (blendedColors?.colLayer0 ?? Appearance.colors.colLayer0),
                                        dockRoot.nativeBlurActive ? 0.46 : 1)
                                    : inirEverywhere ? Appearance.inir.colLayer1
                                    : (cardStyle ? Appearance.colors.colLayer1 : Appearance.colors.colLayer0)
                                border.width: root.isM3Style ? 1
                                    : root.zzzEverywhere ? 0
                                    : angelEverywhere ? Appearance.angel.panelBorderWidth : 1
                                border.color: root.isM3Style ? Appearance.colors.colLayer0Border
                                    : root.zzzEverywhere ? "transparent"
                                    : angelEverywhere ? Appearance.angel.colPanelBorder
                                    : inirEverywhere ? Appearance.inir.colBorder
                                    : Appearance.colors.colLayer0Border
                                radius: root.isM3Style ? Appearance.rounding.normal + 6
                                    : root.zzzEverywhere ? Appearance.zzz.panelRadius
                                    : angelEverywhere ? Appearance.angel.roundingNormal
                                    : inirEverywhere ? Appearance.inir.roundingNormal
                                    : cardStyle ? Appearance.rounding.normal : Appearance.rounding.large
                                // Radius is a direct style binding. Adding a Behavior here
                                // installs a second interceptor when the dock Rectangle is
                                // rebuilt after an edge move, which Qt rejects at runtime.
                                Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                                Behavior on border.width { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                                Behavior on border.color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }

                                ZzzPlate {
                                    anchors.fill: parent
                                    z: -1
                                    visible: root.zzzEverywhere
                                    chamfer: Appearance.zzz.cutCorner
                                    chamferBottomRight: true
                                    chamferTopRight: false
                                    // Glass on: the wash below owns the fill (blurred
                                    // wallpaper + veil). A translucent fill here let the
                                    // SHARP wallpaper through instead of a blurred one.
                                    fillColor: dockVisualBackground.zzzGlassActive
                                        ? "transparent"
                                        : Appearance.zzz.chromeAlt
                                    strokeColor: Appearance.zzz.hairline
                                    strokeWidth: 1
                                }

                                ZzzGlassWash {
                                    anchors.fill: parent
                                    z: -2
                                    // dockVisualBackground.radius is a fixed small corner-soften
                                    // (Appearance.zzz.panelRadius), unrelated to round/square shape
                                    // mode. Passing it straight through forced this mask onto
                                    // ZzzPlate's ROUNDED renderer (radius>0 wins over chamfer),
                                    // so the wash ignored the chamfer and leaked past the real
                                    // chamfered shelf plate below. Only use it in round mode.
                                    maskRadius: Appearance.zzz.round ? dockVisualBackground.radius : 0
                                    chamfer: Appearance.zzz.cutCorner
                                    chamferTopRight: false
                                    chamferBottomRight: true
                                    glassEnabled: dockVisualBackground.zzzGlassActive
                                    selfBacked: true
                                    // The dock holds icons, not text — it can drink
                                    // more wallpaper than the bar without costing
                                    // legibility.
                                    veilAlpha: Appearance.zzz.dark ? 0.66 : 0.72
                                }

                                clip: true
                                layer.enabled: auroraEverywhere && !inirEverywhere && !root.zzzEverywhere
                                    && !gameModeMinimal && !dockRoot.nativeBlurActive
                                layer.effect: GE.OpacityMask {
                                    maskSource: Rectangle {
                                        width: dockVisualBackground.width
                                        height: dockVisualBackground.height
                                        radius: dockVisualBackground.radius
                                    }
                                }

                                Image {
                                    id: dockBlurredWallpaper
                                    x: root.isVertical 
                                        ? (root.isLeft ? 0 : (-(dockRoot.screen?.width ?? 1920) + dockVisualBackground.width + Appearance.sizes.hyprlandGapsOut))
                                        : (-(dockRoot.screen?.width ?? 1920) / 2 + dockVisualBackground.width / 2)
                                    y: root.isVertical 
                                        ? (-(dockRoot.screen?.height ?? 1080) / 2 + dockVisualBackground.height / 2)
                                        : (root.isTop ? 0 : (-(dockRoot.screen?.height ?? 1080) + dockVisualBackground.height + Appearance.sizes.hyprlandGapsOut))
                                    width: dockRoot.screen?.width ?? 1920
                                    height: dockRoot.screen?.height ?? 1080
                                    visible: dockVisualBackground.auroraEverywhere
                                        && !dockVisualBackground.inirEverywhere
                                        && !root.zzzEverywhere
                                        && !dockVisualBackground.gameModeMinimal
                                        && !dockRoot.nativeBlurActive
                                    // An invisible Image still decodes its source: gate it too,
                                    // or non-aurora users keep a screen-sized wallpaper resident.
                                    source: visible ? dockVisualBackground.wallpaperUrl : ""
                                    fillMode: Image.PreserveAspectCrop
                                    cache: true
                                    sourceSize.width: dockRoot.screen?.width ?? 1920
                                    sourceSize.height: dockRoot.screen?.height ?? 1080
                                    asynchronous: true

                                    // See #159 — skip QML blur when compositor blur covers this layer
                                    layer.enabled: Appearance.effectsEnabled && dockVisualBackground.auroraEverywhere && !dockVisualBackground.inirEverywhere && !dockVisualBackground.gameModeMinimal && !dockRoot.nativeBlurActive
                                    layer.effect: MultiEffect {
                                        source: dockBlurredWallpaper
                                        anchors.fill: source
                                        saturation: dockVisualBackground.angelEverywhere
                                            ? (Appearance.angel.blurSaturation * Appearance.angel.colorStrength)
                                            : (Appearance.effectsEnabled ? 0.2 : 0)
                                        blurEnabled: Appearance.effectsEnabled
                                        blurMax: 64
                                        blur: Appearance.effectsEnabled
                                            ? (dockVisualBackground.angelEverywhere ? Appearance.angel.blurIntensity : 1)
                                            : 0
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        color: dockVisualBackground.angelEverywhere
                                            ? ColorUtils.transparentize((dockVisualBackground.blendedColors?.colLayer0 ?? Appearance.colors.colLayer0Base), Appearance.angel.overlayOpacity * Appearance.angel.panelTransparentize)
                                            : ColorUtils.transparentize((dockVisualBackground.blendedColors?.colLayer0 ?? Appearance.colors.colLayer0Base), Appearance.aurora.overlayTransparentize)
                                    }
                                }

                                AngelPartialBorder {
                                    visible: dockVisualBackground.angelEverywhere
                                    targetRadius: dockVisualBackground.radius
                                }

                            }

                             // macOS unified shelf background — visible only in macOS style
                               DockMacBackground {
                                   id: macBackground
                                   visible: (Config.options?.dock?.showBackground ?? true)
                                            && root.isMacosStyle && !root.zzzEverywhere && !Appearance.gameModeMinimal
                                   anchors.fill: parent
                                   anchors.topMargin:    root.isTop     ? Appearance.sizes.hyprlandGapsOut : (root.isVertical ? 0 : Appearance.sizes.elevationMargin)
                                   anchors.bottomMargin: root.position === "bottom" ? Appearance.sizes.hyprlandGapsOut : (root.isVertical ? 0 : Appearance.sizes.elevationMargin)
                                   anchors.leftMargin:   root.isLeft   ? Appearance.sizes.hyprlandGapsOut : (root.isVertical ? Appearance.sizes.elevationMargin : 0)
                                   anchors.rightMargin:  root.position === "right" ? Appearance.sizes.hyprlandGapsOut : (root.isVertical ? Appearance.sizes.elevationMargin : 0)
                                   dockHeight:    dockRoot.dockHeight
                                   vertical:      root.isVertical
                                   wallpaperUrl:  dockVisualBackground.wallpaperUrl
                                   dockScreen:    dockRoot.screen
                                   nativeBlurActive: dockRoot.nativeBlurActive
                                   surfaceDialect: root.surfaceDialect
                                   blendedLayer0: dockVisualBackground.blendedColors?.colLayer0 ?? Appearance.colors.colLayer0
                               }

                            RowLayout {
                                id: dockRow
                                visible: !root.isVertical
                                anchors.centerIn: (root.isMacosStyle && !root.zzzEverywhere) ? macBackground : dockVisualBackground
                                spacing: root.isM3Style ? 3 : (root.zzzEverywhere ? 5 : 2)
                                property real padding: root.zzzEverywhere ? 7 : 5

                                DockApps {
                                    id: dockApps
                                    enabled: !root.isVertical
                                    buttonPadding: dockRow.padding
                                    vertical: false
                                    dockPosition: root.position
                                    parentWindow: dockRoot
                                }
                                DockButton {
                                    vertical: false
                                    dockPosition: root.position
                                    onClicked: GlobalStates.toggleOverview(dockRoot.screen?.name ?? "")
                                    contentItem: MaterialSymbol {
                                        anchors.centerIn: parent
                                        font.pixelSize: parent.width * 0.5
                                        text: "apps"
                                        color: root.zzzEverywhere ? Appearance.zzz.ink : Appearance.colors.colOnLayer0
                                        Behavior on color {
                                            enabled: Appearance.animationsEnabled
                                            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                                        }
                                    }
                                }
                            }

                              ColumnLayout {
                                  id: dockColumn
                                  visible: root.isVertical
                                  anchors.centerIn: (root.isMacosStyle && !root.zzzEverywhere) ? macBackground : dockVisualBackground
                                spacing: root.isM3Style ? 3 : (root.zzzEverywhere ? 5 : 2)
                                property real padding: root.zzzEverywhere ? 7 : 5

                                DockApps {
                                    id: dockAppsVertical
                                    enabled: root.isVertical
                                    buttonPadding: dockColumn.padding
                                    vertical: true
                                    dockPosition: root.position
                                    parentWindow: dockRoot
                                }
                                DockButton {
                                    vertical: true
                                    dockPosition: root.position
                                    onClicked: GlobalStates.toggleOverview(dockRoot.screen?.name ?? "")
                                    contentItem: MaterialSymbol {
                                        anchors.centerIn: parent
                                        font.pixelSize: parent.width * 0.5
                                        text: "apps"
                                        color: root.zzzEverywhere ? Appearance.zzz.ink : Appearance.colors.colOnLayer0
                                        Behavior on color {
                                            enabled: Appearance.animationsEnabled
                                            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    ShellEditSurfaceFrame {
                        id: dockEditFrame
                        // Hug the visible dock body, not the transparent
                        // hover/elevation region around it.
                        readonly property Item visualTarget: dockRoot.nativeBlurItem
                            ?? dockBackground
                        // Keep every dependency explicit. mapToItem() hides the
                        // target's anchor changes from QML's binding tracker and
                        // left stale frame origins after dock content reflowed.
                        x: Math.round(dockBackground.x + visualTarget.x)
                        y: Math.round(dockBackground.y + visualTarget.y)
                        width: Math.round(visualTarget.width)
                        height: Math.round(visualTarget.height)
                        surfaceId: "iiDock"
                        label: Translation.tr("Dock")
                        active: ShellEditSession.blocksNormalActions(surfaceId)
                        selected: ShellEditSession.selectedSurfaceId === surfaceId
                        lifted: ShellEditSession.liftedSurfaceId === surfaceId
                        slotHint: Config.options?.dock?.position ?? "bottom"
                        screenWidth: dockRoot.screen?.width ?? 0
                        screenHeight: dockRoot.screen?.height ?? 0
                        onDragStarted: surface => ShellEditSession.beginDrag(surface)
                        onDragMoved: (surface, screenX, screenY) =>
                            ShellEditSession.updateDrag(screenX, screenY)
                        onDragEnded: () => ShellEditSession.endDrag()
                        onDragCanceled: () => ShellEditSession.cancelDrag()
                        accentColor: Appearance.colors.colPrimary
                        surfaceColor: Appearance.colors.colLayer2
                        textColor: Appearance.colors.colOnLayer2
                        frameRadius: Appearance.rounding.small
                        fontFamily: Appearance.font.family.main
                        fontPixelSize: Appearance.font.pixelSize.smaller
                        animationDuration: Appearance.animationsEnabled
                            ? Appearance.animation.elementMoveFast.duration : 0
                        onActivated: surface => ShellEditSession.selectSurface(surface)
                    }

                    ShellEditResizeHandle {
                        z: 11000
                        width: root.isVertical ? 20 : 96
                        height: root.isVertical ? 96 : 20
                        anchors {
                            horizontalCenter: root.isVertical
                                ? (root.isLeft ? dockEditFrame.right : dockEditFrame.left)
                                : dockEditFrame.horizontalCenter
                            verticalCenter: root.isVertical
                                ? dockEditFrame.verticalCenter
                                : (root.isTop ? dockEditFrame.bottom : dockEditFrame.top)
                        }
                        axis: root.isVertical ? "horizontal" : "vertical"
                        active: ShellEditSession.active
                            && ShellEditSession.selectedSurfaceId === "iiDock"
                            && ShellEditSession.liftedSurfaceId.length === 0
                        accentColor: Appearance.colors.colPrimary
                        surfaceColor: Appearance.colors.colLayer2
                        animationsEnabled: Appearance.animationsEnabled
                        radius: Appearance.rounding.full
                        onDragStarted: dockRoot.beginDockResize()
                        onDragged: (axis, deltaX, deltaY) =>
                            dockRoot.updateDockResize(deltaX, deltaY)
                        onDragFinished: dockRoot.finishDockResize()
                        onDragCanceled: dockRoot.cancelDockResize()
                    }

                    ShellEditSizeBadge {
                        z: 12000
                        anchors.centerIn: dockEditFrame
                        active: dockRoot.editThicknessPreview >= 0
                        valueText: Math.round(dockRoot.dockHeight) + " px"
                        accentColor: Appearance.colors.colPrimary
                        surfaceColor: Appearance.colors.colLayer2
                        textColor: Appearance.colors.colOnLayer2
                        fontFamily: Appearance.font.family.main
                        fontPixelSize: Appearance.font.pixelSize.smaller
                    }
                }
            }
        }
    }
}
