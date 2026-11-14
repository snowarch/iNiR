pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.services

QtObject {
    id: root
    property Item target: null
    property bool active: true
    // A reader on a surface a fullscreen window covers (a bar on Top) lets go while it is covered: nobody sees it, and
    // the sampling (and the GPU tool it runs) would go on through the whole game. The overview shows Top again.
    property bool pausesUnderFullscreen: false
    readonly property string _screenName: root.target?.QsWindow.window?.screen?.name ?? ""
    readonly property bool _covered: root.pausesUnderFullscreen && root._screenName.length > 0
        && GameMode.hasFullscreenOnOutput(root._screenName) && !NiriService.inOverview
    readonly property bool monitoring: active && !_covered && (!target || (target.visible
        && (!target.QsWindow.window || target.QsWindow.window.visible)))
    property bool _holding: false

    function sync(): void {
        if (monitoring === _holding) return;
        _holding = monitoring;
        if (_holding) ResourceUsage.keepAlive(root);
        else ResourceUsage.releaseKeepAlive(root);
    }

    onMonitoringChanged: sync()
    Component.onCompleted: sync()
    Component.onDestruction: if (_holding) ResourceUsage.releaseKeepAlive(root)
}
