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
    property real rimWidth: IrisStyle.rimWidth
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
    function glassOf(shape: var): int {
        if (!shape) return 0
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

        function shapeAt(i: int): var {
            const s = root.shapes[i]
            return s ? Qt.vector4d(s.x + s.width / 2, s.y + s.height / 2, s.width / 2, s.height / 2)
                : Qt.vector4d(0, 0, 0, 0)
        }
        function radiusBlock(block: int): var {
            const r = i => {
                const s = root.shapes[block * 4 + i]
                return s ? Number(s.radius ?? 0) : 0
            }
            return Qt.vector4d(r(0), r(1), r(2), r(3))
        }
        function fuseBlock(block: int): var {
            const k = i => {
                const s = root.shapes[block * 4 + i]
                return s ? Number(s.fuse ?? root.smoothing) : 0
            }
            return Qt.vector4d(k(0), k(1), k(2), k(3))
        }
        readonly property var indexOf: {
            const map = {}
            const list = root.shapes ?? []
            for (let i = 0; i < Math.min(list.length, root.capacity); i++)
                if (list[i]?.id) map[list[i].id] = i
            return map
        }
        function joinBlock(block: int, which: int): var {
            const j = i => {
                const s = root.shapes[block * 4 + i]
                const list = !s || !s.joins ? [] : Array.isArray(s.joins) ? s.joins : [s.joins]
                const name = list[which]
                if (!name) return 0
                if (name === "frame") return root.framed ? -1 : 0
                const index = pass.indexOf[name]
                return index === undefined ? 0 : index + 1
            }
            return Qt.vector4d(j(0), j(1), j(2), j(3))
        }
        function paintsBlock(block: int): var {
            const f = i => {
                const s = root.shapes[block * 4 + i]
                return s && s.paints ? 1 : 0
            }
            return Qt.vector4d(f(0), f(1), f(2), f(3))
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
        readonly property vector4d options: Qt.vector4d(0, 0, 0, 0)
        readonly property vector4d quiet: root.quietRect
        readonly property color rim: root.rim
        readonly property color sheen: root.sheen
        readonly property vector4d edgeGlass: IrisStyle.afterglow ? Qt.vector4d(0, 0, 1, 0)
            : Qt.vector4d(IrisStyle.glassEdgeLight, IrisStyle.glassEdgeLine, Math.max(1, Math.round(IrisStyle.glassEdgeWidth * IrisStyle.density)), IrisStyle.edgeLit ? 1 : 0)
        readonly property vector4d edge: Qt.vector4d(root.rimWidth, root.rim.a > 0 ? 1 : 0, 0, 0)
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
        readonly property vector4d shape0: pass.shapeAt(0)
        readonly property vector4d shape1: pass.shapeAt(1)
        readonly property vector4d shape2: pass.shapeAt(2)
        readonly property vector4d shape3: pass.shapeAt(3)
        readonly property vector4d shape4: pass.shapeAt(4)
        readonly property vector4d shape5: pass.shapeAt(5)
        readonly property vector4d shape6: pass.shapeAt(6)
        readonly property vector4d shape7: pass.shapeAt(7)
        readonly property vector4d shape8: pass.shapeAt(8)
        readonly property vector4d shape9: pass.shapeAt(9)
        readonly property vector4d shape10: pass.shapeAt(10)
        readonly property vector4d shape11: pass.shapeAt(11)
        readonly property vector4d shape12: pass.shapeAt(12)
        readonly property vector4d shape13: pass.shapeAt(13)
        readonly property vector4d shape14: pass.shapeAt(14)
        readonly property vector4d shape15: pass.shapeAt(15)
        readonly property vector4d shape16: pass.shapeAt(16)
        readonly property vector4d shape17: pass.shapeAt(17)
        readonly property vector4d shape18: pass.shapeAt(18)
        readonly property vector4d shape19: pass.shapeAt(19)
        readonly property vector4d radiiA: pass.radiusBlock(0)
        readonly property vector4d radiiB: pass.radiusBlock(1)
        readonly property vector4d radiiC: pass.radiusBlock(2)
        readonly property vector4d radiiD: pass.radiusBlock(3)
        readonly property vector4d radiiE: pass.radiusBlock(4)
        readonly property vector4d fuseA: pass.fuseBlock(0)
        readonly property vector4d fuseB: pass.fuseBlock(1)
        readonly property vector4d fuseC: pass.fuseBlock(2)
        readonly property vector4d fuseD: pass.fuseBlock(3)
        readonly property vector4d fuseE: pass.fuseBlock(4)
        readonly property vector4d joinA: pass.joinBlock(0, 0)
        readonly property vector4d alsoA: pass.joinBlock(0, 1)
        readonly property vector4d joinB: pass.joinBlock(1, 0)
        readonly property vector4d alsoB: pass.joinBlock(1, 1)
        readonly property vector4d joinC: pass.joinBlock(2, 0)
        readonly property vector4d alsoC: pass.joinBlock(2, 1)
        readonly property vector4d joinD: pass.joinBlock(3, 0)
        readonly property vector4d alsoD: pass.joinBlock(3, 1)
        readonly property vector4d joinE: pass.joinBlock(4, 0)
        readonly property vector4d alsoE: pass.joinBlock(4, 1)
        readonly property vector4d paintsA: pass.paintsBlock(0)
        readonly property vector4d paintsB: pass.paintsBlock(1)
        readonly property vector4d paintsC: pass.paintsBlock(2)
        readonly property vector4d paintsD: pass.paintsBlock(3)
        readonly property vector4d paintsE: pass.paintsBlock(4)
        function glassBlock(block: int): var {
            const g = i => root.glassOf(root.shapes[block * 4 + i])
            return Qt.vector4d(g(0), g(1), g(2), g(3))
        }
        readonly property vector4d glassA: pass.glassBlock(0)
        readonly property vector4d glassB: pass.glassBlock(1)
        readonly property vector4d glassC: pass.glassBlock(2)
        readonly property vector4d glassD: pass.glassBlock(3)
        readonly property vector4d glassE: pass.glassBlock(4)
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
