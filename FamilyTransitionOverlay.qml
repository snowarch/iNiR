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

    Connections {
        target: GlobalStates
        function onFamilyTransitionActiveChanged() {
            if (GlobalStates.familyTransitionActive) {
                root._isWaffle = GlobalStates.familyTransitionDirection === "left"
                root._phase = false
                root._active = true
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
            exitTimer.start()
        }
    }
    
    Timer {
        id: exitTimer
        interval: root.exitDuration + 80
        onTriggered: {
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

            // Blurred wallpaper background
            Item {
                id: blurredBg
                anchors.fill: parent
                opacity: root._phase ? 0 : 1
                
                Behavior on opacity {
                    NumberAnimation { 
                        duration: root.exitDuration
                        easing.type: Easing.OutQuad
                    }
                }

                Image {
                    id: wallpaperImg
                    anchors.fill: parent
                    source: {
                        const path = Config.options?.background?.wallpaperPath ?? ""
                        if (!path) return ""
                        return path.startsWith("file://") ? path : "file://" + path
                    }
                    fillMode: Image.PreserveAspectCrop
                    visible: false
                }

                MultiEffect {
                    anchors.fill: parent
                    source: wallpaperImg
                    visible: wallpaperImg.status === Image.Ready
                    blurEnabled: true
                    blur: 0.8
                    blurMax: 64
                    saturation: 0.3
                }

                // Subtle tint overlay
                Rectangle {
                    anchors.fill: parent
                    color: root._isWaffle 
                        ? (Looks.dark ? "#000000" : "#FFFFFF")
                        : Appearance.m3colors.m3background
                    opacity: 0.3
                }
            }

            // Family-specific transition effect
            Loader {
                anchors.fill: parent
                sourceComponent: root._isWaffle ? waffleTransition : materialTransition
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // WAFFLE - 4 tiles expand from center
    // ═══════════════════════════════════════════════════════════════════════
    Component {
        id: waffleTransition
        
        Item {
            id: waffleRoot
            anchors.fill: parent
            
            readonly property real centerX: width / 2
            readonly property real centerY: height / 2
            property bool expanded: false
            property bool showContent: false
            
            Component.onCompleted: Qt.callLater(() => expanded = true)
            
            Timer {
                interval: 200
                running: waffleRoot.expanded
                onTriggered: waffleRoot.showContent = true
            }
            
            // 4 expanding tiles
            Repeater {
                model: 4
                
                Rectangle {
                    id: tile
                    required property int index
                    
                    readonly property bool isLeft: index % 2 === 0
                    readonly property bool isTop: index < 2
                    
                    x: waffleRoot.expanded && !root._phase
                        ? (isLeft ? 0 : waffleRoot.centerX + 2)
                        : waffleRoot.centerX - 24
                    y: waffleRoot.expanded && !root._phase
                        ? (isTop ? 0 : waffleRoot.centerY + 2)
                        : waffleRoot.centerY - 24
                    width: waffleRoot.expanded && !root._phase
                        ? waffleRoot.centerX - 2
                        : 48
                    height: waffleRoot.expanded && !root._phase
                        ? waffleRoot.centerY - 2
                        : 48
                    
                    radius: waffleRoot.expanded ? 0 : 4
                    color: ColorUtils.transparentize(Looks.colors.bg0, 0.15)
                    border.width: 1
                    border.color: ColorUtils.transparentize(Looks.colors.fg, 0.92)
                    opacity: root._phase ? 0 : 1
                    
                    Behavior on x { NumberAnimation { duration: root._phase ? root.exitDuration * 0.6 : root.enterDuration; easing.type: Easing.OutExpo } }
                    Behavior on y { NumberAnimation { duration: root._phase ? root.exitDuration * 0.6 : root.enterDuration; easing.type: Easing.OutExpo } }
                    Behavior on width { NumberAnimation { duration: root._phase ? root.exitDuration * 0.6 : root.enterDuration; easing.type: Easing.OutExpo } }
                    Behavior on height { NumberAnimation { duration: root._phase ? root.exitDuration * 0.6 : root.enterDuration; easing.type: Easing.OutExpo } }
                    Behavior on radius { NumberAnimation { duration: root.enterDuration * 0.5; easing.type: Easing.OutQuad } }
                    Behavior on opacity { NumberAnimation { duration: root.exitDuration; easing.type: Easing.OutQuad } }
                }
            }
            
            // Center content
            Column {
                anchors.centerIn: parent
                spacing: 16
                opacity: root._phase ? 0 : (waffleRoot.showContent ? 1 : 0)
                scale: root._phase ? 0.9 : (waffleRoot.showContent ? 1 : 0.8)
                
                Behavior on opacity { NumberAnimation { duration: root._phase ? 200 : 250; easing.type: Easing.OutQuad } }
                Behavior on scale { NumberAnimation { duration: root._phase ? 200 : 300; easing.type: Easing.OutCubic } }
                
                Image {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 48
                    height: 48
                    source: `${Looks.iconsPath}/start-here.svg`
                    sourceSize: Qt.size(48, 48)
                    
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        colorization: 1.0
                        colorizationColor: Looks.colors.fg
                    }
                }
                
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 4
                    
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Waffle"
                        font.pixelSize: 22
                        font.family: Looks.font.family
                        font.weight: Font.DemiBold
                        color: Looks.colors.fg
                        
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: Looks.dark ? "#000000" : "#FFFFFF"
                            shadowBlur: 0.8
                            shadowVerticalOffset: 1
                        }
                    }
                    
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Windows 11 Style"
                        font.pixelSize: Looks.font.size.small
                        font.family: Looks.font.family
                        color: Looks.colors.fg
                        opacity: 0.7
                        
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: Looks.dark ? "#000000" : "#FFFFFF"
                            shadowBlur: 0.6
                            shadowVerticalOffset: 1
                        }
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
                        
                        layer.enabled: true
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
                        
                        layer.enabled: true
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
                        
                        layer.enabled: true
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
