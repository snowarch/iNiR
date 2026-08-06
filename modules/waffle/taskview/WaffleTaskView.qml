pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.waffle.looks

Scope {
    id: root

    // Previews are cached and cleaned up automatically when windows close
    // No need to clear on TaskView close - improves performance on re-open

    function openTaskView(): void {
        if (GlobalStates.waffleTaskViewOpen) return
        // Open INSTANTLY - previews load progressively in background
        GlobalStates.waffleTaskViewOpen = true
    }

    Loader {
        id: panelLoader
        active: GlobalStates.waffleTaskViewOpen
        sourceComponent: PanelWindow {
            id: panelWindow
            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:wTaskView"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            color: "transparent"

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            // Wallpaper source for blur
            Image {
                id: wallpaperSource
                anchors.fill: parent
                source: {
                    const wBg = Config.options?.waffles?.background ?? {}
                    const path = (wBg.useMainWallpaper ?? true)
                        ? Config.options?.background?.wallpaperPath ?? ""
                        : wBg.wallpaperPath ?? Config.options?.background?.wallpaperPath ?? ""
                    return path ? "file://" + path : ""
                }
                fillMode: Image.PreserveAspectCrop
                visible: false
            }

            // Click outside to close - but not during drag
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                z: -1  // Below everything so workspace clicks work
                onClicked: mouse => {
                    if (content.isDragging) return
                    GlobalStates.waffleTaskViewOpen = false
                }
            }

            // Blur strip - Windows 11 style horizontal band
            Item {
                id: blurStrip
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: content.totalHeight + 80
                clip: true
                
                // Entry animation - respects GameMode
                opacity: 0
                transform: Translate { id: stripTranslate; y: 25 }
                
                Component.onCompleted: {
                    if (Looks.transition.enabled) {
                        stripEntryAnim.start()
                    } else {
                        opacity = 1
                        stripTranslate.y = 0
                    }
                }
                
                ParallelAnimation {
                    id: stripEntryAnim
                    NumberAnimation { 
                        target: blurStrip
                        property: "opacity"
                        to: 1
                        duration: Looks.transition.enabled ? 180 : 0
                        easing.type: Easing.OutCubic 
                    }
                    NumberAnimation { 
                        target: stripTranslate
                        property: "y"
                        to: 0
                        duration: Looks.transition.enabled ? 220 : 0
                        easing.type: Easing.OutCubic 
                    }
                }

                // Blurred wallpaper background
                ShaderEffectSource {
                    id: blurSource
                    anchors.fill: parent
                    sourceItem: wallpaperSource
                    sourceRect: Qt.rect(
                        0,
                        (panelWindow.height - blurStrip.height) / 2,
                        panelWindow.width,
                        blurStrip.height
                    )
                    visible: false
                }

                MultiEffect {
                    anchors.fill: parent
                    source: blurSource
                    blurEnabled: Appearance.effectsEnabled
                    blur: 0.8
                    blurMax: 68
                    saturation: 0.5
                }

                // Dark tint overlay
                Rectangle {
                    anchors.fill: parent
                    color: ColorUtils.transparentize(Looks.colors.bg0Opaque, 0.4)
                }

                // Top edge fade
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 20
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.15) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

                // Bottom edge fade
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 20
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.15) }
                    }
                }
            }

            WaffleTaskViewContent {
                id: content
                anchors.centerIn: blurStrip
                focus: true
                onClosed: GlobalStates.waffleTaskViewOpen = false
                
                Keys.onEscapePressed: GlobalStates.waffleTaskViewOpen = false
            }
        }
    }

}
