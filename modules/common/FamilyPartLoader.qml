import QtQuick
import Quickshell
import qs.services

// A family's part that is not drawn inside an item (a window, a host, a style object), loaded by name; nothing when
// the family has none. LazyLoader takes a new file only on a fresh activation, so a change of family or part
// deactivates it first (bound, a file that came after `active` never loaded, and a family switch kept the old one).
LazyLoader {
    id: root

    property string part: ""
    property string family: Plugins.active
    property bool when: true
    readonly property string url: root.part.length > 0 && Plugins.ready ? Plugins.part(root.family, root.part) : ""
    readonly property bool wanted: root.when && root.url.length > 0
    // What was last asked of the LazyLoader: `active` reads false until the item exists, so it can't tell.
    property string _url: ""
    property bool _on: false

    onUrlChanged: root._load()
    onWantedChanged: root._load()
    Component.onCompleted: root._load()

    function _load(): void {
        if (root._url === root.url && root._on === root.wanted) return
        root._url = root.url
        root._on = root.wanted
        root.active = false
        root.source = root.url
        root.active = root.wanted
    }
}
