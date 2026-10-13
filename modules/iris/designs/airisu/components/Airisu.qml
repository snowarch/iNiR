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
    // ── Lacquer (漆) and the 90/8/2 rule: ninety parts lacquer and ink (shikkoku, sumi, tetsu), eight of gofun, two of
    // seal. The ladder is the solver's (scripts/colors/washi/airisu.go): canvas, raised and rule rungs. A subject's
    // pigment never colours a whole panel; it is breathed into the rung (a few parts in a hundred) and spent whole only
    // on what is live: the seal, a level's run, a mark.
    function pigment(subject: string): color {
        switch (subject) {
        // Caution is the Design's yamabuki as the solver keeps it for a fill (the airisu language seeds danger with it),
        // never the highlight solved to read as text: on paper that one is deepened to an olive brown.
        case "caution": return IrisStyle.dangerFill
        case "system": return root.tame
        default: return IrisStyle.accentFill
        }
    }
    // Tame (溜): the seal with its fire taken out, for what is at rest or set aside.
    readonly property color tame: ColorUtils.mix(IrisStyle.accentFill, IrisStyle.textSecondary, 0.35) // iris-literal: the seal at rest
    // The neutral of the ladder: the scheme's own black (or its plain paper).
    readonly property color base: IrisStyle.materialSwatch("black")
    readonly property color raised: root.solid(IrisStyle.surfaceHigh)
    readonly property color iron: root.solid(IrisStyle.surfaceHighest)
    // How much of a pigment each rung carries: a panel breathes it, a widget's coat holds a little more, the canvas less.
    readonly property real lacquerLoad: 0.07 // iris-literal: pigment in a panel's lacquer
    readonly property real stockLoad: 0.1    // iris-literal: pigment in a widget's lacquer
    // A panel: the raised rung (sumi at night, the next paper by day) with a breath of its subject.
    function lacquerOf(pigment: color): color { return ColorUtils.mix(pigment, root.raised, root.lacquerLoad) }
    // A desktop widget: the same rung as an object on the wall, holding a little more of its pigment.
    function stockOf(pigment: color): color { return ColorUtils.mix(pigment, root.raised, root.stockLoad) }
    // An object made of the lacquer itself (a dial): the canvas rung, whatever the scheme.
    function deepOf(pigment: color): color {
        return ColorUtils.mix(pigment, IrisStyle.light ? root.solid(IrisStyle.bodySurface) : root.base, 0.06) // iris-literal: canvas with a breath
    }
    // The second coat, under type (the 45° band): the rule rung with a little more of the pigment, so whatever is set on
    // it still reads and the band is told from the panel by a step of the ladder, not by a colour.
    function coat(pigment: color): color { return ColorUtils.mix(pigment, root.iron, 0.14) } // iris-literal: the coat's pigment
    // The pigment at full strength, where nothing is set on it (a level's run, a mark).
    function vivid(pigment: color): color {
        // By day a pigment is deepened to read on paper, but a yellow printed on paper is yellow with sumi on it: deepened it
        // went the olive brown of mud.
        return IrisStyle.light ? ColorUtils.mix(pigment, IrisStyle.text, 0.78 + 0.22 * root.yellowness(pigment)) : pigment // iris-literal: the day pigment, deepened to read
    }
    // How near a hue is to yellow: a yellow deepened toward sumi goes olive, so it keeps itself.
    function yellowness(c: color): real { return Math.max(0, 1 - Math.abs(Qt.color(c).hslHue - 0.125) / 0.075) }
    // The ink a lacquer takes (gofun or sumi, whichever reads), and its lower tones tinted with the lacquer's own hue:
    // on a coloured surface a second line is the colour, never grey.
    // A see-through colour (a glass body's next coat) as the eye sees it over the body, so its ink is chosen against that.
    function solid(c: color): color {
        if (c.a >= 0.99) return c
        const b = Qt.color(root.base), body = Qt.color(IrisStyle.bodySurface)
        return Qt.tint(Qt.tint(Qt.rgba(b.r, b.g, b.b, 1), body), c)
    }
    function inkOn(lacquer: color): color {
        return Qt.colorEqual(lacquer, IrisStyle.accentFill) ? IrisStyle.inkOnAccentFill : IrisStyle.onTintFor(root.solid(lacquer))
    }
    // The ink for type that spans a lacquer and its coat: whichever of the two inks reads worst-case better on both.
    function inkOver(lacquer: color, coat: color): color {
        const a = root.solid(lacquer), b = root.solid(coat), l = IrisStyle.onTint, k = IrisStyle.inkOnPale
        return Math.min(ColorUtils.contrastRatio(l, a), ColorUtils.contrastRatio(l, b))
            >= Math.min(ColorUtils.contrastRatio(k, a), ColorUtils.contrastRatio(k, b)) ? l : k
    }
    function inkSecondOn(lacquer: color): color { return ColorUtils.mix(root.inkOn(lacquer), root.solid(lacquer), 0.74) } // iris-literal: second tone on lacquer
    function inkThirdOn(lacquer: color): color { return ColorUtils.mix(root.inkOn(lacquer), root.solid(lacquer), 0.52) }  // iris-literal: third tone on lacquer

    // A control answers by a coat (the pointer one, a press two). A coloured lacquer is coated a step toward its own ink;
    // a dark one takes a coat of shu, so the pointer warms it into the urushi instead of greying it like any dark theme's
    // hover. A control that cannot be taken keeps no coat.
    function step(lacquer: color, n: real): color {
        const c = root.solid(lacquer)
        return c.hslSaturation > 0.45 && c.hslLightness > 0.3 ? ColorUtils.mix(root.inkOn(lacquer), c, n)
            : ColorUtils.mix(root.seal, c, n * 1.6)
    }
    readonly property real hoverStep: 0.12 // iris-literal: the pointer's coat
    readonly property real pressStep: 0.22 // iris-literal: a press's coat
    // A slot (a level's run, a switch, a choice of words) is sunk into whatever lacquer it is cut in: that lacquer one
    // shade deeper in its own hue, so it reads on the body and on a coloured panel alike; the pointer lifts it a step.
    // At night the slot is the rule rung (tetsu), which reads on the canvas and on sumi alike.
    readonly property color slot: IrisStyle.light ? ColorUtils.applyAlpha(IrisStyle.text, 0.1) : root.iron // iris-literal: a slot's depth
    readonly property color slotLifted: IrisStyle.light ? ColorUtils.applyAlpha(IrisStyle.text, 0.16) : ColorUtils.mix(IrisStyle.text, root.iron, 0.08) // iris-literal: a lifted slot
    readonly property color slotCoat: ColorUtils.applyAlpha(IrisStyle.text, 0.08) // iris-literal: the pointer's coat inside a slot
    readonly property color slotPress: ColorUtils.applyAlpha(IrisStyle.text, 0.15) // iris-literal: a press inside a slot
    // A key that cannot be taken sits half a rung over the canvas, under the live keys: raised a full step it read as a
    // grey key that stood out more than the live ones beside it, sunk under the canvas it vanished.
    readonly property color dim: IrisStyle.light ? ColorUtils.mix(IrisStyle.text, root.solid(IrisStyle.bodySurface), 0.07) // iris-literal: an inactive key, sunk
        : ColorUtils.mix(root.raised, root.base, 0.5)                                                                     // iris-literal: an inactive key, half a rung

    // A record's own pigment: the colour its cover is printed in (the engine's art tint), or music's when it has none.
    function recordPigment(tint: color): color { return Qt.colorEqual(tint, IrisStyle.text) ? root.pigment("music") : tint }

    // The surfaces of the first pass that printed on a light "sticker" stock now take the person's lacquer, with its inks.
    readonly property color sticker: root.lacquerOf(IrisStyle.accentFill)
    readonly property color seal: IrisStyle.accentFill              // 朱: only the seal, what is live or signs
    readonly property color inkOnSeal: IrisStyle.inkOnAccentFill
    readonly property color sealText: IrisStyle.accent              // 朱 set as type, solved to read on the stock
    readonly property color sealOnMedia: IrisStyle.accentOnMedia    // 朱 over a picture (the lock), in every scheme
    readonly property color caution: IrisStyle.secondaryAccent      // 山吹: only caution
    readonly property color danger: IrisStyle.danger
    readonly property color rule: IrisStyle.hairline                // the 1 px rule
    // The identity bands, like a station sign's line colour: they say which line, never how much.
    function band(id: string): color { return IrisStyle.identityColor(id) }

    // ── The grid: the module is born of the base label's cap height.
    readonly property int m: Math.round(4 * root.d)
    function u(n: real): int { return Math.round(n * 4 * root.d) }

    // ── Dies (型抜き): a closed set, one per kind of object.
    readonly property int chamfer: IrisStyle.chamferCut               // a body's 45° cut, the field's own
    function cutFor(h: real): int { return Math.max(2, Math.min(2 * root.m, Math.round(h / 4))) }

    // ── Strokes.
    readonly property int hair: Math.max(1, Math.round(root.d))
    readonly property int strong: Math.max(2, Math.round(2 * root.d))
    readonly property int offset: Math.max(2, Math.round(2 * root.d))  // a print's hard offset shadow
    // ── Chosen (選). What is picked among choices (a box of a form, the switch's taken cell, the open tab of an index) is
    // lacquered in the selection's pigment with its ink cut out of it, as a lit control is. A plate in the ink's own colour
    // read as a white (or black) block on the lacquer, the one thing AIRISU never lays.
    readonly property color chosen: IrisStyle.selectionFill
    readonly property color inkOnChosen: IrisStyle.selectionInk
    // A box that holds something but is not chosen (the switch's off cell, the group being read): one step of ink on the stock.
    readonly property color cell: ColorUtils.mix(IrisStyle.text, root.solid(IrisStyle.bodySurface), IrisStyle.light ? 0.08 : 0.12) // iris-literal: a filled box, one step of ink
    // The cover a Place's index is printed on: the black lacquer a step under the body at night, sumi by day.
    readonly property color cover: IrisStyle.light ? ColorUtils.mix(IrisStyle.text, root.solid(IrisStyle.bodySurface), 0.88) // iris-literal: the cover by day, sumi
        : ColorUtils.mix(root.solid(IrisStyle.bodySurface), root.base, 0.42)                                                  // iris-literal: the cover at night, under the body
    // A sheet laid on the body (a page on its cover): the next lacquer at night; by day a paper whiter than the body, never
    // the see-through coat the body's next sheet is on glass, which read as a grey slab sunk into the page.
    readonly property color sheet: IrisStyle.light ? ColorUtils.lighten(root.solid(IrisStyle.bodySurface), 0.06) // iris-literal: a sheet's paper, a step over the body
        : root.solid(IrisStyle.surfaceHigh)
    // The sumi that offset shadow is printed in: under the lacquer at night, a pale sumi on paper by day.
    readonly property color shade: IrisStyle.light ? ColorUtils.mix(IrisStyle.text, root.solid(IrisStyle.bodySurface), 0.16) // iris-literal: a print's shadow on paper
        : ColorUtils.mix(root.solid(IrisStyle.bodySurface), root.base, 0.35)                                                     // iris-literal: a print's shadow on lacquer
    // How far a lacquer panel stands inside the body that holds it, so the body's material frames it.
    readonly property int kiss: Math.round(3 * root.d)

    // ── Faces.
    // How far a hero figure leans (tan of its slope, about 11°).
    readonly property real lean: 0.2
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
}
