pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.services

QtObject {
    id: root
    property Item target: null
    property bool active: true
    readonly property bool monitoring: active && (!target || (target.visible
        && (!target.QsWindow.window || target.QsWindow.window.visible)))
    property bool _holding: false

    function sync(): void {
        if (monitoring === _holding) return;
        _holding = monitoring;
        if (_holding) ResourceUsage.keepAlive();
        else ResourceUsage.releaseKeepAlive();
    }

    onMonitoringChanged: sync()
    Component.onCompleted: sync()
    Component.onDestruction: if (_holding) ResourceUsage.releaseKeepAlive()
}
