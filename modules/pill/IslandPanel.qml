import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE
import qs.modules.common
import qs.services

/**
 * The island's surface, factored out of the bar so any panel can wear the same
 * skin: a vertical card gradient, a one-pixel hairline border, a top sheen that
 * fakes a lit edge, and a soft drop shadow.
 *
 * Panels opt in through their own `style` config key rather than a global flag,
 * so a user can run an island bar over a default dock, or the reverse. Corner
 * radius is a property because the bar rounds harder than the docked panels.
 */
Rectangle {
    id: root

    /**
     * Defaults come from the shared appearance.island config so ONE settings
     * section skins every island in the shell; a surface can still override
     * any of these locally (the pill sets its own radius mid-morph, panels
     * that already cast a shadow pass shadow: false).
     */
    property bool shadow: Config.options?.appearance?.island?.shadow ?? true
    property real shadowOffset: 3
    readonly property real fillOpacity: Config.options?.appearance?.island?.opacity ?? 1

    /**
     * Premium glass: a blurred wallpaper backdrop behind the translucent card,
     * so lowering the fill opacity reads as frosted glass instead of raw
     * see-through. Consumers opt in with `glassEnabled: true` plus their
     * screen-relative offsets (the same numbers their aurora backdrops use);
     * the shared appearance.island.glass switch and the fill opacity gate it.
     */
    property bool glassEnabled: false
    property bool nativeBlurActive: false
    property real glassScreenX: 0
    property real glassScreenY: 0
    property real glassScreenWidth: screen?.width ?? 1920
    property real glassScreenHeight: screen?.height ?? 1080
    property var screen: null
    readonly property bool glassActive: root.visible && glassEnabled
        && (Config.options?.appearance?.island?.glass ?? true)
        && Appearance.blurBackendFor("islands",
            Appearance.blurTopology.roundedRectangle) === "wallpaper"
        && !root.nativeBlurActive
        && fillOpacity < 0.999

    radius: Config.options?.appearance?.island?.radius ?? 18
    border.width: 1
    border.color: PillTheme.border

    gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.alpha(PillTheme.cardTop, root.fillOpacity) }
        GradientStop { position: 1.0; color: Qt.alpha(PillTheme.cardBot, root.fillOpacity) }
    }

    // Several island consumers stay instantiated while their panel is closed.
    // Do not keep a shadow texture allocated for an invisible surface.
    layer.enabled: root.shadow && root.visible
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: Qt.rgba(0, 0, 0, PillTheme.shadowOpacity)
        shadowBlur: 0.7
        shadowVerticalOffset: root.shadowOffset
    }

    // Below the card's own gradient (negative z), masked to the same corners.
    Item {
        anchors.fill: parent
        z: -1
        visible: root.glassActive
        layer.enabled: root.glassActive
        layer.effect: GE.OpacityMask {
            maskSource: Rectangle {
                width: root.width
                height: root.height
                radius: root.radius
            }
        }

        Image {
            id: glassWallpaper
            x: -root.glassScreenX
            y: -root.glassScreenY
            width: root.glassScreenWidth
            height: root.glassScreenHeight
            visible: root.glassActive && status === Image.Ready
            source: root.glassActive ? Wallpapers.effectiveWallpaperUrl : ""
            fillMode: Image.PreserveAspectCrop
            cache: true
            asynchronous: true
            sourceSize.width: root.glassScreenWidth
            sourceSize.height: root.glassScreenHeight

            layer.enabled: root.glassActive && root.visible
            layer.effect: MultiEffect {
                source: glassWallpaper
                anchors.fill: source
                saturation: 0.15
                blurEnabled: true
                blurMax: 64
                blur: Config.options?.appearance?.island?.glassBlur ?? 1
            }
        }
    }

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 1
        anchors.leftMargin: root.radius * 0.6
        anchors.rightMargin: root.radius * 0.6
        height: 1
        visible: Config.options?.appearance?.island?.sheen ?? true
        color: PillTheme.sheen
    }
}
