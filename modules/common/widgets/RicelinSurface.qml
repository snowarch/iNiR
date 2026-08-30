pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE
import Quickshell
import qs.modules.common
import qs.services

Item {
    id: root

    property bool shadow: Config.options?.appearance?.island?.shadow ?? true
    property real shadowOffset: 3
    property int shadowRadius: 16
    property real radius: Config.options?.appearance?.island?.radius ?? 18
    property real topLeftRadiusOverride: -1
    property real topRightRadiusOverride: -1
    property real bottomLeftRadiusOverride: -1
    property real bottomRightRadiusOverride: -1
    property bool glassEnabled: true
    property bool nativeBlurActive: false
    property var screen: null
    property real glassScreenX: -1
    property real glassScreenY: -1
    property real glassScreenWidth: -1
    property real glassScreenHeight: -1

    readonly property real fillOpacity: Config.options?.appearance?.island?.opacity ?? 1
    readonly property real topLeftRadius: topLeftRadiusOverride >= 0 ? topLeftRadiusOverride : radius
    readonly property real topRightRadius: topRightRadiusOverride >= 0 ? topRightRadiusOverride : radius
    readonly property real bottomLeftRadius: bottomLeftRadiusOverride >= 0 ? bottomLeftRadiusOverride : radius
    readonly property real bottomRightRadius: bottomRightRadiusOverride >= 0 ? bottomRightRadiusOverride : radius

    readonly property var _window: root.QsWindow?.window ?? null
    readonly property var _screen: root.screen ?? root._window?.screen ?? Quickshell.screens[0] ?? null
    readonly property real _screenWidth: root.glassScreenWidth > 0 ? root.glassScreenWidth : (root._screen?.width ?? 1920)
    readonly property real _screenHeight: root.glassScreenHeight > 0 ? root.glassScreenHeight : (root._screen?.height ?? 1080)
    readonly property real _windowWidth: root._window?.width ?? root._screenWidth
    readonly property real _windowHeight: root._window?.height ?? root._screenHeight
    readonly property var _anchors: root._window?.anchors ?? null
    readonly property var _margins: root._window?.margins ?? null
    readonly property real _windowX: !root._anchors ? (root._window?.x ?? 0)
        : root._anchors.left ? (root._margins?.left ?? 0)
        : root._anchors.right ? (root._screenWidth - root._windowWidth - (root._margins?.right ?? 0))
        : (root._screenWidth - root._windowWidth) / 2
    readonly property real _windowY: !root._anchors ? (root._window?.y ?? 0)
        : root._anchors.top ? (root._margins?.top ?? 0)
        : root._anchors.bottom ? (root._screenHeight - root._windowHeight - (root._margins?.bottom ?? 0))
        : (root._screenHeight - root._windowHeight) / 2

    property point _inWindow: Qt.point(0, 0)

    function _syncBackdropPosition(): void {
        if (!root.visible || !root.glassEnabled)
            return
        root._inWindow = root.mapToItem(null, 0, 0)
    }

    onXChanged: root._syncBackdropPosition()
    onYChanged: root._syncBackdropPosition()
    onWidthChanged: root._syncBackdropPosition()
    onHeightChanged: root._syncBackdropPosition()
    onGlassEnabledChanged: root._syncBackdropPosition()
    onVisibleChanged: if (visible) Qt.callLater(root._syncBackdropPosition)
    on_WindowWidthChanged: root._syncBackdropPosition()
    on_WindowHeightChanged: root._syncBackdropPosition()
    Component.onCompleted: Qt.callLater(root._syncBackdropPosition)

    readonly property real effectiveScreenX: root.glassScreenX >= 0
        ? root.glassScreenX : root._windowX + root._inWindow.x
    readonly property real effectiveScreenY: root.glassScreenY >= 0
        ? root.glassScreenY : root._windowY + root._inWindow.y
    readonly property string wallpaperUrl: WallpaperListener.wallpaperUrlForScreen(root._screen)
    readonly property string glassBackend: Appearance.blurBackendFor("islands", Appearance.blurTopology.roundedRectangle)
    readonly property bool glassActive: root.visible
        && root.glassEnabled
        && Appearance.effectsEnabled
        && (Config.options?.appearance?.island?.glass ?? true)
        && root.fillOpacity < 0.999
        && (root.glassBackend === "wallpaper"
            || (root.glassBackend === "compositor" && !root.nativeBlurActive))

    Item {
        id: glass
        anchors.fill: parent
        visible: root.glassActive
        layer.enabled: root.glassActive
        layer.effect: GE.OpacityMask {
            maskSource: Rectangle {
                width: glass.width
                height: glass.height
                radius: root.radius
                topLeftRadius: root.topLeftRadius
                topRightRadius: root.topRightRadius
                bottomLeftRadius: root.bottomLeftRadius
                bottomRightRadius: root.bottomRightRadius
            }
        }

        Image {
            id: glassWallpaper
            x: -root.effectiveScreenX
            y: -root.effectiveScreenY
            width: root._screenWidth
            height: root._screenHeight
            visible: root.glassActive && status === Image.Ready
            source: root.glassActive ? root.wallpaperUrl : ""
            fillMode: Image.PreserveAspectCrop
            cache: true
            asynchronous: true
            sourceSize.width: Math.round(root._screenWidth)
            sourceSize.height: Math.round(root._screenHeight)

            layer.enabled: root.glassActive
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
        id: card
        anchors.fill: parent
        radius: root.radius
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        bottomRightRadius: root.bottomRightRadius
        border.width: 0
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.alpha(Appearance.colors.colLayer3, root.fillOpacity) }
            GradientStop { position: 1.0; color: Qt.alpha(Appearance.colors.colLayer1, root.fillOpacity) }
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
            color: Qt.alpha(Appearance.colors.colOnLayer0, 0.07)
        }
    }

    GE.DropShadow {
        anchors.fill: card
        source: card
        visible: Appearance.effectsEnabled && root.shadow && root.visible
        z: -1
        color: Qt.rgba(0, 0, 0, 0.35)
        radius: root.shadowRadius
        samples: radius * 2 + 1
        verticalOffset: root.shadowOffset
        transparentBorder: true
    }
}
