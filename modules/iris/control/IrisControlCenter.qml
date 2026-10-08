pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.frame
import qs.modules.iris.style
import qs.modules.iris.components

Item {
    id: root

    property var screenData: null
    readonly property string screenName: root.screenData?.name ?? ""
    readonly property var options: Config.options?.iris?.controlCenter ?? ({})
    readonly property var barOptions: Config.options?.iris?.bar ?? ({})
    readonly property string islandEdge: IrisFrame.islandEdge
    readonly property bool barBottom: root.islandEdge === "bottom"
    readonly property bool islandSide: root.islandEdge === "left" || root.islandEdge === "right"
    readonly property bool morphOpen: GlobalStates.controlPanelOpen
        && root.screenName === (GlobalStates.focusedScreen?.name ?? "")
        && (String(Config.options?.iris?.controlCenter?.opens ?? "island") !== "island" || GlobalStates.irisMorphOwner === "stage")
    readonly property bool armed: root.morphOpen && panel.armed
    readonly property bool present: root.morphOpen || panel.progress > 0
    readonly property alias body: panel
    readonly property var fieldShapes: {
        void (panel.x + panel.y + panel.width + panel.height + panel.progress)
        if (!root.present || panel.width < 1) return []
        const rect = panel.bodyRect
        if (rect.width <= 1 || rect.height <= 1) return []
        const joinOrigin = IrisStyle.cardJoins
        const joinRise = root.fromPiece && joinOrigin && String(root.origin?.fieldId ?? "").length > 0
            ? IrisStyle.ramp(panel.progress, 0.08, 0.3) : 0
        const shapes = [{ x: rect.x, y: rect.y, width: rect.width, height: rect.height,
            radius: rect.radius, paints: true,
            fuse: root.fromPiece ? Math.round(IrisStyle.fuseDeep * joinRise) : IrisStyle.fuseDeep,
            id: "control-center", glass: IrisStyle.surfaceGlass("controlCenter"),
            joins: root.fromPiece ? (joinRise > 0 ? String(root.origin?.fieldId ?? "") : "")
                : root.islandBody ? "island" : "" }]
        return shapes
    }
    readonly property var islandBody: GlobalStates.irisIslandGeometry?.[root.screenName] ?? null

    visible: root.present
    readonly property real edgeGap: IrisFrame.islandVisualDepth + 8 * IrisStyle.density
    property var origin: GlobalStates.irisMorphOrigin
    onMorphOpenChanged: if (root.morphOpen) root.origin = Qt.binding(() => GlobalStates.irisMorphOrigin)
        else root.origin = root.origin
    readonly property bool fromPiece: root.origin?.owner === "stage" && String(root.origin?.fieldId ?? "").length > 0
    readonly property var placementOrigin: root.fromPiece && root.origin
        ? Object.assign({}, root.origin, { obstacle: null }) : root.origin
    readonly property var avoidRects: {
        const out = []
        if (root.islandBody && root.islandBody.width > 0 && root.islandBody.height > 0)
            out.push({ x: root.islandBody.x, y: root.islandBody.y, width: root.islandBody.width, height: root.islandBody.height })
        const dock = GlobalStates.irisDockBody?.[root.screenName] ?? []
        for (const shape of (Array.isArray(dock) ? dock : []))
            if (shape?.id === "dock") out.push({ x: shape.x, y: shape.y, width: shape.width, height: shape.height })
        const sidebars = Config.options?.iris?.sidebars ?? ({})
        if (GlobalStates.sidebarLeftOpen && GlobalStates.sidebarLeftPresentationOutput === root.screenName) {
            const o = sidebars?.left ?? ({})
            const width = Math.max(300, Math.min(600, Number(o?.width ?? 380))) * IrisStyle.density
            out.push({ x: 0, y: 0, width: IrisFrame.band + width + ((o?.notch ?? false) ? 0 : 12 * IrisStyle.density), height: root.height })
        }
        if (GlobalStates.sidebarRightOpen && GlobalStates.sidebarRightPresentationOutput === root.screenName) {
            const o = sidebars?.right ?? ({})
            const width = Math.max(300, Math.min(600, Number(o?.width ?? 380))) * IrisStyle.density
            const depth = IrisFrame.band + width + ((o?.notch ?? false) ? 0 : 12 * IrisStyle.density)
            out.push({ x: root.width - depth, y: 0, width: depth, height: root.height })
        }
        return out
    }
    readonly property real baseRadius: IrisStyle.surfaceRadius("controlCenter", IrisStyle.radiusPanel)
    readonly property var placement: root.fromPiece
        ? IrisFrame.place(root.placementOrigin, panel.width, panel.height, root.width, root.height, root.baseRadius,
            root.avoidRects, IrisStyle.cardJoins ? -IrisStyle.weld : Math.max(IrisFrame.bodyAir, IrisStyle.cardGap)) : null
    readonly property real panelWidth: Math.min(root.width - 16, (Math.max(320, Number(root.options?.width ?? 360))
        + (GlobalStates.irisControlEdit ? IrisControlOptions.editorExtra : 0)) * IrisStyle.density)
    readonly property real contentPadding: IrisStyle.concentricPad(IrisStyle.surfaceRadius("controlCenter", IrisStyle.radiusPanel), 16 * IrisStyle.density)
    readonly property real edge: Math.round(8 * IrisStyle.density) + IrisFrame.band
    readonly property real edgeLeft: Math.round(8 * IrisStyle.density) + IrisFrame.safeClear("left")
    readonly property real edgeRight: Math.round(8 * IrisStyle.density) + IrisFrame.safeClear("right")

    MouseArea { anchors.fill: parent; onClicked: GlobalStates.controlPanelOpen = false }
    Shortcut { sequence: "Escape"; onActivated: GlobalStates.controlPanelOpen = false }

    property bool engaged: false
    property real heldTop: 0
    readonly property bool holding: root.barBottom && root.engaged && panel.settled
    HoverHandler {
        property point last: Qt.point(-1, -1)
        onHoveredChanged: if (!hovered) root.engaged = false
        onPointChanged: {
            const p = point.position
            if (Math.abs(p.x - last.x) + Math.abs(p.y - last.y) > 2) {
                last = p
                root.engaged = panelHover.hovered
            }
        }
    }

    IrisMorphSurface {
        id: panel
        open: root.morphOpen
        motionSurface: "controlCenter"
        settles: true
        color: IrisStyle.bodySurface
        fieldBacked: true
        contentReady: contents.contentHeight > 0
        radius: root.placement && !IrisStyle.cardJoins
            ? IrisFrame.nestRadius({ x: root.placement.x, y: root.placement.y, width: panel.width, height: panel.height },
                root.baseRadius, root.origin?.obstacle ?? root.origin, Number(root.origin?.nestFuse ?? IrisStyle.fuse), root.width, root.height)
            : root.baseRadius
        origin: root.fromPiece ? root.origin : null
        onClosed: if (GlobalStates.irisMorphOwner === "stage" && !GlobalStates.settingsOverlayOpen) GlobalStates.irisMorphOwner = ""
        light: IrisStyle.surfaceLight("controlCenter", IrisStyle.wallpaperLight)
        lightFrom: root.placement ? (root.placement.sideways ? (root.placement.towardsLeft ? "right" : "left") : (root.placement.towardsUp ? "bottom" : "top"))
            : root.islandSide ? root.islandEdge : root.barBottom ? "bottom" : "top"
        x: root.placement ? root.placement.x
            : root.islandSide && root.islandBody ? (root.islandEdge === "left"
                ? root.islandBody.x + root.islandBody.width - IrisStyle.weld
                : root.islandBody.x - width + IrisStyle.weld)
            : root.origin
            ? Math.max(root.edgeLeft, Math.min(root.width - width - root.edgeRight,
                root.origin.x + root.origin.width / 2 - width / 2))
            : (root.width - width) / 2
        y: root.placement ? root.placement.y
            : root.holding ? Math.max(12, Math.min(root.heldTop, root.height - height - root.edgeGap))
            : root.islandSide ? Math.round(Math.max(IrisFrame.safeInset("top") + root.edge, Math.min(root.height - height - IrisFrame.safeInset("bottom") - root.edge,
                (root.origin ? root.origin.y + root.origin.height / 2 : (root.islandBody ? root.islandBody.y + root.islandBody.height / 2 : root.height / 2)) - height / 2)))
            : root.barBottom ? (root.islandBody ? root.islandBody.y - height + IrisStyle.weld
                : root.height - height - root.edgeGap - IrisFrame.band)
            : (root.islandBody ? root.islandBody.y + root.islandBody.height - IrisStyle.weld
                : root.edgeGap + IrisFrame.band)
        onYChanged: if (!root.holding) root.heldTop = panel.y
        width: root.panelWidth
        readonly property real room: {
            const top = IrisFrame.safeClear("top") + Math.round(8 * IrisStyle.density)
            const bottom = IrisFrame.safeClear("bottom") + Math.round(8 * IrisStyle.density)
            const body = root.islandBody
            if (root.placement || root.islandSide || !body) return root.height - top - bottom
            return root.barBottom ? body.y - top : root.height - (body.y + body.height) - bottom
        }
        height: Math.min(panel.room, contents.contentHeight + root.contentPadding * 2)
        Behavior on y {
            enabled: panel.settled
            NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve }
        }
        Behavior on height {
            enabled: panel.settled
            NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve }
        }

        MouseArea { anchors.fill: parent }
        HoverHandler { id: panelHover; onHoveredChanged: if (hovered) root.engaged = true }

        Flickable {
            id: contents
            anchors.fill: parent
            anchors.margins: root.contentPadding
            contentHeight: quickPanel.item?.implicitHeight ?? 0
            boundsBehavior: Flickable.StopAtBounds
            // Scroll only when capped, or a drag on a capsule becomes a flick.
            interactive: contents.contentHeight > contents.height + 1
            clip: true

            Loader {
                id: quickPanel
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                sourceComponent: IrisQuickPanel { targetScreen: root.screenData }
            }
        }
    }
}
