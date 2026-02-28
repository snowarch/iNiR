import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE

// macOS-style "shelf" — single translucent frosted-glass background.
// Color blending is done in Dock.qml (which already has ColorQuantizer +
// AdaptedMaterialScheme) and passed in as the `blendedLayer0` property.
// This component only handles rendering.
Rectangle {
    id: root

    property real   dockHeight:    70
    property bool   vertical:      false
    property string wallpaperUrl:  ""
    property var    dockScreen:    null

    // Pre-computed blended color from Dock.qml's dockVisualBackground.blendedColors
    property color  blendedLayer0: Appearance.colors.colLayer0

    readonly property bool auroraEverywhere: Appearance.auroraEverywhere
    readonly property bool inirEverywhere:   Appearance.inirEverywhere
    readonly property bool angelEverywhere:  Appearance.angelEverywhere
    readonly property bool gameModeMinimal:  Appearance.gameModeMinimal

    // ─── Shape ───────────────────────────────────────────────────────
    radius: angelEverywhere ? Appearance.angel.roundingNormal
          : inirEverywhere  ? Appearance.inir.roundingNormal
          :                   Appearance.rounding.large

    // ─── Fill: genuinely translucent for macOS look ──────────────────
    color: auroraEverywhere
        ? ColorUtils.transparentize(blendedLayer0, 0.18)
        : inirEverywhere
            ? ColorUtils.transparentize(Appearance.inir.colLayer1, 0.28)
            : ColorUtils.transparentize(Appearance.colors.colLayer0, 0.22)

    Behavior on color {
        enabled: Appearance.animationsEnabled
        ColorAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

    // ─── Border ──────────────────────────────────────────────────────
    border.width: angelEverywhere ? Appearance.angel.panelBorderWidth : 1
    border.color: angelEverywhere
        ? Appearance.angel.colPanelBorder
        : inirEverywhere
            ? ColorUtils.transparentize(Appearance.inir.colBorder, 0.4)
            : ColorUtils.transparentize(Appearance.colors.colLayer0Border, 0.5)

    Behavior on border.color {
        enabled: Appearance.animationsEnabled
        ColorAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

    // ─── Drop shadow ─────────────────────────────────────────────────
    StyledRectangularShadow {
        target: root
        visible: !gameModeMinimal
    }

    // ─── Clip + rounded mask so blur respects corners ─────────────────
    clip: true
    layer.enabled: !gameModeMinimal
    layer.effect: GE.OpacityMask {
        maskSource: Rectangle {
            width:  root.width
            height: root.height
            radius: root.radius
        }
    }

    // ─── Blurred wallpaper ────────────────────────────────────────────
    Image {
        id: macBlurWall
        visible: !root.gameModeMinimal
        source: root.wallpaperUrl
        fillMode: Image.PreserveAspectCrop
        cache: true
        asynchronous: true

        readonly property real scrW: root.dockScreen?.width  ?? 1920
        readonly property real scrH: root.dockScreen?.height ?? 1080
        width:  scrW
        height: scrH

        x: root.vertical ? 0 : (-(scrW / 2) + root.width  / 2)
        y: root.vertical
            ? (-(scrH / 2) + root.height / 2)
            : (-(scrH)     + root.height + Appearance.sizes.hyprlandGapsOut)

        layer.enabled: Appearance.effectsEnabled && !root.gameModeMinimal
        layer.effect: MultiEffect {
            source: macBlurWall
            anchors.fill: source
            saturation: root.angelEverywhere
                ? (Appearance.angel.blurSaturation * Appearance.angel.colorStrength)
                : (Appearance.effectsEnabled ? 0.35 : 0)
            blurEnabled: Appearance.effectsEnabled
            blurMax: 100
            blur: Appearance.effectsEnabled
                ? (root.angelEverywhere ? Appearance.angel.blurIntensity : 0.9)
                : 0
        }

        // Tinted overlay — lighter than the standard panel
        Rectangle {
            anchors.fill: parent
            color: root.angelEverywhere
                ? ColorUtils.transparentize(
                      root.blendedLayer0,
                      Appearance.angel.overlayOpacity * Appearance.angel.panelTransparentize * 0.7)
                : ColorUtils.transparentize(
                      root.blendedLayer0,
                      (Appearance.aurora.overlayTransparentize ?? 0.5) * 0.65)
        }
    }

    // ─── Angel partial border highlight ──────────────────────────────
    AngelPartialBorder {
        visible: angelEverywhere
        targetRadius: root.radius
    }
}
