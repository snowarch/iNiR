import QtQuick
import Qt5Compat.GraphicalEffects as GE
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Scope {
    id: bar
    property bool showBarBackground: Config.options?.bar?.showBackground ?? true
    // Note: Vignette effect moved to Backdrop.qml (backdrop wallpaper layer)

    Variants {
        // For each monitor
        model: {
            const screens = Quickshell.screens;
            const list = Config.options?.bar?.screenList ?? [];
            if (!list || list.length === 0)
                return screens;
            return screens.filter(screen => list.includes(screen.name));
        }
        LazyLoader {
            id: barLoader
            active: GlobalStates.barOpen && !GlobalStates.screenLocked
            required property ShellScreen modelData
            component: PanelWindow { // Bar window
                id: barRoot
                screen: barLoader.modelData

                property var brightnessMonitor: Brightness.getMonitorForScreen(barLoader.modelData)
                property real useShortenedForm: (Appearance.sizes.barHellaShortenScreenWidthThreshold >= screen.width) ? 2 : (Appearance.sizes.barShortenScreenWidthThreshold >= screen.width) ? 1 : 0
                readonly property int centerSideModuleWidth: (useShortenedForm == 2) ? Appearance.sizes.barCenterSideModuleWidthHellaShortened : (useShortenedForm == 1) ? Appearance.sizes.barCenterSideModuleWidthShortened : Appearance.sizes.barCenterSideModuleWidth

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
                exclusionMode: ExclusionMode.Ignore
                exclusiveZone: (Config?.options.bar.autoHide.enable && (!mustShow || !Config?.options.bar.autoHide.pushWindows)) ? 0 :
                    Appearance.sizes.baseBarHeight + ((((Config.options?.bar?.cornerStyle ?? 0) === 1) || ((Config.options?.bar?.cornerStyle ?? 0) === 3)) ? (Appearance.sizes.hyprlandGapsOut * 2) : 0)
                WlrLayershell.namespace: "quickshell:bar"
                implicitHeight: Appearance.sizes.barHeight + Appearance.rounding.screenRounding
                mask: Region {
                    item: hoverMaskRegion
                }
                color: "transparent"

                anchors {
                    top: !(Config.options?.bar?.bottom ?? false)
                    bottom: (Config.options?.bar?.bottom ?? false)
                    left: true
                    right: true
                }

                margins {
                    right: ((Config.options?.interactions?.deadPixelWorkaround?.enable ?? false) && barRoot.anchors.right) * -1
                    bottom: ((Config.options?.interactions?.deadPixelWorkaround?.enable ?? false) && barRoot.anchors.bottom) * -1
                }

                MouseArea  {
                    id: hoverRegion
                    hoverEnabled: true
                    property alias barContent: barContent
                    anchors {
                        fill: parent
                        rightMargin: ((Config.options?.interactions?.deadPixelWorkaround?.enable ?? false) && barRoot.anchors.right) * 1
                        bottomMargin: ((Config.options?.interactions?.deadPixelWorkaround?.enable ?? false) && barRoot.anchors.bottom) * 1
                    }

                    Item {
                        id: hoverMaskRegion
                        anchors {
                            fill: barContent
                            topMargin: -(Config.options?.bar?.autoHide?.hoverRegionWidth ?? 2)
                            bottomMargin: -(Config.options?.bar?.autoHide?.hoverRegionWidth ?? 2)
                        }
                    }

                    BarContent {
                        id: barContent
                        
                        implicitHeight: Appearance.sizes.barHeight
                        anchors {
                            right: parent.right
                            left: parent.left
                            top: parent.top
                            bottom: undefined
                            topMargin: (Config?.options.bar.autoHide.enable && !mustShow) ? -Appearance.sizes.barHeight : 0
                            bottomMargin: ((Config.options?.interactions?.deadPixelWorkaround?.enable ?? false) && barRoot.anchors.bottom) * -1
                            rightMargin: ((Config.options?.interactions?.deadPixelWorkaround?.enable ?? false) && barRoot.anchors.right) * -1
                        }
                        Behavior on anchors.topMargin {
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }
                        Behavior on anchors.bottomMargin {
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }

                        states: State {
                            name: "bottom"
                            when: (Config.options?.bar?.bottom ?? false)
                            AnchorChanges {
                                target: barContent
                                anchors {
                                    right: parent.right
                                    left: parent.left
                                    top: undefined
                                    bottom: parent.bottom
                                }
                            }
                            PropertyChanges {
                                target: barContent
                                anchors.topMargin: 0
                                anchors.bottomMargin: (Config?.options.bar.autoHide.enable && !mustShow) ? -Appearance.sizes.barHeight : 0
                            }
                        }
                    }

                    // Round decorators
                    Loader {
                        id: roundDecorators
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: barContent.bottom
                            bottom: undefined
                        }
                        height: Appearance.rounding.screenRounding
                        active: showBarBackground && (Config.options?.bar?.cornerStyle ?? 0) === 0 // Hug

                        states: State {
                            name: "bottom"
                            when: (Config.options?.bar?.bottom ?? false)
                            AnchorChanges {
                                target: roundDecorators
                                anchors {
                                    right: parent.right
                                    left: parent.left
                                    top: undefined
                                    bottom: barContent.top
                                }
                            }
                        }

                        sourceComponent: Item {
                            id: hugDecorators
                            implicitHeight: Appearance.rounding.screenRounding
                            
                            readonly property bool isAurora: Appearance.auroraEverywhere
                            readonly property bool isInir: Appearance.inirEverywhere
                            readonly property bool isBottom: Config.options?.bar?.bottom ?? false
                            readonly property color solidColor: showBarBackground 
                                ? (isInir ? Appearance.inir.colLayer0 
                                    : isAurora ? Appearance.aurora.colPopupSurface
                                    : Appearance.colors.colLayer0) 
                                : "transparent"
                            
                            // Left corner - solid for Material/Inir, blur for Aurora
                            RoundCorner {
                                id: leftCorner
                                visible: !hugDecorators.isAurora
                                anchors {
                                    top: parent.top
                                    bottom: parent.bottom
                                    left: parent.left
                                }

                                implicitSize: Appearance.rounding.screenRounding
                                color: hugDecorators.solidColor

                                corner: RoundCorner.CornerEnum.TopLeft
                                states: State {
                                    name: "bottom"
                                    when: hugDecorators.isBottom
                                    PropertyChanges {
                                        leftCorner.corner: RoundCorner.CornerEnum.BottomLeft
                                    }
                                }
                            }
                            
                            // Right corner - solid for Material/Inir
                            RoundCorner {
                                id: rightCorner
                                visible: !hugDecorators.isAurora
                                anchors {
                                    right: parent.right
                                    top: !hugDecorators.isBottom ? parent.top : undefined
                                    bottom: hugDecorators.isBottom ? parent.bottom : undefined
                                }
                                implicitSize: Appearance.rounding.screenRounding
                                color: hugDecorators.solidColor

                                corner: RoundCorner.CornerEnum.TopRight
                                states: State {
                                    name: "bottom"
                                    when: hugDecorators.isBottom
                                    PropertyChanges {
                                        rightCorner.corner: RoundCorner.CornerEnum.BottomRight
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
                                            // Position relative to screen
                                            x: blurCorner.isLeft ? 0 : -(barRoot.screen?.width ?? 1920) + blurCorner.cornerSize
                                            y: hugDecorators.isBottom 
                                                ? (-(barRoot.screen?.height ?? 1080) + Appearance.sizes.barHeight)
                                                : (-Appearance.sizes.barHeight)
                                            width: barRoot.screen?.width ?? 1920
                                            height: barRoot.screen?.height ?? 1080
                                            source: Wallpapers.effectiveWallpaperUrl
                                            fillMode: Image.PreserveAspectCrop
                                            cache: true
                                            asynchronous: true
                                            
                                            layer.enabled: Appearance.effectsEnabled
                                            layer.effect: StyledBlurEffect {
                                                source: blurImg
                                            }
                                            
                                            Rectangle {
                                                anchors.fill: parent
                                                color: ColorUtils.transparentize((barContent.blendedColors?.colLayer0 ?? Appearance.colors.colLayer0Base), Appearance.aurora.overlayTransparentize)
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
                                        anchors.left: parent.left
                                        anchors.top: !hugDecorators.isBottom ? parent.top : undefined
                                        anchors.bottom: hugDecorators.isBottom ? parent.bottom : undefined
                                        corner: hugDecorators.isBottom ? RoundCorner.CornerEnum.BottomLeft : RoundCorner.CornerEnum.TopLeft
                                    }
                                    
                                    AuroraBlurCorner {
                                        anchors.right: parent.right
                                        anchors.top: !hugDecorators.isBottom ? parent.top : undefined
                                        anchors.bottom: hugDecorators.isBottom ? parent.bottom : undefined
                                        corner: hugDecorators.isBottom ? RoundCorner.CornerEnum.BottomRight : RoundCorner.CornerEnum.TopRight
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "bar"

        function toggle(): void {
            GlobalStates.barOpen = !GlobalStates.barOpen
        }

        function close(): void {
            GlobalStates.barOpen = false
        }

        function open(): void {
            GlobalStates.barOpen = true
        }
    }

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
