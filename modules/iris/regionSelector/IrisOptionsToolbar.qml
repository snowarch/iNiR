pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.modules.common
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.regionSelector

IrisSurface {
    id: root

    property var action
    property var selectionMode
    signal dismiss()
    signal fullscreenRequested()
    signal colorPickerRequested()

    readonly property real d: IrisStyle.density
    readonly property var actionList: [
        { action: RegionSelection.SnipAction.Copy, icon: "content_cut", name: Translation.tr("Shot") },
        { action: RegionSelection.SnipAction.Edit, icon: "draw", name: Translation.tr("Edit") },
        { action: RegionSelection.SnipAction.CharRecognition, icon: "document_scanner", name: Translation.tr("OCR") },
        { action: RegionSelection.SnipAction.Search, icon: "image_search", name: Translation.tr("Search") },
        { action: RegionSelection.SnipAction.Record, icon: "videocam", name: Translation.tr("Record") }
    ]
    readonly property int actionIndex: {
        for (let i = 0; i < root.actionList.length; i++)
            if (root.actionList[i].action === root.action) return i
        return root.action === RegionSelection.SnipAction.RecordWithSound ? 4 : 0
    }

    function persistSnipChoice(): void {
        if (!(Config.options?.regionSelector?.rememberSnipChoice ?? true)) return
        const isRecord = root.action === RegionSelection.SnipAction.Record
            || root.action === RegionSelection.SnipAction.RecordWithSound
        const updates = { "regionSelector.lastMode": root.selectionMode }
        if (!isRecord) updates["regionSelector.lastAction"] = root.action
        Config.setNestedValues(updates)
    }

    raised: true
    radius: height / 2
    implicitWidth: strip.implicitWidth + Math.round(16 * root.d)
    implicitHeight: Math.round(52 * root.d)

    component Divider: Rectangle {
        Layout.preferredWidth: Math.max(1, Math.round(IrisStyle.density))
        Layout.preferredHeight: Math.round(22 * IrisStyle.density)
        Layout.alignment: Qt.AlignVCenter
        color: IrisStyle.hairline
    }

    RowLayout {
        id: strip
        anchors.fill: parent
        anchors.leftMargin: Math.round(8 * root.d)
        anchors.rightMargin: Math.round(8 * root.d)
        spacing: Math.round(8 * root.d)

        Rectangle {
            id: actions
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: actionRow.implicitWidth + 4
            implicitHeight: Math.round(38 * root.d)
            radius: height / 2
            color: IrisStyle.fillQuiet

            Rectangle {
                readonly property Item current: actionRepeater.count > 0
                    ? actionRepeater.itemAt(root.actionIndex) : null
                x: 2 + (current?.x ?? 0)
                y: 2
                width: current?.width ?? 0
                height: actions.height - 4
                radius: height / 2
                color: IrisStyle.fillActive
                Behavior on x { NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve } }
                Behavior on width { NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve } }
            }

            Row {
                id: actionRow
                x: 2
                y: 2
                Repeater {
                    id: actionRepeater
                    model: root.actionList
                    MouseArea {
                        id: actionButton
                        required property var modelData
                        required property int index
                        readonly property bool current: root.actionIndex === actionButton.index
                        width: actionContent.implicitWidth + Math.round(22 * root.d)
                        height: actions.height - 4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        Accessible.role: Accessible.PageTab
                        Accessible.name: actionButton.modelData.name
                        Accessible.checked: actionButton.current
                        onClicked: {
                            if (root.action !== actionButton.modelData.action) root.action = actionButton.modelData.action
                            root.persistSnipChoice()
                        }
                        Row {
                            id: actionContent
                            anchors.centerIn: parent
                            spacing: Math.round(6 * root.d)
                            MaterialSymbol {
                                anchors.verticalCenter: parent.verticalCenter
                                text: actionButton.modelData.icon
                                iconSize: Math.round(17 * root.d)
                                fill: actionButton.current ? 1 : 0
                                animateFill: true
                                color: actionButton.current ? IrisStyle.text
                                    : actionButton.containsMouse ? IrisStyle.textSecondary : IrisStyle.subtext
                            }
                            IrisText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: actionButton.modelData.name
                                font.pixelSize: IrisStyle.typeLabel
                                font.weight: actionButton.current ? Font.DemiBold : Font.Normal
                                color: actionButton.current ? IrisStyle.text
                                    : actionButton.containsMouse ? IrisStyle.textSecondary : IrisStyle.subtext
                            }
                        }
                    }
                }
            }
        }

        Divider {}

        Rectangle {
            id: shapes
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: shapeRow.implicitWidth + 4
            implicitHeight: Math.round(38 * root.d)
            radius: height / 2
            color: IrisStyle.fillQuiet
            readonly property int current: root.selectionMode === RegionSelection.SelectionMode.Circle ? 1 : 0

            Rectangle {
                x: 2 + shapes.current * (shapes.width - 4) / 2
                y: 2
                width: (shapes.width - 4) / 2
                height: shapes.height - 4
                radius: height / 2
                color: IrisStyle.fillActive
                Behavior on x { NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve } }
            }

            Row {
                id: shapeRow
                x: 2
                y: 2
                Repeater {
                    model: [
                        { icon: "activity_zone", name: Translation.tr("Rect") },
                        { icon: "gesture", name: Translation.tr("Circle") }
                    ]
                    MouseArea {
                        id: shapeButton
                        required property var modelData
                        required property int index
                        readonly property bool current: shapes.current === shapeButton.index
                        width: Math.round(42 * root.d)
                        height: shapes.height - 4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        Accessible.role: Accessible.PageTab
                        Accessible.name: shapeButton.modelData.name
                        Accessible.checked: shapeButton.current
                        onClicked: {
                            root.selectionMode = shapeButton.index === 0
                                ? RegionSelection.SelectionMode.RectCorners : RegionSelection.SelectionMode.Circle
                            root.persistSnipChoice()
                        }
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: shapeButton.modelData.icon
                            iconSize: Math.round(17 * root.d)
                            fill: shapeButton.current ? 1 : 0
                            animateFill: true
                            color: shapeButton.current ? IrisStyle.text
                                : shapeButton.containsMouse ? IrisStyle.textSecondary : IrisStyle.subtext
                        }
                    }
                }
            }
        }

        Divider {}

        IrisIconButton {
            Layout.alignment: Qt.AlignVCenter
            materialIcon: "fullscreen"
            Accessible.name: Translation.tr("Capture fullscreen")
            onClicked: root.fullscreenRequested()
        }
        IrisIconButton {
            Layout.alignment: Qt.AlignVCenter
            materialIcon: "colorize"
            Accessible.name: Translation.tr("Color picker")
            onClicked: root.colorPickerRequested()
        }
        IrisIconButton {
            Layout.alignment: Qt.AlignVCenter
            materialIcon: "close"
            Accessible.name: Translation.tr("Close")
            danger: true
            onClicked: root.dismiss()
        }
    }
}
