pragma ComponentBehavior: Bound

import QtQuick
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.pieces

Item {
    id: zones

    required property Item island
    property bool vertical: false
    property real thickness: 42
    property real heartLength: 0
    // The band the zones sit in across the bar: all of it, or a menu bar's strip.
    property real laneTop: 0
    property real lane: zones.height
    property var start: []
    property var center: []
    property var end: []
    property var absorbed: []
    property string screenName: ""
    property string clockStyle: "dateTime"
    property real clockScale: 1
    property color clockAccent: IrisStyle.secondaryAccent
    // A clear menu bar leaves its items on the wallpaper: each group reads what is under it (Lume) and takes
    // dark ink over a light one, as macOS does.
    property bool clear: false
    property bool bottomEdge: false
    // How far the lane's centre moves toward the screen edge, so it sits in the middle of the body the eye sees.
    property real lift: 0
    readonly property real liftY: zones.bottomEdge ? zones.lift : -zones.lift

    readonly property real d: IrisStyle.density
    // The rail changes depth, but the controls keep the full bar's touch and glyph scale.
    readonly property bool strip: zones.lane < zones.height - 0.5
    readonly property real pieceSize: Math.round(zones.thickness)
    readonly property real faceBox: Math.min(zones.pieceSize, Math.round(32 * zones.d))
    readonly property real endInset: Math.round(10 * zones.d)
    readonly property real gap: Math.round(6 * zones.d)
    readonly property real length: zones.vertical ? zones.height : zones.width
    // The tray remains one usable piece when its individual apps would squeeze the live heart.
    readonly property bool trayApps: String(Config.options?.iris?.tray?.face ?? "apps") === "apps"
        && zones.length >= 1100 * zones.d

    function taken(kind: string): bool {
        if (zones.absorbed.includes(kind)) return false
        return IrisPieces.floats(Config.options?.iris?.bubbles, kind)
    }
    function usable(kind: string): bool {
        if (kind === "island" || kind === "window" || kind === "time" || kind === "|") return true
        if (kind === "workspaces") return CompositorService.isNiri && !zones.taken(kind)
        return IrisPieces.extraIds.includes(kind) && IrisPieces.available(kind) && !zones.taken(kind)
    }
    readonly property var entries: {
        const seen = []
        const out = [zones.start, zones.center, zones.end].map(list => Array.from(list ?? []).filter(kind => {
            const id = String(kind)
            if (id === "|") return true
            if (seen.includes(id) || !zones.usable(id)) return false
            seen.push(id)
            return true
        }).filter((kind, i, list) => kind !== "|" || (i > 0 && i < list.length - 1 && list[i - 1] !== "|")))
        if (!seen.includes("island")) out[1].unshift("island")
        return out
    }
    readonly property bool hasTime: zones.entries.some(list => list.includes("time"))

    property Item heartItem: null
    readonly property Item heartGroup: zones.heartItem?.parent ?? null
    readonly property real heartAlong: zones.heartItem && zones.heartGroup
        ? (zones.vertical ? zones.heartGroup.y + zones.heartItem.y : zones.heartGroup.x + zones.heartItem.x) : 0

    property var registry: ({})
    function itemFor(kind: string): var {
        const item = zones.registry[kind] ?? null
        return item && item.visible ? item : null
    }

    function alongOf(group: Item): real { return zones.vertical ? group.height : group.width }
    readonly property real startEnd: zones.endInset + zones.alongOf(startGroup)
    readonly property real endStart: zones.length - zones.endInset - zones.alongOf(endGroup)
    readonly property rect startArea: Qt.rect(startGroup.x, startGroup.y, startGroup.width, startGroup.height)
    readonly property rect endArea: Qt.rect(endGroup.x, endGroup.y, endGroup.width, endGroup.height)

    component Group: Grid {
        id: group
        property var kinds: []
        property bool light: false
        readonly property var backdrop: {
            void (zones.x + zones.y + group.x + group.y + group.width + (zones.parent?.x ?? 0) + (zones.parent?.y ?? 0))
            if (!zones.clear || zones.vertical || group.width < 1) return null
            const at = group.mapToItem(null, 0, 0)
            return Lume.read(zones.screenName, at.x, zones.bottomEdge ? at.y + group.height - zones.lane : at.y, group.width, zones.lane)
        }
        onBackdropChanged: group.light = group.backdrop ? Lume.lightAfter(group.backdrop.luminance, group.light, 0.30, 0.21) : false
        columns: zones.vertical ? 1 : Math.max(1, kinds.length)
        flow: zones.vertical ? Grid.TopToBottom : Grid.LeftToRight
        spacing: zones.gap
        verticalItemAlignment: Grid.AlignVCenter
        horizontalItemAlignment: Grid.AlignHCenter
        x: zones.vertical ? Math.round((zones.width - width) / 2) : 0
        y: zones.vertical ? 0 : Math.round(zones.laneTop + (zones.lane - height) / 2 + zones.liftY)
        Repeater {
            model: parent.kinds
            delegate: Loader {
                id: entry
                required property string modelData
                visible: (item?.implicitWidth ?? 0) > 0.5 && (item?.implicitHeight ?? 0) > 0.5
                sourceComponent: entry.modelData === "|" ? breathEntry
                    : entry.modelData === "island" ? heartSlot
                    : entry.modelData === "workspaces" ? workspacesEntry
                    : entry.modelData === "window" ? windowEntry
                    : entry.modelData === "time" ? timeEntry
                    : entry.modelData === "tray" && zones.trayApps ? trayEntry : pieceEntry
                Binding {
                    when: entry.item !== null && entry.item.light !== undefined
                    target: entry.item
                    property: "light"
                    value: group.light
                }
                Binding {
                    when: entry.item !== null && entry.item.backdrop !== undefined
                    target: entry.item
                    property: "backdrop"
                    value: group.backdrop
                }
                onLoaded: {
                    entry.item.kind = entry.modelData
                    if (entry.modelData === "island") zones.heartItem = entry
                    const next = Object.assign({}, zones.registry)
                    next[entry.modelData] = entry
                    zones.registry = next
                }
                Component.onDestruction: {
                    if (zones.heartItem === entry) zones.heartItem = null
                    if (zones.registry[entry.modelData] === entry) {
                        const next = Object.assign({}, zones.registry)
                        delete next[entry.modelData]
                        zones.registry = next
                    }
                }
            }
        }
    }

    Group {
        id: startGroup
        kinds: zones.entries[0]
        x: zones.vertical ? Math.round((zones.width - width) / 2) : zones.endInset
        y: zones.vertical ? zones.endInset : Math.round(zones.laneTop + (zones.lane - height) / 2 + zones.liftY)
    }
    Group {
        id: endGroup
        kinds: zones.entries[2]
        x: zones.vertical ? Math.round((zones.width - width) / 2) : Math.round(zones.width - zones.endInset - width)
        y: zones.vertical ? Math.round(zones.height - zones.endInset - height) : Math.round(zones.laneTop + (zones.lane - height) / 2 + zones.liftY)
    }
    Group {
        id: centerGroup
        kinds: zones.entries[1]
        readonly property real size: zones.alongOf(centerGroup)
        readonly property real along: Math.round(Math.max(zones.startEnd + 2 * zones.gap,
            Math.min(zones.endStart - 2 * zones.gap - size, (zones.length - size) / 2)))
        x: zones.vertical ? Math.round((zones.width - width) / 2) : centerGroup.along
        y: zones.vertical ? centerGroup.along : Math.round(zones.laneTop + (zones.lane - height) / 2 + zones.liftY)
    }

    component Platter: Rectangle {
        property bool lit: false
        anchors.fill: parent
        radius: Math.min(width, height) / 2
        property bool light: false
        color: IrisStyle.fillHoverOf(light ? IrisStyle.inkOnLight : IrisStyle.text)
        opacity: lit ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
    }

    // Air between what the bar carries and the pieces it took in: grouped by space, never by a box.
    Component {
        id: breathEntry
        Item {
            property string kind: ""
            implicitWidth: zones.vertical ? 1 : zones.gap * 2
            implicitHeight: zones.vertical ? zones.gap * 2 : 1
        }
    }

    Component {
        id: heartSlot
        Item {
            property string kind: ""
            implicitWidth: zones.vertical ? zones.thickness : zones.heartLength
            implicitHeight: zones.vertical ? zones.heartLength : zones.thickness
        }
    }

    Component {
        id: pieceEntry
        Item {
            id: piece
            property string kind: ""
            property bool light: false
            property var backdrop: null
            implicitWidth: zones.vertical ? zones.pieceSize : face.laneWidth
            implicitHeight: zones.pieceSize
            IrisBubbleFace {
                id: face
                anchors.fill: parent
                screenName: zones.screenName
                kind: piece.kind
                plated: true
                lane: !zones.vertical
                contentInset: Math.round((zones.pieceSize - zones.faceBox) / 2)
                lightBackdrop: piece.light
                backdrop: piece.backdrop
                open: zones.island.pieceOpen(piece.kind, piece)
                hovered: pieceHover.hovered
                pressed: pieceTap.pressed
            }
            HoverHandler { id: pieceHover; cursorShape: Qt.PointingHandCursor }
            TapHandler {
                id: pieceTap
                onTapped: {
                    if (GlobalStates.irisEdit) {
                        GlobalStates.irisEditSelection = ""
                        GlobalStates.irisEditTarget = "island"
                        return
                    }
                    zones.island.activatePiece(piece.kind, piece)
                }
            }
            WheelHandler {
                enabled: piece.kind === "sound" || piece.kind === "mic"
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    const steps = zones.island.wheelSteps(event)
                    if (steps === 0) return
                    GlobalStates.quietIrisLevels()
                    zones.island.stepLevel(piece.kind === "mic" ? "mic" : "volume", steps)
                }
            }
            Accessible.role: Accessible.Button
            Accessible.name: Translation.tr(IrisPieces.labelOf(piece.kind))
        }
    }

    Component {
        id: trayEntry
        Item {
            property string kind: ""
            property bool light: false
            property var backdrop: null
            implicitWidth: strip.width
            implicitHeight: strip.height
            IrisTrayStrip {
                id: strip
                cellSize: zones.pieceSize
                vertical: zones.vertical
                screenName: zones.screenName
                menuToward: zones.island.trayMenuToward
            }
        }
    }

    Component {
        id: workspacesEntry
        Item {
            id: strip
            property string kind: ""
            property bool light: false
            property var backdrop: null
            readonly property color ink: strip.light ? IrisStyle.inkOnLight : IrisStyle.text
            readonly property var list: {
                const all = (NiriService.allWorkspaces ?? []).filter(ws => ws.output === zones.screenName)
                    .sort((a, b) => a.idx - b.idx)
                const windows = NiriService.windows ?? []
                const used = all.map(ws => windows.some(w => w.workspace_id === ws.id))
                return all.filter((ws, i) => ws.is_active || used[i] || i < all.length - 1)
                    .map(ws => ({ id: ws.id, active: ws.is_active, urgent: ws.is_urgent ?? false,
                        used: windows.some(w => w.workspace_id === ws.id) }))
            }
            readonly property real slot: Math.round(14 * zones.d)
            readonly property real dot: Math.max(4, Math.round(6 * zones.d))
            readonly property real pad: Math.round(6 * zones.d)
            implicitWidth: strip.list.length === 0 ? 0 : zones.vertical ? zones.pieceSize : dots.implicitWidth + 2 * strip.pad
            implicitHeight: strip.list.length === 0 ? 0 : zones.vertical ? dots.implicitHeight + 2 * strip.pad : zones.pieceSize
            function step(by: int): void {
                const at = strip.list.findIndex(ws => ws.active)
                const next = strip.list[Math.max(0, Math.min(strip.list.length - 1, at + by))]
                if (next && !next.active) NiriService.switchToWorkspaceById(next.id)
            }
            property real wheel: 0
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    strip.wheel += event.angleDelta.y !== 0 ? event.angleDelta.y : event.pixelDelta.y * 4
                    const steps = Math.trunc(strip.wheel / 120)
                    if (steps === 0) return
                    strip.wheel -= steps * 120
                    strip.step(-steps)
                }
            }
            Grid {
                id: dots
                anchors.centerIn: parent
                columns: zones.vertical ? 1 : Math.max(1, strip.list.length)
                flow: zones.vertical ? Grid.TopToBottom : Grid.LeftToRight
                Repeater {
                    model: strip.list
                    delegate: Item {
                        id: space
                        required property var modelData
                        readonly property real extent: space.modelData.active ? strip.slot + Math.round(10 * zones.d) : strip.slot
                        width: zones.vertical ? zones.pieceSize : space.extent
                        height: zones.vertical ? space.extent : zones.pieceSize
                        Behavior on width { enabled: !zones.vertical; NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve } }
                        Behavior on height { enabled: zones.vertical; NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve } }
                        Rectangle {
                            anchors.centerIn: parent
                            readonly property real along: space.modelData.active ? space.extent - strip.slot + strip.dot : strip.dot
                            width: zones.vertical ? strip.dot : along
                            height: zones.vertical ? along : strip.dot
                            radius: strip.dot / 2
                            color: space.modelData.active ? IrisStyle.markOn(IrisStyle.accent, strip.backdrop, strip.light, 3)
                                : space.modelData.urgent ? IrisStyle.markOn(IrisStyle.secondaryAccent, strip.backdrop, strip.light, 3)
                                : spaceHover.hovered ? strip.ink
                                : space.modelData.used ? (strip.light ? IrisStyle.inkOnLightMuted : IrisStyle.textSecondary)
                                : strip.light ? IrisStyle.inkOnLightFaint : IrisStyle.textTertiary
                            Behavior on color { ColorAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
                        }
                        HoverHandler { id: spaceHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: if (!space.modelData.active) NiriService.switchToWorkspaceById(space.modelData.id) }
                    }
                }
            }
            Accessible.role: Accessible.PageTabList
            Accessible.name: Translation.tr("Workspaces")
        }
    }

    Component {
        id: windowEntry
        Item {
            id: current
            property string kind: ""
            property bool light: false
            property var backdrop: null
            readonly property var window: {
                const ws = (NiriService.allWorkspaces ?? []).find(w => w.output === zones.screenName && w.is_active)
                if (!ws) return null
                const onWorkspace = (NiriService.windows ?? []).filter(w => w.workspace_id === ws.id)
                return onWorkspace.find(w => w.id === ws.active_window_id) ?? null
            }
            readonly property string title: String(current.window?.title ?? "")
            readonly property real iconSize: Math.round(18 * zones.d)
            readonly property real pad: Math.round(8 * zones.d)
            readonly property real maxTitle: Math.round(Math.min(280 * zones.d, zones.length * 0.22))
            implicitWidth: !current.window ? 0 : zones.vertical ? zones.pieceSize
                : current.pad * 2 + current.iconSize + (label.text.length > 0 ? Math.round(8 * zones.d) + Math.min(current.maxTitle, label.implicitWidth) : 0)
            implicitHeight: !current.window ? 0 : zones.vertical ? zones.pieceSize : zones.pieceSize
            SmartAppIcon {
                id: icon
                x: zones.vertical ? Math.round((parent.width - width) / 2) : current.pad
                anchors.verticalCenter: parent.verticalCenter
                icon: IrisPieces.appIcon(String(current.window?.app_id ?? ""))
                fallback: "application-x-executable"
                iconSize: current.iconSize
            }
            IrisText {
                id: label
                visible: !zones.vertical
                anchors.left: icon.right
                anchors.leftMargin: Math.round(8 * zones.d)
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(current.maxTitle, implicitWidth)
                text: current.title
                color: current.light ? IrisStyle.inkOnLight : IrisStyle.text
                font.pixelSize: IrisStyle.typeLabel
                font.weight: IrisStyle.weight(Font.Medium)
                elide: Text.ElideRight
            }
            Accessible.role: Accessible.StaticText
            Accessible.name: current.title
        }
    }

    Component {
        id: timeEntry
        Item {
            id: time
            property string kind: ""
            property bool light: false
            property var backdrop: null
            readonly property real pad: Math.round(10 * zones.d)
            implicitWidth: zones.vertical ? zones.pieceSize : row.implicitWidth + 2 * time.pad
            implicitHeight: zones.vertical ? column.implicitHeight + 2 * time.pad : zones.pieceSize
            Platter { lit: timeHover.hovered; light: time.light }
            Row {
                id: row
                visible: !zones.vertical
                anchors.centerIn: parent
                spacing: Math.round(8 * zones.d)
                DateMark {
                    visible: zones.clockStyle === "dateTime"
                    anchors.verticalCenter: parent.verticalCenter
                    pixelSize: 12 * IrisStyle.typeScale * zones.clockScale
                    dayColor: IrisStyle.markOn(zones.clockAccent, time.backdrop, time.light, 4.5)
                    inkColor: time.light ? IrisStyle.inkOnLightMuted : IrisStyle.muted
                }
                IrisClock {
                    anchors.verticalCenter: parent.verticalCenter
                    pixelSize: 14 * IrisStyle.typeScale * zones.clockScale
                    color: time.light ? IrisStyle.inkOnLight : IrisStyle.text
                    separatorColor: IrisStyle.markOn(zones.clockAccent, time.backdrop, time.light, 3)
                }
            }
            IslandStackedClock {
                id: column
                visible: zones.vertical
                anchors.centerIn: parent
                pixelSize: 14 * IrisStyle.typeScale * zones.clockScale
                accent: zones.clockAccent
                showDay: zones.clockStyle === "dateTime"
            }
            HoverHandler { id: timeHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: zones.island.openPage("desktop", true, time) }
            Accessible.role: Accessible.Button
            Accessible.name: DateTime.timeDisplay
        }
    }
}
