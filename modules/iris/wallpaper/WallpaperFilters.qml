pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components

// What the web is asked for besides the words: the shape, how far back Top looks, and (Wallhaven) one colour.
Flow {
    id: root

    required property var engine
    readonly property real d: IrisStyle.density

    spacing: Math.round(10 * root.d)

    IrisSegmented {
        visible: root.engine.filtersShaped
        glyphOnly: true
        implicitHeight: Math.round(32 * root.d)
        accessibleName: Translation.tr("Shape")
        options: root.engine.ratioChoices
        current: root.engine.ratio
        onPicked: value => root.engine.setRatio(value)
    }
    IrisSegmented {
        visible: root.engine.ranged
        implicitHeight: Math.round(32 * root.d)
        implicitWidth: Math.max(Math.round(58 * root.d) * 4 + 2 * inset, fitWidth)
        accessibleName: Translation.tr("Top of the")
        options: root.engine.rangeChoices
        current: root.engine.topRange
        onPicked: value => root.engine.setRange(value)
    }
    Row {
        visible: root.engine.provider === "wallhaven" || root.engine.colour.length > 0
        height: Math.round(32 * root.d)
        spacing: Math.round(4 * root.d)
        Repeater {
            model: root.engine.palette
            MouseArea {
                id: swatch
                required property string modelData
                readonly property bool chosen: root.engine.colour === swatch.modelData
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(18 * root.d)
                height: Math.round(26 * root.d)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                Accessible.role: Accessible.Button
                Accessible.name: "#" + swatch.modelData
                onClicked: root.engine.setColour(swatch.modelData)
                Rectangle {
                    anchors.centerIn: parent
                    width: swatch.chosen ? parent.width : Math.round(14 * root.d)
                    height: swatch.chosen ? parent.height : swatch.containsMouse ? Math.round(22 * root.d) : Math.round(18 * root.d)
                    radius: IrisStyle.capsule(width)
                    color: "#" + swatch.modelData
                    border.width: 1
                    border.color: swatch.chosen ? IrisStyle.text : IrisStyle.hairlineStrong
                    Behavior on height { NumberAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
                    Behavior on width { NumberAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
                }
            }
        }
    }
    IrisChip {
        visible: root.engine.filtersOn > 0
        glyph: "filter_alt_off"
        label: Translation.tr("Clear")
        quiet: true
        onClicked: root.engine.clearFilters()
    }
}
