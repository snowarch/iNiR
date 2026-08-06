import QtQuick
import Quickshell
import qs.modules.common

/**
 * Animated (GIF) variant of MascotImage for spots that loop while
 * visible. Note: AnimatedImage's sourceSize is read-only, so no
 * downsampling here — size via width/height at the call site.
 */
AnimatedImage {
    id: root

    property string pose
    property string surface: ""
    // Coarse group this spot belonged to before finer keys existed
    property string fallbackSurface: ""
    readonly property bool active: (Config.options?.mascot?.enable ?? false) && surfaceEnabled
    readonly property bool surfaceEnabled: {
        if (surface.length === 0) return true
        const s = Config.options?.mascot?.surfaces
        if (!s) return true
        let v = s[surface]
        if (v === undefined && fallbackSurface.length > 0) v = s[fallbackSurface]
        return v === undefined ? true : v
    }
    // Per-surface override; a static override name renders as a still PNG
    readonly property string requestedPose: {
        if (surface.length > 0) {
            const o = Config.options?.mascot?.surfacePoses
            if (o) {
                const v = o[surface] ?? ""
                if (v.length > 0) return v
                const legacy = fallbackSurface.length > 0 ? (o[fallbackSurface] ?? "") : ""
                if (legacy.length > 0) return legacy
            }
        }
        return pose
    }
    readonly property string effectivePose: MascotCatalog.resolvePose(requestedPose, surface, fallbackSurface)
    // Same apparent-size correction as MascotImage — see MascotCatalog.
    readonly property real frameScale: MascotCatalog.scaleFor(effectivePose)
    transform: Scale {
        origin.x: root.width / 2
        origin.y: root.height / 2
        xScale: root.frameScale
        yScale: root.frameScale
    }

    visible: active && MascotCatalog.ready
    playing: active && visible && Appearance.animationsEnabled
    source: (active && MascotCatalog.ready && effectivePose.length > 0)
        ? MascotCatalog.sourceFor(effectivePose)
        : ""
    fillMode: Image.PreserveAspectFit
    asynchronous: true
    cache: true
    smooth: false
    mipmap: false
}
