import QtQuick
import qs.modules.iris.style
import "../components"

// AIRISU's lock clock: the time as a race number is cut, leaning, the figures four times the display size, in
// the ink Clock colour names, with a hard shadow of sumi cut a step down and to the right of them so they hold on a
// bright picture without a glow; the date over them, a step smaller in the media's second ink. Every Type and Clock row
// comes resolved from the engine's block; Date off leaves the time alone. Beside the foot of the figures the session is
// postmarked (APostmark): the machine's name, the day and the minute it was locked, in the seal, a stamp's turn off
// square. It is the only shu on the clock: the lock is the moment that was sealed. The stamp stands clear of the figures
// and their lean, and the box makes room for it on both sides, so the time keeps its axis; a clock too small to hold
// the stamp's date, or too wide to leave it room on screen, gets neither.
Item {
    id: root
    property var host
    readonly property int size: root.host?.timeSize ?? 4 * IrisStyle.typeDisplay
    readonly property bool showDate: root.host?.showDate ?? true
    // The shadow's step grows with the figures, as a cut number's does.
    readonly property int step: Math.max(Airisu.offset, Math.round(root.size / 40))
    readonly property int dateSize: Math.max(IrisStyle.typeLabel, Math.round(root.size * 0.16))
    readonly property int dateGap: Math.round(root.size * 0.02)

    // How far the lean carries the figures' top corner past their box, and the air between it and the stamp.
    readonly property int overhang: Math.ceil(Airisu.lean * ink.figureItem.height / 2)
    readonly property int stampGap: Math.max(Airisu.m, Math.round(root.size * 0.08))
    readonly property int stampRoom: root.overhang + root.stampGap + postmark.width
    // The date and the time keep the block's middle, the axis the other blocks stand on, so the stamp's room is kept
    // on both sides; a stamp that would run past the screen's edge is left off.
    readonly property real screenWidth: root.Window.window?.width ?? 0
    readonly property real reachable: root.screenWidth > 0 ? root.screenWidth / 2 - root.stampGap : Infinity
    readonly property bool stamped: String(root.host?.lockedText ?? "").length > 0 && postmark.drawn
        && ink.width / 2 + root.step + root.stampRoom <= root.reachable
    readonly property int wing: root.step + (root.stamped ? root.stampRoom : 0)

    implicitWidth: ink.implicitWidth + 2 * root.wing
    implicitHeight: Math.max(ink.implicitHeight + root.step, root.stamped ? postmark.y + postmark.height : 0)

    component Plate: Column {
        id: plate
        property color dateInk
        property color timeInk
        // Small type takes a small step, or it reads doubled.
        property int dateShift: 0
        readonly property alias figureItem: figure
        spacing: root.dateGap
        AText {
            transform: Translate { x: plate.dateShift; y: plate.dateShift }
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.showDate
            size: root.dateSize
            font.weight: Font.Bold
            renderType: root.host?.renderType ?? Text.NativeRendering
            color: plate.dateInk
            text: root.host?.dateText ?? ""
        }
        // Leaning like a livery number, sheared about its middle so it keeps its box; set in curves, since a sheared
        // glyph cache blurs.
        Text {
            id: figure
            anchors.horizontalCenter: parent.horizontalCenter
            renderType: Text.CurveRendering
            transform: Matrix4x4 {
                matrix: Qt.matrix4x4(1, -Airisu.lean, 0, Airisu.lean * figure.height / 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
            }
            color: plate.timeInk
            text: root.host?.timeText ?? ""
            font.family: root.host?.family ?? Airisu.figureFace
            font.features: ({ "tnum": 1 })
            font.pixelSize: root.size
            font.weight: root.host?.timeWeight ?? Font.ExtraBold
            font.letterSpacing: root.host?.tracking ?? 0
        }
    }

    Plate {
        x: root.wing + root.step
        y: root.step
        dateInk: IrisStyle.veilStrong
        timeInk: IrisStyle.veilStrong
        dateShift: Math.min(0, Airisu.hair - root.step)
    }
    Plate {
        id: ink
        x: root.wing
        dateInk: IrisStyle.onMediaSecondary
        timeInk: root.host?.colour ?? IrisStyle.onMedia
    }
    APostmark {
        id: postmark
        visible: root.stamped
        width: Math.round(root.size * 1.3)
        height: width
        x: ink.x + ink.width + root.step + root.overhang + root.stampGap
        y: Math.max(0, ink.height + root.step - height)
        colour: Airisu.sealOnMedia
        over: String(root.host?.machine ?? "").toUpperCase()
        date: root.host?.lockedAt ? Qt.formatDate(root.host.lockedAt, "dd·MM·yy") : ""
        under: String(root.host?.lockedText ?? "")
    }
}
