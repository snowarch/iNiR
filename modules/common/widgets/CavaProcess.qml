pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.services.deferred

// Thin wrapper for backwards compatibility. All consumers historically
// instantiated their own CavaProcess { active: ...; points }, which spawned
// a subprocess per consumer. The actual cava lifecycle now lives in
// services/CavaService.qml — see #160.
//
// This component just subscribes/unsubscribes on `active` and exposes the
// shared points list. Same external API.
Item {
    id: root

    property bool active: false
    readonly property var points: CavaService.points

    onActiveChanged: {
        if (active) CavaService.subscribe()
        else CavaService.unsubscribe()
    }

    Component.onDestruction: {
        if (active) CavaService.unsubscribe()
    }
}
