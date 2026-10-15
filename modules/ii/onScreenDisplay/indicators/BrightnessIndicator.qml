import qs.services
import QtQuick
import Quickshell
import qs.modules.ii.onScreenDisplay

OsdValueIndicator {
    id: root
    // Use the same screen logic as QuickSliders / bars so it works on Niri too
    property var screen: root.QsWindow.window?.screen
    // Brightness monitor may be undefined; guard access
    property var brightnessMonitor: screen ? Brightness.getMonitorForScreen(screen) : null

    icon: Hyprsunset.active ? "routine" : "light_mode"
    name: Translation.tr("Brightness")
    // Brightness service exposes value in range [0, 1], same as volume
    value: root.brightnessMonitor ? root.brightnessMonitor.brightness : 0
}
