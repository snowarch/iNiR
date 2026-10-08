pragma Singleton

import QtQuick
import qs.modules.common
import qs.modules.iris.style

QtObject {
    id: root

    readonly property var bar: Config.options?.iris?.bar ?? ({})
    readonly property var dock: Config.options?.iris?.dock ?? ({})
    readonly property var surround: Config.options?.iris?.surround ?? ({})
    readonly property real d: IrisStyle.density

    // Bodies of Places that meet the frame, keyed by owner ({ screen, shapes }): the chassis of that
    // output draws them in its field, so the join, the shadow and the compositor blur are the frame's own.
    property var placeBodies: ({})
    function publishPlace(key: string, screen: string, shapes: var): void {
        if (!key) return
        if (shapes.length === 0 && !root.placeBodies[key]) return
        const next = Object.assign({}, root.placeBodies)
        if (shapes.length > 0 && screen) next[key] = { screen: screen, shapes: shapes }
        else delete next[key]
        root.placeBodies = next
    }
    function placeShapesOn(screen: string): var {
        const out = []
        for (const key in root.placeBodies) {
            const entry = root.placeBodies[key]
            if (entry.screen === screen) for (const shape of entry.shapes) out.push(shape)
        }
        return out
    }
    readonly property bool musicActive: {
        Config.revision
        return root.framed && Boolean(Config.options?.background?.edgeWidgets?.organic?.enable ?? false)
            && String(root.surround?.music ?? "widget") === "frame"
    }
    function musicReach(edge: string): real {
        Config.revision
        if (!root.musicActive) return 0
        const mode = String(root.surround?.musicEdges ?? "sides")
        if (mode === "sides" && (edge === "top" || edge === "bottom")) return 0
        if (mode === "horizontal" && (edge === "left" || edge === "right")) return 0
        return 18 * root.d * Math.max(0.5, Math.min(3, Number(root.surround?.musicStrength ?? 160) / 100))
    }
    function safeInset(edge: string): real { return root.inset(edge) + root.musicReach(edge) }
    function safeClear(edge: string): real { return root.clear(edge) + root.musicReach(edge) }
    readonly property int musicAppearanceCode: ({ sculpted: 0, etched: 1, satin: 2 })[String(root.surround?.musicAppearance ?? "etched")] ?? 1
    readonly property color musicInk: {
        const colour = String(root.surround?.musicColour ?? "pearl")
        return colour === "accent" ? IrisStyle.accent
            : colour === "highlight" ? IrisStyle.secondaryAccent
            : colour === "wallpaper" ? IrisStyle.wallpaperLight : IrisStyle.text
    }
    readonly property real musicLight: Math.max(0, Math.min(1, Number(root.surround?.musicLight ?? 35) / 100))
    readonly property real musicLightWidth: Math.max(1, Math.min(18, Number(root.surround?.musicLightWidth ?? 5))) * root.d

    readonly property bool framed: Boolean(root.surround?.enable ?? false)
    readonly property real band: root.framed
        ? Math.max(1, Math.round(Number(root.surround?.thickness ?? 10) * root.d)) : 0
    readonly property real cornerRadius: root.framed
        ? Math.max(0, Math.round(Number(root.surround?.radius ?? 22) * root.d)) : 0

    readonly property var edges: ["top", "bottom", "left", "right"]
    function opposite(edge: string): string {
        return ({ top: "bottom", bottom: "top", left: "right", right: "left" })[edge] ?? "bottom"
    }
    function vertical(edge: string): bool { return edge === "left" || edge === "right" }
    readonly property string islandEdge: root.edges.includes(String(root.bar?.position ?? "top")) ? String(root.bar.position) : "top"
    readonly property string dockEdge: {
        const wanted = String(root.dock?.position ?? "auto")
        return root.edges.includes(wanted) && wanted !== root.islandEdge ? wanted : root.opposite(root.islandEdge)
    }
    readonly property string wantedIsland: String(root.bar?.position ?? "top")
    readonly property string wantedDock: String(root.dock?.position ?? "auto")
    property string settledIsland: ""
    property string settledDock: ""
    Component.onCompleted: { root.settledIsland = root.islandEdge; root.settledDock = root.dockEdge }
    onWantedIslandChanged: {
        if (root.edges.includes(root.wantedIsland) && root.wantedIsland === root.wantedDock
                && root.settledIsland.length > 0 && root.settledIsland !== root.wantedIsland)
            Config.setNestedValue("iris.dock.position", root.settledIsland)
        root.settle()
    }
    onWantedDockChanged: {
        if (root.edges.includes(root.wantedDock) && root.wantedDock === root.islandEdge
                && root.settledDock.length > 0 && root.settledDock !== root.wantedDock)
            Config.setNestedValue("iris.bar.position", root.settledDock)
        root.settle()
    }
    function settle(): void {
        Qt.callLater(() => { root.settledIsland = root.islandEdge; root.settledDock = root.dockEdge })
    }
    readonly property bool notch: Boolean(root.bar?.notch ?? false)
    readonly property real islandFullBand: Math.max(32, Math.round(Number(root.bar?.height ?? 42) * root.d))
    // A menu bar gives windows back all but its strip: the notch hangs over them.
    readonly property bool islandMenubar: String(root.bar?.layout ?? "island") === "menubar" && !root.vertical(root.islandEdge)
    readonly property real islandBand: root.islandMenubar
        ? Math.max(Math.round(24 * root.d), Math.round(root.islandFullBand * 0.72)) : root.islandFullBand
    readonly property real islandMargin: root.notch ? 0 : Math.max(0, Math.round(Number(root.bar?.margin ?? 8) * root.d))
    readonly property bool islandAutoHide: Boolean(root.bar?.autoHide ?? false)
    readonly property real islandVisualDepth: root.islandAutoHide ? 0 : root.islandBand + root.islandMargin
    readonly property real islandDepth: (root.bar?.reserveSpace ?? true) && !root.islandAutoHide
        ? root.islandVisualDepth : 0
    readonly property real dockIcon: Math.max(28, Math.min(64, Number(root.dock?.iconSize ?? 40))) * root.d
    readonly property real dockBand: root.dockIcon + 18 * root.d
    readonly property real dockMargin: Boolean(root.dock?.notch ?? false) ? 0 : 10 * root.d
    readonly property real dockVisualDepth: (root.dock?.enable ?? true) && !(root.dock?.autoHide ?? false)
        ? root.dockBand + root.dockMargin : 0
    readonly property real dockDepth: (root.dock?.enable ?? true)
        && (root.dock?.reserveSpace ?? true) && !(root.dock?.autoHide ?? false)
        ? root.dockVisualDepth : 0

    readonly property var bubbles: Config.options?.iris?.bubbles ?? ({})
    readonly property bool piecesAttached: root.bubbles?.attach ?? true
    readonly property bool piecesReserve: root.piecesAttached && (root.bubbles?.reserve ?? true)
    readonly property string pieceJoin: root.piecesAttached ? String(root.bubbles?.join ?? "notch") : "float"
    readonly property bool piecesMelt: root.pieceJoin === "notch" || root.pieceJoin === "weld"
    readonly property real pieceGap: root.pieceJoin === "gap" ? Math.max(root.islandMargin, Math.round(8 * root.d)) : 0
    readonly property real pieceInset: root.band + root.pieceGap
    readonly property real pieceScale: Math.max(0.6, Math.min(1.4, Number(root.bubbles?.scale ?? 100) / 100))
    readonly property real pieceBand: Math.round(root.islandBand * root.pieceScale)
    readonly property real pieceDepth: root.pieceGap + root.pieceBand
    // How pieces meet a given edge. On the Island's own edge they meet it the way the Island does: melted with it,
    // or floating at its margin when it floats (two grammars on one edge read as parts from different kits). A corner
    // plate takes its edge's join on both walls (IrisStage.zones): floating, it keeps that margin from the frame's side
    // too, never floating off one wall and welded to the other.
    readonly property bool islandSpans: String(root.bar?.layout ?? "island") === "full" || root.islandMenubar
    function joinOn(side: string): string {
        if (!root.piecesAttached) return "float"
        if (side === root.islandEdge && !root.notch && !root.islandSpans && root.pieceJoin !== "gap") return "gap"
        return root.pieceJoin
    }
    function meltsOn(side: string): bool { const join = root.joinOn(side); return join === "notch" || join === "weld" }
    function pieceGapOn(side: string): real {
        return root.joinOn(side) === "gap" ? Math.max(root.islandMargin, Math.round(Number(root.bar?.margin ?? 8) * root.d), Math.round(8 * root.d)) : 0
    }
    function pieceInsetOn(side: string): real { return root.band + root.pieceGapOn(side) }
    function pieceDepthOn(side: string): real { return root.pieceGapOn(side) + root.pieceBand }
    // An announcement is never switched on: like Material's bar indicator it shows whenever its state is there.
    readonly property var announcements: ["shellUpdate"]
    property var availableExtras: null
    function extraOn(extras: var, id: string): bool {
        return root.announcements.includes(id) || Boolean(extras?.[id]?.enable ?? false)
    }
    function edgeOf(place: string): string {
        if (place.startsWith("edge:")) return ["top", "bottom", "left", "right"].includes(place.slice(5)) ? place.slice(5) : ""
        if (place === "top-left" || place === "top-right") return "top"
        if (place === "bottom-left" || place === "bottom-right") return "bottom"
        if (place === "left" || place === "right") return place
        return ""
    }
    readonly property var pieceEdges: {
        const o = root.bubbles
        const edges = []
        const note = place => {
            const edge = root.edgeOf(String(place ?? ""))
            if (edge.length > 0 && !edges.includes(edge)) edges.push(edge)
        }
        for (const id of ["left", "right", "utility"]) note(o?.[id]?.place ?? "island")
        const extras = o?.extras ?? ({})
        // A piece that has nothing to show (no update, no player, an empty tray) is not on its edge: the edge
        // reserves nothing for it. IrisPieces feeds availableExtras (it imports this singleton, not the other way).
        for (const id of Object.keys(extras))
            if (root.extraOn(extras, id) && (root.availableExtras === null || root.availableExtras.includes(id))) note(extras[id]?.place)
        for (const app of (o?.apps ?? [])) if (app) note(app?.place)
        return edges
    }

    function clear(edge: string): real {
        let inner = 0
        if (edge === root.islandEdge) inner = Math.max(inner, root.islandVisualDepth)
        if (root.piecesAttached && root.pieceEdges.includes(edge))
            inner = Math.max(inner, root.pieceDepthOn(edge))
        if (edge === root.dockEdge) inner = Math.max(inner, root.dockVisualDepth)
        return Math.round(root.band + inner)
    }

    readonly property var theme: Config.options?.iris?.appearance?.theme ?? ({})
    readonly property real bodyAir: Math.round(Math.max(0, Math.min(40, Number(root.theme?.air ?? 8))) * root.d)
    readonly property real bodyMargin: Math.round(8 * root.d)
    readonly property string placementMode: String(root.theme?.placement ?? "auto")

    function place(origin: var, width: real, height: real, screenWidth: real, screenHeight: real, radius: real, avoid: var, air: real): var {
        if (!origin) return { sideways: false, towardsLeft: false, towardsUp: false, x: (screenWidth - width) / 2, y: (screenHeight - height) / 2 }
        const ob = origin.obstacle ?? origin
        const cx = origin.x + origin.width / 2
        const cy = origin.y + origin.height / 2
        let left = root.bodyMargin + root.band + root.musicReach("left")
        let right = screenWidth - width - root.bodyMargin - root.band - root.musicReach("right")
        let top = root.bodyMargin + root.band + root.musicReach("top")
        let bottom = screenHeight - height - root.bodyMargin - root.band - root.musicReach("bottom")
        for (const b of (avoid ?? [])) {
            if (!b || b.width <= 0 || b.height <= 0) continue
            const fullHeight = b.y <= root.bodyMargin + 1
                && b.y + b.height >= screenHeight - root.bodyMargin - 1
            if (fullHeight) {
                if (b.x + b.width <= screenWidth / 2) left = Math.max(left, b.x + b.width + root.bodyAir)
                else if (b.x >= screenWidth / 2) right = Math.min(right, b.x - width - root.bodyAir)
            }
            const fullWidth = b.x <= root.bodyMargin + 1
                && b.x + b.width >= screenWidth - root.bodyMargin - 1
            if (fullWidth) {
                if (b.y + b.height <= screenHeight / 2) top = Math.max(top, b.y + b.height + root.bodyAir)
                else if (b.y >= screenHeight / 2) bottom = Math.min(bottom, b.y - height - root.bodyAir)
            }
        }
        if (right < left) right = left
        if (bottom < top) bottom = top
        const nearSide = Math.min(cx, screenWidth - cx) < Math.min(cy, screenHeight - cy) - Math.min(origin.width, origin.height)
        const sideways = root.placementMode === "along" ? !nearSide : nearSide
        const towardsLeft = screenWidth - cx < cx
        const towardsUp = screenHeight - cy < cy
        const straight = Math.min(origin.width, origin.height) / 2 + radius
        const clamp = (value, low, high) => Math.max(low, Math.min(high, value))
        const along = (centre, size, low, high) => {
            const wanted = Math.max(low, Math.min(high, centre - size / 2))
            return Math.max(centre + straight - size, Math.min(centre - straight, wanted))
        }
        const candidate = side => {
            if (side) {
                const rawX = towardsLeft ? ob.x - width - air : ob.x + ob.width + air
                return { sideways: true, towardsLeft: towardsLeft, towardsUp: towardsUp,
                    x: clamp(rawX, left, right), y: clamp(along(cy, height, top, bottom), top, bottom) }
            }
            const rawY = towardsUp ? ob.y - height - air : ob.y + ob.height + air
            return { sideways: false, towardsLeft: towardsLeft, towardsUp: towardsUp,
                x: clamp(along(cx, width, left, right), left, right), y: clamp(rawY, top, bottom) }
        }
        const overlap = (a, b) => Math.max(0, Math.min(a.x + width, b.x + b.width) - Math.max(a.x, b.x))
            * Math.max(0, Math.min(a.y + height, b.y + b.height) - Math.max(a.y, b.y))
        const score = a => {
            let sum = 0
            for (const b of (avoid ?? [])) if (b && b.width > 0 && b.height > 0) sum += overlap(a, b)
            return sum
        }
        const primary = candidate(sideways)
        const alternate = candidate(!sideways)
        if (score(alternate) + 1 < score(primary)) return alternate
        if (primary.sideways) {
            return { sideways: true, towardsLeft: towardsLeft, towardsUp: towardsUp,
                x: primary.x, y: primary.y }
        }
        return { sideways: false, towardsLeft: towardsLeft, towardsUp: towardsUp,
            x: primary.x, y: primary.y }
    }

    // The fillet a body melted into a wall draws there: the field's polynomial smooth union of two perpendicular edges
    // bulges k/4 along the diagonal, which is a circular fillet of radius k / (4·(1 − 1/√2)).
    function filletRadius(fuse: real): real { return fuse / (4 * (1 - Math.SQRT1_2)) }
    function meltFuse(side: string, pieceSize: real): real {
        return root.joinOn(side) === "notch"
            ? IrisStyle.edgeFuseFor(pieceSize, Number(root.bubbles?.notchCurve ?? 100)) : IrisStyle.fuse
    }
    function nestRadius(rect: var, radius: real, origin: var, originFuse: real, screenWidth: real, screenHeight: real): real {
        if (!rect || rect.width <= 0 || rect.height <= 0) return radius
        const reach = Math.max(root.bodyAir, root.bodyMargin) + 2 * root.d
        const floor = Math.round(6 * root.d)
        const gap = { left: rect.x - root.band, right: screenWidth - root.band - rect.x - rect.width,
            top: rect.y - root.band, bottom: screenHeight - root.band - rect.y - rect.height }
        const o = origin?.obstacle ?? origin
        const touches = (r, wall) => r && (wall === "left" ? r.x - root.band
            : wall === "right" ? screenWidth - root.band - r.x - r.width
            : wall === "top" ? r.y - root.band : screenHeight - root.band - r.y - r.height) <= 1.5
        const nests = []
        for (const side of ["left", "right"]) {
            for (const end of ["top", "bottom"]) {
                if (gap[side] > reach) continue
                if (root.framed && gap[end] <= reach) {
                    nests.push(root.cornerRadius - (gap[side] + gap[end]) / 2)
                    continue
                }
                if (o && touches(o, side) && o.width > 0) {
                    const between = end === "top" ? rect.y - (o.y + o.height) : o.y - (rect.y + rect.height)
                    if (between >= -1 && between <= reach)
                        nests.push(root.filletRadius(originFuse) - (gap[side] + between) / 2)
                }
            }
        }
        for (const end of ["top", "bottom"]) {
            for (const side of ["left", "right"]) {
                if (gap[end] > reach || !o || !touches(o, end) || o.height <= 0) continue
                const between = side === "left" ? rect.x - (o.x + o.width) : o.x - (rect.x + rect.width)
                if (between >= -1 && between <= reach)
                    nests.push(root.filletRadius(originFuse) - (gap[end] + between) / 2)
            }
        }
        if (nests.length === 0) return radius
        // Or nothing: a corner much tighter than the body would square a sheet off to the floor; it keeps its own radius and floats.
        const nested = Math.min(...nests)
        if (nested < Math.max(floor * 2, radius * 0.4)) return radius
        return Math.round(Math.min(Math.min(rect.width, rect.height) / 2, nested))
    }

    function reserve(edge: string, chassisPresent: bool): real {
        let inner = 0
        if (chassisPresent && edge === root.islandEdge) inner = Math.max(inner, root.islandDepth)
        if (chassisPresent && root.piecesReserve && root.pieceEdges.includes(edge))
            inner = Math.max(inner, root.pieceDepthOn(edge))
        if (edge === root.dockEdge) inner = Math.max(inner, root.dockDepth)
        return Math.round(root.band + inner)
    }
    function inset(edge: string): real {
        let inner = 0
        if (edge === root.islandEdge) inner = Math.max(inner, root.islandVisualDepth)
        if (root.piecesAttached && root.pieceEdges.includes(edge))
            inner = Math.max(inner, root.pieceDepthOn(edge))
        if (edge === root.dockEdge) inner = Math.max(inner, root.dockVisualDepth)
        return Math.round(root.band + inner)
    }
}
