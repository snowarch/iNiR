pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.background.widgets
import qs.modules.iris.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "screenTime"
    defaultConfig: ({
        placementStrategy: "free", widgetScale: 100, cornerRadius: -1, x: 120, y: 240
    })

    implicitWidth: root.irisFaced ? root.irisFaceWidth : instrumentBody.implicitWidth
    implicitHeight: root.irisFaced ? root.irisFaceHeight : instrumentBody.implicitHeight
    irisOnly: true
    irisFace: Component { IrisScreenTimeFace { widget: root } }
    irisSizes: ["small", "medium", "large"]
    irisDefaultSize: "medium"
    semanticPaletteControls: false
    widgetSurfaceEnabled: false
    needsColText: !root.irisFaced

    Loader {
        id: instrumentBody
        anchors.fill: parent
        active: !root.irisFaced
        sourceComponent: ScreenTimeInstrument { widget: root }
    }
}
