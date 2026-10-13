pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.bar.island
import "../components"

// AIRISU's OSD, where the Island is not there to answer: the body holds one lacquer panel breathing the pigment of what
// changed. A level is set as a meter: its figure leaning at the start, its name in the data face's capitals over a
// ladder of steps that light as it climbs (Bar lays them flat; Minimal keeps a gauge round the sign). A keyboard lock is
// its glyph while it holds, a layout its keycap sunk in the panel; a song is its cover and words; a connection takes its
// line's colour. A volume held back or a connection in trouble keeps the panel and gains a band of yamabuki along its
// head, its die ruled in yamabuki. Each time it comes up its lacquer is laid across it. IrisOSD keeps when, where, how
// long and the body, so every row of Feedback in Settings still means what it says.
Item {
    id: root
    property var osd: null
    readonly property real d: Airisu.d
    readonly property string kind: root.osd?.kind ?? "volume"
    readonly property bool level: root.osd?.level ?? false
    readonly property string style: root.osd?.levelStyle ?? "capsule"
    readonly property bool minimal: root.style === "minimal"
    readonly property bool muted: root.osd?.muted ?? false
    readonly property real value: Math.max(0, Math.min(1, root.osd?.value ?? 0))
    readonly property real restWidth: Math.max(260, Math.min(520, Number(Config.options?.iris?.osd?.width ?? 320))) * root.d
    readonly property int pad: Airisu.u(4)
    readonly property int rise: Airisu.u(3)
    readonly property Item current: ({ volume: levelRow, brightness: levelRow, mic: levelRow, keyboard: keyRow, media: mediaRow,
        connection: connectionRow, warning: warningRow })[root.kind] ?? levelRow
    implicitWidth: root.level && !root.minimal ? Math.round(root.restWidth)
        : Math.round(Math.max(Math.round(200 * root.d), Math.min(root.restWidth * 1.2, root.current.implicitWidth + 2 * root.pad)))
    implicitHeight: Math.round(root.current.implicitHeight + 2 * root.rise + root.tape)

    readonly property bool opened: root.osd?.open ?? false
    readonly property int kiss: Airisu.kiss

    // The panel's pigment for what changed.
    readonly property string connectionTone: root.osd?.connection?.tone ?? ""
    readonly property bool keyLocked: (root.osd?.keyboardIcon ?? "") !== "language" && (root.osd?.keyboardActive ?? false)
    readonly property color pigment: {
        switch (root.kind) {
        case "volume": return Airisu.pigment(root.muted ? "system" : "music")
        case "brightness": return Airisu.pigment("display")
        case "mic": return Airisu.pigment(root.muted ? "system" : "message")
        case "keyboard": return root.keyLocked ? Airisu.seal : Airisu.pigment("system")
        case "media": return Airisu.pigment("music")
        case "connection": return root.connectionTone === "off" ? Airisu.pigment("system") : root.connectionTone === "warn"
            ? Airisu.pigment("caution") : (root.osd?.connectionTint ?? Airisu.pigment("network"))
        case "warning": return Airisu.pigment("caution")
        default: return Airisu.pigment("rest")
        }
    }
    // Caution is a band of yamabuki along the head and the die ruled in it; the panel stays the stock's.
    readonly property bool cautioned: root.kind === "warning" || (root.kind === "connection" && root.connectionTone === "warn")
    readonly property int tape: root.cautioned ? Airisu.u(1) : 0
    readonly property color panel: Airisu.lacquerOf(root.pigment)
    readonly property bool barLevel: root.style === "bar"
    readonly property color ink: Airisu.inkOn(root.panel)
    readonly property color inkSecond: Airisu.inkSecondOn(root.panel)
    readonly property color inkThird: Airisu.inkThirdOn(root.panel)

    ALacquer {
        id: panel
        anchors.fill: parent
        anchors.margins: root.kiss
        cut: Math.max(2, Airisu.chamfer - root.kiss)
        lacquer: root.opened ? root.panel : Airisu.ground
    }
    ADie {
        visible: root.cautioned
        anchors.fill: panel
        kind: "chamfer"
        cut: panel.cut
        stroke: Airisu.tape
        strokeWidth: Airisu.hair
    }
    Rectangle {
        visible: root.cautioned
        x: panel.x
        y: panel.y
        width: panel.width - panel.cut
        height: root.tape
        color: Airisu.tape
        antialiasing: false
    }

    component Slot: RowLayout {
        id: slot
        x: root.pad
        y: root.rise + root.tape
        width: root.width - 2 * root.pad
        height: root.height - 2 * root.rise - root.tape
        visible: root.current === slot
        spacing: Airisu.u(3)
    }

    // A level: the figure leaning at the start, and over the ladder of steps (ASteps) the name in the data face's capitals
    // with its sign; Bar lays the steps flat, Minimal keeps a gauge round the sign instead of the ladder.
    Slot {
        id: levelRow
        readonly property string name: root.kind === "brightness" ? Translation.tr("Brightness")
            : root.kind === "mic" ? Translation.tr("Microphone") : Translation.tr("Volume")
        AText {
            visible: root.osd?.levelFigure ?? true
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: hundred.advanceWidth
            voice: "figure"
            lean: Airisu.lean
            size: IrisStyle.typeDisplay
            color: root.muted ? root.inkThird : root.ink
            text: Math.round(root.value * 100)
            TextMetrics {
                id: hundred
                font.family: Airisu.figureFace
                font.pixelSize: IrisStyle.typeDisplay
                font.weight: Font.ExtraBold
                font.letterSpacing: -Math.round(IrisStyle.typeDisplay * 0.03)
                text: "100"
            }
        }
        Item {
            visible: root.minimal
            implicitWidth: Airisu.u(9)
            implicitHeight: Airisu.u(9)
            Layout.alignment: Qt.AlignVCenter
            ProgressRing {
                anchors.fill: parent
                progress: root.value
                tint: root.muted ? root.inkThird : Airisu.seal
                stroke: Math.round(3 * root.d)
            }
            MaterialSymbol {
                anchors.centerIn: parent
                text: root.osd?.icon ?? "volume_up"
                fill: 1
                iconSize: Math.round(15 * root.d)
                color: root.muted ? root.inkSecond : root.ink
            }
        }
        Column {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: Airisu.u(1.5)
            Row {
                spacing: Airisu.u(1)
                MaterialSymbol {
                    visible: !root.minimal
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.osd?.icon ?? "volume_up"
                    fill: 1
                    iconSize: Math.round(14 * root.d)
                    color: root.muted ? root.inkSecond : root.ink
                }
                AText {
                    anchors.verticalCenter: parent.verticalCenter
                    voice: "mono"
                    size: IrisStyle.typeCaption
                    color: root.inkSecond
                    text: root.muted ? Translation.tr("Muted") : levelRow.name
                }
            }
            ASteps {
                visible: !root.minimal
                width: parent.width
                height: Airisu.u(4)
                value: root.value
                muted: root.muted
                rising: !root.barLevel
                ink: root.ink
                quiet: root.inkThird
            }
        }
    }

    // A lock is its glyph on the accent's lacquer while it holds; a layout is its keycap sunk in the panel.
    Slot {
        id: keyRow
        readonly property bool layout: (root.osd?.keyboardIcon ?? "") === "language"
        readonly property bool active: root.osd?.keyboardActive ?? false
        MaterialSymbol {
            visible: !keyRow.layout
            Layout.alignment: Qt.AlignVCenter
            text: root.osd?.keyboardIcon ?? "keyboard"
            fill: 1
            iconSize: Math.round(22 * root.d)
            color: keyRow.active ? root.ink : root.inkThird
        }
        ALacquer {
            visible: keyRow.layout
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: Math.max(Airisu.u(9), Math.min(Airisu.u(18), legend.implicitWidth + Airisu.u(4)))
            implicitHeight: Airisu.u(9)
            cut: Airisu.cutFor(Airisu.u(9))
            lacquer: Airisu.slot
            moving: false
            AText {
                id: legend
                anchors.centerIn: parent
                width: Math.min(implicitWidth, parent.width - Airisu.u(2))
                voice: "figure"
                size: IrisStyle.typeTitle
                color: root.ink
                text: root.osd?.keyboardText ?? ""
            }
        }
        AText {
            Layout.fillWidth: true
            Layout.maximumWidth: Math.round(240 * root.d)
            Layout.alignment: Qt.AlignVCenter
            size: IrisStyle.typeBody
            font.weight: Font.Bold
            color: keyRow.layout || keyRow.active ? root.ink : root.inkSecond
            text: keyRow.layout ? Translation.tr("Keyboard layout") : (root.osd?.keyboardText ?? "")
        }
    }

    // A song: its cover, the artist over the title, what the key did.
    Slot {
        id: mediaRow
        IrisArtwork {
            Layout.preferredWidth: Airisu.u(10)
            Layout.preferredHeight: Airisu.u(10)
            Layout.alignment: Qt.AlignVCenter
            circular: false
            radius: 0
            source: MediaArtwork.displaySource
        }
        Column {
            Layout.fillWidth: true
            Layout.maximumWidth: Math.round(260 * root.d)
            Layout.alignment: Qt.AlignVCenter
            spacing: Math.round(2 * root.d)
            AText {
                width: parent.width
                visible: text.length > 0
                size: IrisStyle.typeFootnote
                font.weight: Font.Bold
                color: root.inkSecond
                text: root.osd?.mediaArtist ?? ""
            }
            AText {
                width: parent.width
                size: IrisStyle.typeLabel
                font.weight: Font.Bold
                color: root.ink
                text: (root.osd?.mediaTitle ?? "").length > 0 ? root.osd.mediaTitle : Translation.tr("Now playing")
            }
        }
        MaterialSymbol {
            visible: (root.osd?.mediaAction ?? "").length > 0
            Layout.alignment: Qt.AlignVCenter
            text: root.osd?.mediaIcon ?? "play_arrow"
            fill: 1
            iconSize: Math.round(22 * root.d)
            color: root.ink
        }
    }

    // A connection: its sign, what it is over how, and a figure when it has one.
    Slot {
        id: connectionRow
        readonly property string tone: root.osd?.connection?.tone ?? ""
        MaterialSymbol {
            Layout.alignment: Qt.AlignVCenter
            text: root.osd?.connection?.icon ?? ""
            fill: 1
            iconSize: Math.round(22 * root.d)
            color: connectionRow.tone === "off" ? root.inkThird : root.ink
        }
        Column {
            id: connectionWords
            Layout.fillWidth: true
            Layout.maximumWidth: Math.round(260 * root.d)
            Layout.alignment: Qt.AlignVCenter
            spacing: Math.round(2 * root.d)
            AText {
                width: parent.width
                size: IrisStyle.typeLabel
                font.weight: Font.Bold
                color: root.ink
                text: root.osd?.connection?.title ?? ""
            }
            AText {
                width: parent.width
                visible: text.length > 0
                size: IrisStyle.typeFootnote
                font.weight: Font.Medium
                color: root.inkSecond
                text: root.osd?.connection?.detail ?? ""
            }
        }
        AText {
            visible: (root.osd?.connection?.value ?? -1) >= 0
            Layout.alignment: Qt.AlignVCenter
            voice: "figure"
            lean: Airisu.lean
            size: IrisStyle.typeTitle
            color: root.ink
            text: Math.round(root.osd?.connection?.value ?? 0) + "%"
        }
    }

    // A volume held back: under the caution's band, its sign in yamabuki and why.
    Slot {
        id: warningRow
        MaterialSymbol {
            Layout.alignment: Qt.AlignVCenter
            text: "volume_off"
            fill: 1
            iconSize: Math.round(22 * root.d)
            color: Airisu.caution
        }
        Column {
            id: warningWords
            Layout.fillWidth: true
            Layout.maximumWidth: Math.round(260 * root.d)
            Layout.alignment: Qt.AlignVCenter
            spacing: Math.round(2 * root.d)
            AText {
                width: parent.width
                size: IrisStyle.typeLabel
                font.weight: Font.Bold
                color: root.ink
                text: Translation.tr("Volume held back")
            }
            AText {
                width: parent.width
                visible: text.length > 0
                size: IrisStyle.typeFootnote
                font.weight: Font.Medium
                color: root.inkSecond
                text: root.osd?.warningText ?? ""
            }
        }
    }
}
