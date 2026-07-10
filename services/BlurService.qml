pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common

Singleton {
    id: root

    property bool ready: true

    readonly property bool isPlugged: !Battery.available || Battery.isPluggedIn

    onIsPluggedChanged: {
        const scriptPath = Quickshell.shellPath("scripts/niri-config.py");
        Quickshell.execDetached(["python3", scriptPath, "sync-power-state", String(isPlugged)]);
    }

    Component.onCompleted: {
        const scriptPath = Quickshell.shellPath("scripts/niri-config.py");
        Quickshell.execDetached(["python3", scriptPath, "sync-power-state", String(isPlugged)]);
    }
}
