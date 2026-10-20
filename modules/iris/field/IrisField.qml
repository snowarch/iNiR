pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.iris.style
import qs.modules.iris.frame

Item {
    id: root

    property var shapes: []
    property color tint: IrisStyle.bodySurface
    property color rim: IrisStyle.rim
    property real rimWidth: IrisStyle.edgeWidth
    property color sheen: IrisStyle.glassEdgeColour
    property real smoothing: IrisStyle.fuse
    property bool framed: IrisFrame.framed
    property real band: IrisFrame.band
    property real cornerRadius: IrisFrame.cornerRadius
    readonly property int capacity: 20
    // The bodies' shadow is drawn by the pass itself, from the joined silhouette (IrisField.frag `shade`).
    readonly property real shadowFall: Math.round(3 * IrisStyle.density)
    readonly property real shadowBlur: Math.round(16 * IrisStyle.density)
    readonly property bool casts: IrisStyle.shadow.a > 0.004
    readonly property real reach: root.smoothing + 2 + IrisStyle.afterglowReach + IrisStyle.leakReach
        + (root.casts ? root.shadowFall + 1.5 * root.shadowBlur : 0)
    property bool compositorAllowed: false
    // A field that does not cover its output: its window's position on the output and the output's size.
    property point sceneOrigin: Qt.point(0, 0)
    property size sceneSize: Qt.size(0, 0)
    readonly property int glassCode: IrisStyle.glassCompositor ? (root.compositorAllowed ? 2 : 1) : IrisStyle.glassWallpaper ? 1 : 0
    // The music frame stays the compositor's glass: what the swell adds is blurred by strips below the chassis
    // (IrisWaveBlur), so the moving band is one material with the resting one.
    property int frameGlass: root.glassCode
    property vector4d edgeWave: Qt.vector4d(0, 0, 0, 0)
    property real waveClock: 0
    property real frameMusicLevel: 0
    property int frameMusicAppearance: IrisFrame.musicAppearanceCode
    property color frameMusicInk: IrisFrame.musicInk
    property real frameMusicLight: IrisFrame.musicLight
    property real frameMusicLightWidth: IrisFrame.musicLightWidth
    // One matter (2026-10-15, the maintainer: the Dock on the frame "se ve separado del frame" once it is glass): a
    // body welded to the frame, directly or through the bodies it hangs from, is the frame's material wherever it is
    // joined; its own material is for when it floats. A glass body on a solid band read as two things fitted together.
    function glassOf(shape: var, depth: int): int {
        if (!shape) return 0
        if (root.framed && root.weldedToFrame(shape, depth ?? 0)) return root.frameGlass
        return root.ownGlass(shape)
    }
    // A chamfered Design cuts a body welded to the frame on the two corners it shows (IrisField.frag cutsCorner): the
    // Design's own pair (upper-right, lower-left) left one shoulder square and one cut. IrisBlurRegion.cutMaskOf mirrors it.
    function cutMask(s: var): int {
        const list = !s.joins ? [] : Array.isArray(s.joins) ? s.joins : [s.joins]
        if (!root.framed || !list.includes("frame")) return 0
        const reach = IrisFrame.band + 2
        if (s.y + s.height >= root.height - reach) return -1
        if (s.y <= reach) return -2
        if (s.x + s.width >= root.width - reach) return -3
        if (s.x <= reach) return -4
        return 0
    }
    function weldedToFrame(shape: var, depth: int): bool {
        const list = !shape.joins ? [] : Array.isArray(shape.joins) ? shape.joins : [shape.joins]
        if (list.includes("frame")) return true
        if (depth >= 4) return false
        const all = root.shapes ?? []
        return list.some(name => { const other = all.find(candidate => candidate?.id === name); return other ? root.weldedToFrame(other, depth + 1) : false })
    }
    function ownGlass(shape: var): int {
        const g = shape.glass
        if (g === undefined || g === null || g === "inherit") return root.glassCode
        if (g === "compositor") return Appearance.compositorBlurActive && root.compositorAllowed ? 2 : 1
        if (g === "wallpaper" || g === true) return 1
        return 0
    }
    // The window's chassis field lends its backdrop to every other field and pane in that window.
    property bool providesBackdrop: false
    readonly property bool wantsBackdrop: root.visible && ((root.framed && root.frameGlass === 1)
        || (root.shapes ?? []).some(shape => root.glassOf(shape) === 1))
    readonly property Item windowHost: root.QsWindow.contentItem ?? null
    readonly property Item sharedBackdrop: root.wantsBackdrop && !root.providesBackdrop
        ? IrisGlassBackdrops.find(root.windowHost, null) : null
    readonly property Item backdropSource: root.sharedBackdrop ?? backdropLoader.item

    Loader {
        id: backdropLoader
        active: (root.providesBackdrop && root.visible && root.glassCode === 1)
            || (root.wantsBackdrop && !root.sharedBackdrop)
        sourceComponent: IrisGlassSource {
            screen: root.QsWindow.window?.screen ?? null
        }
        onItemChanged: {
            if (!root.providesBackdrop) return
            if (backdropLoader.item) IrisGlassBackdrops.register(root.windowHost, backdropLoader.item)
            else IrisGlassBackdrops.unregister(root._lent)
            root._lent = backdropLoader.item
        }
    }
    property Item _lent: null
    Component.onDestruction: if (root._lent) IrisGlassBackdrops.unregister(root._lent)

    Item {
        id: noBackdrop
        visible: false
        width: 1
        height: 1
        layer.enabled: true
    }

    // The frame's interior that no band, wave, frame light or body (with its fillet) reaches. The
    // chassis field covers the whole output, so while music moves the band every frame this is most
    // of the screen skipping the shader.
    readonly property vector4d quietRect: {
        if (!root.framed) return Qt.vector4d(0, 0, 0, 0)
        const wave = Math.max(root.edgeWave.x, root.edgeWave.y, root.edgeWave.z, root.edgeWave.w, 0)
        const edge = root.band + wave + root.frameMusicLightWidth + root.reach + 16
        let left = edge, top = edge, right = root.width - edge, bottom = root.height - edge
        const margin = root.reach + 32
        for (const s of root.shapes ?? []) {
            const x0 = s.x - margin, y0 = s.y - margin
            const x1 = s.x + s.width + margin, y1 = s.y + s.height + margin
            if (x1 <= left || x0 >= right || y1 <= top || y0 >= bottom) continue
            const keep = [
                { area: (right - x1) * (bottom - top), l: x1, t: top, r: right, b: bottom },
                { area: (x0 - left) * (bottom - top), l: left, t: top, r: x0, b: bottom },
                { area: (right - left) * (bottom - y1), l: left, t: y1, r: right, b: bottom },
                { area: (right - left) * (y0 - top), l: left, t: top, r: right, b: y0 }
            ].reduce((best, c) => c.area > best.area ? c : best)
            left = keep.l; top = keep.t; right = keep.r; bottom = keep.b
        }
        if (right - left < 64 || bottom - top < 64) return Qt.vector4d(0, 0, 0, 0)
        return Qt.vector4d(left, top, right, bottom)
    }

    readonly property rect bounds: {
        if (root.framed) return Qt.rect(0, 0, root.width, root.height)
        const list = root.shapes ?? []
        if (list.length === 0) return Qt.rect(0, 0, 0, 0)
        let left = Infinity;
        let top = Infinity;
        let right = -Infinity;
        let bottom = -Infinity;
        for (const s of list) {
            left = Math.min(left, s.x - root.reach)
            top = Math.min(top, s.y - root.reach)
            right = Math.max(right, s.x + s.width + root.reach)
            bottom = Math.max(bottom, s.y + s.height + root.reach)
        }
        const x = Math.max(0, Math.floor(left));
        const y = Math.max(0, Math.floor(top))
        return Qt.rect(x, y, Math.ceil(Math.min(root.width, right)) - x,
            Math.ceil(Math.min(root.height, bottom)) - y)
    }

    ShaderEffect {
        id: pass
        visible: root.bounds.width > 0 && root.bounds.height > 0
        x: root.bounds.x
        y: root.bounds.y
        width: root.bounds.width
        height: root.bounds.height
        fragmentShader: Qt.resolvedUrl("IrisField.frag.qsb")
        blending: true

        // Every per-body uniform in one pass over the table. A moving body rewrites `shapes` every frame, and as ~55
        // bindings (one per uniform, each with its own closures and lookups) that pass cost several times the work.
        readonly property var packed: {
            const list = root.shapes ?? []
            const n = Math.min(list.length, root.capacity)
            const chamfer = IrisStyle.fieldChamfer
            const zero = Qt.vector4d(0, 0, 0, 0)
            const index = {}
            for (let i = 0; i < n; i++)
                if (list[i]?.id) index[list[i].id] = i
            const geometry = [], radius = [], fuse = [], join = [], also = [], paints = [], glass = []
            const slot = (s, which) => {
                const names = !s || !s.joins ? [] : Array.isArray(s.joins) ? s.joins : [s.joins]
                const name = names[which]
                if (!name) return 0
                if (name === "frame") return root.framed ? -1 : 0
                const at = index[name]
                return at === undefined ? 0 : at + 1
            }
            for (let i = 0; i < root.capacity; i++) {
                const s = list[i]
                geometry.push(s ? Qt.vector4d(s.x + s.width / 2, s.y + s.height / 2, s.width / 2, s.height / 2) : zero)
                radius.push(!s ? 0 : chamfer ? root.cutMask(s) : Number(s.radius ?? 0))
                fuse.push(s ? Number(s.fuse ?? root.smoothing) : 0)
                join.push(slot(s, 0))
                also.push(slot(s, 1))
                paints.push(s && s.paints ? 1 : 0)
                glass.push(root.glassOf(s))
            }
            const blocks = values => {
                const out = []
                for (let b = 0; b < root.capacity / 4; b++)
                    out.push(Qt.vector4d(values[b * 4], values[b * 4 + 1], values[b * 4 + 2], values[b * 4 + 3]))
                return out
            }
            return { geometry: geometry, radius: blocks(radius), fuse: blocks(fuse), join: blocks(join), also: blocks(also),
                paints: blocks(paints), glass: blocks(glass) }
        }
        readonly property vector4d viewport: Qt.vector4d(pass.x, pass.y,
            Math.max(1, pass.width), Math.max(1, pass.height))
        readonly property vector2d screen: Qt.vector2d(Math.max(1, root.width), Math.max(1, root.height))
        readonly property vector4d scene: Qt.vector4d(root.sceneOrigin.x, root.sceneOrigin.y,
            root.sceneSize.width > 0 ? root.sceneSize.width : Math.max(1, root.width),
            root.sceneSize.height > 0 ? root.sceneSize.height : Math.max(1, root.height))
        readonly property vector4d field: Qt.vector4d(root.smoothing, root.framed ? 1 : 0,
            root.band, root.cornerRadius)
        readonly property color tint: root.tint
        readonly property vector4d options: Qt.vector4d(0, IrisStyle.fieldChamfer ? 1 : 0, IrisStyle.chamferCut, 0)
        readonly property vector4d quiet: root.quietRect
        readonly property color rim: root.rim
        readonly property color sheen: root.sheen
        readonly property vector4d edgeGlass: IrisStyle.afterglow ? Qt.vector4d(0, 0, 1, 0)
            : Qt.vector4d(IrisStyle.glassEdgeLight, IrisStyle.glassEdgeLine, IrisStyle.edgeWidth, IrisStyle.edgeLit ? 1 : 0)
        // z: one device pixel in the field's units; both edges are drawn that many pixels wide.
        readonly property vector4d edge: Qt.vector4d(root.rimWidth, root.rim.a > 0 ? 1 : 0, IrisStyle.devicePx, 0)
        readonly property vector4d glowMix: IrisStyle.afterglowMix
        readonly property vector4d glowShadow: IrisStyle.afterglowShadow
        readonly property vector4d glowLight: IrisStyle.afterglowLight
        readonly property vector4d glowBloom: IrisStyle.afterglowBloomInk
        readonly property vector4d glowShape: IrisStyle.afterglowShape
        readonly property vector4d leakMix: IrisStyle.leakMix
        readonly property vector4d leakGrain: IrisStyle.leakFilm
        readonly property vector4d leakShape: IrisStyle.leakBody
        readonly property vector4d leakStop0: IrisStyle.leakStop0
        readonly property vector4d leakStop1: IrisStyle.leakStop1
        readonly property vector4d leakStop2: IrisStyle.leakStop2
        readonly property vector4d leakStop3: IrisStyle.leakStop3
        readonly property vector4d leakStop4: IrisStyle.leakStop4
        readonly property vector4d leakCore: IrisStyle.leakCore
        readonly property vector4d leakAt0: IrisStyle.leakAt0
        readonly property vector4d leakAt1: IrisStyle.leakAt1
        readonly property vector4d leakAt2: IrisStyle.leakAt2
        readonly property vector4d leakForm0: IrisStyle.leakForm0
        readonly property vector4d leakForm1: IrisStyle.leakForm1
        readonly property vector4d leakForm2: IrisStyle.leakForm2
        readonly property vector4d leakHue0: IrisStyle.leakHue0
        readonly property vector4d leakHue1: IrisStyle.leakHue1
        readonly property vector4d leakHue2: IrisStyle.leakHue2
        readonly property vector4d shape0: pass.packed.geometry[0]
        readonly property vector4d shape1: pass.packed.geometry[1]
        readonly property vector4d shape2: pass.packed.geometry[2]
        readonly property vector4d shape3: pass.packed.geometry[3]
        readonly property vector4d shape4: pass.packed.geometry[4]
        readonly property vector4d shape5: pass.packed.geometry[5]
        readonly property vector4d shape6: pass.packed.geometry[6]
        readonly property vector4d shape7: pass.packed.geometry[7]
        readonly property vector4d shape8: pass.packed.geometry[8]
        readonly property vector4d shape9: pass.packed.geometry[9]
        readonly property vector4d shape10: pass.packed.geometry[10]
        readonly property vector4d shape11: pass.packed.geometry[11]
        readonly property vector4d shape12: pass.packed.geometry[12]
        readonly property vector4d shape13: pass.packed.geometry[13]
        readonly property vector4d shape14: pass.packed.geometry[14]
        readonly property vector4d shape15: pass.packed.geometry[15]
        readonly property vector4d shape16: pass.packed.geometry[16]
        readonly property vector4d shape17: pass.packed.geometry[17]
        readonly property vector4d shape18: pass.packed.geometry[18]
        readonly property vector4d shape19: pass.packed.geometry[19]
        readonly property vector4d radiiA: pass.packed.radius[0]
        readonly property vector4d radiiB: pass.packed.radius[1]
        readonly property vector4d radiiC: pass.packed.radius[2]
        readonly property vector4d radiiD: pass.packed.radius[3]
        readonly property vector4d radiiE: pass.packed.radius[4]
        readonly property vector4d fuseA: pass.packed.fuse[0]
        readonly property vector4d fuseB: pass.packed.fuse[1]
        readonly property vector4d fuseC: pass.packed.fuse[2]
        readonly property vector4d fuseD: pass.packed.fuse[3]
        readonly property vector4d fuseE: pass.packed.fuse[4]
        readonly property vector4d joinA: pass.packed.join[0]
        readonly property vector4d alsoA: pass.packed.also[0]
        readonly property vector4d joinB: pass.packed.join[1]
        readonly property vector4d alsoB: pass.packed.also[1]
        readonly property vector4d joinC: pass.packed.join[2]
        readonly property vector4d alsoC: pass.packed.also[2]
        readonly property vector4d joinD: pass.packed.join[3]
        readonly property vector4d alsoD: pass.packed.also[3]
        readonly property vector4d joinE: pass.packed.join[4]
        readonly property vector4d alsoE: pass.packed.also[4]
        readonly property vector4d paintsA: pass.packed.paints[0]
        readonly property vector4d paintsB: pass.packed.paints[1]
        readonly property vector4d paintsC: pass.packed.paints[2]
        readonly property vector4d paintsD: pass.packed.paints[3]
        readonly property vector4d paintsE: pass.packed.paints[4]
        readonly property vector4d glassA: pass.packed.glass[0]
        readonly property vector4d glassB: pass.packed.glass[1]
        readonly property vector4d glassC: pass.packed.glass[2]
        readonly property vector4d glassD: pass.packed.glass[3]
        readonly property vector4d glassE: pass.packed.glass[4]
        readonly property bool backdropReady: root.backdropSource?.ready ?? false
        readonly property vector4d glass: Qt.vector4d(pass.backdropReady ? 1 : 0, root.framed ? root.frameGlass : 0,
            IrisStyle.glassTint, IrisStyle.glassLip)
        readonly property vector4d edgeWave: root.edgeWave
        readonly property vector4d waveClock: Qt.vector4d(root.waveClock, 0, 0, 0)
        readonly property vector4d frameLight: Qt.vector4d(root.frameMusicAppearance, root.frameMusicLevel,
            root.frameMusicLight, root.frameMusicLightWidth)
        readonly property color frameInk: root.frameMusicInk
        readonly property color shade: IrisStyle.shadow
        readonly property vector4d shadeShape: Qt.vector4d(root.shadowFall, root.shadowBlur, root.casts ? 1 : 0, 0)
        readonly property Item backdrop: pass.backdropReady ? root.backdropSource.texture : noBackdrop
    }
}
