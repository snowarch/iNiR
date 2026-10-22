pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.settings

// Option rows, grouped as Settings groups them: a caption over a raised plate of rows.
ColumnLayout {
    id: root

    property var specs: []
    // A group's title wears the colour of the area it belongs to; neutral where there is none.
    property color tint: IrisStyle.label
    readonly property real d: IrisStyle.density
    readonly property var groups: {
        Config.revision
        const out = []
        for (const spec of root.specs) {
            if (!IrisOptions.shown(spec)) continue
            const title = String(spec.group ?? "")
            if (out.length === 0 || out[out.length - 1].title !== title) {
                const occurrence = out.filter(group => group.title === title).length
                out.push({ title: title, modelKey: title + ":" + occurrence, rows: [] })
            }
            out[out.length - 1].rows.push(Object.assign({ modelKey: String(spec.path ?? spec.label) }, spec))
        }
        return out
    }

    spacing: Math.round(12 * root.d)

    Repeater {
        model: ScriptModel { objectProp: "modelKey"; values: root.groups }
        ColumnLayout {
            id: group
            required property var modelData
            Layout.fillWidth: true
            spacing: Math.round(6 * root.d)
            IrisText {
                visible: group.modelData.title.length > 0
                Layout.leftMargin: Math.round(12 * root.d)
                text: Translation.tr(group.modelData.title)
                color: root.tint
                font.family: IrisStyle.fontTitle
                font.pixelSize: IrisStyle.typeMeta
                font.weight: IrisStyle.weight(Font.DemiBold)
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: plate.implicitHeight
                radius: IrisStyle.radiusTile
                color: IrisStyle.surfaceHigh
                ColumnLayout {
                    id: plate
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 0
                    Repeater {
                        model: ScriptModel { objectProp: "modelKey"; values: group.modelData.rows }
                        IrisSetting {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            spec: modelData
                            last: index === group.modelData.rows.length - 1
                        }
                    }
                }
            }
        }
    }
}
