pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.preview.parts

PreviewScene {
    id: settingsRoot
    readonly property real naturalWidth: Math.round(620 * settingsRoot.d)
    readonly property real naturalHeight: Math.round(300 * settingsRoot.d)
    Plate {
        id: settingsPlate
        surface: "settings"
        fallbackRadius: IrisStyle.radiusPanel
        anchors.centerIn: parent
        width: Math.round(540 * settingsRoot.d)
        height: Math.round(250 * settingsRoot.d)
        clip: true
        Rectangle {
            id: settingsSide
            x: 1; y: 1
            width: Math.round(150 * settingsRoot.d); height: parent.height - 2
            radius: parent.radius
            color: IrisStyle.surfaceHigh
            Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: IrisStyle.hairline }
            Column {
                x: Math.round(10 * settingsRoot.d); y: Math.round(18 * settingsRoot.d)
                width: parent.width - 2 * x
                spacing: Math.round(4 * settingsRoot.d)
                Rectangle { width: parent.width; height: Math.round(18 * settingsRoot.d); radius: height / 2; color: IrisStyle.fillQuiet }
                Item { width: 1; height: Math.round(4 * settingsRoot.d) }
                Repeater {
                    model: [IrisStyle.identity.gray, IrisStyle.identity.purple, IrisStyle.identity.indigo, IrisStyle.identity.blue, IrisStyle.identity.sky, IrisStyle.identity.pink]
                    Rectangle {
                        required property color modelData
                        required property int index
                        width: parent.width; height: Math.round(20 * settingsRoot.d)
                        radius: IrisStyle.radiusRow
                        color: index === 4 ? IrisStyle.fillActive : "transparent"
                        Row {
                            x: Math.round(4 * settingsRoot.d); anchors.verticalCenter: parent.verticalCenter
                            spacing: Math.round(6 * settingsRoot.d)
                            Rectangle { width: Math.round(13 * settingsRoot.d); height: width; radius: IrisStyle.iconRadius(width); color: parent.parent.modelData }
                            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: Math.round(56 * settingsRoot.d); height: Math.round(6 * settingsRoot.d); radius: height / 2; color: IrisStyle.fillStrong }
                        }
                    }
                }
            }
        }
        Column {
            x: settingsSide.width + Math.round(22 * settingsRoot.d); y: Math.round(20 * settingsRoot.d)
            width: parent.width - x - Math.round(22 * settingsRoot.d)
            spacing: Math.round(12 * settingsRoot.d)
            Rectangle { width: Math.round(120 * settingsRoot.d); height: Math.round(10 * settingsRoot.d); radius: height / 2; color: IrisStyle.text }
            Rectangle {
                width: parent.width
                height: groupRows.implicitHeight
                radius: IrisStyle.radiusTile
                color: IrisStyle.fillQuiet
                Column {
                    id: groupRows
                    width: parent.width
                    Repeater {
                        model: [IrisStyle.identity.yellow, IrisStyle.identity.red, IrisStyle.identity.green, IrisStyle.identity.blue, IrisStyle.identity.teal]
                        Item {
                            required property color modelData
                            required property int index
                            width: parent.width; height: Math.round(32 * settingsRoot.d)
                            Rectangle { id: rowMark; x: Math.round(10 * settingsRoot.d); anchors.verticalCenter: parent.verticalCenter; width: Math.round(16 * settingsRoot.d); height: width; radius: IrisStyle.iconRadius(width); color: parent.modelData }
                            Rectangle { x: rowMark.x + rowMark.width + Math.round(10 * settingsRoot.d); anchors.verticalCenter: parent.verticalCenter; width: Math.round((80 + 24 * (parent.index % 3)) * settingsRoot.d); height: Math.round(7 * settingsRoot.d); radius: height / 2; color: IrisStyle.fillStrong }
                            Rectangle { anchors.right: parent.right; anchors.rightMargin: Math.round(26 * settingsRoot.d); anchors.verticalCenter: parent.verticalCenter; width: Math.round(46 * settingsRoot.d); height: Math.round(6 * settingsRoot.d); radius: height / 2; color: IrisStyle.fill }
                            MaterialSymbol { anchors.right: parent.right; anchors.rightMargin: Math.round(8 * settingsRoot.d); anchors.verticalCenter: parent.verticalCenter; text: "chevron_right"; iconSize: Math.round(14 * settingsRoot.d); color: IrisStyle.muted }
                            Rectangle { visible: parent.index > 0; x: rowMark.x + rowMark.width + Math.round(10 * settingsRoot.d); width: parent.width - x; height: 1; color: IrisStyle.hairline }
                        }
                    }
                }
            }
        }
    }
}
