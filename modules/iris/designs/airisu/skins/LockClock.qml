import QtQuick
import qs.modules.iris.style
import "../components"

// AIRISU's lock clock: the time as a race number is cut, the figures four times the display size, in
// the ink Clock colour names, with a hard shadow of sumi cut a step down and to the right of them so they hold on a
// bright picture without a glow; the date over them, a step smaller in the media's second ink. Every Type and Clock row
// comes resolved from the engine's block; Date off leaves the time alone.
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
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            renderType: root.host?.renderType ?? Text.NativeRendering
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
}
