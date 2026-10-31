pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.shared.background.widgets
AbstractBackgroundWidget {
    id: root

    configEntryName: "controls"
    semanticPaletteControls: false
    widgetSurfaceEnabled: false
    needsColText: !root.familyFaced

    Loader {
        id: instrumentBody
        anchors.fill: parent
        active: !root.familyFaced
        sourceComponent: ControlsInstrument { widget: root }
    }
}
