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
    // A Settings layout (Folio, Console) voices its rows' controls; only the rows it hosts pass it, the shell never does.
    property string voice: ""
    readonly property var voiced: ({ folio: ["switch", "segmented", "scrubber", "groupHeader"],
        deck: ["segmented"], console: ["switch", "segmented", "scrubber", "groupHeader"] })
    readonly property string voiceUrl: (root.voiced[root.voice] ?? []).includes(root.part)
        ? Qt.resolvedUrl("../settings/layouts/" + root.voice + "/" + root.part.charAt(0).toUpperCase() + root.part.slice(1) + ".qml") : ""
    // What the owner draws with when the Design has no anatomy of its own for the part (Settings' layouts).
    property string fallback: ""
    readonly property string url: !root.wanted ? "" : IrisDesign.skin(root.part) || root.voiceUrl || root.fallback
    anchors.fill: parent
    active: root.url.length > 0
    source: root.url
    onLoaded: item.host = root.host
}
