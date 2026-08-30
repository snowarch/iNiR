import QtQuick
import Quickshell
import qs

Item {
    LazyLoader {
        loading: GlobalStates.deferredPanelsReady
        activeAsync: GlobalStates.deferredPanelsReady
        source: "modules/waffle/ShellWafflePanelsImpl.qml"
    }
}
