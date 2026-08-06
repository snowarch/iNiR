pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common
import qs.modules.common.functions

// Giant faint ZZZ wordmark watermark for panel backdrops. Drop it into a clipped
// surface (behind content, low z). Shared so every major panel carries the same
// ZZZ signature — generated ink, no hardcoded color. Zero cost when inactive.
Text {
    id: root

    property real sizeFactor: 0.5      // height fraction
    property real strength: 1.0        // opacity multiplier
    property string mark: "Z·Z·Z"

    visible: Appearance.zzzEverywhere
    text: mark
    color: ColorUtils.applyAlpha(Appearance.zzz.onColor,
        (Appearance.m3colors.darkmode ? 0.035 : 0.045) * strength)
    font.family: Appearance.font.family.title
    font.pixelSize: Math.max(48, Math.round((parent ? parent.height : 200) * sizeFactor))
    font.weight: Font.Black
    font.italic: true
    renderType: Text.NativeRendering
}
