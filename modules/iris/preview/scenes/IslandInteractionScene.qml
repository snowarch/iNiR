pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.frame
import qs.modules.iris.components
import qs.modules.iris.field as Field
import qs.modules.iris.preview.parts

PreviewScene {
    id: actRoot
    readonly property real naturalWidth: Math.round(620 * actRoot.d)
    readonly property real naturalHeight: Math.round(280 * actRoot.d)
    readonly property bool hover: actRoot.opt("iris.bar.hoverExpand", true)
    readonly property int delay: Math.max(120, Math.min(800, Number(actRoot.opt("iris.bar.hoverDelay", 300))))
    readonly property string scroll: String(actRoot.opt("iris.bar.scrollAction", "volume"))
    readonly property bool events: actRoot.opt("iris.bar.events", true)
    readonly property bool caps: actRoot.events && actRoot.opt("keyboardIndicators.popup.caps", true)
    property int step: 0
    property bool expanded: false
    property bool clicked: false
    property real level: 0.35
    readonly property real restW: Math.round(150 * actRoot.d)
    readonly property real restH: IrisFrame.islandBand
    readonly property real pillW: actRoot.expanded ? Math.round(360 * actRoot.d) : actRoot.step === 3 && actRoot.events ? Math.round(260 * actRoot.d) : actRoot.restW
    readonly property real pillH: actRoot.expanded ? Math.round(150 * actRoot.d) : actRoot.restH
    Timer {
        running: actRoot.playing
        interval: 1700
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            actRoot.step = (actRoot.step + 1) % 4
            actRoot.expanded = false
            actRoot.clicked = false
            if (actRoot.step === 1) expandTimer.restart()
            if (actRoot.step === 2) actRoot.level = 0.35
        }
    }
    Timer {
        id: expandTimer
        interval: actRoot.hover ? actRoot.delay : 420
        onTriggered: { actRoot.clicked = !actRoot.hover; actRoot.expanded = true }
    }
    Timer {
        running: actRoot.playing && actRoot.step === 2 && actRoot.scroll !== "none"
        interval: 120
        repeat: true
        onTriggered: actRoot.level = Math.min(0.85, actRoot.level + 0.05)
    }
    Item {
        id: pill
        anchors.horizontalCenter: parent.horizontalCenter
        y: IrisFrame.band + IrisFrame.islandMargin
        width: actRoot.pillW
        height: actRoot.pillH
        property real radius: actRoot.expanded ? IrisStyle.radius : height / 2
        // Drawn by the field, as the Island it shows.
        Field.IrisField {
            anchors.fill: parent
            framed: false
            shapes: [{ id: "island", x: 0, y: 0, width: pill.width, height: pill.height, radius: pill.radius }]
        }
        Behavior on width { NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
        Behavior on height { NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
        Behavior on radius { NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
        IrisClock {
            anchors.centerIn: parent
            visible: !actRoot.expanded && !(actRoot.step === 2 && actRoot.scroll !== "none") && !(actRoot.step === 3 && actRoot.events)
            pixelSize: IrisStyle.typeHeadline
            separatorColor: IrisStyle.secondaryAccent
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Math.round(14 * actRoot.d)
            anchors.rightMargin: Math.round(16 * actRoot.d)
            visible: actRoot.step === 2 && actRoot.scroll !== "none" && !actRoot.expanded
            spacing: Math.round(8 * actRoot.d)
            MaterialSymbol { text: actRoot.scroll === "brightness" ? "light_mode" : "volume_up"; fill: 1; iconSize: Math.round(16 * actRoot.d); color: IrisStyle.text }
            Level { value: actRoot.level; tint: IrisStyle.text }
        }
        RowLayout {
            anchors.centerIn: parent
            visible: actRoot.step === 3 && actRoot.events && !actRoot.expanded
            spacing: Math.round(8 * actRoot.d)
            MaterialSymbol { text: "battery_charging_full"; fill: 1; iconSize: Math.round(17 * actRoot.d); color: IrisStyle.identity.green }
            IrisText { text: Translation.tr("Charger connected"); font.weight: IrisStyle.weight(Font.DemiBold) }
        }
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Math.round(18 * actRoot.d)
            visible: actRoot.expanded
            opacity: actRoot.expanded ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(200); easing.type: IrisStyle.feedbackEasing } }
            IrisText { text: Translation.locale.toString(DateTime.clock.date, "dddd d MMMM"); color: IrisStyle.secondaryAccent; font.weight: IrisStyle.weight(Font.DemiBold) }
            IrisText { text: Translation.locale.toString(DateTime.clock.date, "hh:mm"); font.family: IrisStyle.fontNumbers; font.weight: IrisStyle.figureWeight; font.pixelSize: 40 * IrisStyle.typeScale }
            Item { Layout.fillHeight: true }
            Level { value: 0.6 }
        }
    }
    Rectangle {
        anchors.horizontalCenter: pill.horizontalCenter
        anchors.top: pill.bottom
        anchors.topMargin: Math.round(8 * actRoot.d)
        visible: actRoot.step === 3 && actRoot.caps
        width: capsLabel.implicitWidth + Math.round(24 * actRoot.d)
        height: Math.round(26 * actRoot.d)
        radius: height / 2
        color: IrisStyle.bodySurface
        IrisText { id: capsLabel; anchors.centerIn: parent; text: Translation.tr("Caps Lock on"); font.pixelSize: IrisStyle.typeMeta; font.weight: IrisStyle.weight(Font.DemiBold) }
    }
    MaterialSymbol {
        id: pointer
        text: actRoot.step === 2 ? "mouse" : "arrow_selector_tool"
        fill: 1
        iconSize: Math.round(22 * actRoot.d)
        color: "white"
        x: actRoot.step === 0 ? parent.width * 0.72 : pill.x + pill.width * 0.55
        y: actRoot.step === 0 ? parent.height * 0.7 : pill.y + Math.min(pill.height - 8, IrisFrame.islandBand * 0.6)
        visible: actRoot.step < 3
        Behavior on x { NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve } }
        Behavior on y { NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve } }
        Rectangle {
            anchors.centerIn: parent
            width: actRoot.clicked ? parent.width * 1.6 : 0
            height: width
            radius: width / 2
            color: "transparent"
            border.width: 2
            border.color: IrisStyle.accent
            opacity: actRoot.clicked ? 0 : 1
            Behavior on width { NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve } }
            Behavior on opacity { NumberAnimation { duration: IrisStyle.emergeDuration; easing.type: IrisStyle.feedbackEasing } }
        }
    }
    Caption {
        glyph: ["near_me", actRoot.hover ? "timer" : "ads_click", "swipe_vertical", "campaign"][actRoot.step]
        text: [Translation.tr("Resting"),
            actRoot.hover ? Translation.tr("Opens after resting %1 ms").arg(actRoot.delay) : Translation.tr("Opens on a click"),
            actRoot.scroll === "none" ? Translation.tr("Scroll does nothing") : actRoot.scroll === "brightness" ? Translation.tr("Scroll sets brightness") : Translation.tr("Scroll sets volume"),
            actRoot.events ? (actRoot.caps ? Translation.tr("System events and the Caps Lock badge") : Translation.tr("System events")) : Translation.tr("System events off")][actRoot.step]
    }
}
