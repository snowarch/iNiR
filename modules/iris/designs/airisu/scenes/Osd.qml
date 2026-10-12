pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.bar.island
import "../components"

// AIRISU's OSD, where the Island is not there to answer (SYSTEM.md §7): a stamp's impression. A level is the LED board
// with its figure set large and its name as ruby; Bar slims the board and Minimal prints the level as the postmark round
// the mark. A keyboard lock is its lamp and a layout its keycap; a song is its cover and title; a connection is set like
// a banner, its line a band on the foot; a volume held back runs caution tape there. IrisOSD keeps when, where, how long
// and the body, so every row of Feedback in Settings still means what it says.
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
    implicitHeight: Math.round(root.current.implicitHeight + 2 * root.rise)

    // Each time it comes up, the stamp lands a step out of register and settles.
    property bool fresh: false
    readonly property bool opened: root.osd?.open ?? false
    onOpenedChanged: if (root.opened && Airisu.moving) { root.fresh = true; settle.restart() }
    Timer { id: settle; interval: Airisu.snap; onTriggered: root.fresh = false }

    component Slot: RowLayout {
        id: slot
        x: root.pad
        y: root.rise
        width: root.width - 2 * root.pad
        height: root.height - 2 * root.rise
        visible: root.current === slot
        spacing: Airisu.u(3)
        transform: Translate { x: root.fresh ? Airisu.registration : 0; y: root.fresh ? Airisu.registration : 0 }
    }
    // A line as a station sign draws it: a short band on the foot, under the words.
    component Band: Rectangle {
        y: root.height - height
        width: Airisu.u(8)
        height: Airisu.m
    }

    // A level: the mark, its name over the board, the figure.
    Slot {
        id: levelRow
        readonly property string name: root.kind === "brightness" ? Translation.tr("Brightness")
            : root.kind === "mic" ? Translation.tr("Microphone") : Translation.tr("Volume")
        readonly property color ink: root.muted ? Airisu.inkThird : Airisu.ink
        Item {
            implicitWidth: Airisu.u(8)
            implicitHeight: Airisu.u(8)
            Layout.alignment: Qt.AlignVCenter
            ProgressRing {
                anchors.fill: parent
                visible: root.minimal
                progress: root.value
                tint: levelRow.ink
                stroke: Math.round(3 * root.d)
            }
            MaterialSymbol {
                anchors.centerIn: parent
                text: root.osd?.icon ?? "volume_up"
                fill: 1
                iconSize: Math.round((root.minimal ? 16 : 22) * root.d)
                color: levelRow.ink
            }
        }
        Column {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: Airisu.u(1.5)
            AText {
                width: parent.width
                voice: "ruby"
                text: root.muted ? Translation.tr("Muted") : levelRow.name
            }
            ALed {
                visible: !root.minimal
                width: parent.width
                height: root.style === "bar" ? Airisu.m : Airisu.u(2)
                value: root.value
                dim: root.muted
            }
        }
        AText {
            visible: root.osd?.levelFigure ?? true
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: hundred.advanceWidth
            horizontalAlignment: Text.AlignRight
            voice: "figure"
            size: IrisStyle.typeDisplay
            color: levelRow.ink
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
    }

    // A lock is its lamp, lit while it holds; a layout is its keycap.
    Slot {
        id: keyRow
        readonly property bool layout: (root.osd?.keyboardIcon ?? "") === "language"
        readonly property bool active: root.osd?.keyboardActive ?? false
        Rectangle {
            visible: !keyRow.layout
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: Airisu.u(2.5)
            implicitHeight: Airisu.u(2.5)
            color: keyRow.active ? Airisu.seal : Airisu.groundRaised
        }
        ADie {
            visible: keyRow.layout
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: Math.max(Airisu.u(9), Math.min(Airisu.u(18), legend.implicitWidth + Airisu.u(4)))
            implicitHeight: Airisu.u(9)
            kind: "rect"
            stroke: Airisu.ink
            strokeWidth: Airisu.hair
            AText {
                id: legend
                anchors.centerIn: parent
                width: Math.min(implicitWidth, parent.width - Airisu.u(2))
                voice: "figure"
                size: IrisStyle.typeTitle
                text: root.osd?.keyboardText ?? ""
            }
        }
        AText {
            Layout.fillWidth: true
            Layout.maximumWidth: Math.round(240 * root.d)
            Layout.alignment: Qt.AlignVCenter
            size: IrisStyle.typeBody
            font.weight: Font.Bold
            color: keyRow.layout || keyRow.active ? Airisu.ink : Airisu.inkSecond
            text: keyRow.layout ? Translation.tr("Keyboard layout") : (root.osd?.keyboardText ?? "")
        }
    }

    // A song: its cover, the artist as ruby over the title, what the key did.
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
                voice: "ruby"
                text: root.osd?.mediaArtist ?? ""
            }
            AText {
                width: parent.width
                size: IrisStyle.typeLabel
                font.weight: Font.Bold
                text: (root.osd?.mediaTitle ?? "").length > 0 ? root.osd.mediaTitle : Translation.tr("Now playing")
            }
        }
        MaterialSymbol {
            visible: (root.osd?.mediaAction ?? "").length > 0
            Layout.alignment: Qt.AlignVCenter
            text: root.osd?.mediaIcon ?? "play_arrow"
            fill: 1
            iconSize: Math.round(22 * root.d)
            // Playing is live: the seal. Every other key is the ink.
            color: (root.osd?.mediaAction ?? "") === "play" ? Airisu.sealText : Airisu.ink
        }
    }

    // A connection: set like a banner, with the line it belongs to on the foot.
    Slot {
        id: connectionRow
        readonly property string tone: root.osd?.connection?.tone ?? ""
        MaterialSymbol {
            Layout.alignment: Qt.AlignVCenter
            text: root.osd?.connection?.icon ?? ""
            fill: 1
            iconSize: Math.round(22 * root.d)
            color: connectionRow.tone === "off" ? Airisu.inkThird : connectionRow.tone === "warn" ? Airisu.caution : Airisu.ink
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
                text: root.osd?.connection?.title ?? ""
            }
            AText {
                width: parent.width
                visible: text.length > 0
                voice: "ruby"
                text: root.osd?.connection?.detail ?? ""
            }
        }
        AText {
            visible: (root.osd?.connection?.value ?? -1) >= 0
            Layout.alignment: Qt.AlignVCenter
            voice: "figure"
            size: IrisStyle.typeTitle
            text: Math.round(root.osd?.connection?.value ?? 0) + "%"
        }
    }
    Band {
        visible: connectionRow.visible && connectionRow.tone !== "off"
        x: connectionRow.x + connectionWords.x
        color: root.osd?.connectionTint ?? Airisu.rule
    }

    // A volume held back: the caution plate, why, and tape on the foot.
    Slot {
        id: warningRow
        ADie {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: Airisu.u(8)
            implicitHeight: Airisu.u(8)
            kind: "rect"
            fill: Airisu.caution
            MaterialSymbol {
                anchors.centerIn: parent
                text: "volume_off"
                fill: 1
                iconSize: Math.round(18 * root.d)
                color: Airisu.inkOnCaution
            }
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
                text: Translation.tr("Volume held back")
            }
            AText {
                width: parent.width
                visible: text.length > 0
                voice: "ruby"
                text: root.osd?.warningText ?? ""
            }
        }
    }
    ACautionTape {
        visible: warningRow.visible
        x: warningRow.x + warningWords.x
        y: root.height - height
        width: root.width - x - root.pad
    }
}
