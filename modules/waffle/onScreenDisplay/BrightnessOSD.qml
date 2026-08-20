import qs
import QtQuick
import Quickshell
import qs.services
import qs.modules.waffle.looks

OSDValue {
    id: root
    property var screen: root.QsWindow.window?.screen
    property var brightnessMonitor: screen ? Brightness.getMonitorForScreen(screen) : null
    iconName: "weather-sunny"
    value: brightnessMonitor?.brightness ?? 0
    showNumber: true

    Connections {
        target: Brightness
        function onBrightnessChanged() {
            root.timer.restart();
        }
    }
}
