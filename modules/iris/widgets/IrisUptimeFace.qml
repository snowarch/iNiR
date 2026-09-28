pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.iris.style

IrisWidgetFace {
    id: root

    readonly property int total: root.widget.sessionSeconds
    readonly property int days: Math.floor(root.total / 86400)
    readonly property int hours: Math.floor(root.total % 86400 / 3600)
    readonly property int minutes: Math.floor(root.total % 3600 / 60)
    readonly property var parts: root.days > 0
        ? [{ value: root.days, unit: Translation.tr("d") }, { value: root.hours, unit: Translation.tr("h") }]
        : [{ value: root.hours, unit: Translation.tr("h") }, { value: root.minutes, unit: Translation.tr("min") }]

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        FaceHeader {
            face: root
            Layout.fillWidth: true
            glyph: "timelapse"
            text: Translation.tr("Uptime")
        }
        Item { Layout.fillHeight: true }
        Row {
            spacing: root.dp(6)
            Repeater {
                model: root.parts
                Row {
                    id: part
                    required property var modelData
                    spacing: root.dp(2)
                    FaceFigure {
                        id: figure
                        face: root
                        text: part.modelData.value
                        size: 38
                    }
                    FaceText {
                        face: root
                        anchors.baseline: figure.baseline
                        text: part.modelData.unit
                        color: root.inkSecondary
                        size: 15
                        weight: Font.DemiBold
                    }
                }
            }
        }
        FaceText {
            face: root
            Layout.fillWidth: true
            visible: root.widget.showSince
            text: Translation.tr("Since %1").arg(root.widget.bootLabel)
            color: root.inkSecondary
            size: 12.5
        }
        FaceText {
            face: root
            Layout.fillWidth: true
            visible: root.widget.showBreakdown && root.widget.sessionDay > 1
            text: Translation.tr("Day %1 of this session").arg(root.widget.sessionDay)
            color: root.inkTertiary
            size: 11.5
        }
    }
}
