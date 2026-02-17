import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.modules.common
import qs.modules.common.functions
import qs.modules.waffle.looks
import qs.services

// Family transition with blurred wallpaper backdrop
// Waffle: 4 tiles expand from center
// Material: Ripple circle expands from center
Scope {
    id: root

    signal exitComplete()
    signal enterComplete()

    readonly property int enterDuration: Appearance.animationsEnabled ? 400 : 10
    readonly property int holdDuration: 250
    readonly property int exitDuration: Appearance.animationsEnabled ? 450 : 10
    
    property bool _isWaffle: false
    property bool _phase: false
    property bool _active: false
    property real _overlayOpacity: 0

    Connections {
        target: GlobalStates
        function onFamilyTransitionActiveChanged() {
            if (GlobalStates.familyTransitionActive) {
                fadeOut.stop()
                root._isWaffle = GlobalStates.familyTransitionDirection === "left"
                root._phase = false
                root._active = true
                root._overlayOpacity = 1
                enterTimer.start()
            }
        }
    }

    Timer {
        id: enterTimer
        interval: root.enterDuration + 80
        onTriggered: {
            root.exitComplete()
            holdTimer.start()
        }
    }
    
    Timer {
        id: holdTimer
        interval: root.holdDuration
        onTriggered: {
            root._phase = true
            fadeOut.restart()
        }
    }

    NumberAnimation {
        id: fadeOut
        target: root
        property: "_overlayOpacity"
        to: 0
        duration: root.exitDuration
        easing.type: Easing.InOutCubic
        onFinished: {
            root._active = false
            root.enterComplete()
        }
    }

    Loader {
        active: GlobalStates.familyTransitionActive || root._active

        sourceComponent: PanelWindow {
            visible: true
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: -1

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            WlrLayershell.namespace: "quickshell:familyTransition"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            
            implicitWidth: screen?.width ?? 1920
            implicitHeight: screen?.height ?? 1080

            Item {
                id: content
                anchors.fill: parent

                opacity: root._overlayOpacity

                Rectangle {
                    anchors.fill: parent
                    color: root._isWaffle ? Looks.colors.bg0 : Appearance.m3colors.m3background
                    opacity: 1
                }

                // Blurred wallpaper background
                Item {
                    id: blurredBg
                    anchors.fill: parent
                    opacity: 1

                    Image {
                        id: wallpaperImg
                        anchors.fill: parent
                        source: {
                            // Use target family's wallpaper
                            let path = ""
                            if (root._isWaffle) {
                                // Going to Waffle - use waffle wallpaper (or main if shared)
                                const wBg = Config.options?.waffles?.background ?? {}
                                const useMain = wBg.useMainWallpaper ?? true
                                path = useMain 
                                    ? (Config.options?.background?.wallpaperPath ?? "")
                                    : (wBg.wallpaperPath ?? Config.options?.background?.wallpaperPath ?? "")
                            } else {
                                // Going to Material - use main wallpaper
                                path = Config.options?.background?.wallpaperPath ?? ""
                            }
                            if (!path) return ""
                            return path.startsWith("file://") ? path : "file://" + path
                        }
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        visible: false
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: wallpaperImg
                        visible: wallpaperImg.status === Image.Ready
                        blurEnabled: Appearance.effectsEnabled
                        blur: 0.8
                        blurMax: 64
                        saturation: 0.3
                    }

                    // Subtle tint overlay (only for Material, Waffle uses clean blur)
                    Rectangle {
                        anchors.fill: parent
                        color: Appearance.m3colors.m3background
                        opacity: root._isWaffle ? 0 : 0.3
                        visible: !root._isWaffle
                    }
                }

                // Family-specific transition effect
                Loader {
                    anchors.fill: parent
                    sourceComponent: root._isWaffle ? waffleTransition : materialTransition
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // WAFFLE - Fluent Reveal: Acrylic panel emerges from center
    // ═══════════════════════════════════════════════════════════════════════
    Component {
        id: waffleTransition
        
        Item {
            id: waffleRoot
            anchors.fill: parent
            
            property bool expanded: false
            property bool showContent: false
            
            Component.onCompleted: Qt.callLater(() => expanded = true)
            
            Timer {
                interval: 250
                running: waffleRoot.expanded
                onTriggered: waffleRoot.showContent = true
            }
            
            // Acrylic panel - the main element
            Rectangle {
                id: acrylicPanel
                anchors.centerIn: parent
                width: waffleRoot.expanded && !root._phase ? 280 : 56
                height: waffleRoot.expanded && !root._phase ? 200 : 56
                radius: waffleRoot.expanded ? Looks.radius.xLarge : 28
                color: ColorUtils.transparentize(Looks.colors.bg0, 0.12)
                border.width: 1
                border.color: ColorUtils.transparentize(Looks.colors.fg, 0.88)
                opacity: root._phase ? 0 : 1
                scale: root._phase ? 0.92 : 1
                
                Behavior on width { NumberAnimation { duration: root._phase ? 280 : root.enterDuration; easing.type: Easing.OutCubic } }
                Behavior on height { NumberAnimation { duration: root._phase ? 280 : root.enterDuration; easing.type: Easing.OutCubic } }
                Behavior on radius { NumberAnimation { duration: root.enterDuration * 0.5; easing.type: Easing.OutQuad } }
                Behavior on opacity { NumberAnimation { duration: root._phase ? 250 : 100 } }
                Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                
                // Accent line at bottom
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: waffleRoot.showContent && !root._phase ? 60 : 0
                    height: 3
                    radius: 1.5
                    color: Looks.colors.accent
                    opacity: root._phase ? 0 : 1
                    
                    Behavior on width { NumberAnimation { duration: root._phase ? 150 : 300; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }
            }
            
            // Content
            Column {
                anchors.centerIn: parent
                spacing: 14
                opacity: root._phase ? 0 : (waffleRoot.showContent ? 1 : 0)
                scale: root._phase ? 0.95 : (waffleRoot.showContent ? 1 : 0.9)
                
                Behavior on opacity { NumberAnimation { duration: root._phase ? 150 : 220; easing.type: Easing.OutQuad } }
                Behavior on scale { NumberAnimation { duration: root._phase ? 150 : 280; easing.type: Easing.OutCubic } }
                
                // Windows logo
                Image {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 52
                    height: 52
                    source: `${Looks.iconsPath}/start-here.svg`
                    sourceSize: Qt.size(52, 52)
                    
                    layer.enabled: Appearance.effectsEnabled
                    layer.effect: MultiEffect {
                        colorization: 1.0
                        colorizationColor: Looks.colors.fg
                    }
                }
                
                // Text
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 2
                    
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Waffle"
                        font.pixelSize: 20
                        font.family: Looks.font.family.ui
                        font.weight: Font.DemiBold
                        color: Looks.colors.fg
                    }
                    
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Windows 11 Style"
                        font.pixelSize: Looks.font.pixelSize.small
                        font.family: Looks.font.family.ui
                        color: Looks.colors.subfg
                    }
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MATERIAL II - Ripple circle expands from center
    // ═══════════════════════════════════════════════════════════════════════
    Component {
        id: materialTransition
        
        Item {
            id: materialRoot
            anchors.fill: parent
            
            readonly property real maxRadius: Math.sqrt(width * width + height * height) / 2 + 100
            property bool expanded: false
            property bool showContent: false
            
            Component.onCompleted: Qt.callLater(() => expanded = true)
            
            Timer {
                interval: 180
                running: materialRoot.expanded
                onTriggered: materialRoot.showContent = true
            }
            
            // Expanding ripple circle
            Rectangle {
                anchors.centerIn: parent
                width: materialRoot.expanded && !root._phase ? materialRoot.maxRadius * 2 : 0
                height: width
                radius: width / 2
                color: ColorUtils.transparentize(Appearance.colors.colPrimaryContainer, 0.4)
                opacity: root._phase ? 0 : 1
                
                Behavior on width { NumberAnimation { duration: root._phase ? root.exitDuration * 0.7 : root.enterDuration; easing.type: Easing.OutQuart } }
                Behavior on opacity { NumberAnimation { duration: root.exitDuration; easing.type: Easing.OutQuad } }
            }
            
            // Secondary ripple ring
            Rectangle {
                anchors.centerIn: parent
                width: materialRoot.expanded && !root._phase ? materialRoot.maxRadius * 2.1 : 0
                height: width
                radius: width / 2
                color: "transparent"
                border.width: 2
                border.color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.7)
                opacity: root._phase ? 0 : 1
                
                Behavior on width { NumberAnimation { duration: root._phase ? root.exitDuration * 0.6 : root.enterDuration + 80; easing.type: Easing.OutQuart } }
                Behavior on opacity { NumberAnimation { duration: root.exitDuration * 0.8 } }
            }
            
            // Center content
            Column {
                anchors.centerIn: parent
                spacing: 14
                opacity: root._phase ? 0 : (materialRoot.showContent ? 1 : 0)
                scale: root._phase ? 0.9 : (materialRoot.showContent ? 1 : 0.75)
                
                Behavior on opacity { NumberAnimation { duration: root._phase ? 200 : 280; easing.type: Easing.OutQuad } }
                Behavior on scale { NumberAnimation { duration: root._phase ? 200 : 350; easing.type: Easing.OutCubic } }
                
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 64
                    height: 64
                    radius: 32
                    color: Appearance.colors.colPrimaryContainer
                    
                    Image {
                        anchors.centerIn: parent
                        width: 36
                        height: 36
                        source: Qt.resolvedUrl("assets/icons/illogical-impulse.svg")
                        sourceSize: Qt.size(36, 36)
                        
                        layer.enabled: Appearance.effectsEnabled
                        layer.effect: MultiEffect {
                            colorization: 1.0
                            colorizationColor: Appearance.colors.colOnPrimaryContainer
                        }
                    }
                }
                
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 2
                    
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Material ii"
                        font.pixelSize: Appearance.font.pixelSize.title
                        font.family: Appearance.font.family.title
                        font.weight: Font.Medium
                        color: Appearance.m3colors.m3onSurface
                        
                        layer.enabled: Appearance.effectsEnabled
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: Appearance.m3colors.darkmode ? "#000000" : "#FFFFFF"
                            shadowBlur: 0.8
                            shadowVerticalOffset: 1
                        }
                    }
                    
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Material Design"
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.family: Appearance.font.family.main
                        color: Appearance.m3colors.m3onSurface
                        opacity: 0.7
                        
                        layer.enabled: Appearance.effectsEnabled
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: Appearance.m3colors.darkmode ? "#000000" : "#FFFFFF"
                            shadowBlur: 0.6
                            shadowVerticalOffset: 1
                        }
                    }
                }
            }
        }
    }
}
