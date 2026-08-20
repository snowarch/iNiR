pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.services.deferred
import qs.modules.common

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
    property int sampleCount: 0
    readonly property var _emptyPoints: []
    readonly property var points: root._held ? CavaService.points : root._emptyPoints
    readonly property real normalizationCeiling: root._held
        ? CavaService.normalizationCeiling : 100
    readonly property bool audioSignalActive: root._held
        ? CavaService.audioSignalActive : false

    readonly property bool _wanted: active && !Appearance.gameModeMinimal
    property bool _held: false
    readonly property bool held: root._held
    property int _subscriptionId: -1

    function _reconcile(): void {
        if (_wanted === _held)
            return
        if (_wanted) {
            root._subscriptionId = CavaService.subscribe(root.sampleCount)
        } else {
            CavaService.unsubscribe(root._subscriptionId)
            root._subscriptionId = -1
        }
        _held = _wanted
    }

    on_WantedChanged: root._reconcile()
    onSampleCountChanged: {
        if (root._held)
            CavaService.updateSubscription(root._subscriptionId, root.sampleCount)
    }
    Component.onCompleted: root._reconcile()

    Component.onDestruction: {
        if (_held) CavaService.unsubscribe(root._subscriptionId)
    }
}
