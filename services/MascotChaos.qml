pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.common

/**
 * Chaos-mode bus for the mascot: desktop widgets report their live geometry
 * here (only while chaos is enabled), the romp emits physics impulses, and
 * widgets animate them locally. Also remembers every widget's pre-chaos
 * position so tidy() can undo the whole mess.
 *
 * Signals are fire-and-forget; widgets own their animations. Nothing here
 * moves anything directly except tidy(), which writes original positions
 * back through the normal Config path.
 */
Singleton {
    id: root

    readonly property bool enabled: (Config.options?.mascot?.enable ?? false)
        && (Config.options?.mascot?.chaos?.enable ?? false)
    readonly property bool allowRearrange: Config.options?.mascot?.chaos?.allowRearrange ?? false

    // Live widget geometry, key -> { x, y, w, h } (screen coordinates)
    property var geometry: ({})
    // First-seen config positions, key -> { x, y } — the "before chaos" state
    property var originals: ({})

    // mode: "bounce" (spring back home) | "persist" (keep the new spot) |
    //       "wreck" (knocked out — falls to the floor and stays there until tidy)
    signal impact(string widgetKey, real vx, real vy, string mode)
    // intensity 1 = ground-slam rumble; 2 = direct kick to the panel
    signal panelShake(real intensity)
    signal tidied()

    function report(key: string, x: real, y: real, w: real, h: real): void {
        const g = root.geometry
        g[key] = { x: x, y: y, w: w, h: h }
        root.geometry = g
    }
    function unreport(key: string): void {
        const g = root.geometry
        delete g[key]
        root.geometry = g
    }
    function rememberOriginal(key: string, x: real, y: real): void {
        if (key in root.originals) return
        const o = root.originals
        o[key] = { x: x, y: y }
        root.originals = o
    }

    // Kickable targets for the romp planner
    function targets(): var {
        const out = []
        for (const key in root.geometry) {
            const g = root.geometry[key]
            if (g && g.w > 0 && g.h > 0)
                out.push({ key: key, x: g.x, y: g.y, w: g.w, h: g.h })
        }
        return out
    }

    // Put every displaced widget back where it was before the chaos started
    function tidy(): void {
        const updates = {}
        for (const key in root.originals) {
            const o = root.originals[key]
            updates[`background.widgets.${key}.x`] = Math.round(o.x)
            updates[`background.widgets.${key}.y`] = Math.round(o.y)
        }
        if (Object.keys(updates).length > 0)
            Config.setNestedValues(updates)
        root.originals = ({})
        root.tidied()
        console.log("[MascotChaos] tidy: restored", Object.keys(updates).length / 2, "widgets")
    }
}
