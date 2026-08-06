import QtQuick
import QtQuick.Shapes
import qs.modules.common

/**
 * Self-contained vector glyph drawn from baked SVG path data, so the pill never
 * depends on the system icon theme or external asset files. Set `name` to pick a
 * glyph, `color` to tint it; stroked glyphs use `stroke` width, filled glyphs
 * (media transport) paint solid. Paths live in a 24x24 space and scale to the
 * item's size. Each glyph's actual bounding box is centred within the item on
 * both axes, so glyphs with differing path extents share one optical baseline.
 */
Item {
    id: root

    property string name: ""
    property color color: PillTheme.iconDim
    property real stroke: 1.8
    property real fillProgress: 1

    readonly property real u: Math.min(width, height) / 24

    readonly property var glyphs: ({
        "sun": { d: "M16 12a4 4 0 1 0-8 0a4 4 0 1 0 8 0 M12 2v2 M12 20v2 M4.2 4.2l1.4 1.4 M18.4 18.4l1.4 1.4 M2 12h2 M20 12h2 M4.2 19.8l1.4-1.4 M18.4 5.6l1.4-1.4", fill: false },
        "moon": { d: "M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9z", fill: false },
        "cloud": { d: "M17.5 19H9a7 7 0 1 1 6.71-9h1.79a4.5 4.5 0 1 1 0 9z", fill: false },
        "cloud-rain": { d: "M4 14.9A7 7 0 1 1 15.7 8h1.8a4.5 4.5 0 0 1 2.5 8.2 M16 14v5 M8 14v5 M12 16v5", fill: false },
        "cloud-snow": { d: "M4 14.9A7 7 0 1 1 15.7 8h1.8a4.5 4.5 0 0 1 2.5 8.2 M8 15h.01 M8 19h.01 M12 17h.01 M12 21h.01 M16 15h.01 M16 19h.01", fill: false },
        "cloud-lightning": { d: "M6 16.3A7 7 0 1 1 15.7 8h1.8a4.5 4.5 0 0 1 .5 9 M12 12l-3 5h4l-3 5", fill: false },
        "cloud-fog": { d: "M4 14.9A7 7 0 1 1 15.7 8h1.8a4.5 4.5 0 0 1 2.5 8.2 M16 17H7 M17 21H9", fill: false },
        "droplet": { d: "M12 3c3.5 4.2 5.5 7 5.5 9.5a5.5 5.5 0 0 1-11 0C6.5 10 8.5 7.2 12 3z", fill: false },
        "check": { d: "M20 6 9 17l-5-5", fill: false },
        "agenda": { d: "M3.5 5h5v5h-5z M3 16.5l2 2 4-4 M13 6h8 M13 12h8 M13 18h8", fill: false },
        "arrow-up": { d: "M12 19V5 M6 11l6-6 6 6", fill: false },
        "stopwatch": { d: "M10 2h4 M12 14V9 M19 7l1.5-1.5 M12 22a8 8 0 1 0 0-16 8 8 0 0 0 0 16z", fill: false },
        "type": { d: "M4 7V5h16v2 M12 5v14 M9 19h6", fill: false },
        "language": { d: "M3 5h8 M7 4v2c0 3.5-2 6-4 7 M4 9c0 2 2.5 4 6 4.5 M13 20l4-9 4 9 M14.5 17h5", fill: false },
        "palette": { d: "M12 2a10 10 0 1 0 0 20c1.1 0 2-.9 2-2v-1a2 2 0 0 1 2-2h1c1.1 0 2-.9 2-2a10 10 0 0 0-9-11z M7.5 11.5a1 1 0 1 0 .01 0 M9.5 7.5a1 1 0 1 0 .01 0 M14 6.5a1 1 0 1 0 .01 0 M17 10.5a1 1 0 1 0 .01 0", fill: false },
        "scaling": { d: "M3 7V3h4 M17 3h4v4 M21 17v4h-4 M7 21H3v-4 M9 12h6", fill: false },
        "waves": { d: "M2 8c2.5-3 5-3 7.5 0s5 3 7.5 0 M2 16c2.5-3 5-3 7.5 0s5 3 7.5 0", fill: false },
        "sparkles": { d: "M12 3l1.7 5.1 5.1 1.7-5.1 1.7L12 16.6l-1.7-5.1-5.1-1.7 5.1-1.7z M5 15.5l.7 2 2 .7-2 .7-.7 2-.7-2-2-.7 2-.7z", fill: false },
        "app-window": { d: "M3 5h18a1 1 0 0 1 1 1v12a1 1 0 0 1-1 1H3a1 1 0 0 1-1-1V6a1 1 0 0 1 1-1z M2 9.5h20 M5.5 7h.01 M8 7h.01 M10.5 7h.01", fill: false },
        "mouse": { d: "M12 2a6 6 0 0 0-6 6v8a6 6 0 0 0 12 0V8a6 6 0 0 0-6-6z M12 6v3.5", fill: false },
        "keyboard": { d: "M2.5 6h19a1 1 0 0 1 1 1v10a1 1 0 0 1-1 1h-19a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1z M6 10h.01 M10 10h.01 M14 10h.01 M18 10h.01 M7.5 14h9", fill: false },
        "download": { d: "M12 3v12 M7.5 10.5l4.5 4.5 4.5-4.5 M5 21h14", fill: false },
        "monitor": { d: "M4 4h16a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2h-16a2 2 0 0 1-2-2v-9a2 2 0 0 1 2-2z M8 21h8 M12 17v4 M7 13c1.5-4 3-4 5-1s3.5 2 5-2", fill: false },
        "speaker": { d: "M4 9v6h4l5 4V5L8 9z M16 9.5a3 3 0 0 1 0 5 M18.5 7.5a6 6 0 0 1 0 9", fill: false },
        "speaker-off": { d: "M4 9v6h4l5 4V5L8 9z M16.2 9.8l4.4 4.4 M20.6 9.8l-4.4 4.4", fill: false },
        "mic": { d: "M9 9V6a3 3 0 0 1 6 0v6a3 3 0 0 1-6 0 M5 11a7 7 0 0 0 14 0 M12 18v3", fill: false },
        "mic-off": { d: "M9 9V6a3 3 0 0 1 6 0v3 M15 12v0a3 3 0 0 1-5.6 1.5 M5 11a7 7 0 0 0 11 5.5 M12 19v3 M3 3l18 18", fill: false },
        "lock": { d: "M6 10h12a1.5 1.5 0 0 1 1.5 1.5v6a1.5 1.5 0 0 1-1.5 1.5H6a1.5 1.5 0 0 1-1.5-1.5v-6A1.5 1.5 0 0 1 6 10z M8.5 10V7a3.5 3.5 0 0 1 7 0v3", fill: false },
        "lock-round": { d: "M8 8.5H16A3 3 0 0 1 19 11.5V15.5A3 3 0 0 1 16 18.5H8A3 3 0 0 1 5 15.5V11.5A3 3 0 0 1 8 8.5Z M8.4 8.5V5.7A3.6 3.6 0 0 1 15.6 5.7V8.5", fill: false },
        "lock-outline": { d: "M6.4 9.5H17.6A2.4 2.4 0 0 1 20 11.9V17.6A2.4 2.4 0 0 1 17.6 20H6.4A2.4 2.4 0 0 1 4 17.6V11.9A2.4 2.4 0 0 1 6.4 9.5Z M7.5 9.5V6A4.5 4.5 0 0 1 16.5 6V9.5", fill: false },
        "logout": { d: "M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4 M16 17l5-5-5-5 M21 12H9", fill: false },
        "suspend": { d: "M21 12.8A9 9 0 1 1 11.2 3 7 7 0 0 0 21 12.8z", fill: false },
        "reboot": { d: "M21 12a9 9 0 1 1-2.6-6.4 M21 3v5h-5", fill: false },
        "undo": { d: "M3 12a9 9 0 1 0 2.6-6.4 M3 3v5h5", fill: false },
        "shutdown": { d: "M12 3v9 M7.8 6.3a8 8 0 1 0 8.4 0", fill: false },
        "mixer": { d: "M6 4v16M12 4v16M18 4v16M3.5 9h5M9.5 15h5M15.5 7h5", fill: false },
        "music": { d: "M9 18V5l12-2v13 M9 18a3 3 0 1 1-6 0 3 3 0 0 1 6 0z M21 16a3 3 0 1 1-6 0 3 3 0 0 1 6 0z", fill: false },
        "play": { d: "M7 5l12 7-12 7z", fill: true },
        "pause": { d: "M8 5h3v14H8z M13 5h3v14h-3z", fill: true },
        "next": { d: "M6 5l9 7-9 7z M16 5h2v14h-2z", fill: true },
        "prev": { d: "M18 5l-9 7 9 7z M6 5h2v14H6z", fill: true },
        "play-s": { d: "M8 5.5l10.5 6.5L8 18.5z", fill: false },
        "pause-s": { d: "M9 5.5v13 M15 5.5v13", fill: false },
        "next-s": { d: "M7 5.5l9 6.5-9 6.5z M17 5.5v13", fill: false },
        "prev-s": { d: "M17 5.5l-9 6.5 9 6.5z M7 5.5v13", fill: false },
        "dnd": { d: "M6 16V11a6 6 0 0 1 9.3-5M18 11v5M4 16h16M10.5 20a1.8 1.8 0 0 0 3 0M3 3l18 18", fill: false },
        "awake": { d: "M2 12s3.5-6 10-6 10 6 10 6-3.5 6-10 6-10-6-10-6zM12 9a3 3 0 1 0 0 6 3 3 0 0 0 0-6z", fill: false },
        "chevron-left": { d: "M14 6l-6 6 6 6", fill: false },
        "chevron-right": { d: "M10 6l6 6-6 6", fill: false },
        "chevron-down": { d: "M6 10l6 6 6-6", fill: false },
        "chevron-up": { d: "M6 14l6-6 6 6", fill: false },
        "close": { d: "M6 6l12 12 M18 6l-12 12", fill: false },
        "trash": { d: "M3 6h18 M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6 M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2 M10 11v6 M14 11v6", fill: false },
        "return": { d: "M20 6v6a3 3 0 0 1-3 3H5 M9 11l-4 4 4 4", fill: false },
        "wifi": { d: "M4 9.5C9 4.8 15 4.8 20 9.5 M7 13c3-2.8 7-2.8 10 0 M11 16.8a1.4 1.4 0 1 0 2 0a1.4 1.4 0 1 0-2 0", fill: false },
        "ethernet": { d: "M5 5h14a1.5 1.5 0 0 1 1.5 1.5v8a1.5 1.5 0 0 1-1.5 1.5H5a1.5 1.5 0 0 1-1.5-1.5v-8A1.5 1.5 0 0 1 5 5z M8 19h8 M12 16v3 M8 8.5v3.5 M12 8.5v3.5 M16 8.5v3.5", fill: false },
        "bluetooth": { d: "M12 2.8v18.4 M12 2.8l5.2 4.6-10.4 9 M12 21.2l5.2-4.6-10.4-9", fill: false },
        "inbox": { d: "M6 16v-5a6 6 0 0 1 12 0v5 M4 16h16 M10.5 20a1.8 1.8 0 0 0 3 0", fill: false },
        "clipboard": { d: "M9 3.5h6a1 1 0 0 1 1 1v1a1 1 0 0 1-1 1H9a1 1 0 0 1-1-1v-1a1 1 0 0 1 1-1z M16 4.5h2a2 2 0 0 1 2 2v12.5a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6.5a2 2 0 0 1 2-2h2", fill: false },
        "bolt": { d: "M13 2 4 13.5h6.5L11 22l9-11.5h-6.5z", fill: false },
        "hotspot": { d: "M12 12a1.3 1.3 0 1 0 0.01 0 M8.8 8.5A5 5 0 0 0 8.8 15.5 M15.2 8.5A5 5 0 0 1 15.2 15.5 M6 6A9 9 0 0 0 6 18 M18 6A9 9 0 0 1 18 18", fill: false },
        "cog": { d: "M12 9a3 3 0 1 0 0 6 3 3 0 0 0 0-6z M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z", fill: false },
        "clock": { d: "M12 3a9 9 0 1 0 0 18a9 9 0 1 0 0-18z M12 7v5l3.5 2", fill: false },
        "cursor": { d: "M5 3l6 16 2-6 6-2L5 3z", fill: false },
        "video": { d: "M3 7.5a1.5 1.5 0 0 1 1.5-1.5h9A1.5 1.5 0 0 1 15 7.5v9A1.5 1.5 0 0 1 13.5 18h-9A1.5 1.5 0 0 1 3 16.5z M15 10l6-3v10l-6-3z", fill: false },
        "record": { d: "M12 4a8 8 0 1 0 0 16a8 8 0 1 0 0-16z", fill: true },
        "gamepad": { d: "M7 11h4 M9 9v4 M15.5 10h.01 M17.5 13h.01 M17 7H7a5 5 0 0 0-5 5l-.9 4.5A2.4 2.4 0 0 0 5.7 18L8 15h8l2.3 3a2.4 2.4 0 0 0 4.6-1.5L22 12a5 5 0 0 0-5-5z", fill: false }
    })

    readonly property var g: glyphs[name] !== undefined ? glyphs[name] : ({ d: "", fill: false })

    Shape {
        id: glyph

        width: 24
        height: 24
        scale: root.u
        transformOrigin: Item.TopLeft
        // Snap the optically-centred offset to the pixel grid: a glyph parked on
        // a half pixel renders every 1.2px stroke as a soft smear.
        x: Math.round(glyph.boundingRect.width > 0
           ? root.width / 2 - (glyph.boundingRect.x + glyph.boundingRect.width / 2) * root.u
           : (root.width - 24 * root.u) / 2)
        y: Math.round(glyph.boundingRect.height > 0
           ? root.height / 2 - (glyph.boundingRect.y + glyph.boundingRect.height / 2) * root.u
           : (root.height - 24 * root.u) / 2)
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.g.fill ? "transparent" : root.color
            fillColor: root.g.fill ? root.color : "transparent"
            strokeWidth: root.stroke
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: root.g.d }
        }
    }
}
