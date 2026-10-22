import QtQuick
import qs.modules.iris.style

// Nothing's dot type: each character a 5×7 grid of round dots, lit ones in the ink and the rest barely there. Set at a
// pitch (the dots' spacing); `fit` shrinks the pitch until the line fits its width.
Canvas {
    id: root
    property string text: ""
    property real pitch: 9
    property real fit: 0
    property real minPitch: 3
    property color color: IrisStyle.text
    property color offColor: Qt.rgba(IrisStyle.text.r, IrisStyle.text.g, IrisStyle.text.b, 0.06)
    readonly property string shown: root.text.normalize("NFD").replace(/[̀-ͯ]/g, "").toUpperCase()
    readonly property int columns: Math.max(0, root.shown.length * 6 - 1)
    readonly property real step: root.fit > 0 && root.columns > 0 ? Math.max(root.minPitch, Math.min(root.pitch, Math.floor(root.fit / root.columns * 10) / 10)) : root.pitch
    implicitWidth: Math.ceil(root.columns * root.step)
    implicitHeight: Math.ceil(7 * root.step)
    width: implicitWidth
    height: implicitHeight
    readonly property var glyphs: ({
        "0": "01110100011001110101110011000101110", "1": "00100011000010000100001000010001110", "2": "01110100010000100010001000100011111",
        "3": "11111000100010000010000011000101110", "4": "00010001100101010010111110001000010", "5": "11111100001111000001000011000101110",
        "6": "00110010001000011110100011000101110", "7": "11111000010001000100010000100001000", "8": "01110100011000101110100011000101110",
        "9": "01110100011000101111000010001001100",
        A: "01110100011000111111100011000110001", B: "11110100011000111110100011000111110", C: "01110100011000010000100001000101110",
        D: "11100100101000110001100011001011100", E: "11111100001000011110100001000011111", F: "11111100001000011110100001000010000",
        G: "01110100011000010111100011000101111", H: "10001100011000111111100011000110001", I: "01110001000010000100001000010001110",
        J: "00111000100001000010000101001001100", K: "10001100101010011000101001001010001", L: "10000100001000010000100001000011111",
        M: "10001110111010110101100011000110001", N: "10001100011100110101100111000110001", O: "01110100011000110001100011000101110",
        P: "11110100011000111110100001000010000", Q: "01110100011000110001101011001001101", R: "11110100011000111110101001001010001",
        S: "01111100001000001110000010000111110", T: "11111001000010000100001000010000100", U: "10001100011000110001100011000101110",
        V: "10001100011000110001100010101000100", W: "10001100011000110101101011010101010", X: "10001100010101000100010101000110001",
        Y: "10001100010101000100001000010000100", Z: "11111000010001000100010001000011111",
        "&": "01100100101010001000101011001001101", ".": "00000000000000000000000000110001100", "%": "11000110010001000100010001001100011",
        "-": "00000000000000011111000000000000000", "/": "00000000010001000100010001000000000", "'": "00100001000100000000000000000000000",
        ":": "00000011000110000000011000110000000", "+": "00000001000010011111001000010000000"
    })
    onShownChanged: requestPaint()
    onStepChanged: requestPaint()
    onColorChanged: requestPaint()
    onOffColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        const s = root.step
        const r = Math.max(0.8, s / 2 - Math.max(0.6, s * 0.1))
        for (let i = 0; i < root.shown.length; i++) {
            const bits = root.glyphs[root.shown[i]] ?? "00000000000000000000000000000000000"
            for (let b = 0; b < 35; b++) {
                ctx.fillStyle = bits[b] === "1" ? root.color : root.offColor
                ctx.beginPath()
                ctx.arc((i * 6 + b % 5) * s + s / 2, Math.floor(b / 5) * s + s / 2, r, 0, 2 * Math.PI)
                ctx.fill()
            }
        }
    }
}
