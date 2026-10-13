import QtQuick
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import "../components"

// AIRISU's toast (a shell's own word: reloaded, copied, failed): a tag torn off the strip. A die of the next sheet with
// its sign and its words, the detail in the data face; its time is a hairline run of shu along the foot that is drawn
// back as it goes (the engine's clock dismisses it). An error is ruled in yamabuki with a band at its head. The engine
// keeps the click and the clock.
Item {
    id: root
    property var host
    readonly property bool error: root.host?.isError ?? false
    readonly property int pad: Airisu.u(3)
    property real remaining: 1
    NumberAnimation on remaining { from: 1; to: 0; duration: Number(root.host?.duration ?? 3000); running: root.visible }

    ALacquer {
        id: plate
        anchors.fill: parent
        cut: Airisu.cutFor(height)
        lacquer: Airisu.sheet
        coat: Airisu.tape
        head: true
        band: root.error ? Airisu.u(1) : 0
        share: root.error ? 1 : 0
        moving: false
    }
    ADie {
        visible: root.error
        anchors.fill: parent
        kind: "chamfer"
        cut: plate.c
        stroke: Airisu.tape
        strokeWidth: Airisu.hair
    }
    Row {
        anchors.verticalCenter: parent.verticalCenter
        x: root.pad
        width: parent.width - 2 * root.pad
        spacing: Airisu.u(2)
        MaterialSymbol {
            anchors.verticalCenter: parent.verticalCenter
            text: String(root.host?.icon ?? "info")
            iconSize: Math.round(17 * Airisu.d)
            color: root.error ? Airisu.caution : Airisu.inkOn(Airisu.sheet)
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - Airisu.u(7)
            AText {
                width: parent.width
                size: IrisStyle.typeLabel
                font.weight: Font.Bold
                color: Airisu.inkOn(Airisu.sheet)
                text: root.host?.copied ? Translation.tr("Copied") : String(root.host?.title ?? "")
            }
            AText {
                width: parent.width
                visible: text.length > 0
                voice: "data"
                size: IrisStyle.typeCaption
                color: Airisu.inkSecondOn(Airisu.sheet)
                text: String(root.host?.message ?? "")
            }
        }
    }
    Rectangle {
        x: Airisu.cutFor(root.height)
        y: root.height - height
        width: Math.round((root.width - x) * root.remaining)
        height: Airisu.strong
        color: root.error ? Airisu.tape : Airisu.seal
        antialiasing: false
    }
}
