pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.frame
import qs.modules.iris.components
import qs.modules.iris.preview.parts

PreviewScene {
    id: panelRoot
    readonly property real panelWidth: Math.max(300, Math.min(560, Number(panelRoot.opt("iris.sidebars.right.width", 380)))) * panelRoot.d
    readonly property real naturalWidth: panelRoot.panelWidth * 2.2
    readonly property real naturalHeight: Math.round(420 * panelRoot.d)
    Plate {
        surface: "panels"
        fallbackRadius: IrisStyle.radiusPanel
        anchors.right: parent.right
        anchors.rightMargin: IrisFrame.band + IrisFrame.bodyAir
        y: IrisFrame.band + IrisFrame.bodyAir
        width: panelRoot.panelWidth
        height: parent.height - 2 * y
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Math.round(16 * panelRoot.d)
            spacing: Math.round(10 * panelRoot.d)
            RowLayout {
                spacing: Math.round(10 * panelRoot.d)
                IrisText { text: Translation.locale.toString(DateTime.clock.date, "d"); color: IrisStyle.identity.red; font.family: IrisStyle.fontNumbers; font.weight: IrisStyle.weight(Font.Bold); font.pixelSize: 30 * IrisStyle.typeScale }
                ColumnLayout {
                    spacing: 0
                    IrisText { text: Translation.tr("Today"); font.family: IrisStyle.fontTitle; font.weight: IrisStyle.weight(Font.Bold); font.pixelSize: IrisStyle.typeTitle }
                    IrisText { text: Translation.locale.toString(DateTime.clock.date, "dddd, MMMM"); color: IrisStyle.subtext; font.pixelSize: IrisStyle.typeMeta }
                }
                Item { Layout.fillWidth: true }
                IrisControlPlate {
                    id: previewPanelTools
                    Layout.alignment: Qt.AlignVCenter
                    controlHeight: Math.round(28 * panelRoot.d)
                    Row {
                        spacing: Math.round(2 * panelRoot.d)
                        Repeater {
                            model: ["keep", "tune", "close"]
                            Item {
                                required property string modelData
                                width: Math.round(28 * panelRoot.d); height: width
                                MaterialSymbol { anchors.centerIn: parent; text: parent.modelData; iconSize: Math.round(16 * panelRoot.d); color: IrisStyle.textSecondary }
                            }
                        }
                    }
                }
            }
            Repeater {
                model: [["calendar_month", Translation.tr("Calendar"), IrisStyle.identity.red], ["partly_cloudy_day", Translation.tr("Weather"), IrisStyle.identity.sky], ["notifications", Translation.tr("Notifications"), IrisStyle.identity.orange]]
                Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: IrisStyle.radiusCard
                    color: IrisStyle.surfaceHigh
                    RowLayout {
                        x: Math.round(12 * panelRoot.d); y: Math.round(12 * panelRoot.d)
                        spacing: Math.round(8 * panelRoot.d)
                        Rectangle {
                            implicitWidth: Math.round(24 * panelRoot.d); implicitHeight: implicitWidth
                            radius: IrisStyle.iconRadius(width); color: parent.parent.modelData[2]
                            MaterialSymbol { anchors.centerIn: parent; text: parent.parent.parent.modelData[0]; fill: 1; iconSize: Math.round(14 * panelRoot.d); color: IrisStyle.onTint }
                        }
                        IrisText { text: parent.parent.modelData[1]; font.weight: IrisStyle.weight(Font.DemiBold) }
                    }
                }
            }
        }
    }
}
