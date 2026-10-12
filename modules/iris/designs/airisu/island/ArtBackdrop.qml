import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.iris.style
import "../components"

// The record under AIRISU's page: the cover printed again, large, as a one-ink halftone run off the right edge (a
// record shop's poster), in a tone low enough to read over. It fades toward the reading side by its dots, never by a
// gradient or a blur of its colours.
Item {
    id: root
    clip: true
    AHalftone {
        width: Math.round(root.height * 1.1)
        height: width
        x: root.width - Math.round(width * 0.62)
        y: Math.round((root.height - height) / 2)
        source: MediaArtwork.displaySource
        ink: ColorUtils.mix(Airisu.ink, Airisu.ground, 0.17) // iris-literal: the poster's one ink, well under the third
        fadeFrom: 0.18
        fadeTo: 0.75
    }
}
