import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Shapes
import QtQuick.Layouts
import qs.modules.bar as Bar

Item { // Full hitbox
    id: root

    implicitHeight: content.implicitHeight
    implicitWidth: Appearance.sizes.verticalBarWidth
    property string dayOfMonth: Qt.locale().toString(DateTime.clock.date, "dd")  // What if 🍔murica🦅? good question
    property string monthOfYear: Qt.locale().toString(DateTime.clock.date, "MM")

    Item { // Boundaries for date numbers
        id: content
        anchors.centerIn: parent
        implicitWidth: 24
        implicitHeight: 30

        Shape {
            id: diagonalLine
            property real padding: 4
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: 1.2
                strokeColor: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext
                fillColor: "transparent"
                startX: content.width - diagonalLine.padding
                startY: diagonalLine.padding
                PathLine {
                    x: diagonalLine.padding
                    y: content.height - diagonalLine.padding
                }
            }
        }

        StyledText {
            id: dayText
            anchors {
                top: parent.top
                left: parent.left
            }
            font.pixelSize: Appearance.font.pixelSize.smallie
            color: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1
            text: dayOfMonth
        }

        StyledText {
            id: monthText
            anchors {
                bottom: parent.bottom
                right: parent.right
            }
            font.pixelSize: Appearance.font.pixelSize.smallie
            color: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1
            text: monthOfYear
        }
    }
}
