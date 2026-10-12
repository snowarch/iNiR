import QtQuick
import qs.services
import qs.modules.common
import qs.modules.iris.style
import "../components"

// AIRISU's Spotlight head (SYSTEM.md §7, the catalogue's page head): what you type is the page's headline, set in the
// figures' face; the running head above it says which part of the catalogue you are in (Search, or the mode its key
// opened, with that key), and the folio on the right counts what the page holds, its name as ruby over the figure. A
// strong rule closes the head. The field, its keys and its focus stay the engine's: this answers where they go and the
// type they are set in.
Item {
    id: root
    property Item host
    readonly property var mode: root.host?.mode ?? null
    readonly property bool browsing: root.host?.browsing ?? true
    readonly property int count: root.host?.count ?? 0
    readonly property real d: Airisu.d
    readonly property int pad: Airisu.u(6)
    readonly property int headTop: Airisu.u(4)
    readonly property int headFoot: Airisu.u(3)

    // What the engine reads to set the query.
    readonly property int inputLeft: root.pad
    readonly property int inputRight: root.pad + (folio.visible ? folio.width + Airisu.u(4) : 0)
    readonly property int inputOffset: Math.round((running.height + Airisu.u(1)) / 2 + (root.headTop - root.headFoot) / 2)
    readonly property int inputSize: IrisStyle.typeDisplay
    readonly property string inputFamily: Airisu.figureFace
    readonly property int inputWeight: Font.ExtraBold
    readonly property int inputSpacing: -Math.round(IrisStyle.typeDisplay * 0.03)
    readonly property color inputColour: Airisu.ink
    readonly property color placeholderColour: Airisu.inkThird
    readonly property color selectionColour: Airisu.seal
    readonly property color selectedTextColour: Airisu.inkOnSeal
    readonly property int ruleWeight: Airisu.strong
    readonly property color ruleColour: Airisu.ink
    readonly property int ruleInset: root.pad

    implicitHeight: root.headTop + running.height + Airisu.u(1) + Math.ceil(IrisStyle.typeDisplay * 1.24) + root.headFoot

    // The running head: the part of the catalogue, with the key that opens it.
    Row {
        id: running
        x: root.pad
        y: root.headTop
        height: Math.max(keycap.height, word.implicitHeight)
        spacing: Airisu.u(1.5)
        ADie {
            id: keycap
            visible: root.mode !== null
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(Airisu.u(4), key.implicitWidth + Airisu.u(1.5))
            height: Airisu.u(4)
            kind: "rect"
            stroke: Airisu.inkSecond
            strokeWidth: Airisu.hair
            AText {
                id: key
                anchors.centerIn: parent
                voice: "data"
                size: IrisStyle.typeFootnote
                font.weight: Font.Bold
                color: Airisu.ink
                text: String(root.mode?.key ?? "")
            }
        }
        AText {
            id: word
            anchors.verticalCenter: parent.verticalCenter
            voice: "ruby"
            text: root.mode ? String(root.mode.label ?? "") : Translation.tr("Search")
        }
    }

    // The folio: what the page holds, its name over the figure.
    Column {
        id: folio
        visible: !root.browsing
        anchors.right: parent.right
        anchors.rightMargin: root.pad
        y: root.headTop
        spacing: Airisu.u(1)
        AText {
            anchors.right: parent.right
            voice: "ruby"
            text: root.host?.clipboardMode ? Translation.tr("History") : Translation.tr("Results")
        }
        AText {
            anchors.right: parent.right
            voice: "figure"
            size: IrisStyle.typeTitleLarge
            color: root.count > 0 ? Airisu.ink : Airisu.inkThird
            text: String(root.count)
        }
    }
}
