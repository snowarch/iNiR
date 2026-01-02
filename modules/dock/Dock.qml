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

Scope {
    id: root
    property bool pinned: Config.options?.dock?.pinnedOnStartup ?? false
    readonly property string position: Config.options?.dock?.position ?? "bottom"
    readonly property bool isVertical: root.position === "left" || root.position === "right"
    readonly property bool isTop: root.position === "top"
    readonly property bool isLeft: root.position === "left"
    
    // Key para forzar recreación del panel cuando cambia posición
    property string _positionKey: root.position

    Variants {
        model: Quickshell.screens

        Loader {
            id: panelLoader
            required property var modelData
            active: true
            
            // Recrear cuando cambie la posición
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

                property bool reveal: root.pinned || (Config.options?.dock?.hoverToReveal && dockMouseArea.containsMouse) || dockApps.requestDockShow || (!ToplevelManager.activeToplevel?.activated)

                readonly property real dockHeight: Config.options?.dock?.height ?? 70

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

                mask: Region { item: dockMouseArea }

                MouseArea {
                    id: dockMouseArea
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton

                    width: root.isVertical ? parent.width : undefined
                    height: root.isVertical ? undefined : parent.height
                    implicitWidth: root.isVertical ? parent.width : (dockBackground.implicitWidth + Appearance.sizes.elevationMargin * 2)
                    implicitHeight: root.isVertical ? (dockBackground.implicitHeight + Appearance.sizes.elevationMargin * 2) : parent.height

                    anchors {
                        top: root.isTop ? parent.top : (!root.isVertical ? parent.top : undefined)
                        bottom: root.position === "bottom" ? parent.bottom : (!root.isVertical ? parent.bottom : undefined)
                        left: root.isLeft ? parent.left : (root.isVertical ? parent.left : undefined)
                        right: root.position === "right" ? parent.right : (root.isVertical ? parent.right : undefined)
                        horizontalCenter: !root.isVertical ? parent.horizontalCenter : undefined
                        verticalCenter: root.isVertical ? parent.verticalCenter : undefined
                    }

                    property real hideOffset: dockRoot.reveal ? 0 : Config.options?.dock?.hoverToReveal ? (dockRoot.implicitHeight - (Config.options?.dock?.hoverRegionHeight ?? 5)) : (dockRoot.implicitHeight + 1)
                    property real hideOffsetV: dockRoot.reveal ? 0 : Config.options?.dock?.hoverToReveal ? (dockRoot.implicitWidth - (Config.options?.dock?.hoverRegionHeight ?? 5)) : (dockRoot.implicitWidth + 1)
                    
                    anchors.topMargin: root.isTop ? -hideOffset : 0
                    anchors.bottomMargin: root.position === "bottom" ? -hideOffset : 0
                    anchors.leftMargin: root.isLeft ? -hideOffsetV : 0
                    anchors.rightMargin: root.position === "right" ? -hideOffsetV : 0

                    Behavior on anchors.topMargin { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this) }
                    Behavior on anchors.bottomMargin { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this) }
                    Behavior on anchors.leftMargin { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this) }
                    Behavior on anchors.rightMargin { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this) }

                    Item {
                        id: dockHoverRegion
                        anchors.fill: parent
                        // Remove binding loop - use dockRoot dimensions directly
                        // implicitWidth: dockBackground.implicitWidth
                        // implicitHeight: dockBackground.implicitHeight

                        Item {
                            id: dockBackground
                            
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
                                visible: (Config.options?.dock?.showBackground ?? true) && !Appearance.gameModeMinimal
                            }

                            Rectangle {
                                id: dockVisualBackground
                                property bool cardStyle: Config.options?.dock?.cardStyle ?? false
                                readonly property bool auroraEverywhere: Appearance.auroraEverywhere
                                readonly property bool inirEverywhere: Appearance.inirEverywhere
                                readonly property bool gameModeMinimal: Appearance.gameModeMinimal
                                readonly property string wallpaperUrl: Wallpapers.effectiveWallpaperUrl

                                ColorQuantizer {
                                    id: dockWallpaperQuantizer
                                    source: dockVisualBackground.wallpaperUrl
                                    depth: 0
                                    rescaleSize: 10
                                }

                                readonly property color wallpaperDominantColor: dockWallpaperQuantizer?.colors?.[0] ?? Appearance.colors.colPrimary
                                readonly property QtObject blendedColors: AdaptedMaterialScheme {
                                    color: ColorUtils.mix(dockVisualBackground.wallpaperDominantColor, Appearance.colors.colPrimaryContainer, 0.8) || Appearance.m3colors.m3secondaryContainer
                                }

                                anchors.fill: parent
                                anchors.topMargin: root.isTop ? Appearance.sizes.hyprlandGapsOut : (root.isVertical ? 0 : Appearance.sizes.elevationMargin)
                                anchors.bottomMargin: root.position === "bottom" ? Appearance.sizes.hyprlandGapsOut : (root.isVertical ? 0 : Appearance.sizes.elevationMargin)
                                anchors.leftMargin: root.isLeft ? Appearance.sizes.hyprlandGapsOut : (root.isVertical ? Appearance.sizes.elevationMargin : 0)
                                anchors.rightMargin: root.position === "right" ? Appearance.sizes.hyprlandGapsOut : (root.isVertical ? Appearance.sizes.elevationMargin : 0)

                                visible: (Config.options?.dock?.showBackground ?? true) && !gameModeMinimal
                                color: auroraEverywhere ? ColorUtils.applyAlpha((blendedColors?.colLayer0 ?? Appearance.colors.colLayer0), 1)
                                    : inirEverywhere ? Appearance.inir.colLayer1
                                    : (cardStyle ? Appearance.colors.colLayer1 : Appearance.colors.colLayer0)
                                border.width: inirEverywhere ? 1 : 1
                                border.color: inirEverywhere ? Appearance.inir.colBorder : Appearance.colors.colLayer0Border
                                radius: inirEverywhere ? Appearance.inir.roundingNormal : cardStyle ? Appearance.rounding.normal : Appearance.rounding.large

                                clip: true
                                layer.enabled: auroraEverywhere && !inirEverywhere && !gameModeMinimal
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
                                    visible: dockVisualBackground.auroraEverywhere && !dockVisualBackground.inirEverywhere && !dockVisualBackground.gameModeMinimal
                                    source: dockVisualBackground.wallpaperUrl
                                    fillMode: Image.PreserveAspectCrop
                                    cache: true
                                    asynchronous: true

                                    layer.enabled: Appearance.effectsEnabled && !dockVisualBackground.gameModeMinimal
                                    layer.effect: StyledBlurEffect { source: dockBlurredWallpaper }

                                    Rectangle {
                                        anchors.fill: parent
                                        color: ColorUtils.transparentize((dockVisualBackground.blendedColors?.colLayer0 ?? Appearance.colors.colLayer0Base), Appearance.aurora.overlayTransparentize)
                                    }
                                }
                            }

                            RowLayout {
                                id: dockRow
                                visible: !root.isVertical
                                anchors.centerIn: dockVisualBackground
                                spacing: 2
                                property real padding: 5

                                DockApps {
                                    id: dockApps
                                    buttonPadding: dockRow.padding
                                    vertical: false
                                    dockPosition: root.position
                                }
                                DockButton {
                                    vertical: false
                                    dockPosition: root.position
                                    onClicked: GlobalStates.overviewOpen = !GlobalStates.overviewOpen
                                    contentItem: MaterialSymbol {
                                        anchors.centerIn: parent
                                        font.pixelSize: parent.width * 0.5
                                        text: "apps"
                                        color: Appearance.colors.colOnLayer0
                                    }
                                }
                            }

                            ColumnLayout {
                                id: dockColumn
                                visible: root.isVertical
                                anchors.centerIn: dockVisualBackground
                                spacing: 2
                                property real padding: 5

                                DockApps {
                                    id: dockAppsVertical
                                    buttonPadding: dockColumn.padding
                                    vertical: true
                                    dockPosition: root.position
                                }
                                DockButton {
                                    vertical: true
                                    dockPosition: root.position
                                    onClicked: GlobalStates.overviewOpen = !GlobalStates.overviewOpen
                                    contentItem: MaterialSymbol {
                                        anchors.centerIn: parent
                                        font.pixelSize: parent.width * 0.5
                                        text: "apps"
                                        color: Appearance.colors.colOnLayer0
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
