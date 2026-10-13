import QtQuick
import qs.modules.iris.style
import "../components"

// AIRISU's lock clock: the time as a race number is cut, leaning, the figures four times the display size, in
// the ink Clock colour names, with a hard shadow of sumi cut a step down and to the right of them so they hold on a
// bright picture without a glow; the date over them, a step smaller in the media's second ink. Every Type and Clock row
// comes resolved from the engine's block; Date off leaves the time alone. Over the lower end of the figures the session
// is postmarked (APostmark): the machine's name, the day and the minute it was locked, in the seal, a stamp's turn off
// square. It is the only shu on the clock: the lock is the moment that was sealed.
Item {
    id: root
    property var host
    readonly property int size: root.host?.timeSize ?? 4 * IrisStyle.typeDisplay
    readonly property bool showDate: root.host?.showDate ?? true
    // The shadow's step grows with the figures, as a cut number's does.
    readonly property int step: Math.max(Airisu.offset, Math.round(root.size / 40))
    readonly property int dateSize: Math.max(IrisStyle.typeLabel, Math.round(root.size * 0.16))
    readonly property int dateGap: Math.round(root.size * 0.02)

    implicitWidth: ink.implicitWidth + root.step
    implicitHeight: ink.implicitHeight + root.step

    component Plate: Column {
        id: plate
        property color dateInk
        property color timeInk
        // Small type takes a small step, or it reads doubled.
        property int dateShift: 0
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
        x: root.step
        y: root.step
        dateInk: IrisStyle.veilStrong
        timeInk: IrisStyle.veilStrong
        dateShift: Math.min(0, Airisu.hair - root.step)
    }
    Plate {
        id: ink
        dateInk: IrisStyle.onMediaSecondary
        timeInk: root.host?.colour ?? IrisStyle.onMedia
    }
    APostmark {
        visible: String(root.host?.lockedText ?? "").length > 0
        width: Math.round(root.size * 1.3)
        height: width
        x: ink.width - Math.round(width * 0.55)
        y: ink.height - Math.round(height * 0.6)
        colour: Airisu.sealOnMedia
        over: String(root.host?.machine ?? "").toUpperCase()
        date: root.host?.lockedAt ? Qt.formatDate(root.host.lockedAt, "dd·MM·yy") : ""
        under: String(root.host?.lockedText ?? "")
    }
}
