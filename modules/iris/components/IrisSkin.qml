import QtQuick
import qs.modules.iris.style

// Where a primitive lets the active Design draw it (DESIGNS.md › skins): the Design's anatomy for `part`, loaded over
// the primitive with `host` set to it. The primitive keeps its behaviour, input and accessibility; it hides its own
// drawing while `active`. iRiS declares no skins, so this costs nothing there.
Loader {
    id: root
    property Item host: parent
    property string part
    // The owner may decline the Design's anatomy where it does not fit (Settings' spread in a narrow window).
    property bool wanted: true
    readonly property string url: root.wanted ? IrisDesign.skin(root.part) : ""
    anchors.fill: parent
    active: root.url.length > 0
    source: root.url
    onLoaded: item.host = root.host
}
