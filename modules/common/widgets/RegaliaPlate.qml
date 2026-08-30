pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.functions

Item {
    id: root

    property color fillColor: Appearance.regalia.surfacePlate
    property real radius: Appearance.regalia.roundNormal
    property real inset: Appearance.regalia.surfaceInset
    property bool elevated: false
    property bool deepFrame: false
    property bool active: false
    property bool hovered: false
    property bool glassEnabled: false
    property real glassScreenX: {
        void root.width
        void root.height
        return root.mapToItem(null, 0, 0).x
    }
    property real glassScreenY: {
        void root.width
        void root.height
        return root.mapToItem(null, 0, 0).y
    }
    property real glassScreenWidth: root.QsWindow?.window?.screen?.width ?? (Quickshell.screens[0]?.width ?? 1920)
    property real glassScreenHeight: root.QsWindow?.window?.screen?.height ?? (Quickshell.screens[0]?.height ?? 1080)

    readonly property bool _glassActive: root.glassEnabled && Appearance.regalia.glass && Appearance.effectsEnabled
    readonly property real _materialStrength: Math.max(0, Math.min(1, Appearance.regalia.glassSurfaceOpacity))
    readonly property real _glassFrameOpacity: 0.58 + root._materialStrength * 0.34
    readonly property real _glassFieldOpacity: 0.22 + root._materialStrength * 0.50
    readonly property color _frameColor: root.elevated
        ? Appearance.regalia.chassis2
        : root.deepFrame ? Appearance.regalia.chassis0 : Appearance.regalia.chassis1
    readonly property color _fieldColor: root.active
        ? Appearance.regalia.surfacePlateActive
        : root.hovered ? Appearance.regalia.surfacePlateHover : root.fillColor
    readonly property color _paintFrameColor: root._glassActive
        ? ColorUtils.applyAlpha(root._frameColor, root._glassFrameOpacity) : root._frameColor
    readonly property color _paintFieldColor: root._glassActive
        ? ColorUtils.applyAlpha(root._fieldColor, root._glassFieldOpacity) : root._fieldColor

    GlassBackground {
        anchors.fill: parent
        visible: root._glassActive
        forceBackdrop: true
        blurStrength: Appearance.regalia.glassBlur
        saturationStrength: Appearance.regalia.glassSaturation
        auroraTransparency: Appearance.regalia.glassTintTransparency
        radius: root.radius
        screenX: root.glassScreenX
        screenY: root.glassScreenY
        screenWidth: root.glassScreenWidth
        screenHeight: root.glassScreenHeight
    }

    Rectangle {
        id: chassis
        anchors.fill: parent
        radius: root.radius
        gradient: Gradient {
            GradientStop {
                position: 0
                color: root._glassActive
                    ? ColorUtils.applyAlpha(root.elevated ? Appearance.regalia.chassisLight : root._frameColor, root._glassFrameOpacity)
                    : (root.elevated ? Appearance.regalia.chassisLight : root._frameColor)
            }
            GradientStop { position: 0.42; color: root._paintFrameColor }
            GradientStop {
                position: 1
                color: root._glassActive
                    ? ColorUtils.applyAlpha(Appearance.regalia.chassisShade, root._glassFrameOpacity)
                    : Appearance.regalia.chassisShade
            }
        }
    }

    Rectangle {
        id: field
        anchors.fill: parent
        anchors.margins: root.inset
        radius: Math.max(0, root.radius - root.inset)
        color: root._paintFieldColor
        gradient: Gradient {
            GradientStop {
                position: 0
                color: root._glassActive
                    ? ColorUtils.applyAlpha(ColorUtils.mix(root._fieldColor, Appearance.regalia.onColor, 0.965), root._glassFieldOpacity)
                    : ColorUtils.mix(root._fieldColor, Appearance.regalia.onColor, 0.965)
            }
            GradientStop { position: 0.52; color: root._paintFieldColor }
            GradientStop {
                position: 1
                color: root._glassActive
                    ? ColorUtils.applyAlpha(ColorUtils.mix(root._fieldColor, Appearance.m3colors.m3shadow, 0.94), root._glassFieldOpacity)
                    : ColorUtils.mix(root._fieldColor, Appearance.m3colors.m3shadow, 0.94)
            }
        }

        Behavior on color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.regalia.stateDuration; easing.type: Easing.OutCubic }
        }
    }
}
