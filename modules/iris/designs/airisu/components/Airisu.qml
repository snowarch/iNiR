pragma Singleton

import QtQuick
import Quickshell
import qs.modules.common.functions
import qs.modules.iris.style

// AIRISU's tokens (designs/airisu/SYSTEM.md §3): printed, not painted. Every value comes from iRiS's resolved roles, so
// Dark (gofun ink on lacquer), Ink and Light (sumi ink on gofun paper) are the same plates on another stock.
QtObject {
    id: root
    readonly property real d: IrisStyle.density

    // ── Plates (特色). A second level is another plate, a finer stroke or a screen, never a transparency.
    readonly property color ground: IrisStyle.bodySurface          // the stock: lacquer at night, gofun paper by day
    readonly property color groundRaised: IrisStyle.surfaceHigh    // the next sheet laid on it
    readonly property color ink: IrisStyle.text                    // 墨 / 胡粉: the ink that structures
    // Text one and two steps down, as solid tones of the ink on this stock (a tint, not a see-through film).
    readonly property color inkSecond: ColorUtils.mix(IrisStyle.text, IrisStyle.bodySurface, 0.66) // iris-literal: AIRISU's second tone, solid
    readonly property color inkThird: ColorUtils.mix(IrisStyle.text, IrisStyle.bodySurface, 0.44)  // iris-literal: AIRISU's third tone, solid
    readonly property color reverse: IrisStyle.bodySurface          // ink reversed out of a solid ink plate
    readonly property color seal: IrisStyle.accentFill              // 朱: only the seal, what is live or signs
    readonly property color inkOnSeal: IrisStyle.inkOnAccentFill
    readonly property color sealText: IrisStyle.accent              // 朱 set as type, solved to read on the stock
    // The plate under the seal, seen only when the seal is pressed and its registration runs.
    readonly property color sealUnder: ColorUtils.mix(IrisStyle.accentFill, IrisStyle.bodySurface, 0.55) // iris-literal: the seal's under-plate
    readonly property color inkUnder: ColorUtils.mix(IrisStyle.text, IrisStyle.bodySurface, 0.5)        // iris-literal: an ink plate's under-plate
    readonly property color caution: IrisStyle.secondaryAccent      // 山吹: only caution
    readonly property color inkOnCaution: IrisStyle.onTintFor(IrisStyle.secondaryAccent)
    readonly property color danger: IrisStyle.danger
    readonly property color rule: IrisStyle.hairline                // the 1 px rule
    readonly property color ruleStrong: IrisStyle.text              // the 2 px rule that closes a head
    // The identity bands, like a station sign's line colour: they say which line, never how much.
    function band(id: string): color { return IrisStyle.identityColor(id) }

    // ── The grid: the module is born of the base label's cap height.
    readonly property int m: Math.round(4 * root.d)
    function u(n: real): int { return Math.round(n * 4 * root.d) }
    readonly property int cap: 2 * root.m
    readonly property int gutter: 4 * root.m
    readonly property int margin: 6 * root.m

    // ── Dies (型抜き): a closed set, one per kind of object.
    readonly property int chamfer: IrisStyle.chamferCut               // a body's 45° cut, the field's own
    function cutFor(h: real): int { return Math.max(2, Math.min(2 * root.m, Math.round(h / 4))) }
    readonly property int perforation: root.m                         // pitch; holes are half of it
    readonly property int tomboLength: Math.round(1.5 * root.m)
    readonly property int tomboAir: Math.max(2, Math.round(0.75 * root.m))

    // ── Strokes.
    readonly property int hair: Math.max(1, Math.round(root.d))
    readonly property int strong: Math.max(2, Math.round(2 * root.d))
    readonly property int registration: Math.max(2, Math.round(2 * root.d)) // how far a pressed plate runs out of register
    readonly property int offset: Math.max(2, Math.round(2 * root.d))  // a print's hard offset shadow

    // ── Faces.
    readonly property string figureFace: "Archivo SemiExpanded"
    readonly property string textFace: "Archivo"
    readonly property string dataFace: IrisStyle.fontMono
    readonly property string kanaFace: "Airisu Kana"
    // The Japanese layer: a subset of Noto Sans CJK JP Bold renamed so it never shadows the system's (OFL, assets/).
    readonly property FontLoader kana: FontLoader { source: Qt.resolvedUrl("../assets/fonts/AirisuKana-Bold.otf") }

    // ── Time: a machine with detents, not springs. One curve.
    readonly property bool moving: IrisStyle.motionEnabled
    readonly property int detent: root.moving ? 90 : 0
    readonly property int snap: root.moving ? 140 : 0
    readonly property int tear: root.moving ? 220 : 0
    readonly property int ceremony: root.moving ? 420 : 0
    readonly property int inkTime: 600 // sealing by holding: the person's time, so it never goes to 0
    readonly property var curve: [0.2, 0, 0, 1, 1, 1]

    // A pattern's one cell as an SVG data url (QtSvg reads no rgba(): a hex fill and its opacity), tiled by the caller.
    function hex2(v: real): string {
        const s = Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16)
        return s.length < 2 ? "0" + s : s
    }
    function svgCell(w: int, h: int, body: string, colour: color): string {
        const c = Qt.color(colour)
        const svg = `<svg xmlns='http://www.w3.org/2000/svg' width='${w}' height='${h}' shape-rendering='crispEdges'>`
            + `<g fill='#${root.hex2(c.r)}${root.hex2(c.g)}${root.hex2(c.b)}' fill-opacity='${Math.round(c.a * 1000) / 1000}'>${body}</g></svg>`
        // Base64 by hand: Qt hands a percent-encoded data url to the SVG reader undecoded, and Qt.btoa is deprecated.
        const table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
        let out = ""
        for (let i = 0; i < svg.length; i += 3) {
            const a = svg.charCodeAt(i), b = svg.charCodeAt(i + 1), d = svg.charCodeAt(i + 2)
            const n = (a << 16) | ((b || 0) << 8) | (d || 0)
            out += table[(n >> 18) & 63] + table[(n >> 12) & 63]
                + (i + 1 < svg.length ? table[(n >> 6) & 63] : "=") + (i + 2 < svg.length ? table[n & 63] : "=")
        }
        return "data:image/svg+xml;base64," + out
    }

    // ── Until every surface is rebuilt on the plates above (SYSTEM.md R1): the first pass's names.
    readonly property color lacquer: root.ground
    readonly property color sumi: root.groundRaised
    readonly property color gofun: root.ink
    readonly property color inkOnGofun: root.reverse
    readonly property color amber: root.caution
    readonly property color inkOnAmber: root.inkOnCaution
    readonly property color data: root.inkSecond
    readonly property color quiet: root.inkThird
    readonly property color fillet: root.rule
    readonly property color socket: IrisStyle.fill
    readonly property color sealDim: root.sealUnder
    readonly property string wide: root.figureFace
    readonly property string body: root.textFace
    readonly property string mono: root.dataFace
    readonly property int line: root.hair
    readonly property int pad: 5 * root.m
    readonly property int gap: 2 * root.m
    readonly property int cut: root.chamfer
    readonly property int shift: root.detent
    readonly property int whip: root.snap
    readonly property int roll: root.tear
}
