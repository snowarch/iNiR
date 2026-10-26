import QtQuick
import qs.services

// A part the active family draws on a shared surface (a part in its plugin.json), loaded by name; nothing when the
// family has none. `props` are handed over at creation and again whenever they change.
Loader {
    id: root

    property string part: ""
    property string family: Plugins.active
    property bool when: true
    property var props: ({})
    readonly property string url: root.part.length > 0 && Plugins.ready ? Plugins.part(root.family, root.part) : ""

    active: root.when && root.url.length > 0
    onUrlChanged: root._load()
    onPropsChanged: root._apply()
    // A part made again after `when` turned back on is built from the props it was first given: bring it up to date.
    onLoaded: root._apply()
    Component.onCompleted: root._load()

    function _apply(): void {
        if (!root.item) return
        for (const key in root.props)
            if (key in root.item && root.item[key] !== root.props[key]) root.item[key] = root.props[key]
    }

    function _load(): void {
        if (root.url.length > 0) root.setSource(root.url, root.props)
        else root.source = ""
    }
}
