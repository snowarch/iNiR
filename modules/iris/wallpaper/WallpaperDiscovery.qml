pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components

ColumnLayout {
    id: root

    required property var picker
    readonly property real d: IrisStyle.density

    spacing: Math.round(8 * root.d)

    component ChipStrip: Flickable {
        id: strip
        default property alias chips: chipRow.data
        Layout.fillWidth: true
        implicitHeight: Math.round(30 * root.d)
        contentWidth: chipRow.implicitWidth
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                const delta = event.pixelDelta.x || event.pixelDelta.y || (event.angleDelta.y || event.angleDelta.x) / 2
                strip.contentX = Math.max(0, Math.min(Math.max(0, strip.contentWidth - strip.width), strip.contentX - delta))
            }
        }
        Row {
            id: chipRow
            height: strip.height
            spacing: Math.round(6 * root.d)
        }
    }

    ChipStrip {
        Repeater {
            model: root.picker.discoveries
            IrisChip {
                id: tagChip
                required property var modelData
                required property int index
                label: tagChip.modelData.label
                selected: root.picker.discovery === tagChip.index && root.picker.series === null
                    && root.picker.query.length === 0
                quiet: !tagChip.selected
                onClicked: root.picker.pickDiscovery(tagChip.index)
            }
        }
    }

    ChipStrip {
        visible: root.picker.airing.length > 0
        IrisText {
            anchors.verticalCenter: parent?.verticalCenter
            rightPadding: Math.round(4 * root.d)
            text: Translation.tr("Airing now")
            color: IrisStyle.label
            font.pixelSize: IrisStyle.typeMeta
            font.weight: IrisStyle.weight(Font.DemiBold)
        }
        Repeater {
            model: root.picker.airing
            IrisChip {
                id: seriesChip
                required property var modelData
                artwork: String(seriesChip.modelData.imageSmall ?? "")
                label: root.picker.seriesLabel(seriesChip.modelData)
                labelCap: Math.round(180 * root.d)
                selected: root.picker.series?.id === seriesChip.modelData.id
                quiet: !seriesChip.selected
                Accessible.name: String(seriesChip.modelData.title ?? "")
                onClicked: root.picker.pickSeries(seriesChip.modelData)
            }
        }
    }
}
