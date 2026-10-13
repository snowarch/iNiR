import QtQuick
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components
import "../components"

// AIRISU's at-a-glance chip on the lock: an inventory label (SYSTEM.md §6, chip). The mark first, then the datum with
// what it is as its ruby: the city over the temperature, when over the event, Battery over the charge. A figure is set
// in the figure face, words in the reading face; the plate under it is the lock's, cut by the die.
Item {
    id: root
    property var host
    readonly property real s: root.host?.textScale ?? 1
    function t(px: real): int { return Math.round(px * root.s) }
    readonly property string figure: root.host?.figure ?? ""
    readonly property string datum: root.figure.length > 0 ? root.figure : (root.host?.headline || root.host?.label || "")
    readonly property real battery: root.host?.battery ?? -1
    readonly property int pad: Airisu.u(3)
    implicitWidth: root.pad + mark.width + Airisu.u(2) + Math.max(ruby.implicitWidth, Math.min(main.implicitWidth, Airisu.u(55))) + root.pad + Airisu.u(1)
    implicitHeight: Airisu.u(12)

    Item {
        id: mark
        x: root.pad
        anchors.verticalCenter: parent.verticalCenter
        width: Airisu.u(5)
        height: width
        MaterialSymbol {
            anchors.centerIn: parent
            visible: root.battery < 0 || root.host?.glyph === "bolt"
            text: root.host?.glyph ?? ""
            fill: 1
            iconSize: Airisu.u(5)
            color: root.host?.tint ?? IrisStyle.onMedia
        }
        IrisBatteryMark {
            anchors.centerIn: parent
            visible: root.battery >= 0 && root.host?.glyph !== "bolt"
            markHeight: Math.round(11 * Airisu.d)
            level: root.battery
            tint: root.host?.tint ?? IrisStyle.onMedia
            frame: IrisStyle.onMediaTertiary
        }
    }
    Column {
        x: mark.x + mark.width + Airisu.u(2)
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0
        AText {
            id: ruby
            visible: text.length > 0
            voice: "ruby"
            size: root.t(IrisStyle.typeFootnote)
            renderType: root.host?.renderType ?? Text.NativeRendering
            color: IrisStyle.onMediaSecondary
            text: root.host?.ruby ?? ""
        }
        AText {
            id: main
            width: Math.min(implicitWidth, Airisu.u(55))
            voice: root.figure.length > 0 ? "figure" : "text"
            size: root.figure.length > 0 ? root.t(IrisStyle.typeTitle) : root.t(IrisStyle.typeBody)
            font.weight: root.figure.length > 0 ? Font.ExtraBold : Font.DemiBold
            renderType: root.host?.renderType ?? Text.NativeRendering
            color: IrisStyle.onMedia
            text: root.datum
        }
    }
}
