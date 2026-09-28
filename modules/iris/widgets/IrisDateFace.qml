pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.iris.style

IrisWidgetFace {
    id: root

    readonly property var today: root.widget.today
    readonly property real yearShare: root.widget.dayOfYear / root.widget.daysInYear

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        FaceText {
            face: root
            Layout.fillWidth: true
            visible: root.widget.showWeekday
            text: IrisFaceData.capitalized(Qt.locale().toString(root.today, "dddd"))
            color: root.highlight
            size: 13.5
            weight: Font.DemiBold
        }
        FaceFigure {
            face: root
            Layout.fillWidth: true
            Layout.topMargin: -root.dp(4)
            text: root.today.getDate()
            size: 62
        }
        FaceText {
            face: root
            Layout.fillWidth: true
            text: IrisFaceData.capitalized(Qt.locale().toString(root.today, root.widget.showYear ? "MMMM yyyy" : "MMMM"))
            color: root.inkSecondary
            size: 13
            weight: Font.DemiBold
        }
        Item { Layout.fillHeight: true }
        RowLayout {
            visible: root.widget.showOrdinal
            Layout.fillWidth: true
            spacing: root.dp(8)
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: root.dp(4)
                radius: height / 2
                color: root.fill
                Rectangle {
                    width: Math.max(parent.height, parent.width * root.yearShare)
                    height: parent.height
                    radius: height / 2
                    color: root.highlight
                }
            }
            FaceText {
                face: root
                text: Translation.tr("Day %1").arg(root.widget.dayOfYear)
                color: root.inkTertiary
                size: 11
                font.features: ({ "tnum": 1 })
            }
        }
    }
}
