pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.iris.style
import "../components"
import "../parts"

// AIRISU's bar (board Desktop): three lacquer plates hung from the edge instead of the Island. Left, the insignia
// and the workspaces (the current one a gofun disc); centre, a wedge with the chevrons, what is playing, its track
// and time; right, the machine in mono and the clock wide. IrisBar keeps the window, the input and the reservation;
// this publishes the strip as the Island's geometry so every surface that hangs from the Island hangs from it.
Item {
    id: root
    property var targetScreen
    property real availableWidth: 800
    property real compactHeight: Math.round(44 * Airisu.d)
    property string edge: "top"
    // What IrisBar reads from the Island it stands in for.
    readonly property real notchness: 0
    readonly property bool expanded: false
    readonly property real d: Airisu.d
    readonly property string screenName: root.targetScreen?.name ?? ""
    readonly property bool bottomEdge: root.edge === "bottom"
    readonly property var player: MprisController.activePlayer ?? null
    // The track's time is read from the controller once a second while it plays.
    property int tick: 0
    readonly property real position: { void root.tick; return MprisController.positionOf(root.player) }

    implicitWidth: root.availableWidth
    implicitHeight: root.compactHeight

    Component.onCompleted: ResourceUsage.keepAlive()
    Component.onDestruction: ResourceUsage.releaseKeepAlive()

    // The strip is the Island for everything that hangs from it (Control Center, banners, Spotlight).
    readonly property var geometry: {
        void (root.x + root.y + root.width + root.height + (root.parent?.x ?? 0) + (root.parent?.y ?? 0))
        const p = root.mapToItem(null, 0, 0)
        return { x: p.x, y: p.y, width: root.width, height: root.height, bubble: 0, gap: 0, bottomEdge: root.bottomEdge,
            edge: root.edge, vertical: false, resting: true, fullWidth: true }
    }
    onGeometryChanged: publish.restart()
    Timer {
        id: publish
        interval: 0
        onTriggered: {
            if (root.screenName.length === 0) return
            const all = Object.assign({}, GlobalStates.irisIslandGeometry ?? {})
            all[root.screenName] = root.geometry
            GlobalStates.irisIslandGeometry = all
        }
    }
    function originFrom(part: Item): void {
        const p = part.mapToItem(null, 0, 0)
        GlobalStates.irisMorphOrigin = { x: p.x, y: p.y, width: part.width, height: part.height, radius: 0, screen: root.screenName }
    }

    // However it opens (a key, IPC, the plate), the Control Center hangs from the machine plate.
    Connections {
        target: GlobalStates
        function onControlPanelOpenChanged(): void {
            if (GlobalStates.controlPanelOpen && root.screenName === (GlobalStates.focusedScreen?.name ?? "")) root.originFrom(right)
        }
    }

    readonly property var workspaces: {
        const list = (NiriService.allWorkspaces ?? []).filter(ws => ws.output === root.screenName)
        return list.slice().sort((a, b) => a.idx - b.idx)
    }
    function occupied(ws): bool { return (NiriService.windows ?? []).some(w => String(w.workspace_id) === String(ws.id)) }
    function clock(s: real): string {
        const t = Math.max(0, Math.floor(s))
        return `${Math.floor(t / 60)}:${String(t % 60).padStart(2, "0")}`
    }

    // ── Left: insignia and workspaces ───────────────────────────────────────────
    APlate {
        id: left
        cuts: [root.bottomEdge ? "tr" : "br"]
        height: parent.height
        width: leftRow.implicitWidth + Math.round(12 * root.d) + Math.round(8 * root.d)
        Row {
            id: leftRow
            x: Math.round(12 * root.d)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.round(4 * root.d)
            Insignia {
                width: Math.round(26 * root.d); height: width
                anchors.verticalCenter: parent.verticalCenter
                TapHandler { onTapped: GlobalStates.searchOpen = !GlobalStates.searchOpen }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
            }
            Item { width: Math.round(16 * root.d) + Airisu.line; height: parent.height
                ARule { vertical: true; anchors.centerIn: parent; height: Math.round(20 * root.d) } }
            Repeater {
                model: root.workspaces
                Item {
                    id: wsCell
                    required property var modelData
                    readonly property bool current: wsCell.modelData.is_active === true
                    width: Math.round(30 * root.d); height: width
                    anchors.verticalCenter: parent.verticalCenter
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: Airisu.gofun
                        scale: wsCell.current ? 1 : 0.4
                        opacity: wsCell.current ? 1 : 0
                        Behavior on scale { enabled: IrisStyle.motionEnabled; NumberAnimation { duration: Airisu.whip; easing.type: Easing.BezierSpline; easing.bezierCurve: Airisu.curve } }
                        Behavior on opacity { enabled: IrisStyle.motionEnabled; NumberAnimation { duration: Airisu.shift } }
                    }
                    AText {
                        anchors.centerIn: parent
                        voice: "wide"
                        size: IrisStyle.typeHeadline
                        font.weight: Font.Black
                        text: wsCell.modelData.idx
                        color: wsCell.current ? Airisu.inkOnGofun : root.occupied(wsCell.modelData) ? Airisu.data : Airisu.quiet
                    }
                    TapHandler { onTapped: NiriService.switchToWorkspaceById(wsCell.modelData.id) }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                }
            }
        }
        WheelHandler {
            onWheel: event => event.angleDelta.y > 0 ? NiriService.focusWorkspaceUp() : NiriService.focusWorkspaceDown()
        }
    }

    // ── Centre: what is playing, or the window in focus ────────────────────────
    APlate {
        id: centre
        taper: true
        height: parent.height
        width: Math.min(Math.round(520 * root.d), centreRow.implicitWidth + Math.round(40 * root.d))
        x: Math.round((root.width - width) / 2)
        readonly property bool playing: root.player !== null
        Row {
            id: centreRow
            anchors.centerIn: parent
            spacing: Math.round(14 * root.d)
            AChevrons {
                anchors.verticalCenter: parent.verticalCenter
                running: centre.playing && (root.player?.isPlaying ?? false)
                colour: centre.playing ? Airisu.seal : Airisu.quiet
            }
            AText {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, Math.round(220 * root.d))
                size: IrisStyle.typeBody
                font.weight: Font.Bold
                text: centre.playing ? MprisController.titleOf(root.player) : (NiriService.activeWindow?.title ?? Translation.tr("Desktop"))
            }
            AText {
                anchors.verticalCenter: parent.verticalCenter
                visible: text.length > 0
                width: Math.min(implicitWidth, Math.round(140 * root.d))
                size: IrisStyle.typeBody
                font.weight: Font.Normal
                color: Airisu.data
                readonly property string who: centre.playing ? MprisController.artistOf(root.player) : String(NiriService.activeWindow?.app_id ?? "")
                text: who.length > 0 ? `— ${who}` : ""
            }
            Rectangle {
                id: track
                visible: centre.playing && length > 0
                readonly property real length: MprisController.lengthOf(root.player)
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(120 * root.d)
                height: Math.max(2, Math.round(2 * root.d))
                color: Airisu.socket
                Rectangle {
                    height: parent.height
                    width: Math.round(parent.width * Math.max(0, Math.min(1, root.position / Math.max(1, track.length))))
                    color: Airisu.gofun
                }
            }
            AText {
                anchors.verticalCenter: parent.verticalCenter
                visible: track.visible
                voice: "mono"
                font.letterSpacing: 0
                size: IrisStyle.typeMeta
                color: Airisu.data
                text: root.clock(root.position)
            }
            Timer { interval: 1000; repeat: true; running: track.visible && (root.player?.isPlaying ?? false); onTriggered: root.tick++ }
        }
        TapHandler { enabled: centre.playing; onTapped: MprisController.togglePlaying() }
        TapHandler { enabled: centre.playing; acceptedButtons: Qt.MiddleButton; onTapped: MprisController.next() }
        HoverHandler { cursorShape: centre.playing ? Qt.PointingHandCursor : Qt.ArrowCursor }
    }

    // ── Right: the machine and the clock ───────────────────────────────────────
    APlate {
        id: right
        cuts: [root.bottomEdge ? "tl" : "bl"]
        height: parent.height
        width: rightRow.implicitWidth + Math.round(32 * root.d)
        x: root.width - width
        Row {
            id: rightRow
            anchors.centerIn: parent
            spacing: Math.round(16 * root.d)
            component Gauge: Row {
                property string label
                property string value
                property bool alarm: false
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(6 * root.d)
                AText { voice: "mono"; size: IrisStyle.typeMeta; font.letterSpacing: 1; color: Airisu.data; text: parent.label }
                AText { voice: "mono"; size: IrisStyle.typeMeta; font.letterSpacing: 0; color: parent.alarm ? Airisu.amber : Airisu.gofun; text: parent.value }
            }
            Gauge { label: "CPU"; value: Math.round(ResourceUsage.cpuUsage * 100) }
            Gauge { label: "RAM"; value: (ResourceUsage.memoryUsed / 1048576).toFixed(1) }
            Gauge {
                visible: Battery.available
                label: "BAT"
                value: Math.round(Battery.percentage * 100)
                alarm: !Battery.isCharging && Battery.percentage <= 0.15
            }
            ARule { vertical: true; height: Math.round(20 * root.d); anchors.verticalCenter: parent.verticalCenter }
            AText {
                id: clockText
                anchors.verticalCenter: parent.verticalCenter
                voice: "wide"
                size: IrisStyle.typeTitle + Math.round(3 * IrisStyle.typeScale)
                font.weight: Font.Black
                text: DateTime.time
                TapHandler { onTapped: GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen }
            }
        }
        TapHandler {
            onTapped: GlobalStates.controlPanelOpen = !GlobalStates.controlPanelOpen
        }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
    }
}
