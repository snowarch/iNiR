pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.modules.common
import qs.modules.common.functions
import qs.services

// Shared panel-level ZZZ statement. Use this behind content on major ii
// surfaces so the strong identity lives at the container level, not repeated
// inside every child card.
Item {
    id: root

    anchors.fill: parent

    property string label: ""
    property string index: ""
    property string ghostText: "Z·Z·Z"
    property color accentColor: Appearance.zzz.accent
    property bool showBurst: true
    property bool burstTriad: false
    property bool showGrid: true
    property bool showTicks: false
    property bool showGhost: true
    property real ghostWidthFactor: 0.74
    property real ghostStrength: 1.0
    property real horizontalBias: 0.12
    property real verticalBias: 0.04

    // Silhouette of the host panel, used to mask the wallpaper-glass wash so it
    // can't square off past a rounded corner. Panels are plain rounded plates in
    // round mode and flat rects in square mode — they carry no cut corner, so the
    // chamfer defaults to 0 rather than to ZzzGlassWash's plate default.
    property real maskRadius: Appearance.zzz.round ? Appearance.zzz.panelRadius : 0
    property real chamfer: 0
    property bool chamferTopLeft: false
    property bool chamferTopRight: false
    property bool chamferBottomLeft: false
    property bool chamferBottomRight: false

    // Global ZZZ backdrop switches (appearance.zzz.backdrop, edited from the
    // ZZZ style editor). Each layer's visibility is (consumer intent) AND
    // (global master), so a panel that never wanted a layer stays off and the
    // master can hide a layer shell-wide. Defaults true → no behaviour change.
    readonly property var _backdrop: Config.options?.appearance?.zzz?.backdrop
    readonly property bool _burstOn: _backdrop?.burst ?? true
    readonly property bool _ghostOn: _backdrop?.ghost ?? true
    readonly property bool _gridOn: _backdrop?.grid ?? true
    readonly property bool _ticksOn: _backdrop?.ticks ?? true
    readonly property real _burstSizeMult: _backdrop?.burstSize ?? 1.0

    // Optional subtle wallpaper-glass: a blurred wallpaper wash behind the grid so
    // ZZZ's carbon console plate picks up a faint hue of the desktop. Opt-in via
    // appearance.zzz.glass and gated by effectsEnabled, so it costs nothing when
    // off / in game mode. The ghost mark, grid and frame stay crisp on top.
    readonly property bool glass: Appearance.effectsEnabled && (Config.options?.appearance?.zzz?.glass ?? true)

    readonly property bool active: Appearance.zzzEverywhere
    readonly property real frameMargin: Math.max(
        Appearance.zzz.markerLength + Appearance.zzz.borderThick * 3,
        Appearance.zzz.panelRadius + Appearance.zzz.borderThick
    )
    // Fraction of the panel's short side the corner burst spans; panels
    // with room to spare (dashboard) raise it so the triad reads as part
    // of the plate instead of three floating slashes
    property real burstScale: 0.24
    readonly property real burstSize: Math.max(
        Appearance.zzz.markerLength * 4,
        Math.min(width, height) * burstScale * _burstSizeMult
    )

    visible: opacity > 0
    opacity: active ? 1 : 0
    clip: true

    Behavior on opacity {
        enabled: Appearance.animationsEnabled
        NumberAnimation {
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }
    }

    // Wallpaper-glass wash (backmost layer). Was a private copy of the same blur
    // that ZzzGlassWash does, minus the screen alignment: it cropped the wallpaper
    // to the panel's own aspect, so the atmosphere never matched the desktop behind
    // it. Cards sit opaque on top, so this colours the panel/content gaps.
    ZzzGlassWash {
        anchors.fill: parent
        z: -1
        glassEnabled: root.active && root.glass
        // Match the HOST's silhouette or the wash squares off behind a rounded
        // panel. Default to the zzz panel plate (round → panelRadius, square →
        // a flat rect, since panels carry no cut corner); hosts with a different
        // shape override these.
        maskRadius: root.maskRadius
        chamfer: root.chamfer
        chamferTopLeft: root.chamferTopLeft
        chamferTopRight: root.chamferTopRight
        chamferBottomLeft: root.chamferBottomLeft
        chamferBottomRight: root.chamferBottomRight
    }

    // Elegant depth: a faint top sheen lifts the surface and a soft floor
    // grounds it, so the panel reads as a lit console plate instead of a dead
    // flat fill. Pure token-driven, no animation (perf-neutral static layer).
    Rectangle {
        anchors.fill: parent
        visible: root.active
        // Round to the panel radius so this near-full fill never re-squares the
        // host panel's corners (panels clip rectangularly, not by radius).
        radius: Appearance.zzz.panelRadius
        gradient: Gradient {
            GradientStop { position: 0.0; color: ColorUtils.applyAlpha(Appearance.zzz.onColor, Appearance.zzz.dark ? 0.05 : 0.035) }
            GradientStop { position: 0.30; color: "transparent" }
            GradientStop { position: 0.78; color: "transparent" }
            GradientStop { position: 1.0; color: ColorUtils.applyAlpha(Appearance.zzz.bg0, Appearance.zzz.dark ? 0.32 : 0.18) }
        }
    }

    // Lateral light: a left edge lifted by the surface ink and a right edge gently
    // grounded by the base. Crossed with the vertical sheen/floor above, the tint
    // density piles up in the CORNERS and along the LEFT side — the plate reads as
    // lit from the top-left, not a flat fill. Carbon doctrine: onColor/bg0 only, no
    // accent wash. Static layer, perf-neutral.
    Rectangle {
        anchors.fill: parent
        visible: root.active
        radius: Appearance.zzz.panelRadius
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: ColorUtils.applyAlpha(Appearance.zzz.onColor, Appearance.zzz.dark ? 0.06 : 0.04) }
            GradientStop { position: 0.32; color: "transparent" }
            GradientStop { position: 1.0; color: ColorUtils.applyAlpha(Appearance.zzz.bg0, Appearance.zzz.dark ? 0.10 : 0.06) }
        }
    }

    ZzzGhostMark {
        visible: root.active && root.showGhost && root._ghostOn
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: Math.round(root.width * root.horizontalBias)
        anchors.verticalCenterOffset: Math.round(root.height * root.verticalBias)
        width: Math.max(0, Math.min(root.width * root.ghostWidthFactor, root.width - root.frameMargin * 2))
        height: width * 0.42
        strength: root.ghostStrength
        mark: root.ghostText.length > 0 ? root.ghostText : "Z·Z·Z"
    }

    ZzzBurst {
        visible: root.active && root.showBurst && root._burstOn
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        // Round: el burst roza la esquina redondeada (margén = panelRadius) para
        // leerse como un flourish de esquina integrado, no tres líneas sueltas
        // flotando. Square: margén clásico + chamfer.
        anchors.margins: Appearance.zzz.round
            ? Appearance.zzz.panelRadius
            : (root.frameMargin + Appearance.zzz.cutCorner)
        width: root.burstSize
        height: root.burstSize
        barColor: root.accentColor
        triad: root.burstTriad
    }

    ZzzTechFrame {
        anchors.fill: parent
        label: root.label
        index: root.index
        accentColor: root.accentColor
        margin: root.frameMargin
        // Doctrina zzz: round = anime soft; la grilla de ingeniería y las
        // marcas técnicas son vocabulario "console" (square). En round chocan
        // con la esquina suave y se leen como líneas feas (la línea vertical
        // izquierda en x=0 y las horizontales "medias"), así que se suprimen.
        showGrid: root.showGrid && root._gridOn && !Appearance.zzz.round
        showTicks: root.showTicks && root._ticksOn && !Appearance.zzz.round
    }
}
