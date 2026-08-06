pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.UPower
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Scope {
    id: bar
    property bool showBarBackground: Config.options?.bar?.showBackground ?? true

    Variants {
        // For each monitor
        model: {
            const screens = Quickshell.screens;
            const list = Config.options?.bar?.screenList ?? [];
            if (!list || list.length === 0)
                return screens;
            const matchedScreens = screens.filter(screen => {
                const screenName = screen?.name ?? "";
                return screenName.length > 0 && list.includes(screenName);
            });
            // Fallback safety: stale monitor names (e.g. output re-enumeration after VRR changes)
            // should never hide the bar on every screen.
            return matchedScreens.length > 0 ? matchedScreens : screens;
        }
        LazyLoader {
            id: barLoader
            active: GlobalStates.barOpen && !GlobalStates.screenLocked
                && !GlobalStates.widgetEditMode
            required property ShellScreen modelData
            component: PanelWindow { // Bar window
                id: barRoot
                screen: barLoader.modelData
                visible: true

                property var brightnessMonitor: Brightness.getMonitorForScreen(barLoader.modelData)
                
                Timer {
                    id: showBarTimer
                    interval: (Config?.options.bar.autoHide.showWhenPressingSuper.delay ?? 100)
                    repeat: false
                    onTriggered: {
                        barRoot.superShow = true
                    }
                }
                Connections {
                    target: GlobalStates
                    function onSuperDownChanged() {
                        if (!Config?.options.bar.autoHide.showWhenPressingSuper.enable) return;
                        if (GlobalStates.superDown) showBarTimer.restart();
                        else {
                            showBarTimer.stop();
                            barRoot.superShow = false;
                        }
                    }
                }
                property bool superShow: false
                property bool mustShow: hoverRegion.containsMouse || superShow
                    || ShellEditSession.active
                exclusionMode: ExclusionMode.Ignore
                exclusiveZone:
                    (GlobalStates.coverflowSelectorOpen || (Config?.options.bar.autoHide.enable && (!mustShow || !Config?.options.bar.autoHide.pushWindows))) ? 0 :
                    Appearance.sizes.baseVerticalBarWidth + ((Config.options?.bar?.cornerStyle ?? 0) === 1 ? Appearance.sizes.hyprlandGapsOut : 0)
                WlrLayershell.namespace: "quickshell:verticalBar"
                // Default Top layer ON PURPOSE: fullscreen surfaces render
                // above Top, so videos/games naturally cover the bar. Overlay
                // would draw the bar over fullscreen content (GameMode only
                // detects games, not videos).
                implicitWidth: Appearance.sizes.verticalBarWidth + Appearance.rounding.screenRounding
                mask: Region {
                    item: hoverMaskRegion
                }
                color: "transparent"

                BackgroundEffect.blurRegion: Region {
                    item: barContent.nativeBlurActive ? barContent.backgroundItem : null
                    radius: barContent.backgroundItem.radius
                }

                anchors {
                    left: !(Config.options?.bar?.bottom ?? false)
                    right: (Config.options?.bar?.bottom ?? false)
                    top: true
                    bottom: true
                }

                // Focus grab is handled by layer shell (PanelWindow)

                MouseArea  {
                    id: hoverRegion
                    hoverEnabled: true
                    anchors.fill: parent

                    Item {
                        id: hoverMaskRegion
                        anchors {
                            fill: barContent
                            leftMargin: -(Config.options?.bar?.autoHide?.hoverRegionWidth ?? 2)
                            rightMargin: -(Config.options?.bar?.autoHide?.hoverRegionWidth ?? 2)
                        }
                    }

                    VerticalBarContent {
                        id: barContent

                        implicitWidth: Appearance.sizes.verticalBarWidth
                        anchors {
                            top: parent.top
                            bottom: parent.bottom
                            left: parent.left
                            right: undefined
                            leftMargin: ((Config?.options.bar.autoHide.enable && !mustShow) || GlobalStates.coverflowSelectorOpen || !GlobalStates.shellEntryReady) ? -Appearance.sizes.verticalBarWidth : 0
                            rightMargin: 0
                        }
                        Behavior on anchors.leftMargin {
                            animation: NumberAnimation { duration: Appearance.animation.elementMoveEnter.duration; easing.type: Appearance.animation.elementMoveEnter.type; easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve }
                        }
                        Behavior on anchors.rightMargin {
                            animation: NumberAnimation { duration: Appearance.animation.elementMoveEnter.duration; easing.type: Appearance.animation.elementMoveEnter.type; easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve }
                        }

                        states: State {
                            name: "right"
                            when: (Config.options?.bar?.bottom ?? false)
                            AnchorChanges {
                                target: barContent
                                anchors {
                                    top: parent.top
                                    bottom: parent.bottom
                                    left: undefined
                                    right: parent.right
                                }
                            }
                            PropertyChanges {
                                target: barContent
                                anchors.topMargin: 0
                                anchors.rightMargin: ((Config?.options.bar.autoHide.enable && !mustShow) || GlobalStates.coverflowSelectorOpen || !GlobalStates.shellEntryReady) ? -Appearance.sizes.verticalBarWidth : 0
                            }
                        }
                    }

                    ShellEditSurfaceFrame {
                        anchors.fill: barContent
                        surfaceId: "iiBar"
                        label: Translation.tr("Bar")
                        active: ShellEditSession.blocksNormalActions(surfaceId)
                        selected: ShellEditSession.selectedSurfaceId === surfaceId
                        lifted: ShellEditSession.liftedSurfaceId === surfaceId
                        slotHint: (Config.options?.bar?.bottom ?? false) ? "right" : "left"
                        screenWidth: barRoot.screen?.width ?? 0
                        screenHeight: barRoot.screen?.height ?? 0
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

                    // Round decorators
                    Loader {
                        id: roundDecorators
                        anchors {
                            top: parent.top
                            bottom: parent.bottom
                            left: barContent.right
                            right: undefined
                        }
                        width: Appearance.rounding.screenRounding
                        active: showBarBackground && (Config.options?.bar?.cornerStyle ?? 0) === 0 && !Appearance.zzzEverywhere

                        states: State {
                            name: "right"
                            when: (Config.options?.bar?.bottom ?? false)
                            AnchorChanges {
                                target: roundDecorators
                                anchors {
                                    top: parent.top
                                    bottom: parent.bottom
                                    left: undefined
                                    right: barContent.left
                                }
                            }
                        }

                        sourceComponent: Item {
                            id: hugDecorators
                            implicitHeight: Appearance.rounding.screenRounding

                            readonly property bool isInir: Appearance.inirEverywhere
                            readonly property bool isAurora: Appearance.auroraEverywhere
                            readonly property bool isRight: Config.options?.bar?.bottom ?? false
                            // Color must match the bar background color exactly
                            readonly property color solidColor: showBarBackground
                                ? (isInir ? Appearance.inir.colLayer0
                                    : isAurora ? Appearance.aurora.colPopupSurface
                                    : Appearance.colors.colLayer0)
                                : "transparent"

                            // Top corner - solid for Material/Inir
                            RoundCorner {
                                id: topCorner
                                visible: !hugDecorators.isAurora
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    top: parent.top
                                }

                                implicitSize: Appearance.rounding.screenRounding
                                color: hugDecorators.solidColor

                                corner: RoundCorner.CornerEnum.TopLeft
                                states: State {
                                    name: "right"
                                    when: hugDecorators.isRight
                                    PropertyChanges {
                                        topCorner.corner: RoundCorner.CornerEnum.TopRight
                                    }
                                }
                            }

                            // Bottom corner - solid for Material/Inir
                            RoundCorner {
                                id: bottomCorner
                                visible: !hugDecorators.isAurora
                                anchors {
                                    bottom: parent.bottom
                                    left: !hugDecorators.isRight ? parent.left : undefined
                                    right: hugDecorators.isRight ? parent.right : undefined
                                }
                                implicitSize: Appearance.rounding.screenRounding
                                color: hugDecorators.solidColor

                                corner: RoundCorner.CornerEnum.BottomLeft
                                states: State {
                                    name: "right"
                                    when: hugDecorators.isRight
                                    PropertyChanges {
                                        bottomCorner.corner: RoundCorner.CornerEnum.BottomRight
                                    }
                                }
                            }

                            // Aurora blur corners
                            Loader {
                                active: hugDecorators.isAurora
                                anchors.fill: parent
                                sourceComponent: Item {
                                    id: auroraCorners

                                    component AuroraBlurCorner: Item {
                                        id: blurCorner
                                        property int corner: RoundCorner.CornerEnum.TopLeft
                                        property real cornerSize: Appearance.rounding.screenRounding

                                        readonly property bool isLeft: corner === RoundCorner.CornerEnum.TopLeft || corner === RoundCorner.CornerEnum.BottomLeft
                                        readonly property bool isTop: corner === RoundCorner.CornerEnum.TopLeft || corner === RoundCorner.CornerEnum.TopRight

                                        width: cornerSize
                                        height: cornerSize
                                        clip: true

                                        // Solid background matching BarContent
                                        Rectangle {
                                            anchors.fill: parent
                                            color: ColorUtils.applyAlpha((barContent.blendedColors?.colLayer0 ?? Appearance.colors.colLayer0), 1)
                                        }

                                        // Blur background
                                        Image {
                                            id: blurImg
                                            // Position relative to screen for vertical bar
                                            x: hugDecorators.isRight
                                                ? (-(barRoot.screen?.width ?? 1920) + Appearance.sizes.verticalBarWidth)
                                                : (-Appearance.sizes.verticalBarWidth)
                                            y: blurCorner.isTop ? 0 : -(barRoot.screen?.height ?? 1080) + blurCorner.cornerSize
                                            width: barRoot.screen?.width ?? 1920
                                            height: barRoot.screen?.height ?? 1080
                                            source: Wallpapers.effectiveWallpaperUrl
                                            fillMode: Image.PreserveAspectCrop
                                            cache: true
                                            sourceSize.width: barRoot.screen?.width ?? 1920
                                            sourceSize.height: barRoot.screen?.height ?? 1080
                                            asynchronous: true

                                            // See #159 — skip QML blur when compositor blur covers this layer
                                            layer.enabled: Appearance.effectsEnabled && Appearance.auroraEverywhere && !barContent.nativeBlurActive
                                            layer.effect: MultiEffect {
                                                source: blurImg
                                                anchors.fill: source
                                                saturation: Appearance.angelEverywhere
                                                    ? Appearance.angel.blurSaturation
                                                    : (Appearance.effectsEnabled ? 0.2 : 0)
                                                blurEnabled: Appearance.effectsEnabled
                                                blurMax: 64
                                                blur: Appearance.effectsEnabled ? 1 : 0
                                            }

                                            Rectangle {
                                                anchors.fill: parent
                                                color: Appearance.angelEverywhere
                                                    ? ColorUtils.transparentize((barContent.blendedColors?.colLayer0 ?? Appearance.colors.colLayer0Base), Appearance.angel.overlayOpacity)
                                                    : ColorUtils.transparentize((barContent.blendedColors?.colLayer0 ?? Appearance.colors.colLayer0Base), Appearance.aurora.overlayTransparentize)
                                            }
                                        }

                                        // Mask to corner shape
                                        layer.enabled: true
                                        layer.effect: GE.OpacityMask {
                                            maskSource: RoundCorner {
                                                width: blurCorner.width
                                                height: blurCorner.height
                                                implicitSize: blurCorner.cornerSize
                                                corner: blurCorner.corner
                                                color: "white"
                                            }
                                        }
                                    }

                                    AuroraBlurCorner {
                                        anchors.left: !hugDecorators.isRight ? parent.left : undefined
                                        anchors.right: hugDecorators.isRight ? parent.right : undefined
                                        anchors.top: parent.top
                                        corner: hugDecorators.isRight ? RoundCorner.CornerEnum.TopRight : RoundCorner.CornerEnum.TopLeft
                                    }

                                    AuroraBlurCorner {
                                        anchors.left: !hugDecorators.isRight ? parent.left : undefined
                                        anchors.right: hugDecorators.isRight ? parent.right : undefined
                                        anchors.bottom: parent.bottom
                                        corner: hugDecorators.isRight ? RoundCorner.CornerEnum.BottomRight : RoundCorner.CornerEnum.BottomLeft
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // IPC target "bar" is registered once in shell.qml (always loaded, family-
    // agnostic). See the note in Bar.qml — both bars coexist under the ii
    // family, so a handler here would collide with the horizontal bar's.

    Loader {
        active: CompositorService.isHyprland
        sourceComponent: Item {
            GlobalShortcut {
                name: "barToggle"
                description: "Toggles bar on press"

                onPressed: {
                    GlobalStates.barOpen = !GlobalStates.barOpen;
                }
            }

            GlobalShortcut {
                name: "barOpen"
                description: "Opens bar on press"

                onPressed: {
                    GlobalStates.barOpen = true;
                }
            }

            GlobalShortcut {
                name: "barClose"
                description: "Closes bar on press"

                onPressed: {
                    GlobalStates.barOpen = false;
                }
            }
        }
    }
}
