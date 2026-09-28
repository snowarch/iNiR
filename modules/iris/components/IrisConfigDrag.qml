import QtQuick
import qs.modules.common

QtObject {
    id: root

    required property string path
    property int interval: 120
    property var pending: undefined

    function push(value: var): void {
        root.pending = value
        if (!root.throttle.running) root.throttle.start()
    }
    function flush(): void {
        root.throttle.stop()
        if (root.pending === undefined) return
        const value = root.pending
        root.pending = undefined
        if (Config.getNestedValue(root.path, undefined) !== value) Config.setNestedValue(root.path, value)
    }

    property Timer throttle: Timer {
        interval: root.interval
        onTriggered: root.flush()
    }
}
