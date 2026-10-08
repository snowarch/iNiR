pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services
import qs.modules.common

Singleton {
    id: root

    readonly property real strength: Math.max(0, Math.min(1, Number(Config.options?.iris?.appearance?.adaptive ?? 0) / 100))
    readonly property bool active: root.strength > 0 && root.colors.length > 0
    readonly property bool wanted: Config.options?.panelFamily === "iris"
    readonly property bool sampled: root.wanted && root.colors.length > 0

    readonly property string path: String(Wallpapers.effectiveWallpaperPath ?? "")

    ColorQuantizer {
        id: quantizer
        source: root.wanted ? Wallpapers.stillUrlFor(root.path) : ""
        depth: 3
        rescaleSize: 32
    }
    readonly property var colors: Array.from(quantizer.colors ?? []).filter(c => c && c.valid !== false)

    function luminanceOf(c): real { return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b }
    readonly property real luminance: root.colors.length === 0 ? 0.3
        : root.colors.reduce((sum, c) => sum + root.luminanceOf(c), 0) / root.colors.length
    readonly property real contrast: root.colors.length < 2 ? 0.3 : (() => {
        const values = root.colors.map(c => root.luminanceOf(c))
        return Math.max(...values) - Math.min(...values)
    })()
    readonly property real colorfulness: root.colors.length === 0 ? 0.3
        : root.colors.reduce((sum, c) => sum + Math.max(0, c.hslSaturation) * (1 - Math.abs(c.hslLightness - 0.5) * 2), 0) / root.colors.length
    readonly property real warmth: root.colors.length === 0 ? 0.5 : (() => {
        const hue = Math.max(0, root.colors[0].hslHue)
        return hue < 0.17 || hue > 0.9 ? 1 : hue > 0.45 && hue < 0.75 ? 0 : 0.5
    })()

    function factor(name: string): real {
        if (!root.active) return 1
        const a = root.strength
        switch (name) {
        case "shadow": return 1 + a * (root.contrast * 0.9 + (1 - root.luminance) * 0.3 - 0.35)
        case "shape": return 1 + a * (0.22 - root.contrast * 0.45)
        case "fill": return 1 + a * (root.luminance - 0.3) * 0.9
        case "lines": return 1 + a * (root.luminance - 0.25) * 1.2
        case "contrast": return 1 + a * root.contrast * 0.18
        case "lightReach": return 1 + a * (root.colorfulness - 0.25) * 1.6
        case "melt": return 1 + a * (0.5 - root.contrast)
        default: return 1
        }
    }
}
