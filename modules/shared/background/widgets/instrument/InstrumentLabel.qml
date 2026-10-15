pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// The Instrument eyebrow and field caption: monospace capitals on a whole-pixel tracking.
StyledText {
    property real scaleFactor: 1
    property real size: 9
    property bool strong: false

    font.family: Appearance.font.family.monospace
    font.pixelSize: Math.max(7, Math.round(size * scaleFactor))
    font.weight: strong ? Font.DemiBold : Font.Normal
    font.letterSpacing: Math.max(0, Math.round(0.9 * scaleFactor))
    font.capitalization: Font.AllUppercase
    elide: Text.ElideRight
}
