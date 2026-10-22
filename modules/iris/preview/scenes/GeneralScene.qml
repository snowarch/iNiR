pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.preview.parts

// General: the clock as you set it (24 or 12 hours, seconds ticking or not) over the three shell families, the one in
// use ringed; low power sets the body solid and marks it with a leaf.
PreviewScene {
    id: generalRoot
    readonly property real naturalWidth: Math.round(560 * generalRoot.d)
    readonly property real naturalHeight: Math.round(300 * generalRoot.d)
    narrowest: Math.round(380 * generalRoot.d)
    lowest: Math.round(240 * generalRoot.d)
    subject: Qt.rect(clockPlate.x, clockPlate.y, clockPlate.width, clockPlate.height)
    readonly property string format: String(generalRoot.opt("time.format", "hh:mm"))
    readonly property bool seconds: generalRoot.opt("time.secondPrecision", false) === true
    readonly property bool lowPower: generalRoot.opt("performance.lowPower", false) === true
    readonly property string family: String(generalRoot.opt("panelFamily", "iris"))
    readonly property bool twelve: generalRoot.format.toLowerCase().includes("ap")
    property date now: new Date()
    Timer {
        interval: generalRoot.seconds ? 1000 : 10000
        running: generalRoot.visible && generalRoot.preview.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: generalRoot.now = new Date()
    }
    readonly property string time: Qt.formatTime(generalRoot.now, (generalRoot.twelve ? "h:mm" : "hh:mm") + (generalRoot.seconds ? ":ss" : ""))
    readonly property string half: generalRoot.twelve ? Qt.formatTime(generalRoot.now, generalRoot.format.includes("AP") ? "AP" : "ap") : ""

    Plate {
        id: clockPlate
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(26 * generalRoot.d)
        width: Math.round(320 * generalRoot.d)
        height: Math.round(132 * generalRoot.d)
        radius: IrisStyle.radiusSheet
        color: generalRoot.lowPower ? IrisStyle.surfaceOpaque : IrisStyle.bodySurface
        Behavior on color { ColorAnimation { duration: IrisStyle.duration(220); easing.type: IrisStyle.feedbackEasing } }
        Column {
            anchors.centerIn: parent
            spacing: Math.round(2 * generalRoot.d)
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Math.round(6 * generalRoot.d)
                IrisText {
                    id: timeText
                    text: generalRoot.time
                    font.family: IrisStyle.fontDot
                    font.weight: Font.Normal
                    font.pixelSize: Math.round(IrisStyle.typeDisplay * 1.3)
                    font.features: { "tnum": 1 }
                }
                IrisText {
                    visible: generalRoot.half.length > 0
                    anchors.baseline: timeText.baseline
                    text: generalRoot.half
                    color: IrisStyle.textSecondary
                    font.pixelSize: IrisStyle.typeTitle
                    font.weight: Font.DemiBold
                }
            }
            IrisText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDate(generalRoot.now, "dddd d MMMM")
                color: IrisStyle.textSecondary
                font.pixelSize: IrisStyle.typeLabel
            }
        }
        MaterialSymbol {
            opacity: generalRoot.lowPower ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(200); easing.type: IrisStyle.feedbackEasing } }
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Math.round(14 * generalRoot.d)
            text: "eco"
            fill: 1
            iconSize: Math.round(18 * generalRoot.d)
            color: IrisStyle.identity.green
        }
    }

    // The three families as small screens; the ring travels to the one in use.
    Item {
        id: families
        readonly property real cell: Math.round(96 * generalRoot.d)
        readonly property real gap: Math.round(14 * generalRoot.d)
        readonly property var ids: ["iris", "ii", "waffle"]
        readonly property int at: Math.max(0, families.ids.indexOf(generalRoot.family))
        anchors.horizontalCenter: parent.horizontalCenter
        y: clockPlate.y + clockPlate.height + Math.round(22 * generalRoot.d)
        width: 3 * families.cell + 2 * families.gap
        height: Math.round(62 * generalRoot.d)
        Rectangle {
            x: families.at * (families.cell + families.gap) - Math.round(4 * generalRoot.d)
            y: -Math.round(4 * generalRoot.d)
            width: families.cell + Math.round(8 * generalRoot.d)
            height: families.height + Math.round(8 * generalRoot.d)
            radius: IrisStyle.radiusTile + Math.round(4 * generalRoot.d)
            color: "transparent"
            border.width: Math.max(2, Math.round(2 * generalRoot.d))
            border.color: IrisStyle.accent
            Behavior on x { NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
        }
        Repeater {
            model: families.ids
            Rectangle {
                id: screen
                required property string modelData
                required property int index
                readonly property bool on: screen.index === families.at
                x: screen.index * (families.cell + families.gap)
                width: families.cell
                height: families.height
                radius: IrisStyle.radiusTile
                color: IrisStyle.veilHeavy
                border.width: 1
                border.color: IrisStyle.border
                opacity: screen.on ? 1 : 0.55
                Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(200); easing.type: IrisStyle.feedbackEasing } }
                // iRiS: the Island at the top and a Dock; Material: a bar across; Windows 11: a taskbar with centred icons.
                Rectangle {
                    visible: screen.modelData === "iris"
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.round(6 * generalRoot.d)
                    width: parent.width * 0.36
                    height: Math.round(8 * generalRoot.d)
                    radius: height / 2
                    color: IrisStyle.onMedia
                }
                Rectangle {
                    visible: screen.modelData === "iris"
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Math.round(6 * generalRoot.d)
                    width: parent.width * 0.5
                    height: Math.round(9 * generalRoot.d)
                    radius: Math.round(4 * generalRoot.d)
                    color: IrisStyle.onMediaSecondary
                }
                Rectangle {
                    visible: screen.modelData === "ii"
                    x: Math.round(5 * generalRoot.d)
                    y: Math.round(5 * generalRoot.d)
                    width: parent.width - 2 * x
                    height: Math.round(8 * generalRoot.d)
                    radius: height / 2
                    color: IrisStyle.onMedia
                    opacity: 0.85
                }
                Rectangle {
                    visible: screen.modelData === "waffle"
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: Math.round(11 * generalRoot.d)
                    radius: 0
                    color: IrisStyle.onMediaSecondary
                    Row {
                        anchors.centerIn: parent
                        spacing: Math.round(4 * generalRoot.d)
                        Repeater { model: 4; Rectangle { width: Math.round(5 * generalRoot.d); height: width; radius: 1; color: IrisStyle.text } }
                    }
                }
                IrisText {
                    anchors.centerIn: parent
                    text: screen.modelData === "iris" ? "iRiS" : screen.modelData === "ii" ? Translation.tr("Material") : Translation.tr("Windows 11")
                    color: screen.on ? IrisStyle.onMedia : IrisStyle.onMediaSecondary
                    font.pixelSize: IrisStyle.typeMeta
                    font.weight: screen.on ? Font.DemiBold : Font.Medium
                }
            }
        }
    }
    Caption {
        glyph: generalRoot.lowPower ? "eco" : "schedule"
        text: [generalRoot.twelve ? Translation.tr("12-hour clock") : Translation.tr("24-hour clock"),
            generalRoot.seconds ? Translation.tr("exact seconds") : "", generalRoot.lowPower ? Translation.tr("low power") : ""].filter(part => part.length > 0).join(" · ")
    }
}
