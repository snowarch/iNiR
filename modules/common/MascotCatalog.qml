pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Mascot asset catalog: which pose names ship animated (GIF) vs static
 * (PNG), read once from assets/images/mascot/manifest.json so
 * per-instance widgets don't each parse the manifest.
 */
Singleton {
    id: root

    // A missing or temporarily malformed manifest must not make every mascot
    // surface disappear. Keep one pack-stable pose available until the full
    // catalog loads, then replace this fallback atomically.
    property var animatedPoses: ["presence-idle-loop"]
    property var collectionPoses: ["presence-idle-loop"]
    property var pickerPoses: ["presence-idle-loop"]
    property var desktopWidgetPoses: ["presence-idle-loop"]
    property var chibiPoses: []
    property var editorialPoses: []
    property var collectionSpecial: ({})
    property var clickTiers: ({})
    readonly property var manualOnlyPoses: root.collectionPoses.filter(pose =>
        root.editorialPoses.indexOf(pose) === -1
            && root.desktopWidgetPoses.indexOf(pose) === -1)
    readonly property var desktopWidgetSelectablePoses: root._uniquePoses(
        root.desktopWidgetPoses.concat(root.manualOnlyPoses))
    property var fullBodyPoses: ["presence-idle-loop"]
    property var contextualOcclusionPoses: []
    property var fullBodyReplacements: ({})
    property var surfaceDefaults: ({})
    property var surfacePools: ({})
    property bool ready: true
    property bool manifestAvailable: false
    property int revision: 0
    property var _surfaceHistory: ({})
    // Per-pose apparent-size correction, derived from the composition tag
    // logged in PROMPTS.md (extreme close-ups read "bigger" than full-body
    // shots at the same box size). Absent = 1.0, no correction.
    property var frameScale: ({})

    function _uniquePoses(values) {
        const seen = ({})
        const result = []
        for (let i = 0; i < values.length; ++i) {
            const pose = String(values[i] ?? "")
            if (pose.length === 0 || seen[pose])
                continue
            seen[pose] = true
            result.push(pose)
        }
        return result
    }

    function isAnimated(pose) {
        return root.animatedPoses.indexOf(pose) !== -1
    }

    function isManualOnly(pose) {
        return root.manualOnlyPoses.indexOf(pose) !== -1
    }

    function desktopWidgetPosesForGroup(group) {
        const key = group === "classic" ? "pixel" : String(group ?? "all")
        const safe = root.desktopWidgetPoses
        switch (key) {
        case "featured":
            return root.pickerPoses.filter(pose =>
                root.desktopWidgetSelectablePoses.indexOf(pose) !== -1)
        case "pixel":
            // Art-line filters are inclusive. Classic pixel chibis and loops
            // still belong to Pixel while also appearing in their specialized
            // Chibi/Loops views.
            return safe.filter(pose => !pose.startsWith("street-"))
        case "street":
            // Street is an art line, not a safety rating. Include the manual
            // subset here as well so the newest street drops do not disappear
            // from their own class; automatic pools still use `safe` only.
            return root.desktopWidgetSelectablePoses.filter(pose =>
                pose.startsWith("street-") && !root.isAnimated(pose))
        case "chibi":
            return safe.filter(pose => root.chibiPoses.indexOf(pose) !== -1)
        case "loops":
            return safe.filter(pose => root.isAnimated(pose))
        case "manual":
            return root.manualOnlyPoses
        default:
            return root.desktopWidgetSelectablePoses
        }
    }

    function scaleFor(pose) {
        return root.frameScale[pose] ?? 1.0
    }

    function sourceFor(pose) {
        if (!pose || pose.length === 0)
            return ""
        const ext = root.isAnimated(pose) ? "gif" : "png"
        return Quickshell.shellPath(`assets/images/mascot/inir-mascot-${pose}.${ext}`)
    }

    function displayName(pose) {
        const value = String(pose ?? "").replace(/^street-/, "")
        return value.split("-").map(word => word.length > 0
            ? word[0].toUpperCase() + word.slice(1)
            : word).join(" ")
    }

    function isCompatible(pose) {
        return root.fullBodyPoses.indexOf(pose) !== -1
            || root.contextualOcclusionPoses.indexOf(pose) !== -1
    }

    function collectionCategory(pose) {
        const special = root.collectionSpecial[pose]
        if (special?.category) return special.category
        if (root.fullBodyPoses.indexOf(pose) !== -1) return "fullbody"
        if (root.contextualOcclusionPoses.indexOf(pose) !== -1) return "contextual"
        if (root.chibiPoses.indexOf(pose) !== -1) return "chibi"
        if (root.editorialPoses.indexOf(pose) !== -1) return "editorial"
        if (root.isAnimated(pose)) return "animated"
        return "portrait"
    }

    function collectionRole(pose) {
        return root.collectionSpecial[pose]?.role ?? root.collectionCategory(pose)
    }

    function resolvePose(requested, surface, fallbackSurface) {
        if (root.isCompatible(requested)) return requested
        const replacement = root.fullBodyReplacements[requested] ?? ""
        if (root.isCompatible(replacement)) return replacement
        const surfacePose = root.surfaceDefaults[surface]
            ?? root.surfaceDefaults[fallbackSurface]
            ?? "presence-idle-loop"
        return root.isCompatible(surfacePose) ? surfacePose : "presence-idle-loop"
    }

    function pickSurfacePose(surface, fallbackSurface, preferred) {
        const key = root.surfacePools[surface] ? surface
            : root.surfacePools[fallbackSurface] ? fallbackSurface : ""
        const pool = key.length > 0
            ? root.surfacePools[key].filter(pose => root.isCompatible(pose))
            : []
        if (pool.length === 0)
            return root.resolvePose(preferred, surface, fallbackSurface)

        const recent = root._surfaceHistory[key] ?? []
        const fresh = pool.filter(pose => recent.indexOf(pose) === -1)
        const source = fresh.length > 0 ? fresh : pool
        const pick = source[Math.floor(Math.random() * source.length)]
        const nextRecent = recent.concat([pick]).slice(-Math.min(2, Math.max(1, pool.length - 1)))
        root._surfaceHistory = Object.assign({}, root._surfaceHistory, { [key]: nextRecent })
        return pick
    }

    FileView {
        path: Quickshell.shellPath("assets/images/mascot/manifest.json")
        watchChanges: true
        onLoadedChanged: {
            if (!loaded) return
            try {
                const m = JSON.parse(text())
                root.animatedPoses = m.animatedPoses ?? []
                root.collectionPoses = m.collectionPoses ?? []
                root.pickerPoses = m.pickerPoses ?? []
                root.desktopWidgetPoses = m.desktopWidgetPoses ?? []
                root.chibiPoses = m.chibiPoses ?? []
                root.editorialPoses = m.editorialPoses ?? []
                root.collectionSpecial = m.collectionSpecial ?? {}
                root.clickTiers = m.clickTiers ?? {}
                root.fullBodyPoses = m.fullBodyPoses ?? []
                root.contextualOcclusionPoses = m.contextualOcclusionPoses ?? []
                root.fullBodyReplacements = m.fullBodyReplacements ?? {}
                root.surfaceDefaults = m.surfaceDefaults ?? {}
                root.surfacePools = m.surfacePools ?? {}
                root.frameScale = m.frameScale ?? {}
                root.manifestAvailable = true
                root.ready = true
                root.revision++
            } catch (e) {
                root.manifestAvailable = false
                console.warn("[MascotCatalog] manifest load failed; using fallback catalog:", e)
            }
        }
    }

    Timer {
        interval: 1200
        running: true
        repeat: false
        onTriggered: {
            if (!root.manifestAvailable)
                console.warn("[MascotCatalog] mascot manifest unavailable; using fallback catalog")
        }
    }
}
