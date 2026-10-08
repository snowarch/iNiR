pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.frame
import qs.modules.iris.pieces
import qs.modules.settings

Item {
    id: root

    required property var modelData
    readonly property string screenName: root.modelData?.name ?? ""
    readonly property bool occupied: root.anyFloating || root.drag !== null || landing.running || root.cardPresent
    property bool suppressed: false
    readonly property real d: IrisStyle.density
    readonly property var options: Config.options?.iris?.bubbles ?? ({})
    readonly property var islandSlots: IrisPieces.slotIds
    readonly property var extraKinds: IrisPieces.extraIds
    readonly property var allSlots: root.islandSlots.concat(root.extraKinds.map(kind => "extra-" + kind),
        IrisPieces.appPieceIds(), root.trayAppSlots)
    function isExtra(slot: string): bool { return slot.startsWith("extra-") }
    function isApp(slot: string): bool { return IrisPieces.isApp(slot) }
    readonly property bool trayAppsFace: String(Config.options?.iris?.tray?.face ?? "apps") === "apps"
    readonly property var trayApps: !root.trayAppsFace ? [] : SystemTray.items.values.filter(item => item && item.id
        && (!(Config.options?.iris?.tray?.hidePassive ?? false) || item.status !== Status.Passive))
    readonly property var trayAppSlots: root.trayApps.map((item, index) => "trayApp:" + index)
    function isTrayApp(slot: string): bool { return slot.startsWith("trayApp:") }
    function trayItemOf(slot: string): var { return root.trayApps[Number(slot.slice(8))] ?? null }
    readonly property string trayOwner: {
        const owners = ["extra-tray"].concat(root.islandSlots)
        return owners.find(slot => root.baseKindOf(slot) === "tray" && root.configuredPlace(slot) !== "island"
            && !root.absorption.bySlot[slot]) ?? ""
    }
    function ownerSlot(slot: string): string { return root.isTrayApp(slot) && root.trayOwner.length > 0 ? root.trayOwner : slot }
    readonly property bool trayAppsShown: root.trayApps.length > 0 && root.trayOwner.length > 0
    readonly property string trayPlace: root.trayOwner.length > 0 ? root.configuredPlace(root.trayOwner) : ""
    readonly property bool trayGrouped: root.trayAppsShown
        && (root.trayPlace.startsWith("edge:") || !root.zones.some(z => z.zone === root.trayPlace))
    readonly property bool trayStacks: root.trayPlace === "edge:left" || root.trayPlace === "edge:right"
    function optionsFor(slot: string): var {
        slot = root.ownerSlot(slot)
        if (root.isApp(slot)) return IrisPieces.appEntry(IrisPieces.appIdOf(slot))
        return root.isExtra(slot) ? root.options?.extras?.[slot.slice(6)] : root.options?.[slot]
    }
    function configPath(slot: string): string {
        slot = root.ownerSlot(slot)
        return IrisPieces.configPath(root.isExtra(slot) ? slot.slice(6) : slot)
    }
    function placeName(slot: string): string {
        return root.absorption.bySlot[slot] ? "island" : root.configuredPlace(slot)
    }
    function configuredPlace(slot: string): string {
        slot = root.ownerSlot(slot)
        const o = root.optionsFor(slot)
        if (root.isApp(slot)) return String(o?.place ?? IrisPieces.defaultPlace)
        if (root.isExtra(slot)) return IrisFrame.extraOn(root.options?.extras, slot.slice(6)) && !IrisPieces.listedOnIsland(slot.slice(6))
            ? String(o?.place ?? IrisPieces.defaultPlace) : "island"
        return String(o?.place ?? "island")
    }
    function kindOf(slot: string): string {
        if (root.isTrayApp(slot)) return root.trayAppsShown ? "trayApp" : ""
        if (slot === root.trayOwner && root.trayAppsShown) return ""
        return root.baseKindOf(slot)
    }
    function baseKindOf(slot: string): string {
        if (root.isTrayApp(slot)) return ""
        if (root.isApp(slot)) return "app"
        if (!root.isExtra(slot)) return String(root.kinds[slot] ?? "")
        const kind = slot.slice(6)
        return IrisPieces.available(kind) ? kind : ""
    }
    readonly property bool anyFloating: root.allSlots.some(slot => root.placeName(slot) !== "island")
    readonly property var kinds: GlobalStates.irisBubbleKinds?.[root.screenName] ?? ({})
    readonly property var island: GlobalStates.irisIslandGeometry?.[root.screenName] ?? null
    readonly property var drag: GlobalStates.irisBubbleDrag && GlobalStates.irisBubbleDrag.screen === root.screenName
        ? GlobalStates.irisBubbleDrag : null
    readonly property bool carryingIsland: root.drag?.slot === "island"
    readonly property real size: Math.round((root.island?.bubble ?? Math.round(40 * root.d)) * Math.max(0.6, Math.min(1.4, Number(root.options?.scale ?? 100) / 100)))
    readonly property real margin: Math.round(Math.max(0, Number(root.options?.edgeGap ?? 20)) * root.d) + IrisFrame.band
    readonly property real snapDistance: Math.round(110 * root.d)
    readonly property real attachDistance: Math.round(80 * root.d)
    readonly property bool barred: Boolean(root.options?.cluster ?? true)
    readonly property real looseGap: Math.round(8 * root.d)
    readonly property real barGap: Math.round(4 * root.d)
    readonly property real barPad: Math.round(6 * root.d)
    readonly property real absorbRange: root.size * 1.6
    property var liveCentres: ({})
    function publishCentre(slot: string, x: real, y: real): void {
        const next = Object.assign({}, root.liveCentres)
        next[slot] = Qt.point(x, y)
        root.liveCentres = next
    }
    function liveCentre(slot: string): point {
        return root.liveCentres[slot] ?? root.placeOf(slot)
    }
    readonly property var spans: {
        const out = {}
        for (const zone of Object.keys(root.lines)) out[zone] = root.spanOf(zone)
        if (root.trayGrouped) out.tray = root.spanOf("tray")
        return out
    }
    function barSpan(zone: string): var { return root.spans[zone] ?? null }
    function spanOf(zone: string): var {
        const line = root.lineFor(zone)
        if (line.length < 2) return null
        const stacks = zone === "tray" ? root.trayStacks : root.stacks(zone)
        let lo = Infinity;
        let hi = -Infinity;
        let crossSum = 0;
        for (const slot of line) {
            const rest = root.placeOf(slot)
            const main = stacks ? rest.y : rest.x
            lo = Math.min(lo, main)
            hi = Math.max(hi, main)
            crossSum += stacks ? rest.x : rest.y
        }
        return { lo: lo, hi: hi, cross: crossSum / line.length, stacks: stacks }
    }
    function absorbOf(slot: string): real {
        const span = root.barSpan(root.plateKey(slot))
        if (!span) return 0
        const live = root.liveCentres[slot]
        if (!live) return 1
        const main = span.stacks ? live.y : live.x
        const cross = span.stacks ? live.x : live.y
        const away = Math.max(span.lo - main, main - span.hi, Math.abs(cross - span.cross))
        if (away <= 0) return 1
        return Math.max(0, 1 - away / root.absorbRange)
    }

    visible: root.occupied && !root.suppressed

    readonly property bool attached: IrisFrame.piecesAttached
    readonly property var zones: {
        const half = root.size / 2
        const edgeOn = wall => (root.attached ? IrisFrame.pieceInsetOn(wall) : root.margin) + half
        const g = root.island
        const clearance = root.size / 2 + Math.round(10 * root.d)
        const side = g?.edge ?? (g?.bottomEdge ? "bottom" : "top")
        const top = g && side === "top"
            ? Math.max(edgeOn("top"), g.fullWidth ? g.y + g.height + clearance : g.y + g.bubble / 2) : edgeOn("top")
        const bottom = g && side === "bottom"
            ? Math.min(root.height - edgeOn("bottom"), g.fullWidth ? g.y - clearance : g.y + g.height - g.bubble / 2)
            : root.height - edgeOn("bottom")
        const left = g && side === "left"
            ? Math.max(edgeOn("left"), g.fullWidth ? g.x + g.width + clearance : g.x + g.width / 2) : edgeOn("left")
        const right = g && side === "right"
            ? Math.min(root.width - edgeOn("right"), g.fullWidth ? g.x - clearance : g.x + g.width / 2) : root.width - edgeOn("right")
        // An Island moved into a corner (a side layout, a theme) owns that corner: the plate there
        // starts beside it, on the same row, instead of landing on top of it.
        const along = g && !g.fullWidth && (side === "top" || side === "bottom") ? root.ownerSpan("island", side) : null
        const gapBeside = half + Math.round(10 * root.d)
        // A corner plate meets its side wall the way it meets its own edge.
        const wallFor = edgeSide => Math.max(edgeOn("left"), edgeOn(edgeSide))
        const leftOf = edgeSide => g && side === "left" ? left : wallFor(edgeSide)
        const rightOf = edgeSide => g && side === "right" ? right : root.width - Math.max(edgeOn("right"), edgeOn(edgeSide))
        const cornerLeftOf = edgeSide => along && along.lo < leftOf(edgeSide) + half ? Math.max(leftOf(edgeSide), along.hi + gapBeside) : leftOf(edgeSide)
        const cornerRightOf = edgeSide => along && along.hi > rightOf(edgeSide) - half ? Math.min(rightOf(edgeSide), along.lo - gapBeside) : rightOf(edgeSide)
        const at = {
            "top-left": { x: side === "top" ? cornerLeftOf("top") : leftOf("top"), y: top },
            "top-right": { x: side === "top" ? cornerRightOf("top") : rightOf("top"), y: top },
            "left": { x: left, y: root.height / 2 },
            "right": { x: right, y: root.height / 2 },
            "bottom-left": { x: side === "bottom" ? cornerLeftOf("bottom") : leftOf("bottom"), y: bottom },
            "bottom-right": { x: side === "bottom" ? cornerRightOf("bottom") : rightOf("bottom"), y: bottom }
        }
        return IrisPieces.zones.map(zone => ({ zone: zone, x: at[zone].x, y: at[zone].y }))
    }
    function slotCentre(slot: string): point {
        const g = root.island
        if (!g) return Qt.point(root.width / 2, root.margin + root.size / 2)
        const step = g.bubble + g.gap
        if (g.vertical) {
            const cx = g.x + g.width / 2
            if (slot === "left") return Qt.point(cx, g.y - g.gap - g.bubble / 2)
            if (slot === "utility") return Qt.point(cx, g.y + g.height + (g.auxiliarySlot - 1) * step + g.gap + g.bubble / 2)
            return Qt.point(cx, g.y + g.height + g.gap + g.bubble / 2)
        }
        const cy = g.bottomEdge ? g.y + g.height - g.bubble / 2 : g.y + g.bubble / 2
        if (slot === "left") return Qt.point(g.x - g.gap - g.bubble / 2, cy)
        if (slot === "utility") return Qt.point(g.x + g.width + (g.auxiliarySlot - 1) * step + g.gap + g.bubble / 2, cy)
        return Qt.point(g.x + g.width + g.gap + g.bubble / 2, cy)
    }
    function islandCentre(): point {
        const g = root.island
        if (!g || g.width <= 0) return Qt.point(root.width / 2, root.margin + root.size / 2)
        return Qt.point(g.x + g.width / 2, g.y + g.height / 2)
    }
    function islandReach(x: real, y: real): real {
        const g = root.island
        if (!g || g.width <= 0 || g.height <= 0) return Infinity
        return Math.hypot(Math.max(g.x - x, 0, x - (g.x + g.width)), Math.max(g.y - y, 0, y - (g.y + g.height)))
    }
    function clampPoint(x: real, y: real): point {
        const lo = root.margin + root.size / 2
        return Qt.point(Math.max(lo, Math.min(root.width - lo, x)), Math.max(lo, Math.min(root.height - lo, y)))
    }
    // Tables, rebuilt only when their inputs change: recomputed per call they cost O(n^3) per plate on every drag event.
    readonly property var lines: {
        const out = {}
        for (const slot of root.allSlots) {
            if (root.kindOf(slot).length === 0) continue
            const zone = root.placeName(slot)
            if (!out[zone]) out[zone] = []
            out[zone].push(slot)
        }
        return out
    }
    function lineOf(zone: string): var { return root.lines[zone] ?? [] }
    function stacks(zone: string): bool { return zone === "left" || zone === "right" }
    readonly property real edgeLine: (root.attached ? IrisFrame.pieceInset : root.margin) + root.size / 2
    function edgePoint(side: string, fx: real, fy: real): point {
        const lo = root.edgeLine + Math.max(IrisFrame.cornerRadius, root.size / 2)
        const along = (value, span) => Math.max(lo, Math.min(span - lo, value * span))
        if (side === "top") return Qt.point(along(fx, root.width), root.edgeLine)
        if (side === "bottom") return Qt.point(along(fx, root.width), root.height - root.edgeLine)
        if (side === "left") return Qt.point(root.edgeLine, along(fy, root.height))
        return Qt.point(root.width - root.edgeLine, along(fy, root.height))
    }

    readonly property var dockBodyNow: {
        const shapes = GlobalStates.irisDockBody?.[root.screenName] ?? []
        return (Array.isArray(shapes) ? shapes : []).find(shape => shape?.id === "dock") ?? null
    }
    property var dockHeld: null
    onDockBodyNowChanged: {
        const b = root.dockBodyNow
        if (!b) return
        const vertical = IrisFrame.vertical(IrisFrame.dockEdge)
        const lo = vertical ? b.y : b.x
        const length = vertical ? b.height : b.width
        const held = root.dockHeld
        if (held && held.edge === IrisFrame.dockEdge && Math.abs(held.lo - lo) < 1 && Math.abs(held.length - length) < 1) return
        root.dockHeld = { edge: IrisFrame.dockEdge, lo: lo, length: length }
    }
    readonly property bool dockOn: Config.options?.iris?.dock?.enable ?? true
    readonly property string islandSideName: root.island ? String(root.island.edge ?? (root.island.bottomEdge ? "bottom" : "top")) : ""
    function ownerSpan(owner: string, side: string): var {
        const vertical = IrisFrame.vertical(side)
        if (owner === "island") {
            const g = root.island
            if (g.fullWidth) return { lo: -Infinity, hi: Infinity }
            const lo = vertical ? g.y : g.x
            const step = (g.bubble ?? root.size) + (g.gap ?? 0)
            return { lo: lo - step, hi: lo + (vertical ? g.height : g.width) + Math.max(1, g.auxiliarySlot ?? 1) * step }
        }
        const held = root.dockHeld
        if (held && held.edge === side) return { lo: held.lo, hi: held.lo + held.length }
        const span = vertical ? root.height : root.width
        const guess = ((TaskbarApps.apps ?? []).length + 2) * (IrisFrame.dockIcon + 12 * root.d)
        return { lo: (span - guess) / 2, hi: (span + guess) / 2 }
    }
    function ownerOf(side: string): string {
        if (side.length === 0) return ""
        if (root.island && root.islandSideName === side) return "island"
        if (root.dockOn && IrisFrame.dockEdge === side) return "dock"
        return ""
    }
    readonly property var absorption: {
        const bySlot = {}
        const island = []
        const islandStart = []
        const islandSlots = []
        const dock = []
        // Pieces that melt into an edge each carry a notch of `edgeFuse` radius. Sitting
        // closer than that makes the field fuse the notches into one trough instead of
        // giving each piece its own, so the gap has to clear the fuse, not a quarter of it.
        const gapOn = wall => Math.round(12 * root.d + (IrisFrame.meltsOn(wall) ? root.edgeFuseOn(wall) * 0.85 : 0))
        const half = root.size / 2
        const owned = root.allSlots.filter(slot => !root.isTrayApp(slot))
        for (const slot of owned) {
            const place = root.configuredPlace(slot)
            if (place === "island" || place === "free" || root.baseKindOf(slot).length === 0) continue
            const side = IrisFrame.edgeOf(place)
            let owner = root.ownerOf(side)
            // A full bar holds both corners of its edge: a plate there melts into the bar instead of
            // parking against its end.
            if (owner.length === 0 && (root.island?.fullWidth ?? false) && root.islandSideName.length > 0
                    && ["top-left", "top-right", "bottom-left", "bottom-right"].includes(place) && place.includes(root.islandSideName))
                owner = "island"
            if (owner.length === 0) continue
            const vertical = IrisFrame.vertical(side)
            const members = place.startsWith("edge:") ? [slot]
                : owned.filter(other => root.configuredPlace(other) === place && root.baseKindOf(other).length > 0)
            let lo = Infinity
            let hi = -Infinity
            for (const member of members) {
                const p = root.linePoint(member, place, members)
                lo = Math.min(lo, (vertical ? p.y : p.x) - half)
                hi = Math.max(hi, (vertical ? p.y : p.x) + half)
            }
            const block = root.ownerSpan(owner, side)
            if (hi + gapOn(side) <= block.lo || lo - gapOn(side) >= block.hi) continue
            bySlot[slot] = owner
            if (root.isApp(slot)) continue
            if (owner === "island") {
                // It joins the end of the bar it was nearest to.
                const at = root.linePoint(slot, place, members)
                const nearStart = IrisFrame.vertical(root.islandSideName) ? at.y < root.height / 2 : at.x < root.width / 2
                if (root.isExtra(slot) && nearStart) islandStart.push(slot.slice(6))
                if (root.isExtra(slot)) island.push(slot.slice(6))
                else islandSlots.push(slot)
            } else {
                dock.push({ slot: slot, kind: root.isExtra(slot) ? slot.slice(6) : root.baseKindOf(slot) })
            }
        }
        return { bySlot: bySlot, island: island, islandStart: islandStart, islandSlots: islandSlots, dock: dock }
    }
    onAbsorptionChanged: absorbedPublish.restart()
    // Publishing moves the Island and the Dock, which feed the zones this is computed from.
    Timer { id: absorbedPublish; interval: 0; onTriggered: { root.publishAbsorbed(); root.returnAbsorbedApps() } }
    function returnAbsorbedApps(): void {
        if (root.drag || landing.running || root.dockHeld?.edge !== IrisFrame.dockEdge) return
        for (const slot in root.absorption.bySlot)
            if (root.isApp(slot) && root.absorption.bySlot[slot] === "dock") IrisPieces.removeApp(IrisPieces.appIdOf(slot))
    }
    Component.onDestruction: {
        if (root.screenName.length === 0) return
        const next = Object.assign({}, GlobalStates.irisAbsorbed ?? {})
        delete next[root.screenName]
        GlobalStates.irisAbsorbed = next
    }
    function publishAbsorbed(): void {
        if (root.screenName.length === 0) return
        const value = { island: root.absorption.island, islandStart: root.absorption.islandStart,
            islandSlots: root.absorption.islandSlots, dock: root.absorption.dock }
        const current = GlobalStates.irisAbsorbed?.[root.screenName]
        if (JSON.stringify(current ?? null) === JSON.stringify(value)) return
        const next = Object.assign({}, GlobalStates.irisAbsorbed ?? {})
        next[root.screenName] = value
        GlobalStates.irisAbsorbed = next
    }
    readonly property var restPoints: {
        const out = {}
        for (const slot of root.allSlots) out[slot] = root.rawPlaceOf(slot)
        return out
    }
    function placeOf(slot: string): point { return root.restPoints[slot] ?? root.rawPlaceOf(slot) }
    // A plate on the Island's own row sits on the Island's centre line and takes the Island's thickness: a row of
    // bodies of other heights than the object it belongs to reads as the wrong weight.
    function onIslandRow(zone: string): bool {
        const g = root.island
        const side = zone === "tray" ? IrisFrame.edgeOf(root.trayPlace) : IrisFrame.edgeOf(zone)
        return g !== null && g !== undefined && !g.fullWidth && side.length > 0 && side === root.islandSideName
    }
    function acrossHalf(zone: string): real {
        const full = root.size / 2 + root.barPad
        if (!root.onIslandRow(zone)) return full
        // Its pieces sit on the satellites' line (bubble / 2 in from the edge); the plate reaches from there to the
        // Island's far side, so both end on one line, melted or floating.
        const g = root.island
        const thick = g.vertical ? Number(g.width ?? root.size) : Number(g.height ?? root.size)
        return Math.max(root.size / 2 + Math.round(2 * root.d), thick - Number(g.bubble ?? root.size) / 2)
    }
    function linePoint(slot: string, zone: string, line: var): point {
        if (zone.startsWith("edge:")) {
            const o = root.optionsFor(slot)
            return root.edgePoint(zone.slice(5), Number(o?.fx ?? 0.5), Number(o?.fy ?? 0.5))
        }
        const found = root.zones.find(z => z.zone === zone)
        if (!found) {
            const o = root.optionsFor(slot)
            return root.clampPoint(Number(o?.fx ?? 0.5) * root.width, Number(o?.fy ?? 0.5) * root.height)
        }
        const index = Math.max(0, line.indexOf(slot))
        const bar = root.barred && line.length > 1
        const step = root.size + (bar ? root.barGap : root.looseGap)
        const inset = bar ? root.barPad : 0
        const across = root.onIslandRow(zone) ? 0 : inset
        const x = found.x + (zone.endsWith("left") ? 1 : -1) * (root.stacks(zone) ? across : inset)
        const y = zone.startsWith("top") ? found.y + across
            : zone.startsWith("bottom") ? found.y - across : found.y
        if (root.stacks(zone)) return Qt.point(x, y + (index - (line.length - 1) / 2) * step)
        return Qt.point(x + (zone.endsWith("left") ? index : -index) * step, y)
    }
    function trayLinePoint(slot: string): point {
        const base = root.linePoint(root.trayOwner, root.trayPlace, [root.trayOwner])
        const count = root.trayAppSlots.length
        const step = root.size + (root.barred && count > 1 ? root.barGap : root.looseGap)
        const offset = (root.trayAppSlots.indexOf(slot) - (count - 1) / 2) * step
        if (root.trayStacks) {
            const half = (count - 1) / 2 * step
            const y = Math.max(root.edgeLine + half, Math.min(root.height - root.edgeLine - half, base.y))
            return Qt.point(base.x, y + offset)
        }
        const half = (count - 1) / 2 * step
        const x = Math.max(root.edgeLine + half, Math.min(root.width - root.edgeLine - half, base.x))
        return Qt.point(x + offset, base.y)
    }
    function rawPlaceOf(slot: string): point {
        if (root.isTrayApp(slot) && root.trayGrouped) return root.trayLinePoint(slot)
        const zone = root.placeName(slot)
        return root.linePoint(slot, zone, zone.startsWith("edge:") ? [slot] : root.lineOf(zone))
    }
    readonly property var rects: {
        const out = []
        for (const slot of root.allSlots) {
            const floating = root.placeName(slot) !== "island" && root.kindOf(slot).length > 0
            if (!floating) { out.push(null); continue }
            const centre = root.placeOf(slot)
            out.push({ x: Math.round(centre.x - root.size / 2), y: Math.round(centre.y - root.size / 2), size: root.size })
        }
        return out
    }
    readonly property var plates: {
        const out = []
        if (!root.barred) return out
        for (const zone of root.zones) {
            const line = root.lineOf(zone.zone)
            if (line.length < 2) continue
            const first = root.placeOf(line[0])
            const last = root.placeOf(line[line.length - 1])
            const along = root.size / 2 + root.barPad
            const across = root.acrossHalf(zone.zone)
            const hx = root.stacks(zone.zone) ? across : along
            const hy = root.stacks(zone.zone) ? along : across
            const x = Math.round(Math.min(first.x, last.x) - hx)
            const y = Math.round(Math.min(first.y, last.y) - hy)
            out.push({
                zone: zone.zone,
                x: x,
                y: y,
                width: Math.round(Math.max(first.x, last.x) + hx) - x,
                height: Math.round(Math.max(first.y, last.y) + hy) - y,
                stacks: root.stacks(zone.zone)
            })
        }
        if (root.trayGrouped && root.trayAppSlots.length > 1 && root.drag?.slot !== root.trayOwner) {
            const first = root.placeOf(root.trayAppSlots[0])
            const last = root.placeOf(root.trayAppSlots[root.trayAppSlots.length - 1])
            const along = root.size / 2 + root.barPad
            const across = root.acrossHalf("tray")
            const hx = root.trayStacks ? across : along
            const hy = root.trayStacks ? along : across
            const x = Math.round(Math.min(first.x, last.x) - hx)
            const y = Math.round(Math.min(first.y, last.y) - hy)
            out.push({ zone: "tray", side: IrisFrame.edgeOf(root.trayPlace), x: x, y: y,
                width: Math.round(Math.max(first.x, last.x) + hx) - x,
                height: Math.round(Math.max(first.y, last.y) + hy) - y, stacks: root.trayStacks })
        }
        return out
    }
    function plateAt(zone: string): var { return root.plates.find(plate => plate.zone === zone) ?? null }
    function plateKey(slot: string): string {
        return root.isTrayApp(slot) && root.trayGrouped ? "tray" : root.placeName(slot)
    }
    function plateFor(slot: string): var { return root.plateAt(root.plateKey(slot)) }
    function menuToward(slot: string): string {
        const place = root.placeName(slot)
        const side = IrisFrame.edgeOf(place)
        if (side === "top") return "down"
        if (side === "bottom") return "up"
        if (side === "left") return "right"
        if (side === "right") return "left"
        const at = root.placeOf(slot)
        return at.y > root.height / 2 ? "up" : "down"
    }
    function lineFor(key: string): var {
        if (key === "tray") return root.trayGrouped ? root.trayAppSlots : []
        return root.lineOf(key)
    }
    function plateShape(zone: string): var {
        const span = root.barSpan(zone)
        if (!span) return null
        const line = root.lineFor(zone)
        const main = point => span.stacks ? point.y : point.x
        let lo = Infinity;
        let hi = -Infinity;
        let held = 0;
        const arriving = []
        for (const slot of line) {
            const at = main(root.liveCentre(slot))
            const absorbed = root.absorbOf(slot)
            if (absorbed >= 1) {
                lo = Math.min(lo, at)
                hi = Math.max(hi, at)
                held++
            } else {
                arriving.push({ absorbed: absorbed, at: at })
            }
        }
        if (held === 0) { lo = span.lo; hi = span.hi }
        for (const piece of arriving) {
            const edge = piece.at < lo ? lo : hi
            const reached = edge + (piece.at - edge) * piece.absorbed
            lo = Math.min(lo, reached)
            hi = Math.max(hi, reached)
        }
        const along = root.size / 2 + root.barPad
        const across = root.acrossHalf(zone)
        const hx = span.stacks ? across : along
        const hy = span.stacks ? along : across
        const x = Math.round((span.stacks ? span.cross : lo) - hx)
        const y = Math.round((span.stacks ? lo : span.cross) - hy)
        return {
            x: x,
            y: y,
            width: Math.round((span.stacks ? span.cross : hi) + hx) - x,
            height: Math.round((span.stacks ? hi : span.cross) + hy) - y
        }
    }
    readonly property real edgeFuse: root.edgeFuseOn("")
    function edgeFuseOn(side: string): real {
        return IrisFrame.joinOn(side) === "notch" ? IrisStyle.edgeFuseFor(root.size, Number(root.options?.notchCurve ?? 100)) : IrisStyle.fuse
    }
    function meltInto(shape: var, side: string, sides: var): var {
        if (!root.attached || side.length === 0) return Object.assign(shape, { fuse: IrisStyle.fuse, joins: "" })
        if (!IrisFrame.meltsOn(side)) return Object.assign(shape, { fuse: IrisStyle.fuse, joins: IrisFrame.framed ? "frame" : "" })
        const reach = Math.min(shape.width, shape.height) / 2 + 1
        // A corner body also melts into the second wall it rests on: its rounded corner inside that fillet reads as a bump.
        const inset = IrisFrame.framed ? IrisFrame.band : 0
        const walls = [side].concat(["top", "bottom", "left", "right"]
            .filter(wall => wall !== side && root.gapTo(shape, wall, inset) <= 1))
        const grown = Object.assign({}, shape, { fuse: root.edgeFuseOn(side), paints: true,
            joins: IrisFrame.framed ? "frame" : walls.map(wall => "pieceEdge:" + wall) })
        for (const wall of walls) {
            if (wall === "top") { grown.y -= reach; grown.height += reach }
            else if (wall === "bottom") grown.height += reach
            else if (wall === "left") { grown.x -= reach; grown.width += reach }
            else if (wall === "right") grown.width += reach
            if (!IrisFrame.framed && !sides.includes(wall)) sides.push(wall)
        }
        return grown
    }
    function gapTo(shape: var, wall: string, inset: real): real {
        if (wall === "top") return shape.y - inset
        if (wall === "bottom") return root.height - inset - shape.y - shape.height
        if (wall === "left") return shape.x - inset
        return root.width - inset - shape.x - shape.width
    }
    function edgeBody(side: string): var {
        const deep = Math.max(8, root.edgeFuseOn(side))
        const k = root.edgeFuseOn(side)
        if (side === "top") return { x: -2 * k, y: -deep - 1, width: root.width + 4 * k, height: deep, radius: 0, paints: true, fuse: 0, id: "pieceEdge:top" }
        if (side === "bottom") return { x: -2 * k, y: root.height + 1, width: root.width + 4 * k, height: deep, radius: 0, paints: true, fuse: 0, id: "pieceEdge:bottom" }
        if (side === "left") return { x: -deep - 1, y: -2 * k, width: deep, height: root.height + 4 * k, radius: 0, paints: true, fuse: 0, id: "pieceEdge:left" }
        return { x: root.width + 1, y: -2 * k, width: deep, height: root.height + 4 * k, radius: 0, paints: true, fuse: 0, id: "pieceEdge:right" }
    }
    readonly property var fieldShapes: {
        void (card.x + card.y + card.width + card.height + card.progress)
        const out = []
        const sides = []
        for (const plate of root.plates) {
            out.push(root.meltInto({ x: plate.x, y: plate.y, width: plate.width, height: plate.height,
                radius: IrisStyle.pieceRadius(Math.min(plate.width, plate.height)), id: "plate:" + plate.zone },
                plate.side ?? IrisFrame.edgeOf(plate.zone), sides))
        }
        for (let i = 0; i < root.allSlots.length; i++) {
            const slot = root.allSlots[i]
            const rect = root.rects[i]
            if (!rect || root.plateFor(slot)) continue
            const carriedSlot = root.ownerSlot(slot)
            if (root.drag?.slot === carriedSlot || (landing.running && landing.slot === carriedSlot)) continue
            out.push(root.meltInto({ x: rect.x, y: rect.y, width: rect.size, height: rect.size, radius: IrisStyle.pieceRadius(rect.size),
                id: "piece:" + slot }, IrisFrame.edgeOf(root.placeName(slot)), sides))
        }
        for (const side of sides) out.unshift(root.edgeBody(side))
        if (carried.shown && !root.carryingIsland) {
            const size = root.size * carried.scale
            out.push({ x: carried.at.x - size / 2, y: carried.at.y - size / 2,
                width: size, height: size, radius: IrisStyle.pieceRadius(size) })
        }
        if (root.cardPresent && card.width > 1) {
            const body = card.bodyRect
            if (body.width > 1 && body.height > 1) {
                const joinOrigin = IrisStyle.cardJoins
                const joinRise = joinOrigin && root.cardOriginId.length > 0
                    ? IrisStyle.ramp(card.progress, 0.08, 0.3) : 0
                out.push({ x: body.x, y: body.y, width: body.width, height: body.height,
                    radius: body.radius, paints: true, fuse: Math.round(IrisStyle.fuseDeep * joinRise), id: "card", glass: IrisStyle.surfaceGlass("cards"),
                    joins: joinRise > 0 ? root.cardOriginId : "" })
            }
        }
        return out
    }
    // Every floating piece on its own, grouped or not, for the edit layer to outline.
    readonly property var pieceShapes: {
        if (!GlobalStates.irisEdit) return []
        const out = []
        for (let i = 0; i < root.allSlots.length; i++) {
            const rect = root.rects[i]
            if (rect) out.push({ id: "piece:" + root.allSlots[i], x: rect.x, y: rect.y, width: rect.size, height: rect.size,
                radius: IrisStyle.pieceRadius(rect.size) })
        }
        return out
    }
    readonly property var hitRects: {
        const out = []
        for (const plate of root.plates) out.push(plate)
        for (let i = 0; i < root.allSlots.length; i++) {
            const rect = root.rects[i]
            if (!rect || root.plateFor(root.allSlots[i])) continue
            out.push({ x: rect.x, y: rect.y, width: rect.size, height: rect.size })
        }
        return out
    }

    function dockCatches(zone: string, x: real, y: real): bool {
        if (!root.dockOn) return false
        const b = root.dockBodyNow
        const reach = Math.round(24 * root.d)
        if (b && x > b.x - reach && x < b.x + b.width + reach && y > b.y - reach && y < b.y + b.height + reach) return true
        const side = IrisFrame.edgeOf(zone)
        if (side.length === 0 || root.ownerOf(side) !== "dock") return false
        const span = root.ownerSpan("dock", side)
        const along = IrisFrame.vertical(side) ? y : x
        const clear = root.size / 2 + Math.round(12 * root.d)
        return along + clear > span.lo && along - clear < span.hi
    }
    function dockTarget(x: real, y: real): var {
        const home = GlobalStates.irisDockHome
        if (home && home.screen === root.screenName && root.drag && home.appId === IrisPieces.appIdOf(root.drag.slot))
            return { zone: "dock", x: home.x, y: home.y }
        const b = root.dockBodyNow
        if (!b) return { zone: "dock", x: x, y: y }
        const vertical = IrisFrame.vertical(IrisFrame.dockEdge)
        const half = Math.min(b.width, b.height) / 2
        return { zone: "dock",
            x: vertical ? b.x + b.width / 2 : Math.max(b.x + half, Math.min(b.x + b.width - half, x)),
            y: vertical ? Math.max(b.y + half, Math.min(b.y + b.height - half, y)) : b.y + b.height / 2 }
    }
    function resolve(x: real, y: real): var {
        const place = root.resolvePlace(x, y)
        if (place && root.drag && !root.carryingIsland && root.isApp(root.drag.slot) && place.zone !== "island"
            && root.dockCatches(place.zone, place.x ?? x, place.y ?? y)) return root.dockTarget(x, y)
        return place
    }
    function resolvePlace(x: real, y: real): var {
        if (!root.drag) return null
        if (root.carryingIsland) {
            const sides = [{ zone: "top", d: y }, { zone: "bottom", d: root.height - y },
                { zone: "left", d: x }, { zone: "right", d: root.width - x }].sort((a, b) => a.d - b.d)
            return { zone: sides[0].zone }
        }
        if (!root.isExtra(root.drag.slot)) {
            const slot = root.slotCentre(root.drag.slot)
            if (Math.hypot(x - slot.x, y - slot.y) < root.attachDistance) return { zone: "island", x: slot.x, y: slot.y }
        } else if (root.islandReach(x, y) < root.attachDistance) {
            const centre = root.islandCentre()
            return { zone: "island", x: centre.x, y: centre.y }
        }
        const snapping = root.options?.snap ?? true
        let best = null
        for (const z of snapping ? root.zones : []) {
            const distance = Math.hypot(x - z.x, y - z.y)
            if (distance < root.snapDistance && (!best || distance < best.distance)) best = { zone: z.zone, x: z.x, y: z.y, distance: distance }
        }
        if (best) return best
        if (snapping) {
            const reach = root.snapDistance * 0.6
            const sides = [
                { side: "top", distance: Math.abs(y - root.edgeLine) },
                { side: "bottom", distance: Math.abs(root.height - root.edgeLine - y) },
                { side: "left", distance: Math.abs(x - root.edgeLine) },
                { side: "right", distance: Math.abs(root.width - root.edgeLine - x) }
            ].sort((a, b) => a.distance - b.distance)
            const g = root.island
            const clear = at => !g || at.x + root.size / 2 + root.looseGap < g.x || at.x - root.size / 2 - root.looseGap > g.x + g.width
                || at.y + root.size / 2 + root.looseGap < g.y || at.y - root.size / 2 - root.looseGap > g.y + g.height
            if (sides[0].distance < reach) {
                const at = root.edgePoint(sides[0].side, x / Math.max(1, root.width), y / Math.max(1, root.height))
                if (clear(at)) return { zone: "edge:" + sides[0].side, x: at.x, y: at.y }
            }
        }
        const free = root.clampPoint(x, y)
        return { zone: "free", x: free.x, y: free.y }
    }
    readonly property var target: root.drag ? root.resolve(root.drag.x, root.drag.y) : null

    function writeEntry(slot: string, place): void {
        slot = root.ownerSlot(slot)
        if (root.isApp(slot)) {
            const appId = IrisPieces.appIdOf(slot)
            if (place.zone === "island" || place.zone === "dock") IrisPieces.removeApp(appId)
            else IrisPieces.placeApp(appId, place.zone,
                Math.round((place.x ?? 0) / Math.max(1, root.width) * 10000) / 10000,
                Math.round((place.y ?? 0) / Math.max(1, root.height) * 10000) / 10000)
            return
        }
        // A slot that resolves to no known path would write half of this and drop the
        // rest, which is how a piece disappears instead of moving.
        if (!root.allSlots.includes(slot)) {
            console.warn("IrisStage: refusing to place unknown slot", slot)
            return
        }
        const path = root.configPath(slot)
        const updates = {}
        updates[path + ".place"] = place.zone
        if (root.isExtra(slot)) {
            const kind = slot.slice(6)
            const onIsland = place.zone === "island"
            updates[path + ".enable"] = !onIsland
            // One piece, one place: the Island carries it in bar.pieces, or it floats as
            // an extra. Landing on the Island joins that list, leaving it drops out of it.
            const carried = Array.from(Config.options?.iris?.bar?.pieces ?? []).map(entry => String(entry))
            if (onIsland && !carried.includes(kind))
                updates["iris.bar.pieces"] = carried.concat([kind])
            else if (!onIsland && carried.includes(kind))
                updates["iris.bar.pieces"] = carried.filter(entry => entry !== kind)
        }
        if (place.zone === "free" || place.zone.startsWith("edge:")) {
            updates[path + ".fx"] = Math.round(place.x / Math.max(1, root.width) * 10000) / 10000
            updates[path + ".fy"] = Math.round(place.y / Math.max(1, root.height) * 10000) / 10000
        }
        Config.setNestedValues(updates)
    }

    Component.onCompleted: { root.land(); root.publishAbsorbed() }
    Connections {
        target: GlobalStates
        function onIrisBubbleDragChanged(): void { root.land() }
    }
    function land(): void {
        const drag = root.drag
        if (!drag || !drag.released || landing.running) return
        const place = root.resolve(drag.x, drag.y)
        if (root.carryingIsland) {
            GlobalStates.irisBubbleDrag = null
            if (place.zone !== IrisFrame.islandEdge) Config.setNestedValue("iris.bar.position", place.zone)
            return
        }
        landing.slot = drag.slot
        landing.kind = drag.kind
        landing.fromX = drag.x
        landing.fromY = drag.y
        landing.attaching = place.zone === "island" || place.zone === "dock"
        // Onto the Dock the bubble grows into the Dock icon it becomes (the face's icon is its width less 12·d).
        landing.endScale = place.zone === "dock" ? IrisFrame.dockIcon / Math.max(1, root.size - 12 * root.d) : 1
        root.writeEntry(drag.slot, place)
        const lands = landing.attaching ? Qt.point(place.x, place.y) : root.placeOf(drag.slot)
        landing.toX = lands.x
        landing.toY = lands.y
        landing.restart()
    }
    SequentialAnimation {
        id: landing
        property string slot: ""
        property string kind: ""
        property real fromX: 0
        property real fromY: 0
        property real toX: 0
        property real toY: 0
        property bool attaching: false
        property real endScale: 1
        NumberAnimation {
            target: carried
            property: "travel"
            from: 0
            to: 1
            duration: IrisStyle.moveDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: IrisStyle.moveCurve
        }
        ScriptAction { script: GlobalStates.irisBubbleDrag = null }
    }

    component ZonePlate: Item {
        id: plate
        required property string zone
        readonly property var current: root.plateAt(plate.zone) ? root.plateShape(plate.zone) : null
        property real shapeX: 0
        property real shapeY: 0
        property real shapeWidth: 0
        property real shapeHeight: 0
        onCurrentChanged: {
            if (!plate.current) return
            plate.shapeX = plate.current.x
            plate.shapeY = plate.current.y
            plate.shapeWidth = plate.current.width
            plate.shapeHeight = plate.current.height
        }
        x: plate.shapeX
        y: plate.shapeY
        width: plate.shapeWidth
        height: plate.shapeHeight
        opacity: plate.current ? 1 : 0
        visible: plate.opacity > 0 && plate.width > 0
        Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }

    }
    ZonePlate { zone: IrisPieces.zones[0] }
    ZonePlate { zone: IrisPieces.zones[1] }
    ZonePlate { zone: IrisPieces.zones[2] }
    ZonePlate { zone: IrisPieces.zones[3] }
    ZonePlate { zone: IrisPieces.zones[4] }
    ZonePlate { zone: IrisPieces.zones[5] }
    ZonePlate { zone: "tray" }

    component FloatingBubble: Item {
        id: bubble
        z: 2
        required property string slot
        required property int pieceIndex
        readonly property string kind: root.kindOf(bubble.slot)
        readonly property var rect: root.rects[bubble.pieceIndex] ?? null
        readonly property bool floating: bubble.rect !== null
        readonly property string owner: root.ownerSlot(bubble.slot)
        readonly property var trayItem: bubble.kind === "trayApp" ? root.trayItemOf(bubble.slot) : null
        readonly property bool carried: root.drag?.slot === bubble.owner || (landing.running && landing.slot === bubble.owner)
        readonly property bool plated: bubble.floating && root.plateFor(bubble.slot) !== null
        readonly property real absorb: bubble.plated ? root.absorbOf(bubble.slot) : 0
        width: bubble.floating ? bubble.rect.size : 0
        height: width
        x: bubble.floating ? bubble.rect.x : 0
        y: bubble.floating ? bubble.rect.y : 0
        visible: bubble.floating
        property bool placed: false
        Component.onDestruction: if (root.controlIntentSlot === bubble.slot) root.controlIntentSlot = ""
        Component.onCompleted: bubble.settle()
        onFloatingChanged: bubble.settle()
        function settle(): void {
            bubble.report()
            if (!bubble.floating) { bubble.placed = false; return }
            Qt.callLater(() => bubble.placed = bubble.floating)
        }
        Behavior on x { enabled: bubble.placed; NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve } }
        Behavior on y { enabled: bubble.placed; NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve } }
        function report(): void {
            if (bubble.carried) return
            root.publishCentre(bubble.slot, bubble.x + bubble.width / 2, bubble.y + bubble.height / 2)
        }
        onXChanged: bubble.report()
        onYChanged: bubble.report()
        onCarriedChanged: bubble.report()
        readonly property bool yielded: root.placeName(bubble.slot) === "island"
            && (IrisFrame.placeBodies["spotlight"]?.screen ?? "") === root.screenName
        opacity: bubble.carried || bubble.yielded ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }

        IrisBubbleFace {
            bodyless: true
            anchors.fill: parent
            screenName: root.screenName
            kind: bubble.kind
            appId: bubble.kind === "app" ? IrisPieces.appIdOf(bubble.slot) : ""
            trayItem: bubble.trayItem
            plated: bubble.plated
            absorb: bubble.absorb
            pressed: grip.pressed && !grip.lifting
            hovered: bubbleHover.hovered
        }
        property real wheelAccumulator: 0
        HoverHandler {
            id: bubbleHover
            cursorShape: Qt.PointingHandCursor
            onHoveredChanged: {
                if (bubble.kind !== "controls" && bubble.kind !== "battery") return
                if (bubbleHover.hovered) root.controlIntentSlot = bubble.slot
                else if (root.controlIntentSlot === bubble.slot) root.controlIntentSlot = ""
            }
        }
        WheelHandler {
            enabled: bubble.kind === "trayApp"
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => bubble.trayItem?.scroll(event.angleDelta.y || event.angleDelta.x, event.angleDelta.y === 0)
        }
        WheelHandler {
            enabled: bubble.kind === "sound" || bubble.kind === "mic"
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                bubble.wheelAccumulator += event.angleDelta.y || event.pixelDelta.y * 4
                const steps = Math.trunc(bubble.wheelAccumulator / 120)
                if (steps === 0) return
                bubble.wheelAccumulator -= steps * 120
                GlobalStates.quietIrisLevels()
                if (bubble.kind === "mic") Audio.setSourceVolume(Math.max(0, Math.min(1, (Audio.micVolume ?? 0) + steps * 0.05)))
                else Audio.setSinkVolume(Math.max(0, Math.min(Math.max(1, Audio.ceiling), (Audio.value ?? 0) + steps * 0.05)))
            }
        }
        IrisBubbleGrip {
            id: grip
            anchors.fill: parent
            slot: bubble.owner
            kind: bubble.kind === "trayApp" ? "tray" : bubble.kind
            screenName: root.screenName
            holdLifts: !GlobalStates.irisEdit
            pullDistance: GlobalStates.irisEdit ? 6 * root.d : 0
            onTapped: {
                if (GlobalStates.irisEdit) {
                    GlobalStates.irisEditSelection = GlobalStates.irisEditSelection === bubble.owner ? "" : bubble.owner
                    return
                }
                if (bubble.trayItem?.onlyMenu && bubble.trayItem?.hasMenu) { trayMenu.open(); return }
                root.activate(bubble.slot, bubble.kind, bubble.rect)
            }
        }
        Rectangle {
            visible: GlobalStates.irisEdit && bubble.floating
            anchors.fill: parent
            anchors.margins: -Math.round(3 * root.d)
            radius: IrisStyle.pieceRadius(width)
            color: "transparent"
            border.width: Math.max(1, Math.round(2 * root.d))
            border.color: GlobalStates.irisEditSelection === bubble.owner ? IrisStyle.accent : IrisStyle.border
            Behavior on border.color { ColorAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
        }
        Rectangle {
            id: editBadge
            visible: GlobalStates.irisEdit && bubble.floating && !bubble.carried
            anchors.horizontalCenter: parent.left
            anchors.verticalCenter: parent.top
            width: Math.round(16 * root.d)
            height: width
            radius: width / 2
            color: IrisStyle.danger
            border.width: Math.max(1, Math.round(root.d))
            border.color: IrisStyle.bodySurface
            scale: GlobalStates.irisEdit ? 1 : 0
            Behavior on scale { NumberAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
            MaterialSymbol {
                anchors.centerIn: parent
                text: "remove"
                fill: 1
                iconSize: Math.round(12 * root.d)
                color: IrisStyle.onTint
            }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -Math.round(4 * root.d)
                cursorShape: Qt.PointingHandCursor
                Accessible.role: Accessible.Button
                Accessible.name: root.homeText(bubble.slot)
                onClicked: root.sendHome(bubble.slot)
            }
        }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: bubble.kind === "trayApp" ? Qt.RightButton | Qt.MiddleButton : Qt.RightButton
            onPressed: event => {
                if (bubble.kind === "trayApp" && event.button === Qt.MiddleButton) {
                    bubble.trayItem?.secondaryActivate()
                    return
                }
                if (bubble.kind === "trayApp" && bubble.trayItem?.hasMenu) {
                    trayMenu.open()
                    return
                }
                pieceMenu.model = root.pieceMenu(bubble.slot, bubble.kind, bubble.rect)
                pieceMenu.requestOpen()
            }
        }
        IrisDesktopMenu {
            id: pieceMenu
            anchorItem: bubble
            opensToward: root.menuToward(bubble.slot)
        }
        IrisTrayMenu {
            id: trayMenu
            handle: bubble.trayItem?.menu ?? null
            anchorItem: bubble
            opensToward: root.menuToward(bubble.slot)
            title: String(bubble.trayItem?.tooltipTitle || bubble.trayItem?.title || bubble.trayItem?.id || "")
            icon: bubble.trayItem ? TrayService.getSafeIcon(bubble.trayItem) : ""
            extra: [{ text: Translation.tr("Tray bubble…"), iconName: "widgets", keepOpen: true, action: () => {
                trayMenu.close()
                pieceMenu.model = root.pieceMenu(bubble.slot, "tray", bubble.rect)
                pieceMenu.requestOpen()
            } }]
        }
        Connections {
            target: GlobalStates
            enabled: bubble.floating
            function onIrisBubbleMenuRequestChanged(): void {
                const want = GlobalStates.irisBubbleMenuRequest
                if (want.length === 0 || root.screenName !== (GlobalStates.focusedScreen?.name ?? "")) return
                if (want !== bubble.kind && want !== bubble.slot) return
                GlobalStates.irisBubbleMenuRequest = ""
                if (bubble.kind === "trayApp" && bubble.trayItem?.hasMenu) { trayMenu.open(); return }
                pieceMenu.model = root.pieceMenu(bubble.slot, bubble.kind, bubble.rect)
                pieceMenu.requestOpen()
            }
        }
    }
    Repeater {
        model: root.allSlots
        Loader {
            id: bubbleSlot
            required property int index
            required property string modelData
            z: 2
            active: (root.rects[bubbleSlot.index] ?? null) !== null
            sourceComponent: FloatingBubble {
                slot: bubbleSlot.modelData
                pieceIndex: bubbleSlot.index
            }
        }
    }

    readonly property bool opensCards: String(root.options?.opens ?? "card") === "card"
    function toggleCard(slot: string, kind: string, rect: var): void {
        const source = rect?.source ?? "float-" + slot
        if (GlobalStates.irisBubbleCard?.source === source) { GlobalStates.irisBubbleCard = null; return }
        if (!rect) return
        GlobalStates.irisBubbleCard = { kind: kind, source: source, screen: root.screenName,
            x: rect.x, y: rect.y, width: rect.size, height: rect.size, radius: IrisStyle.pieceRadius(rect.size) }
    }
    Connections {
        target: GlobalStates
        function onIrisBubbleCardRequestChanged(): void {
            const kind = GlobalStates.irisBubbleCardRequest
            if (kind.length === 0 || root.screenName !== (GlobalStates.focusedScreen?.name ?? "")) return
            const index = root.allSlots.findIndex((slot, i) => root.rects[i] !== null && root.kindOf(slot) === kind)
            if (index < 0) return
            GlobalStates.irisBubbleCardRequest = ""
            root.toggleCard(root.allSlots[index], kind, root.rects[index])
        }
    }

    property string controlSlot: ""
    property string controlIntentSlot: ""
    readonly property bool controlIntent: root.controlIntentSlot.length > 0
    function toggleControls(slot: string, rect: var): void {
        if (GlobalStates.controlPanelOpen && GlobalStates.irisMorphOwner === "stage" && root.controlSlot === slot) {
            GlobalStates.controlPanelOpen = false
            return
        }
        if (GlobalStates.controlPanelOpen) GlobalStates.controlPanelOpen = false
        GlobalStates.irisBubbleCard = null
        root.controlSlot = slot
        root.publishOrigin(slot, rect)
        Qt.callLater(() => GlobalStates.controlPanelOpen = true)
    }
    Connections {
        target: GlobalStates
        function onIrisBubbleCardChanged(): void {
            if (GlobalStates.irisBubbleCard && GlobalStates.controlPanelOpen) GlobalStates.controlPanelOpen = false
        }
        function onControlPanelOpenChanged(): void {
            if (GlobalStates.controlPanelOpen && GlobalStates.irisBubbleCard) GlobalStates.irisBubbleCard = null
            if (!GlobalStates.controlPanelOpen) root.controlSlot = ""
        }
    }
    function publishOrigin(slot: string, rect: var): void {
        const zone = root.plateKey(slot)
        const plate = root.absorption.bySlot[slot] ? null : root.plateAt(zone)
        const inDock = String(rect?.source ?? "").startsWith("dock-")
        GlobalStates.irisMorphOwner = "stage"
        GlobalStates.irisMorphOrigin = { x: rect.x, y: rect.y, width: rect.size, height: rect.size,
            radius: IrisStyle.pieceRadius(rect.size), screen: root.screenName, owner: "stage",
            fieldId: inDock ? "dock" : plate ? "plate:" + zone : "piece:" + slot,
            obstacle: plate ? { x: plate.x, y: plate.y, width: plate.width, height: plate.height } : null,
            nestFuse: root.edgeFuseOn(plate ? (plate.side ?? IrisFrame.edgeOf(plate.zone)) : IrisFrame.edgeOf(root.placeName(slot))) }
    }
    function activate(slot: string, kind: string, rect: var): void {
        const workspaceCard = kind === "workspaces"
            && String(root.optionsFor(slot)?.opens ?? "card") === "card"
        if ((workspaceCard || (kind !== "workspaces" && root.opensCards && IrisPieces.cardIds.includes(kind)))
                && (kind !== "media" || String(Config.options?.iris?.player?.bubbleOpens ?? "card") === "card")) {
            root.toggleCard(slot, kind, rect)
        } else if (kind === "media") {
            GlobalStates.irisIslandPageRequest = "media"
        } else if (kind === "timer" || kind === "record") {
            GlobalStates.irisIslandPageRequest = "activity"
        } else if (kind === "controls") {
            root.toggleControls(slot, rect)
        } else if (kind === "notifications" || kind === "calendar") {
            GlobalStates.openSidebarRight(root.screenName)
        } else if (kind === "focus") {
            Notifications.silent = !Notifications.silent
        } else if (kind === "battery") {
            root.toggleControls(slot, rect)
        } else if (kind === "weather" || kind === "clock") {
            GlobalStates.irisIslandPageRequest = "desktop"
        } else if (kind === "tray" || kind === "tools") {
            GlobalStates.irisIslandPageRequest = kind
        } else if (kind === "trayApp") {
            const item = root.trayItemOf(slot)
            if (item && !TrayService.smartToggle(item)) item.activate()
        } else if (kind === "app") {
            const appId = IrisPieces.appIdOf(slot)
            const app = (TaskbarApps.apps ?? []).find(a => a && a.appId === appId)
            const windows = app?.toplevels ?? []
            if (MinimizedWindows.countMinimizedForApp(appId) > 0) {
                MinimizedWindows.restoreLatestForApp(appId)
            } else if (windows.length > 0) {
                const current = CompositorService.isNiri
                    ? windows.findIndex(w => w.niriWindowId !== undefined && w.niriWindowId === (NiriService.activeWindow?.id ?? -1))
                    : windows.findIndex(w => w.activated)
                const next = windows[(current + 1) % windows.length]
                if (CompositorService.isNiri && next.niriWindowId !== undefined) NiriService.focusWindow(next.niriWindowId)
                else next.activate()
            } else {
                const entry = AppSearch.lookupDesktopEntry(appId)
                if (entry) AppSearch.launchEntry(entry)
            }
        } else if (kind === "workspaces") {
            NiriService.toggleOverview()
        } else if (kind === "sound") {
            Audio.toggleMute()
        } else if (kind === "mic") {
            Audio.toggleMicMute()
        }
    }

    function pieceLabel(slot: string, kind: string): string {
        slot = root.ownerSlot(slot)
        if (root.isApp(slot)) {
            const appId = IrisPieces.appIdOf(slot)
            return AppSearch.lookupDesktopEntry(appId)?.name ?? appId
        }
        return IrisPieces.labelOf(root.isExtra(slot) ? slot.slice(6) : slot)
    }
    readonly property var openGlyphs: ({ weather: "wb_sunny", notifications: "notifications", controls: "tune",
        sound: "volume_up", mic: "mic", tools: "timer", media: "play_circle", tray: "widgets",
        timer: "hourglass_top", record: "fiber_manual_record", app: "open_in_new",
        network: "wifi", bluetooth: "bluetooth", vitals: "monitoring", workspaces: "grid_view",
        updates: "deployed_code_update" })
    function openText(kind: string, slot: string): string {
        if (kind === "controls") return Translation.tr("Open Control Center")
        if (kind === "notifications") return Translation.tr("Open notifications")
        if (kind === "media") return Translation.tr("Open the player")
        if (kind === "workspaces") return String(root.optionsFor(slot)?.opens ?? "card") === "card"
            ? Translation.tr("Open workspace card") : Translation.tr("Open the overview")
        if (kind === "app") return Translation.tr("Open")
        return IrisPieces.cardIds.includes(kind) ? Translation.tr("Open its card") : Translation.tr("Open")
    }
    function homeText(slot: string): string {
        slot = root.ownerSlot(slot)
        if (root.isApp(slot)) return Translation.tr("Return to the Dock")
        return root.isExtra(slot) ? Translation.tr("Turn off") : Translation.tr("Return to the Island")
    }
    function sendHome(slot: string): void {
        slot = root.ownerSlot(slot)
        if (root.isApp(slot)) { IrisPieces.removeApp(IrisPieces.appIdOf(slot)); return }
        if (root.isExtra(slot)) { Config.setNestedValue(root.configPath(slot) + ".enable", false); return }
        Config.setNestedValue(root.configPath(slot) + ".place", "island")
    }
    function placeAt(slot: string, zone: string): void { root.writeEntry(slot, { zone: zone }) }
    function placeFreeAt(slot: string, fx: real, fy: real): void {
        root.writeEntry(slot, { zone: "free", x: fx * root.width, y: fy * root.height })
    }
    function pieceMenu(slot: string, kind: string, rect: var): var {
        slot = root.ownerSlot(slot)
        const options = root.optionsFor(slot)
        return [
            { text: root.openText(kind, slot), iconName: root.openGlyphs[kind] ?? "open_in_full",
                action: () => root.activate(slot, kind, rect) },
            { type: "separator" },
            { type: "place", place: root.placeName(slot), hasIsland: !root.isExtra(slot) && !root.isApp(slot),
                fx: Number(options?.fx ?? 0.5), fy: Number(options?.fy ?? 0.5),
                label: root.pieceLabel(slot, kind),
                action: zone => root.placeAt(slot, zone),
                freeAction: (fx, fy) => root.placeFreeAt(slot, fx, fy) },
            { type: "separator" },
            { text: root.homeText(slot), iconName: root.isApp(slot) ? "dock_to_bottom" : "keyboard_return",
                action: () => root.sendHome(slot) },
            { text: Translation.tr("Bubble settings…"), iconName: "tune",
                action: () => {
                    root.publishOrigin(slot, rect)
                    const page = SettingsPageRegistry.pages.findIndex(entry => entry.key === "iris")
                    if (page >= 0) GlobalStates.openSettingsPage(page, "bubbles")
                    else GlobalStates.openSettings()
                } }
        ]
    }

    Repeater {
        model: !root.drag || root.carryingIsland ? []
            : !root.island ? root.zones
            : root.zones.concat([root.isExtra(root.drag.slot)
                ? { zone: "island", x: root.islandCentre().x, y: root.islandCentre().y }
                : { zone: "island", x: root.slotCentre(root.drag.slot).x, y: root.slotCentre(root.drag.slot).y }])
        delegate: Rectangle {
            id: hint
            required property var modelData
            readonly property bool active: root.target?.zone === hint.modelData.zone && !root.drag?.released
            width: root.size + 10 * root.d
            height: width
            x: Math.round(hint.modelData.x - width / 2)
            y: Math.round(hint.modelData.y - height / 2)
            radius: IrisStyle.pieceRadius(width)
            color: hint.active ? IrisStyle.tintFill(IrisStyle.accent) : IrisStyle.veilLight
            border.width: Math.max(1, Math.round(1.5 * root.d))
            border.color: hint.active ? IrisStyle.accent : IrisStyle.borderStrong
            scale: hint.active ? 1.08 : 1
            opacity: root.drag?.released ? 0 : 1
            Behavior on scale { NumberAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
            Behavior on color { ColorAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
            Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
        }
    }
    Rectangle {
        readonly property bool shown: (String(root.target?.zone ?? "").startsWith("edge:") || root.target?.zone === "dock")
            && !(root.drag?.released ?? true)
        width: root.size + 10 * root.d
        height: width
        x: Math.round((root.target?.x ?? 0) - width / 2)
        y: Math.round((root.target?.y ?? 0) - height / 2)
        radius: IrisStyle.pieceRadius(width)
        visible: opacity > 0
        opacity: shown ? 1 : 0
        color: IrisStyle.tintFill(IrisStyle.accent)
        border.width: Math.max(1, Math.round(1.5 * root.d))
        border.color: IrisStyle.accent
        Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
    }
    Repeater {
        model: root.carryingIsland ? ["top", "bottom", "left", "right"] : []
        delegate: Rectangle {
            id: edgeHint
            required property string modelData
            readonly property bool active: root.target?.zone === edgeHint.modelData
            readonly property bool side: edgeHint.modelData === "left" || edgeHint.modelData === "right"
            readonly property real along: Math.round(Math.max(root.drag?.width ?? 0, 160 * root.d))
            width: edgeHint.side ? Math.round(root.size) : edgeHint.along
            height: edgeHint.side ? edgeHint.along : Math.round(root.size)
            x: edgeHint.modelData === "left" ? root.margin : edgeHint.modelData === "right" ? root.width - width - root.margin
                : Math.round((root.width - width) / 2)
            y: edgeHint.modelData === "top" ? root.margin : edgeHint.modelData === "bottom" ? root.height - height - root.margin
                : Math.round((root.height - height) / 2)
            radius: Math.min(width, height) / 2
            color: edgeHint.active ? IrisStyle.tintFill(IrisStyle.accent) : IrisStyle.veilLight
            border.width: Math.max(1, Math.round(1.5 * root.d))
            border.color: edgeHint.active ? IrisStyle.accent : IrisStyle.borderStrong
            Behavior on color { ColorAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
        }
    }

    Item {
        id: carried
        property real travel: 0
        readonly property bool shown: (root.drag !== null && root.drag.slot !== "island") || landing.running
        readonly property string slot: landing.running ? landing.slot : String(root.drag?.slot ?? "")
        readonly property point at: landing.running
            ? Qt.point(landing.fromX + (landing.toX - landing.fromX) * carried.travel, landing.fromY + (landing.toY - landing.fromY) * carried.travel)
            : Qt.point(root.drag?.x ?? 0, root.drag?.y ?? 0)
        readonly property real px: carried.at.x
        readonly property real py: carried.at.y
        visible: carried.shown
        function report(): void {
            if (!carried.shown || carried.slot.length === 0) return
            root.publishCentre(carried.slot, carried.at.x, carried.at.y)
        }
        onAtChanged: carried.report()
        onShownChanged: carried.report()
        readonly property real absorb: landing.running && root.plateAt(root.placeName(carried.slot)) !== null
            ? root.absorbOf(carried.slot) : 0
        width: root.size
        height: root.size
        x: carried.at.x - width / 2
        y: carried.at.y - height / 2
        z: 10
        scale: landing.running ? 1.12 + (landing.endScale - 1.12) * carried.travel : 1.12

        IrisBubbleFace {
            anchors.fill: parent
            bodyless: true
            screenName: root.screenName
            absorb: carried.absorb
            kind: landing.running ? landing.kind : String(root.drag?.kind ?? "")
            appId: IrisPieces.isApp(carried.slot) ? IrisPieces.appIdOf(carried.slot) : ""
        }
    }
    Rectangle {
        visible: root.carryingIsland && !(root.drag?.released ?? false)
        width: Math.round(root.drag?.width ?? 160 * root.d)
        height: Math.round(root.size)
        x: (root.drag?.x ?? 0) - width / 2
        y: (root.drag?.y ?? 0) - height / 2
        radius: height / 2
        color: IrisStyle.bodySurface
        opacity: 0.9
        scale: 1.04
    }
    readonly property var cardRequest: GlobalStates.irisBubbleCard
        && (GlobalStates.irisBubbleCard.screen ?? root.screenName) === root.screenName
        ? GlobalStates.irisBubbleCard : null
    property var cardAnchor: null
    onCardRequestChanged: if (root.cardRequest) root.cardAnchor = root.cardRequest
    readonly property string cardKind: String(root.cardAnchor?.kind ?? "")
    readonly property string cardSource: String(root.cardAnchor?.source ?? "")
    readonly property bool cardOpen: root.cardRequest !== null && root.cardKind.length > 0
    readonly property bool cardPresent: root.cardOpen || card.progress > 0
    readonly property bool cardKept: root.cardKind === "media"
        && (Config.options?.iris?.player?.cardPinned ?? false)
    readonly property bool cardArmed: root.cardOpen && card.armed && !root.cardKept
    function closeCard(): void { GlobalStates.irisBubbleCard = null }

    readonly property bool mediaKept: (Config.options?.iris?.player?.cardPinned ?? false)
        && MprisController.activePlayer !== null
        && root.screenName === (GlobalStates.focusedScreen?.name ?? "")
    function syncKeptCard(): void {
        const index = root.allSlots.findIndex((slot, i) => root.rects[i] !== null && root.kindOf(slot) === "media")
        if (root.mediaKept) {
            if (index >= 0 && GlobalStates.irisBubbleCard?.kind !== "media")
                root.toggleCard(root.allSlots[index], "media", root.rects[index])
        } else if (GlobalStates.irisBubbleCard?.kind === "media") {
            GlobalStates.irisBubbleCard = null
        }
    }
    onMediaKeptChanged: Qt.callLater(root.syncKeptCard)

    readonly property real cardPad: IrisStyle.cardPad
    readonly property bool cardFloats: root.cardSource.startsWith("float-")
    readonly property string islandEdge: IrisFrame.islandEdge
    readonly property bool barBottom: root.islandEdge === "bottom"
    readonly property bool islandSide: root.islandEdge === "left" || root.islandEdge === "right"
    readonly property real cardAnchorCX: (root.cardAnchor?.x ?? 0) + (root.cardAnchor?.width ?? 0) / 2
    readonly property real cardAnchorCY: (root.cardAnchor?.y ?? 0) + (root.cardAnchor?.height ?? 0) / 2
    function clampX(x: real): real {
        return Math.max(root.edgeClear("left"), Math.min(root.width - card.width - root.edgeClear("right"), x))
    }
    readonly property bool cardHangs: root.cardSource === "island-chassis"
    readonly property bool cardFromIslandPiece: root.cardSource.startsWith("island-piece-")
    readonly property real cardBandTop: root.cardAnchor?.bandY ?? root.cardAnchor?.y ?? 0
    readonly property real cardBandHeight: root.cardAnchor?.bandHeight ?? root.cardAnchor?.height ?? 0
    readonly property real cardEdge: Math.round(8 * root.d) + IrisFrame.band
    // How far a card stands off the piece it grew from. 0 keeps them welded.
    readonly property real cardGap: IrisStyle.cardGap
    readonly property bool cardFromSatellite: root.cardSource.startsWith("island-") && !root.cardHangs && !root.cardFromIslandPiece
    readonly property var cardOrigin: {
        const a = root.cardAnchor
        if (a && root.cardFromIslandPiece && a.bandY !== undefined)
            return Object.assign({}, a, { obstacle: root.islandSide
                ? { x: a.bandX ?? a.x, y: a.y, width: a.bandWidth ?? a.width, height: a.height }
                : { x: a.x, y: a.bandY, width: a.width, height: a.bandHeight } })
        const g = root.island
        if (a && root.cardFromSatellite && g && g.width > 0) {
            const x = Math.min(a.x, g.x)
            const y = Math.min(a.y, g.y)
            return Object.assign({}, a, { obstacle: { x: x, y: y,
                width: Math.max(a.x + a.width, g.x + g.width) - x, height: Math.max(a.y + a.height, g.y + g.height) - y } })
        }
        const plate = a && root.cardNest && root.cardNest.rect !== undefined && root.plateFor(root.cardSource.slice(6))
        if (plate) return Object.assign({}, a, { obstacle: { x: plate.x, y: plate.y, width: plate.width, height: plate.height } })
        return a
    }
    readonly property var cardAvoidRects: {
        const out = []
        const openerSlot = root.cardFloats ? root.cardSource.slice(6) : ""
        const openerZone = openerSlot.length > 0 ? root.placeName(openerSlot) : ""
        for (const plate of root.plates)
            if (plate.zone !== openerZone) out.push({ x: plate.x, y: plate.y, width: plate.width, height: plate.height })
        for (let i = 0; i < root.allSlots.length; i++) {
            const rect = root.rects[i]
            if (rect && root.allSlots[i] !== openerSlot)
                out.push({ x: rect.x, y: rect.y, width: rect.size, height: rect.size })
        }
        const island = root.island
        if (island && island.width > 0 && island.height > 0)
            out.push({ x: island.x, y: island.y, width: island.width, height: island.height })
        const dock = GlobalStates.irisDockBody?.[root.screenName] ?? []
        for (const shape of (Array.isArray(dock) ? dock : []))
            if (shape?.id === "dock") out.push({ x: shape.x, y: shape.y, width: shape.width, height: shape.height })
        const sidebars = Config.options?.iris?.sidebars ?? ({})
        if (GlobalStates.sidebarLeftOpen && GlobalStates.sidebarLeftPresentationOutput === root.screenName) {
            const o = sidebars?.left ?? ({})
            const width = Math.max(300, Math.min(600, Number(o?.width ?? 380))) * root.d
            out.push({ x: 0, y: 0, width: IrisFrame.band + width + ((o?.notch ?? false) ? 0 : 12 * root.d), height: root.height })
        }
        if (GlobalStates.sidebarRightOpen && GlobalStates.sidebarRightPresentationOutput === root.screenName) {
            const o = sidebars?.right ?? ({})
            const width = Math.max(300, Math.min(600, Number(o?.width ?? 380))) * root.d
            const depth = IrisFrame.band + width + ((o?.notch ?? false) ? 0 : 12 * root.d)
            out.push({ x: root.width - depth, y: 0, width: depth, height: root.height })
        }
        return out
    }
    readonly property real cardBaseRadius: IrisStyle.surfaceRadius("cards", IrisStyle.radiusSheet)
    readonly property var cardNest: {
        const slot = root.cardFloats ? root.cardSource.slice(6) : ""
        if (slot.length === 0) return null
        const plate = root.plateFor(slot)
        if (plate) return { rect: plate, side: plate.side ?? IrisFrame.edgeOf(plate.zone) }
        const rect = root.rects[root.allSlots.indexOf(slot)]
        return rect ? { rect: { x: rect.x, y: rect.y, width: rect.size, height: rect.size }, side: IrisFrame.edgeOf(root.placeName(slot)) } : null
    }
    readonly property real cardRadius: root.cardPlacement && !IrisStyle.cardJoins
        ? IrisFrame.nestRadius({ x: root.cardPlacement.x, y: root.cardPlacement.y, width: card.width, height: card.height },
            root.cardBaseRadius, root.cardNest?.rect ?? null, root.edgeFuseOn(root.cardNest?.side ?? ""), root.width, root.height)
        : root.cardBaseRadius
    readonly property var cardPlacement: root.cardAnchor && !root.cardHangs
        ? IrisFrame.place(root.cardOrigin, card.width, card.height, root.width, root.height, root.cardBaseRadius,
            root.cardAvoidRects, !root.cardFromSatellite && IrisStyle.cardJoins
                ? -IrisStyle.weld : Math.max(IrisFrame.bodyAir, IrisStyle.cardGap)) : null
    readonly property string cardOriginId: {
        if (root.cardHangs || root.cardFromIslandPiece) return "island"
        if (root.cardSource.startsWith("island-")) return "satellite:" + root.cardSource.slice(7)
        if (root.cardSource.startsWith("dock-")) return "dock"
        const slot = root.cardFloats ? root.cardSource.slice(6) : ""
        if (slot.length === 0) return ""
        return root.plateFor(slot) ? "plate:" + root.plateKey(slot) : "piece:" + slot
    }
    function edgeClear(edge: string): real { return Math.round(8 * root.d) + IrisFrame.safeClear(edge) }

    MouseArea {
        anchors.fill: parent
        enabled: root.cardArmed
        onClicked: root.closeCard()
    }
    Shortcut { sequence: "Escape"; enabled: root.cardOpen; onActivated: root.closeCard() }

    RectangularShadow {
        readonly property var body: card.bodyRect
        x: body?.x ?? 0
        y: (body?.y ?? 0) + 6 * root.d
        width: body?.width ?? 0
        height: body?.height ?? 0
        radius: body?.radius ?? card.radius
        blur: 28 * root.d
        spread: -4 * root.d
        color: IrisStyle.shadow
        opacity: IrisStyle.shadowAt(card.progress)
    }

    IrisMorphSurface {
        id: card
        open: root.cardOpen
        motionSurface: "cards"
        settles: true
        color: IrisStyle.bodySurface
        fieldBacked: true
        contentReady: cardContent.contentHeight > 0
        radius: root.cardRadius
        origin: root.cardAnchor
        light: IrisStyle.surfaceLight("cards", cardContent.light)
        lightFrom: !root.cardAnchor ? "top"
            : root.cardHangs ? root.islandEdge
            : root.cardPlacement?.sideways ? (root.cardPlacement.towardsLeft ? "right" : "left")
            : root.cardPlacement?.towardsUp ? "bottom" : "top"
        width: Math.min(root.width - 16, IrisStyle.surfaceWidth("cards", Math.round(360 * root.d)))
        height: Math.round(Math.min(root.height * 0.72, cardContent.contentHeight + (cardContent.bleeds ? 0 : root.cardPad * 2)))
        x: !root.cardAnchor ? (root.width - width) / 2
            : root.cardHangs && root.islandSide ? (root.islandEdge === "left"
                ? (root.cardAnchor?.bandX ?? 0) + (root.cardAnchor?.bandWidth ?? 0) - IrisStyle.weld + root.cardGap
                : (root.cardAnchor?.bandX ?? root.width) - width + IrisStyle.weld - root.cardGap)
            : root.cardHangs ? root.clampX(root.cardAnchorCX - width / 2)
            : root.cardPlacement?.x ?? 0
        y: !root.cardAnchor ? root.cardEdge
            : !root.cardHangs ? root.cardPlacement?.y ?? 0
            : root.islandSide ? Math.max(root.edgeClear("top"), Math.min(root.height - height - root.edgeClear("bottom"), root.cardAnchorCY - height / 2))
            : root.barBottom ? Math.max(root.edgeClear("top"), root.cardBandTop - height + IrisStyle.weld - root.cardGap)
            : Math.min(root.height - height - root.edgeClear("bottom"), root.cardBandTop + root.cardBandHeight - IrisStyle.weld + root.cardGap)
        Behavior on height {
            enabled: card.settled
            NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve }
        }

        MouseArea { anchors.fill: parent }

        // A handle on the edge the card grew from: the one thing on a card that says
        // it can be put away. Hidden while the resize grip owns that edge.
        Rectangle {
            id: cardGrabber
            readonly property bool sideways: root.cardPlacement?.sideways ?? root.islandSide
            visible: IrisStyle.cardGrabber && !GlobalStates.irisEdit && card.progress > 0.6
            opacity: grabberHover.hovered ? 1 : 0.55
            Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
            width: cardGrabber.sideways ? Math.max(2, Math.round(3 * root.d)) : Math.round(34 * root.d)
            height: cardGrabber.sideways ? Math.round(34 * root.d) : Math.max(2, Math.round(3 * root.d))
            radius: Math.min(width, height) / 2
            color: IrisStyle.textTertiary
            x: cardGrabber.sideways
                ? (root.cardAnchorCX > card.x + card.width / 2 ? card.width - width - Math.round(7 * root.d) : Math.round(7 * root.d))
                : Math.round((card.width - width) / 2)
            y: cardGrabber.sideways
                ? Math.round((card.height - height) / 2)
                : (root.barBottom ? card.height - height - Math.round(7 * root.d) : Math.round(7 * root.d))
            HoverHandler { id: grabberHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: GlobalStates.irisBubbleCard = null }
        }

        Item {
            id: cardResize
            z: 30
            visible: GlobalStates.irisEdit && root.cardOpen
            readonly property bool fromLeft: card.x + card.width / 2 > root.width / 2
            width: Math.round(14 * root.d)
            height: Math.round(48 * root.d)
            x: cardResize.fromLeft ? 0 : parent.width - width
            y: Math.round((parent.height - height) / 2)
            Rectangle {
                anchors.centerIn: parent
                width: Math.max(2, Math.round(3 * root.d))
                height: Math.round(26 * root.d)
                radius: width / 2
                color: cardResizeHover.hovered || cardResizeDrag.active ? IrisStyle.accent : IrisStyle.textTertiary
            }
            HoverHandler { id: cardResizeHover; cursorShape: Qt.SizeHorCursor }
            DragHandler {
                id: cardResizeDrag
                target: null
                yAxis.enabled: false
                property real startWidth: 360
                property IrisConfigDrag write: IrisConfigDrag { path: "iris.appearance.surfaces.cards.width" }
                onActiveChanged: {
                    if (!active) { cardResizeDrag.write.flush(); return }
                    const configured = Number(Config.options?.iris?.appearance?.surfaces?.cards?.width ?? 0)
                    cardResizeDrag.startWidth = configured > 0 ? configured : card.width / Math.max(0.01, root.d)
                }
                onTranslationChanged: {
                    if (!active) return
                    const direction = cardResize.fromLeft ? -1 : 1
                    const raw = cardResizeDrag.startWidth + direction * translation.x / Math.max(0.01, root.d)
                    const width = Math.round(Math.max(280, Math.min(560, raw)) / 10) * 10
                    cardResizeDrag.write.push(width)
                }
            }
        }

        ClippingRectangle {
            anchors.fill: parent
            radius: card.radius
            color: "transparent"

            Flickable {
                id: cardScroller
                readonly property bool moreAbove: cardScroller.contentY > 1
                readonly property bool moreBelow: cardScroller.contentY + cardScroller.height < cardScroller.contentHeight - 1
                anchors.fill: parent
                anchors.margins: cardContent.bleeds ? 0 : root.cardPad
                contentHeight: cardContent.contentHeight
                boundsBehavior: Flickable.StopAtBounds
                interactive: cardScroller.contentHeight > cardScroller.height + 1
                clip: !cardContent.bleeds

                IrisCardContent {
                    id: cardContent
                    width: cardScroller.width
                    kind: root.cardKind
                    screenName: root.screenName
                    contentActive: root.cardPresent
                    onNavigate: root.closeCard()
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: Math.round(22 * root.d)
                opacity: cardContent.bleeds && cardScroller.moreAbove ? 1 : 0
                visible: opacity > 0
                gradient: Gradient {
                    GradientStop { position: 0; color: IrisStyle.bodyScrim }
                    GradientStop { position: 1; color: ColorUtils.applyAlpha(IrisStyle.bodyScrim, 0) }
                }
                Behavior on opacity { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
            }
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: Math.round(34 * root.d)
                opacity: cardContent.bleeds && cardScroller.moreBelow ? 1 : 0
                visible: opacity > 0
                gradient: Gradient {
                    GradientStop { position: 0; color: ColorUtils.applyAlpha(IrisStyle.bodyScrim, 0) }
                    GradientStop { position: 1; color: IrisStyle.bodyScrim }
                }
                Behavior on opacity { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
            }
        }

    }
}
