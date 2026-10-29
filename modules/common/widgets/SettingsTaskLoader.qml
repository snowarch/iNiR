pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

Loader {
    id: root

    property bool requested: false
    property bool resident: false

    Layout.fillWidth: true
    Layout.preferredHeight: requested && status === Loader.Ready && item ? item.implicitHeight : 0

    active: resident
    asynchronous: false
    visible: requested && status === Loader.Ready
    enabled: visible

    onRequestedChanged: {
        if (requested) {
            unloadDelay.stop()
            resident = true
        } else if (SettingsMaterialPreset.unified) {
            unloadDelay.stop()
        } else {
            unloadDelay.restart()
        }
    }

    Component.onCompleted: {
        if (requested)
            resident = true
    }

    Timer {
        id: unloadDelay
        interval: 600
        repeat: false
        onTriggered: root.resident = false
    }
}
