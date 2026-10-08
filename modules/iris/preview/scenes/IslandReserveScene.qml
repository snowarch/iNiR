pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.iris.style
import qs.modules.iris.frame
import qs.modules.iris.preview.parts

PreviewScene {
    id: reserveRoot
    readonly property real naturalWidth: Math.round(640 * reserveRoot.d)
    readonly property real naturalHeight: Math.round(280 * reserveRoot.d)
    readonly property bool reserve: reserveRoot.opt("iris.bar.reserveSpace", true)
    readonly property string edge: IrisFrame.islandEdge
    readonly property bool bottomEdge: reserveRoot.edge === "bottom"
    readonly property bool vertical: reserveRoot.edge === "left" || reserveRoot.edge === "right"
    readonly property real islandSpan: IrisFrame.band + IrisFrame.islandMargin + IrisFrame.islandBand
    function inset(side: string): real {
        if (side === reserveRoot.edge) return reserveRoot.reserve ? reserveRoot.islandSpan + Math.round(8 * reserveRoot.d) : IrisFrame.band
        return Math.round((side === "top" || side === "bottom" ? 24 : 40) * reserveRoot.d)
    }
    Rectangle {
        x: reserveRoot.inset("left")
        // From the targets, not the animating x/y, or the size overshoots while they move.
        width: parent.width - reserveRoot.inset("left") - reserveRoot.inset("right")
        y: reserveRoot.inset("top")
        height: parent.height - reserveRoot.inset("top") - reserveRoot.inset("bottom")
        Behavior on x { NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve } }
        Behavior on width { NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve } }
        radius: IrisStyle.radiusTile
        color: IrisStyle.surfaceHigh
        border.width: 1
        border.color: IrisStyle.border
        Behavior on y { NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve } }
        Behavior on height { NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve } }
        Row {
            x: Math.round(12 * reserveRoot.d); y: Math.round(11 * reserveRoot.d)
            spacing: Math.round(6 * reserveRoot.d)
            Repeater { model: 3; Rectangle { required property int index; width: Math.round(10 * reserveRoot.d); height: width; radius: width / 2; color: IrisStyle.fillStrong } }
        }
        Rectangle { x: Math.round(12 * reserveRoot.d); y: Math.round(38 * reserveRoot.d); width: parent.width * 0.42; height: Math.round(9 * reserveRoot.d); radius: height / 2; color: IrisStyle.fill }
        Rectangle { x: Math.round(12 * reserveRoot.d); y: Math.round(56 * reserveRoot.d); width: parent.width * 0.6; height: Math.round(9 * reserveRoot.d); radius: height / 2; color: IrisStyle.fillQuiet }
    }
    IslandPill {
        readonly property real inset: IrisFrame.band + IrisFrame.islandMargin
        vertical: reserveRoot.vertical
        x: reserveRoot.edge === "left" ? inset : reserveRoot.edge === "right" ? parent.width - inset - width : Math.round((parent.width - width) / 2)
        y: reserveRoot.edge === "top" ? inset : reserveRoot.bottomEdge ? parent.height - inset - height : Math.round((parent.height - height) / 2)
    }
    Caption {
        anchors.bottom: reserveRoot.bottomEdge ? undefined : parent.bottom
        anchors.top: reserveRoot.bottomEdge ? parent.top : undefined
        glyph: !reserveRoot.reserve ? "layers" : reserveRoot.edge === "left" ? "align_horizontal_left"
            : reserveRoot.edge === "right" ? "align_horizontal_right" : reserveRoot.bottomEdge ? "vertical_align_bottom" : "vertical_align_top"
        text: !reserveRoot.reserve ? Translation.tr("Windows run under the Island")
            : reserveRoot.vertical ? Translation.tr("Windows start beside the Island")
            : reserveRoot.bottomEdge ? Translation.tr("Windows end above the Island") : Translation.tr("Windows start below the Island")
    }
}
