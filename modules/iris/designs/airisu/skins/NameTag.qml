import QtQuick
import QtQuick.Shapes
import qs.modules.iris.style
import "../components"

// AIRISU's name tag over a Dock slot: a part's label (品名札). A die of the next sheet with the app's name in the text
// face and, when it has more than one window, how many as a figure leaning after it; a small die-cut point on the side
// that faces the Dock says which part it names. The engine keeps when it shows and where.
Item {
    id: root
    property var host
    readonly property string label: String(root.host?.label ?? "")
    readonly property int count: Number(root.host?.windowCount ?? 0)
    readonly property string facing: String(root.host?.facing ?? "down")
    readonly property int pad: Airisu.u(3)
    readonly property int point: Airisu.u(1.5)
    implicitWidth: row.implicitWidth + 2 * root.pad
    implicitHeight: Airisu.u(7)

    ALacquer {
        anchors.fill: parent
        cut: Airisu.cutFor(height)
        lacquer: Airisu.sheet
        moving: false
    }
    // The point, toward the slot.
    Shape {
        id: tip
        readonly property real cx: root.facing === "left" ? 0 : root.facing === "right" ? root.width : root.width / 2
        readonly property real cy: root.facing === "up" ? 0 : root.facing === "down" ? root.height : root.height / 2
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: Airisu.sheet
            strokeColor: "transparent"
            strokeWidth: 0
            PathPolyline {
                path: {
                    const p = root.point, x = tip.cx, y = tip.cy
                    if (root.facing === "down") return [Qt.point(x - p, y), Qt.point(x + p, y), Qt.point(x, y + p), Qt.point(x - p, y)]
                    if (root.facing === "up") return [Qt.point(x - p, y), Qt.point(x + p, y), Qt.point(x, y - p), Qt.point(x - p, y)]
                    if (root.facing === "left") return [Qt.point(x, y - p), Qt.point(x, y + p), Qt.point(x - p, y), Qt.point(x, y - p)]
                    return [Qt.point(x, y - p), Qt.point(x, y + p), Qt.point(x + p, y), Qt.point(x, y - p)]
                }
            }
        }
    }
    Row {
        id: row
        anchors.centerIn: parent
        spacing: Airisu.u(1.5)
        AText {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, Math.round(260 * Airisu.d))
            size: IrisStyle.typeLabel
            font.weight: Font.Bold
            color: Airisu.inkOn(Airisu.sheet)
            text: root.label
        }
        AText {
            visible: root.count > 1
            anchors.verticalCenter: parent.verticalCenter
            voice: "figure"
            lean: Airisu.lean
            size: IrisStyle.typeLabel
            color: Airisu.inkSecondOn(Airisu.sheet)
            text: "×" + root.count
        }
    }
}
