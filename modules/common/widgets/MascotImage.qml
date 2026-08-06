pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.common

/**
 * The iNiR mascot, rendered per branding rules (crisp pixel-art scaling).
 * Set `pose` to a catalog name from assets/images/mascot/PROMPTS.md,
 * e.g. "notifications-clear", "about-confident", "goodbye-wave".
 * Names listed in the manifest's animatedPoses render as looping GIFs.
 * Visibility is gated by the global mascot.enable switch; keep the
 * surface's original icon/placeholder as the switched-off fallback.
 */
Image {
    id: root

    property string pose
    // Settings/archive previews deliberately show the exact requested asset,
    // including legacy portraits and editorial sheets, without enabling the
    // mascot globally or routing it through full-body runtime replacements.
    property bool previewMode: false
    property bool playAnimation: true
    // Placement group for the per-surface toggles in Settings › Mascot.
    // Empty = only gated by the master switch.
    property string surface: ""
    // Coarse group this spot belonged to before finer keys existed; old
    // configs (visibility and pose overrides) keep applying through it.
    property string fallbackSurface: ""
    property string rotatingPose: ""
    readonly property bool active: previewMode || ((Config.options?.mascot?.enable ?? false) && surfaceEnabled)
    readonly property bool surfaceEnabled: {
        if (surface.length === 0) return true
        const s = Config.options?.mascot?.surfaces
        if (!s) return true
        let v = s[surface]
        if (v === undefined && fallbackSurface.length > 0) v = s[fallbackSurface]
        return v === undefined ? true : v
    }
    // Per-surface pose override (Settings › Mascot › Surface poses). Config's
    // revision is an explicit dependency because dynamic JsonObject indexing
    // does not reliably notify every binding after a nested write.
    readonly property string surfaceOverridePose: {
        const _revision = Config.revision
        if (surface.length === 0) return ""
        const overrides = Config.options?.mascot?.surfacePoses
        if (!overrides) return ""
        const direct = overrides[surface] ?? ""
        if (direct.length > 0) return direct
        return fallbackSurface.length > 0 ? (overrides[fallbackSurface] ?? "") : ""
    }
    readonly property bool validSurfaceOverride: surfaceOverridePose.length > 0
        && MascotCatalog.collectionPoses.indexOf(surfaceOverridePose) !== -1
    readonly property string requestedPose: validSurfaceOverride
        ? surfaceOverridePose
        : rotatingPose.length > 0 ? rotatingPose : pose
    // Automatic pools stay in the full-body/contextual domain. A deliberate
    // settings override is different: the user explicitly selected that exact
    // catalog asset, so portraits, chibis and manual-only art must not be
    // silently replaced by resolvePose().
    readonly property string effectivePose: (previewMode || validSurfaceOverride)
        ? requestedPose
        : MascotCatalog.resolvePose(requestedPose, surface, fallbackSurface)
    readonly property bool animatedPose: MascotCatalog.isAnimated(effectivePose)
    // Corrects apparent size so a close-up pose doesn't read "bigger" than
    // a full-body pose inside the same fixed box (see MascotCatalog).
    readonly property real frameScale: MascotCatalog.scaleFor(effectivePose)
    transform: Scale {
        origin.x: root.width / 2
        origin.y: root.height / 2
        xScale: root.frameScale
        yScale: root.frameScale
    }

    visible: active
    source: (active && MascotCatalog.ready && effectivePose.length > 0 && !animatedPose)
        ? MascotCatalog.sourceFor(effectivePose)
        : ""
    sourceSize.width: 384
    sourceSize.height: 384
    fillMode: Image.PreserveAspectFit
    asynchronous: true
    cache: true
    smooth: true
    mipmap: true
    antialiasing: true

    function refreshSurfacePose() {
        if (previewMode || !MascotCatalog.ready) return
        rotatingPose = MascotCatalog.pickSurfacePose(surface, fallbackSurface, pose)
    }

    Component.onCompleted: refreshSurfacePose()
    onSurfaceChanged: Qt.callLater(refreshSurfacePose)
    onFallbackSurfaceChanged: Qt.callLater(refreshSurfacePose)
    Connections {
        target: MascotCatalog
        function onRevisionChanged() { root.refreshSurfacePose() }
    }

    // Animated overrides: AnimatedImage can't be the root (sourceSize is
    // read-only there), so it fills the statically-sized Image instead.
    AnimatedImage {
        anchors.fill: parent
        visible: root.active && MascotCatalog.ready && root.animatedPose
        playing: visible && root.playAnimation && Appearance.animationsEnabled
        source: visible ? MascotCatalog.sourceFor(root.effectivePose) : ""
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: true
        smooth: true
        mipmap: true
        antialiasing: true
    }
}
