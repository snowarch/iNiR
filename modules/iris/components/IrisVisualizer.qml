pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style

// What plays, drawn from the shared cava reading: one look everywhere it shows (the resting Island, its player page,
// the Visualizer bubble), chosen in Now Playing › Visualizer. Nothing runs while it is hidden or silent.
Item {
    id: root
    property bool running: false
    property color tint: IrisStyle.text
    property real barHeight: 16 * IrisStyle.density
    property string style: IrisStyle.visualizerStyle
    property int bars: IrisStyle.visualizerBars
    readonly property real d: IrisStyle.density
    readonly property bool radial: root.style === "ring"
    readonly property real unit: 3 * root.d
    readonly property real gap: 2 * root.d
    readonly property real dot: Math.max(root.unit, Math.round(root.barHeight * 0.34))

    implicitHeight: root.barHeight
    implicitWidth: root.radial ? root.barHeight
        : root.style === "dots" ? root.bars * root.dot + (root.bars - 1) * root.gap
        : root.style === "wave" ? root.bars * 5 * root.d
        : root.bars * root.unit + (root.bars - 1) * root.gap

    // Inside the chassis, once it is still around the bars, they draw in a surface of their own (LiveLayer):
    // at 60 Hz here they repainted the whole output and Niri recomposed it (the edge bubble alone: ~9 points of
    // Niri's GPU). Anywhere else (Settings, previews, the lock) they draw in place.
    LiveLayer {
        anchors.fill: parent
        live: root.running
        content: bars
    }

    Component {
        id: bars
        Item {
            id: face
            property bool drawing: false
            CavaProcess { id: cava; active: root.running && face.drawing && face.visible }
            // Each band is the loudest bin under it, as a level 0..1; a fixed shape while cava has not answered.
            readonly property var levels: {
                const n = Math.max(1, root.bars)
                const out = []
                if (!root.running || !face.drawing) {
                    for (let i = 0; i < n; i++) out.push(0)
                    return out
                }
                const pts = cava.points ?? []
                const ceiling = Math.max(1, cava.normalizationCeiling)
                const rest = [0.45, 0.8, 0.6, 0.9, 0.5]
                const per = pts.length / n
                for (let i = 0; i < n; i++) {
                    if (pts.length === 0) { out.push(rest[i % rest.length]); continue }
                    const from = Math.floor(i * per)
                    const to = Math.max(from + 1, Math.floor((i + 1) * per))
                    let band = 0
                    for (let k = from; k < to && k < pts.length; k++) band = Math.max(band, pts[k] ?? 0)
                    out.push(Math.min(1, band / ceiling))
                }
                return out
            }

            // Capsules (centred) and Rise (from the baseline).
            Row {
                visible: root.style === "capsules" || root.style === "rise"
                anchors.fill: parent
                spacing: root.gap
                Repeater {
                    model: root.bars
                    Item {
                        id: lane
                        required property int index
                        width: root.unit
                        height: face.height
                        Rectangle {
                            width: parent.width
                            radius: root.style === "rise" ? Math.min(root.unit / 2, root.d) : width / 2
                            color: root.tint
                            y: root.style === "rise" ? lane.height - height : Math.round((lane.height - height) / 2)
                            height: Math.max(root.unit, (face.levels[lane.index] ?? 0) * lane.height)
                            Behavior on height { NumberAnimation { duration: IrisStyle.duration(90); easing.type: IrisStyle.feedbackEasing } }
                        }
                    }
                }
            }

            // Dots: one per band, swelling with it.
            Row {
                visible: root.style === "dots"
                anchors.verticalCenter: parent.verticalCenter
                spacing: root.gap
                Repeater {
                    model: root.style === "dots" ? root.bars : 0
                    Rectangle {
                        required property int index
                        width: root.dot
                        height: width
                        radius: width / 2
                        color: root.tint
                        scale: 0.4 + 0.6 * (face.levels[index] ?? 0)
                        opacity: 0.55 + 0.45 * (face.levels[index] ?? 0)
                        Behavior on scale { NumberAnimation { duration: IrisStyle.duration(90); easing.type: IrisStyle.feedbackEasing } }
                    }
                }
            }

            // Wave: one line through the bands, mirrored about the middle.
            Shape {
                visible: root.style === "wave"
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: root.tint
                    strokeWidth: Math.max(1.5, 1.6 * root.d)
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin
                    PathPolyline {
                        path: {
                            if (root.style !== "wave") return []
                            const n = face.levels.length
                            const w = Math.max(1, face.width)
                            const mid = face.height / 2
                            const amp = Math.max(0, mid - root.d)
                            const steps = Math.max(12, n * 6)
                            const out = []
                            for (let s = 0; s <= steps; s++) {
                                const t = s / steps
                                const at = t * (n - 1)
                                const i = Math.floor(at)
                                const f = at - i
                                const a = face.levels[i] ?? 0
                                const b = face.levels[Math.min(n - 1, i + 1)] ?? 0
                                const level = a + (b - a) * (0.5 - Math.cos(f * Math.PI) / 2)
                                const edge = Math.sin(t * Math.PI)
                                out.push(Qt.point(t * w, mid + Math.sin(t * Math.PI * n) * amp * Math.max(0.08, level) * edge))
                            }
                            return out
                        }
                    }
                }
            }

            // Ring: spokes around a circle, for a round face.
            Item {
                id: ring
                visible: root.radial
                anchors.centerIn: parent
                width: root.barHeight
                height: width
                readonly property int spokes: Math.max(8, root.bars * 3)
                readonly property real inner: width * 0.22
                readonly property real reach: width / 2 - inner
                Repeater {
                    model: root.radial ? ring.spokes : 0
                    Item {
                        id: spoke
                        required property int index
                        readonly property real level: {
                            const n = face.levels.length
                            const at = spoke.index / ring.spokes * n
                            return face.levels[Math.floor(at) % n] ?? 0
                        }
                        width: ring.width
                        height: ring.height
                        rotation: spoke.index * 360 / ring.spokes
                        Rectangle {
                            x: Math.round((parent.width - width) / 2)
                            width: Math.max(1.5, 1.8 * root.d)
                            radius: width / 2
                            color: root.tint
                            height: Math.max(width, ring.reach * (0.25 + 0.75 * spoke.level))
                            y: parent.height / 2 - ring.inner - height
                            Behavior on height { NumberAnimation { duration: IrisStyle.duration(90); easing.type: IrisStyle.feedbackEasing } }
                        }
                    }
                }
            }
        }
    }
}
