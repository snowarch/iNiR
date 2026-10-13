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
    // ── Lacquer (漆): AIRISU's material, and the only colours it uses: the person's accent as shu (朱), its hue muted
    // toward the black as tame (溜) for what is at rest or set aside, and ki (黄) for caution, all laid in the black of
    // the urushi. A subject is told by its sign and its words, never by a hue of its own.
    function pigment(subject: string): color {
        switch (subject) {
        // Caution is the Design's yamabuki as the solver keeps it for a fill (the airisu language seeds danger with it),
        // never the highlight solved to read as text: on paper that one is deepened to an olive brown.
        case "caution": return IrisStyle.dangerFill
        case "system": return root.tame
        default: return IrisStyle.accentFill
        }
    }
    readonly property color tame: ColorUtils.darken(ColorUtils.adjustSaturation(IrisStyle.accentFill, 0.45), 0.14)
    // Night lacquer holds a little of its pigment in the black, so a panel is the urushi a shade redder; by day it is the
    // paper washed with it.
    readonly property real lacquerLoad: IrisStyle.light ? 0.16 : 0.22 // iris-literal: how much pigment the lacquer holds
    // The neutral the pigments are laid in: the scheme's black (or its plain paper), never the shell's own urushi, which
    // already carries the accent and would muddy every other hue.
    readonly property color base: IrisStyle.materialSwatch("black")
    function lacquerOf(pigment: color): color {
        const c = Qt.color(pigment)
        if (IrisStyle.light || c.hslHue < 0 || c.hslSaturation < 0.12) return ColorUtils.mix(pigment, root.base, root.lacquerLoad)
        // At night a hue is kept, not mixed into the black: yamabuki mixed so went olive mud, never ki-urushi.
        return Qt.hsla(c.hslHue, Math.min(0.7, c.hslSaturation * 0.85), 0.14 + 0.12 * root.yellowness(c), 1) // iris-literal: night lacquer
    }
    // How near a hue is to yellow. A yellow lacquer stays itself only lighter than a red one (ki-urushi is ochre where
    // shu at the same depth is oxblood); at a red's depth it turns olive.
    function yellowness(c: color): real { return Math.max(0, 1 - Math.abs(c.hslHue - 0.125) / 0.075) }
    // A desktop widget is a thick coat of coloured lacquer (iro-urushi), the pigment carried well into the black, so on
    // the wall it reads as a lacquered object in its colour and never as a dark card.
    readonly property real stockLoad: IrisStyle.light ? 0.2 : 0.42 // iris-literal: how much pigment a widget's lacquer holds
    // At night the coat keeps the pigment's hue and its chroma and only goes deep (iro-urushi is coloured right through);
    // mixing it into the black greyed it into a dark card. A grey pigment has no hue to keep and is mixed.
    function stockOf(pigment: color): color {
        const c = Qt.color(pigment)
        if (IrisStyle.light || c.hslHue < 0 || c.hslSaturation < 0.12) return ColorUtils.mix(pigment, root.base, root.stockLoad)
        return root.deepOf(pigment)
    }
    // Lacquer laid deep whatever the scheme: an object made of it (a dial) is urushi by day too, never washed paper.
    function deepOf(pigment: color): color {
        const c = Qt.color(pigment)
        if (c.hslHue < 0 || c.hslSaturation < 0.12) return ColorUtils.mix(pigment, IrisStyle.materialSwatch("black"), 0.3)
        return Qt.hsla(c.hslHue, Math.min(0.62, c.hslSaturation * 0.9), 0.2 + 0.12 * root.yellowness(c), 1) // iris-literal: night lacquer, deep and still coloured
    }
    // The second coat, under type: a step deeper into the pigment (at night) or into the ink (by day), so whatever is set
    // on it still reads.
    function coat(pigment: color): color {
        return IrisStyle.light ? ColorUtils.mix(pigment, IrisStyle.text, 0.8 + 0.2 * root.yellowness(pigment)) // iris-literal: the day coat, a step toward sumi (a yellow keeps itself: deepened it goes brown)
            : ColorUtils.mix(pigment, root.base, 0.62)                        // iris-literal: the night coat, nearer the pigment
    }
    // The pigment at full strength, where nothing is set on it (a level's run, a mark).
    function vivid(pigment: color): color {
        // By day a pigment is deepened to read on paper, but a yellow printed on paper is yellow with sumi on it: deepened it
        // went the olive brown of mud.
        return IrisStyle.light ? ColorUtils.mix(pigment, IrisStyle.text, 0.78 + 0.22 * root.yellowness(pigment)) : pigment // iris-literal: the day pigment, deepened to read
    }
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
    readonly property color slot: IrisStyle.light ? ColorUtils.applyAlpha(IrisStyle.text, 0.1) : ColorUtils.applyAlpha(root.base, 0.42) // iris-literal: a slot's depth
    readonly property color slotLifted: IrisStyle.light ? ColorUtils.applyAlpha(IrisStyle.text, 0.16) : ColorUtils.applyAlpha(root.base, 0.26) // iris-literal: a lifted slot
    readonly property color slotCoat: ColorUtils.applyAlpha(IrisStyle.text, 0.08) // iris-literal: the pointer's coat inside a slot
    readonly property color slotPress: ColorUtils.applyAlpha(IrisStyle.text, 0.15) // iris-literal: a press inside a slot
    // A key that cannot be taken is sunk into the body, a shade under it: raised a step it read as a grey key that
    // stood out more than the live ones beside it.
    readonly property color dim: IrisStyle.light ? ColorUtils.mix(IrisStyle.text, root.solid(IrisStyle.bodySurface), 0.07) // iris-literal: an inactive key, sunk
        : ColorUtils.mix(root.solid(IrisStyle.bodySurface), root.base, 0.5)                                               // iris-literal: an inactive key, sunk

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
    // ── Chosen (選). What is picked among choices (a box of a form, the switch's taken cell, the open tab of an index) is a
    // plate in the ink's own colour with the stock reversed out of it: gofun at night, sumi by day. The seal stays for what
    // is live or signs, so a page with a chosen box and a running thing never shows two seals.
    readonly property color chosen: IrisStyle.text
    readonly property color inkOnChosen: root.solid(IrisStyle.bodySurface)
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
