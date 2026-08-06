pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common
import qs.services

/**
 * 系 SYSTEM surface: a flat washi card of live machine vitals fed by the
 * PillSysmon singleton. The header carries the kanji, label and uptime. Below it
 * sit flame dials for CPU, GPU and memory load, each a 270deg arc stroked with
 * the mixer's vermLit-to-vermBurn gradient on a thread track and rounded caps,
 * the sweep eased over the value change; the centre shows the value, a unit and
 * a sub line (CPU/GPU temperature, memory total). A hairline stripe underneath
 * reports network throughput, root-disk fill, swap and VRAM with their units
 * folded into the faint labels so the values read bare. On a machine with no
 * discrete GPU the GPU dial and VRAM cell drop and the remaining dials recentre.
 * Polling lives in the singleton and only runs while this surface is open.
 */
PillSurface {
    id: root

    mTop: 14
    mLeft: 16
    mRight: 16
    mBottom: 16

    implicitHeight: content.implicitHeight

    readonly property var dialKeys: PillSysmon.hasGpu ? ["cpu", "gpu", "mem"] : ["cpu", "mem"]
    readonly property var cellKeys: PillSysmon.hasVram ? ["net", "disk", "swap", "vram"] : ["net", "disk", "swap"]

    onActiveChanged: PillSysmon.open = active

    /**
     * The soul ember rests with the 系 header kanji: the kanji is the lantern,
     * the bead its flame, hovering just above the glyph with its wick rising into
     * it. Anchored to the header rather than the dial row so the ember sits in the
     * same deliberate spot whether three dials or two are shown (the header never
     * changes with GPU presence). With glyphs off the kanji is hidden, so the
     * anchor falls back to the SYSTEM label's left edge, vertically centred on the
     * header, and never floats. Mapped into surface-local space so the host can
     * offset it by the surface origin.
     */
    readonly property point soulPoint: {
        void root.width;
        void root.height;
        if (PillTheme.showGlyphs)
            return kanji.mapToItem(root, kanji.width / 2, -3 * root.s);
        return sysLabel.mapToItem(root, -8 * root.s, sysLabel.height / 2);
    }

    ameForm: open ? "soul" : "off"
    amePoint: soulPoint

    component Dial: Item {
        id: dial

        property real arc: 0
        property string big: ""
        property string unit: ""
        property string sub: ""
        property string label: ""
        property bool shrink: false

        property real display: 0
        onArcChanged: display = arc
        Component.onCompleted: display = arc
        onDisplayChanged: face.requestPaint()
        Behavior on display { NumberAnimation { duration: Math.round(700 * PillMotion.mult); easing.type: Easing.OutCubic } }

        width: 110 * root.s
        height: 110 * root.s

        Canvas {
            id: face
            anchors.fill: parent
            antialiasing: true

            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                var cx = width / 2;
                var cy = height / 2;
                var lw = 8 * root.s;
                var r = Math.min(width, height) / 2 - lw / 2 - root.s;
                var start = 135 * Math.PI / 180;
                var full = 270 * Math.PI / 180;
                ctx.lineCap = "round";
                ctx.lineWidth = lw;
                // threadBg is a 0.13-alpha cream. It must keep that alpha: the
                // 6-digit hex path would paint the track as a solid cream ring
                // that outshouts the value arc it is supposed to sit behind.
                ctx.strokeStyle = PillTheme.canvasColor(PillTheme.threadBg);
                ctx.beginPath();
                ctx.arc(cx, cy, r, start, start + full, false);
                ctx.stroke();
                var v = Math.max(0, Math.min(100, dial.display));
                if (v > 0.5) {
                    var diag = r * 0.7071;
                    var grad = ctx.createLinearGradient(cx - diag, cy + diag, cx + diag, cy - diag);
                    grad.addColorStop(0, PillTheme.hex(PillTheme.vermBurn));
                    grad.addColorStop(0.35, PillTheme.hex(PillTheme.vermBurn));
                    grad.addColorStop(1, PillTheme.hex(PillTheme.vermLit));
                    ctx.strokeStyle = grad;
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, start, start + full * v / 100, false);
                    ctx.stroke();
                }
            }
        }

        /**
         * The big value owns the dial's exact centre so it reads as the focal
         * number whatever its width, with the label and sub line stacked
         * directly beneath it; centring the value rather than the whole column
         * means a one- or three-digit value never drifts off the eye line.
         */
        Row {
            id: bigRow
            anchors.centerIn: parent
            /** Ring gap is at the bottom, so its optical middle sits above the hole centre; lift the value there. */
            anchors.verticalCenterOffset: -12 * root.s
            spacing: 1 * root.s

            Text {
                id: bigText
                text: dial.big
                color: PillTheme.cream
                font.family: PillTheme.font
                font.pixelSize: (dial.shrink ? 16 : 20) * root.s
                font.weight: Font.ExtraBold
                font.letterSpacing: -0.5 * root.s
                font.features: { "tnum": 1 }
            }
            Text {
                anchors.baseline: bigText.baseline
                visible: dial.unit.length > 0
                text: dial.unit
                color: PillTheme.subtle
                font.family: PillTheme.font
                font.pixelSize: 11 * root.s
                font.weight: Font.Bold
            }
        }

        Column {
            anchors.top: bigRow.bottom
            anchors.topMargin: 3 * root.s
            anchors.horizontalCenter: bigRow.horizontalCenter
            spacing: 3 * root.s

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: dial.label
                color: PillTheme.faint
                font.family: PillTheme.font
                font.pixelSize: 8.5 * root.s
                font.weight: Font.Bold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1 * root.s
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: dial.sub
                color: PillTheme.subtle
                font.family: PillTheme.font
                font.pixelSize: 10.5 * root.s
                font.weight: Font.Bold
                font.features: { "tnum": 1 }
            }
        }
    }

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        width: parent.width
        spacing: 0

        Item {
            width: parent.width
            height: 24 * root.s

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 9 * root.s

                Text {
                    id: kanji
                    anchors.verticalCenter: parent.verticalCenter
                    visible: PillTheme.showGlyphs
                    text: PillTheme.glyph("sysmon")
                    color: PillTheme.cream
                    font.family: PillTheme.fontJp
                    font.weight: Font.Medium
                    font.pixelSize: 16 * root.s
                }
                Text {
                    id: sysLabel
                    anchors.verticalCenter: parent.verticalCenter
                    text: Translation.tr("SYSTEM")
                    color: PillTheme.subtle
                    font.family: PillTheme.font
                    font.pixelSize: 10 * root.s
                    font.weight: Font.DemiBold
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1.8 * root.s
                }
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: PillSysmon.uptime
                color: PillTheme.dim
                font.family: PillTheme.font
                font.pixelSize: 9.5 * root.s
                font.weight: Font.Bold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.1 * root.s
                font.features: { "tnum": 1 }
            }
        }

        Item { width: 1; height: 16 * root.s }

        Item {
            width: parent.width
            height: 110 * root.s

            Repeater {
                model: root.dialKeys

                Dial {
                    required property int index
                    required property var modelData
                    readonly property string key: modelData
                    readonly property int val: key === "cpu" ? PillSysmon.cpu : key === "gpu" ? PillSysmon.gpu : PillSysmon.memPct

                    x: root.dialKeys.length > 1
                        ? index * (parent.width - width) / (root.dialKeys.length - 1)
                        : (parent.width - width) / 2

                    arc: val
                    big: key === "mem" ? PillSysmon.memUsedGb.toFixed(1) : "" + val
                    unit: key === "mem" ? "" : "%"
                    shrink: key !== "mem" && val >= 100
                    label: key
                    sub: key === "cpu" ? (PillSysmon.cpuTemp >= 0 ? PillSysmon.cpuTemp + "°" : "")
                        : key === "gpu" ? (PillSysmon.gpuTemp >= 0 ? PillSysmon.gpuTemp + "°" : "")
                        : "/ " + PillSysmon.memTotalGb.toFixed(0) + " GB"
                }
            }
        }

        Item { width: 1; height: 18 * root.s }

        Rectangle {
            width: parent.width
            height: 1
            color: PillTheme.hair
        }

        Item { width: 1; height: 13 * root.s }

        /**
         * The stat strip sizes itself off its own content instead of a fixed
         * band: every cell stacks one caption over one 13px value line, so the
         * cells are inherently equal height and the Row can carry the strip's
         * height up into the surface's implicitHeight. The previous fixed 30px
         * band was shorter than that stack and pushed the values into the
         * surface's bottom margin.
         */
        Row {
            id: statStrip
            width: parent.width

            Repeater {
                model: root.cellKeys

                Item {
                    id: cell
                    required property int index
                    required property var modelData
                    readonly property string key: modelData

                    width: statStrip.width / root.cellKeys.length
                    implicitHeight: statCol.implicitHeight + 6 * root.s
                    height: implicitHeight

                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        height: parent.height - 4 * root.s
                        width: 1
                        visible: cell.index > 0
                        color: PillTheme.hairSoft
                    }

                    Column {
                        id: statCol
                        anchors.centerIn: parent
                        spacing: 6 * root.s

                        /**
                         * One caption scale on the card: this matches the dial
                         * labels exactly, so the strip reads as the same family
                         * of furniture rather than a second, tighter caption.
                         */
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: cell.key === "net" ? "Net · MB/s"
                                : cell.key === "disk" ? "Disk · %"
                                : cell.key === "swap" ? "Swap · GB"
                                : "VRAM · GB"
                            color: PillTheme.faint
                            font.family: PillTheme.font
                            font.pixelSize: 8.5 * root.s
                            font.weight: Font.Bold
                            font.capitalization: Font.AllUppercase
                            font.letterSpacing: 1 * root.s
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 8 * root.s
                            visible: cell.key === "net"

                            Text {
                                text: "↓" + PillSysmon.netDown.toFixed(1)
                                color: PillTheme.cream
                                font.family: PillTheme.font
                                font.pixelSize: 13 * root.s
                                font.weight: Font.ExtraBold
                                font.features: { "tnum": 1 }
                            }
                            Text {
                                text: "↑" + PillSysmon.netUp.toFixed(1)
                                color: PillTheme.vermLit
                                font.family: PillTheme.font
                                font.pixelSize: 13 * root.s
                                font.weight: Font.ExtraBold
                                font.features: { "tnum": 1 }
                            }
                        }

                        /**
                         * VRAM carries a used/total pair, so it gets the same
                         * treatment the memory dial gives its own total: the
                         * used figure stays the bright hero and the denominator
                         * drops to the subdued sub scale on the shared baseline.
                         * Rendering both at hero weight made the cell read as
                         * one long number.
                         */
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 3 * root.s
                            visible: cell.key !== "net"

                            Text {
                                id: statValue
                                text: cell.key === "disk" ? "" + PillSysmon.diskPct
                                    : cell.key === "swap" ? PillSysmon.swapUsedGb.toFixed(1)
                                    : PillSysmon.vramUsedGb.toFixed(1)
                                color: PillTheme.cream
                                font.family: PillTheme.font
                                font.pixelSize: 13 * root.s
                                font.weight: Font.ExtraBold
                                font.features: { "tnum": 1 }
                            }
                            Text {
                                anchors.baseline: statValue.baseline
                                visible: cell.key === "vram"
                                text: "/ " + PillSysmon.vramTotalGb.toFixed(0)
                                color: PillTheme.subtle
                                font.family: PillTheme.font
                                font.pixelSize: 10 * root.s
                                font.weight: Font.Bold
                                font.features: { "tnum": 1 }
                            }
                        }
                    }
                }
            }
        }
    }
}
