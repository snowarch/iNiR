pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.frame
import qs.modules.iris.components
import qs.modules.iris.pieces
import qs.modules.iris.field as Field
import qs.modules.iris.preview.parts

PreviewScene {
    id: dockRoot
    readonly property string edge: IrisFrame.dockEdge
    readonly property bool vertical: dockRoot.edge === "left" || dockRoot.edge === "right"
    readonly property real naturalWidth: Math.round((dockRoot.vertical ? 620 : 760) * dockRoot.d)
    readonly property real naturalHeight: dockRoot.vertical ? Math.max(Math.round(300 * dockRoot.d), Math.round(dockRoot.length + 64 * dockRoot.d)) : Math.round(300 * dockRoot.d)
    readonly property bool enabledDock: dockRoot.opt("iris.dock.enable", true)
    readonly property bool autoHide: dockRoot.opt("iris.dock.autoHide", true)
    readonly property bool reserve: !dockRoot.autoHide && dockRoot.opt("iris.dock.reserveSpace", true)
    readonly property bool revealOnEmpty: dockRoot.opt("iris.dock.revealOnEmpty", true)
    readonly property bool notch: dockRoot.opt("iris.dock.notch", true)
    readonly property string material: String(dockRoot.opt("iris.dock.material", "inherit"))
    readonly property bool blur: dockRoot.material === "glass" || dockRoot.material === "blur"
        || (dockRoot.material === "inherit" && (dockRoot.opt("iris.dock.blur", false) || IrisStyle.glassy))
    readonly property bool badges: dockRoot.opt("iris.dock.badges", true)
    readonly property bool launcher: dockRoot.opt("iris.dock.launcher", true)
    readonly property bool magnify: dockRoot.opt("iris.dock.magnification", false)
    readonly property real icon: Math.max(28, Math.min(64, Number(dockRoot.opt("iris.dock.iconSize", 40)))) * dockRoot.d
    readonly property var apps: (TaskbarApps.apps ?? []).filter(app => app && !app.separator && String(app.appId ?? "").length > 0 && app.appId !== "SEPARATOR").slice(0, 6)
    readonly property int count: dockRoot.apps.length + (dockRoot.launcher ? 1 : 0)
    readonly property real length: dockRoot.count * (dockRoot.icon + 10 * dockRoot.d) + 16 * dockRoot.d
    readonly property real thick: dockRoot.icon + 18 * dockRoot.d
    readonly property real span: dockRoot.vertical ? height : width
    readonly property real depth: dockRoot.vertical ? width : height
    readonly property real restInset: IrisFrame.band + (dockRoot.notch ? 0 : Math.round(10 * dockRoot.d))
    property bool hidden: false
    property int hover: -1
    property real slide: dockRoot.hidden ? -dockRoot.thick - 4 : dockRoot.restInset
    Behavior on slide { NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve } }
    readonly property real alongStart: Math.round((dockRoot.span - dockRoot.length) / 2)
    readonly property real acrossAt: dockRoot.edge === "bottom" ? height - dockRoot.slide - dockRoot.thick
        : dockRoot.edge === "right" ? width - dockRoot.slide - dockRoot.thick : dockRoot.slide
    readonly property real plateX: dockRoot.vertical ? dockRoot.acrossAt : dockRoot.alongStart
    readonly property real plateY: dockRoot.vertical ? dockRoot.alongStart : dockRoot.acrossAt
    readonly property real plateW: dockRoot.vertical ? dockRoot.thick : dockRoot.length
    readonly property real plateH: dockRoot.vertical ? dockRoot.length : dockRoot.thick
    readonly property real reach: dockRoot.reserve ? dockRoot.restInset + dockRoot.thick + Math.round(10 * dockRoot.d) : IrisFrame.band

    property int step: 0
    readonly property int steps: dockRoot.count + 3
    readonly property bool gliding: dockRoot.step >= 2 && dockRoot.step < dockRoot.steps - 1
    function iconAlong(index: int): real {
        return dockRoot.alongStart + 8 * dockRoot.d + index * (dockRoot.icon + 10 * dockRoot.d) + dockRoot.icon / 2
    }
    function spot(along: real, inset: real): point {
        const across = dockRoot.edge === "bottom" ? height - inset : dockRoot.edge === "right" ? width - inset : inset
        return dockRoot.vertical ? Qt.point(across, along) : Qt.point(along, across)
    }
    function inset(side: string): real {
        if (side === dockRoot.edge) return dockRoot.reach
        return Math.round((side === "top" || side === "bottom" ? 28 : 40) * dockRoot.d)
    }
    Timer {
        running: dockRoot.playing && dockRoot.enabledDock
        interval: 620
        repeat: true
        triggeredOnStart: true
        onTriggered: dockRoot.step = (dockRoot.step + 1) % dockRoot.steps
        onRunningChanged: if (!running) dockRoot.step = 1
    }
    Binding { dockRoot.hidden: dockRoot.autoHide && dockRoot.enabledDock && (dockRoot.step === 0 || dockRoot.step === dockRoot.steps - 1) }
    Binding { dockRoot.hover: dockRoot.magnify && dockRoot.gliding ? dockRoot.step - 2 : -1 }
    Pointer {
        readonly property point aim: dockRoot.step === 0 ? Qt.point(dockRoot.width * 0.62, dockRoot.height * 0.36)
            : dockRoot.step === dockRoot.steps - 1 ? Qt.point(dockRoot.width * 0.34, dockRoot.height * 0.3)
            : dockRoot.step === 1 ? dockRoot.spot(dockRoot.span / 2, IrisFrame.band)
            : dockRoot.spot(dockRoot.iconAlong(dockRoot.step - 2), dockRoot.restInset + dockRoot.thick * 0.65)
        visible: dockRoot.enabledDock && dockRoot.playing
        x: aim.x - width / 3
        y: aim.y - height / 3
    }

    Rectangle {
        x: dockRoot.inset("left")
        y: dockRoot.inset("top")
        // From the targets, not the animating x/y, or the size overshoots while they move.
        width: parent.width - dockRoot.inset("left") - dockRoot.inset("right")
        height: parent.height - dockRoot.inset("top") - dockRoot.inset("bottom")
        radius: IrisStyle.radiusTile
        color: IrisStyle.surfaceHigh
        border.width: 1
        border.color: IrisStyle.border
        Behavior on x { NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve } }
        Behavior on y { NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve } }
        Behavior on width { NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve } }
        Behavior on height { NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve } }
        Row {
            x: Math.round(12 * dockRoot.d); y: Math.round(11 * dockRoot.d)
            spacing: Math.round(6 * dockRoot.d)
            Repeater { model: 3; Rectangle { required property int index; width: Math.round(10 * dockRoot.d); height: width; radius: width / 2; color: IrisStyle.fillStrong } }
        }
        Rectangle { x: Math.round(12 * dockRoot.d); y: Math.round(38 * dockRoot.d); width: parent.width * 0.4; height: Math.round(9 * dockRoot.d); radius: height / 2; color: IrisStyle.fill }
        Rectangle { x: Math.round(12 * dockRoot.d); y: Math.round(56 * dockRoot.d); width: parent.width * 0.62; height: Math.round(9 * dockRoot.d); radius: height / 2; color: IrisStyle.fillQuiet }
        Rectangle {
            visible: dockRoot.reserve
            x: dockRoot.edge === "right" ? parent.width - 1 : 0
            y: dockRoot.edge === "bottom" ? parent.height - 1 : 0
            width: dockRoot.vertical ? 1 : parent.width
            height: dockRoot.vertical ? parent.height : 1
            color: IrisStyle.accent
        }
    }

    ClippingRectangle {
        visible: dockRoot.blur && dockRoot.enabledDock
        x: dockRoot.plateX; y: dockRoot.plateY
        width: dockRoot.plateW; height: dockRoot.plateH
        radius: dockRoot.notch ? Math.round(16 * dockRoot.d) : dockRoot.thick / 2
        color: "transparent"
        ShaderEffectSource {
            id: dockBlurSource
            x: -dockRoot.plateX; y: -dockRoot.plateY
            width: dockRoot.width; height: dockRoot.height
            visible: false
            sourceItem: dockRoot.wallpaperView.textureItem
            live: true
        }
        MultiEffect { anchors.fill: dockBlurSource; source: dockBlurSource; blurEnabled: true; blur: 1; blurMax: 48 }
    }

    Field.IrisField {
        anchors.fill: parent
        visible: dockRoot.enabledDock
        framed: false
        tint: dockRoot.blur ? IrisStyle.veilStrong : IrisStyle.bodySurface
        shapes: {
            const out = []
            const deep = Math.max(8, IrisStyle.fuseDeep * 2)
            const f = IrisStyle.fuseDeep
            const W = dockRoot.width, H = dockRoot.height, band = IrisFrame.band
            out.push(dockRoot.edge === "top" ? { x: -2 * f, y: -deep, width: W + 4 * f, height: band + deep }
                : dockRoot.edge === "left" ? { x: -deep, y: -2 * f, width: band + deep, height: H + 4 * f }
                : dockRoot.edge === "right" ? { x: W - band, y: -2 * f, width: band + deep, height: H + 4 * f }
                : { x: -2 * f, y: H - band, width: W + 4 * f, height: band + deep })
            Object.assign(out[0], { radius: 0, fuse: f, id: "edge", paints: true })
            out.push({ x: dockRoot.plateX, y: dockRoot.plateY, width: dockRoot.plateW, height: dockRoot.plateH,
                radius: IrisStyle.dockShape !== "auto" ? IrisStyle.profileRadius(IrisStyle.bodyProfile(IrisStyle.dockShape, dockRoot.notch), dockRoot.thick)
                    : dockRoot.notch ? Math.round(16 * dockRoot.d) : dockRoot.thick / 2,
                fuse: dockRoot.notch ? IrisStyle.fuseEdge : IrisStyle.fuse, id: "dock", joins: dockRoot.notch ? "edge" : "", paints: true })
            return out
        }
    }

    Grid {
        visible: dockRoot.enabledDock
        columns: dockRoot.vertical ? 1 : Math.max(1, dockRoot.count)
        x: dockRoot.vertical ? dockRoot.plateX + (dockRoot.thick - dockRoot.icon) / 2 : dockRoot.plateX + 8 * dockRoot.d
        y: dockRoot.vertical ? dockRoot.plateY + 8 * dockRoot.d : dockRoot.plateY + (dockRoot.thick - dockRoot.icon) / 2
        spacing: Math.round(10 * dockRoot.d)
        Repeater {
            model: (dockRoot.launcher ? [{ launcher: true }] : []).concat(dockRoot.apps)
            Item {
                id: dockIcon
                required property var modelData
                required property int index
                readonly property int distance: dockRoot.hover < 0 ? 9 : Math.abs(dockRoot.hover - dockIcon.index)
                width: dockRoot.icon
                height: width
                scale: dockIcon.distance === 0 ? 1.45 : dockIcon.distance === 1 ? 1.18 : 1
                transformOrigin: ({ top: Item.Top, left: Item.Left, right: Item.Right })[dockRoot.edge] ?? Item.Bottom
                z: 3 - Math.min(3, dockIcon.distance)
                Behavior on scale { NumberAnimation { duration: IrisStyle.duration(160); easing.type: IrisStyle.feedbackEasing } }
                Rectangle {
                    anchors.fill: parent
                    visible: dockIcon.modelData.launcher === true
                    radius: IrisStyle.iconRadius(width)
                    color: IrisStyle.fill
                    MaterialSymbol { anchors.centerIn: parent; text: "apps"; iconSize: Math.round(dockRoot.icon * 0.5); color: IrisStyle.text }
                }
                SmartAppIcon {
                    anchors.fill: parent
                    visible: dockIcon.modelData.launcher !== true
                    implicitSize: parent.width
                    icon: IrisPieces.appIcon(dockIcon.modelData.appId ?? "")
                    fallback: "application-x-executable"
                }
                Rectangle {
                    visible: dockRoot.badges && dockIcon.modelData.launcher !== true && dockIcon.index % 3 === 1
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: -Math.round(3 * dockRoot.d)
                    width: Math.round(17 * dockRoot.d); height: width; radius: width / 2
                    color: IrisStyle.badge
                    IrisText { anchors.centerIn: parent; text: dockIcon.index; color: IrisStyle.inkOnBadge; font.pixelSize: IrisStyle.typeCaption; font.weight: IrisStyle.weight(Font.Bold) }
                }
            }
        }
    }

    OffState { visible: !dockRoot.enabledDock; text: Translation.tr("Dock off") }
    Caption {
        anchors.leftMargin: dockRoot.edge === "left" ? dockRoot.restInset + dockRoot.thick + Math.round(14 * dockRoot.d) : Math.round(14 * dockRoot.d)
        glyph: dockRoot.autoHide ? "unfold_less" : !dockRoot.reserve ? "layers"
            : ({ top: "vertical_align_top", left: "align_horizontal_left", right: "align_horizontal_right" })[dockRoot.edge] ?? "vertical_align_bottom"
        text: !dockRoot.enabledDock ? ""
            : dockRoot.autoHide ? (dockRoot.revealOnEmpty ? Translation.tr("Hides over windows · stays on empty workspaces") : Translation.tr("Hides until the pointer reaches the edge"))
            : !dockRoot.reserve ? Translation.tr("Windows run under the Dock")
            : dockRoot.vertical ? Translation.tr("Windows stop beside the Dock")
            : dockRoot.edge === "top" ? Translation.tr("Windows start below the Dock") : Translation.tr("Windows stop above the Dock")
    }
}
