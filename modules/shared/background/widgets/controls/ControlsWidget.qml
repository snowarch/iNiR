pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.shared.background.widgets
AbstractBackgroundWidget {
    id: root

    configEntryName: "controls"
    defaultConfig: ({
        placementStrategy: "free", widgetScale: 100, cornerRadius: -1, x: 120, y: 420
    })

    irisFacePart: "controls"
    semanticPaletteControls: false
    widgetSurfaceEnabled: false
    needsColText: !root.irisFaced

    Loader {
        id: instrumentBody
        anchors.fill: parent
        active: !root.irisFaced
        sourceComponent: ControlsInstrument { widget: root }
    }
}
