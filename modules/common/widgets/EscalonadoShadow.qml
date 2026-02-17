import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE
import qs.modules.common
import qs.modules.common.functions
import qs.services
import Quickshell

// Escalonado shadow — a glass-backed offset rectangle behind the target element.
// Signature angel effect: creates depth via a blurred glass layer
// shifted diagonally. The shadow itself shows wallpaper blur for a
// "glass shelf" effect — the card floats on a frosted platform.
// Usage: place BEFORE the target in z-order, set `target` property.
//
// Example:
//   EscalonadoShadow { target: myCard }
//   Rectangle { id: myCard; ... }
//
Item {
    id: root

    // Target element this shadow follows
    property Item target

    // Whether the target is hovered (animates offset)
    property bool hovered: false

    // Customizable offsets (defaults from Appearance.angel shadow-specific config)
    property int offsetX: Appearance.angel.shadowOffsetX
    property int offsetY: Appearance.angel.shadowOffsetY
    property int hoverOffsetX: Appearance.angel.shadowHoverOffsetX
    property int hoverOffsetY: Appearance.angel.shadowHoverOffsetY

    // Colors
    property color fillColor: Appearance.angel.colShadow
    property color borderColor: Appearance.angel.colShadowBorder
    property color hoverFillColor: Appearance.angel.colShadowHover

    // Screen-relative position for glass blur alignment (set by parent)
    property real screenX: 0
    property real screenY: 0
    property real screenWidth: Quickshell.screens[0]?.width ?? 1920
    property real screenHeight: Quickshell.screens[0]?.height ?? 1080

    visible: Appearance.angelEverywhere

    // Follow target geometry
    x: target ? target.x : 0
    y: target ? target.y : 0
    width: target ? target.width : 0
    height: target ? target.height : 0

    Rectangle {
        id: shadow

        readonly property int currentOffsetX: root.hovered ? root.hoverOffsetX : root.offsetX
        readonly property int currentOffsetY: root.hovered ? root.hoverOffsetY : root.offsetY
        readonly property real targetRadius: target ? (target.radius ?? 0) : 0

        x: currentOffsetX
        y: currentOffsetY
        width: parent.width
        height: parent.height

        color: "transparent"
        radius: targetRadius
        clip: true

        layer.enabled: Appearance.angel.shadowGlass && Appearance.effectsEnabled
        layer.effect: GE.OpacityMask {
            maskSource: Rectangle {
                width: shadow.width
                height: shadow.height
                radius: shadow.targetRadius
            }
        }

        // Glass blur layer — shows blurred wallpaper through the escalonado shadow
        Image {
            id: escalonadoBlur
            x: -root.screenX - shadow.currentOffsetX - root.x
            y: -root.screenY - shadow.currentOffsetY - root.y
            width: root.screenWidth
            height: root.screenHeight
            visible: Appearance.angel.shadowGlass && Appearance.effectsEnabled
            source: Wallpapers.effectiveWallpaperUrl
            fillMode: Image.PreserveAspectCrop
            cache: true
            asynchronous: true

            layer.enabled: Appearance.effectsEnabled
            layer.effect: MultiEffect {
                source: escalonadoBlur
                anchors.fill: source
                saturation: Appearance.angel.blurSaturation * Appearance.angel.colorStrength * 0.7
                blurEnabled: Appearance.effectsEnabled
                blurMax: 100
                blur: Appearance.angel.shadowGlassBlur
            }
        }

        // Color tint overlay
        Rectangle {
            anchors.fill: parent
            color: root.hovered ? root.hoverFillColor : root.fillColor
            radius: shadow.targetRadius

            Behavior on color {
                enabled: Appearance.animationsEnabled
                ColorAnimation { duration: 150 }
            }
        }

        // Subtle border
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            radius: shadow.targetRadius
            border.width: 1
            border.color: root.borderColor
        }

        Behavior on x {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
        Behavior on y {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
    }
}
