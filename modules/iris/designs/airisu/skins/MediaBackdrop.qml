import QtQuick
import qs.modules.common.functions
import "../components"

// AIRISU's cover behind a player (the Control Center's, a media card's): the cover printed again as a one-ink halftone,
// as the Island's page does. The dots fade out toward the side the words are set on, by their size, never by a film,
// so the type stands on the stock. A quiet tone of the ink, a little more than a fifth of the way to it.
Item {
    id: root
    property Item host
    clip: true
    AHalftone {
        anchors.fill: parent
        source: root.host?.source ?? ""
        ink: ColorUtils.mix(Airisu.ink, Airisu.ground, 0.22) // iris-literal: the halftone's quiet tone of the ink
        fadeFrom: 0.12
        fadeTo: 0.78
    }
}
