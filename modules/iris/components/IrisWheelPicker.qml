pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import qs.modules.iris.style

Item {
    id: root

    property var columns: []
    property var values: []
    property string separator: ":"
    property int rows: 3
    property real rowHeight: Math.round(32 * IrisStyle.density)
    property real figureSize: 22 * IrisStyle.typeScale
    signal moved(int column, int index)

    readonly property real d: IrisStyle.density
    function valueOf(column: int): int { return Number(root.values?.[column] ?? 0) }

    implicitWidth: row.implicitWidth + Math.round(28 * root.d)
    implicitHeight: root.rowHeight * root.rows

    Rectangle {
        anchors.centerIn: parent
        width: row.implicitWidth + Math.round(28 * root.d)
        height: root.rowHeight + Math.round(2 * root.d)
        radius: height / 2
        color: IrisStyle.fillQuiet
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Math.round(4 * root.d)

        Repeater {
            model: root.columns
            Row {
                id: column
                required property var modelData
                required property int index
                spacing: Math.round(4 * root.d)

                IrisText {
                    visible: column.index > 0 && root.separator.length > 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.separator
                    color: IrisStyle.secondaryAccent
                    font.family: IrisStyle.fontNumbers
                    font.pixelSize: root.figureSize
                    font.weight: IrisStyle.weight(Font.Bold)
                }

                Tumbler {
                    id: wheel
                    readonly property int step: Number(column.modelData.step ?? 1)
                    model: Number(column.modelData.count ?? 60)
                    visibleItemCount: root.rows
                    wrap: true
                    implicitWidth: Math.round(root.figureSize * 2.4)
                    implicitHeight: root.rowHeight * root.rows
                    background: null
                    function follow(): void {
                        const wanted = root.valueOf(column.index)
                        if (wheel.currentIndex !== wanted) wheel.currentIndex = wanted
                    }
                    Component.onCompleted: wheel.follow()
                    IrisWheelIntent { id: wheelIntent; target: wheel; hovered: wheelHover.hovered }
                    HoverHandler { id: wheelHover; onPointChanged: wheelIntent.track(point.position.x, point.position.y) }
                    Connections {
                        target: root
                        function onValuesChanged(): void { wheel.follow() }
                    }
                    onCurrentIndexChanged: if (wheel.currentIndex !== root.valueOf(column.index)) root.moved(column.index, wheel.currentIndex)
                    activeFocusOnTab: true
                    Keys.onUpPressed: wheel.currentIndex = (wheel.currentIndex - 1 + wheel.count) % wheel.count
                    Keys.onDownPressed: wheel.currentIndex = (wheel.currentIndex + 1) % wheel.count
                    Accessible.role: Accessible.SpinBox
                    Accessible.name: String(column.modelData.unit ?? "")
                    delegate: IrisText {
                        id: figure
                        required property int index
                        readonly property real distance: Math.abs(figure.Tumbler.displacement)
                        text: String(figure.index * wheel.step).padStart(2, "0")
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        opacity: Math.max(0.16, 1 - figure.distance * 0.72)
                        scale: 1 - Math.min(0.26, figure.distance * 0.2)
                        font.family: IrisStyle.fontNumbers
                        font.features: ({ "tnum": 1 })
                        font.pixelSize: root.figureSize
                        font.weight: figure.distance < 0.5 ? Font.Bold : Font.Medium
                    }
                    WheelHandler {
                        enabled: wheelIntent.armed
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        property real accumulator: 0
                        onWheel: event => {
                            accumulator += event.angleDelta.y !== 0 ? event.angleDelta.y : event.pixelDelta.y * 4
                            const steps = Math.trunc(accumulator / 120)
                            if (steps === 0) return
                            accumulator -= steps * 120
                            wheel.currentIndex = ((wheel.currentIndex - steps) % wheel.count + wheel.count) % wheel.count
                        }
                    }
                }

                IrisText {
                    visible: String(column.modelData.unit ?? "").length > 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: String(column.modelData.unit ?? "")
                    color: IrisStyle.textSecondary
                    font.pixelSize: IrisStyle.typeLabel
                    font.weight: IrisStyle.weight(Font.DemiBold)
                }
            }
        }
    }
}
