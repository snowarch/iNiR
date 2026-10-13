pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.bar.island
import "../components"

// AIRISU's Island face. The engine (IrisIsland) decides the mode, the events, the levels, the clock style and the size;
// this lacquers the strip in the pigment of what it is showing and sets the one thing it says as type cut out of the
// lacquer. Only a notice and a recording lacquer the strip (the
// caution's yamabuki for a warning); at rest it is the body with the time cut in its ink. Whatever runs (the song, the timer, a task, a level) is the second coat, its 45° edge
// travelling across the strip; a change of subject repaints the strip along the same cut instead of fading.
Item {
    id: root
    property var island: null
    readonly property real d: Airisu.d
    readonly property string mode: root.island?.compactMode ?? "idle"
    readonly property real h: root.island?.compactHeight ?? 42
    readonly property real pad: Math.round(14 * root.d)
    // What the engine sizes the strip from: the current mode's own content, without the strip's breathing.
    readonly property real contentWidth: (root.rows[root.mode]?.implicitWidth ?? 0) + 2 * root.pad - Math.round(29 * root.d)
    readonly property var rows: ({ idle: idle, clock: idle, media: media, record: record, timer: timer, task: task,
        edit: edit, event: event, feedback: level })
    readonly property real figure: Math.round(IrisStyle.typeHeadline * IrisStyle.typeScale * (root.island?.clockScale ?? 1))
    // A strip tall enough stacks a second line under the first; a slim one keeps everything on one line.
    readonly property bool stacks: root.h >= Math.round(34 * root.d)

    // ── What the strip is lacquered with, mode by mode.
    readonly property color eventTint: root.island?.event?.tint ?? IrisStyle.accentFill
    readonly property bool eventCaution: Qt.colorEqual(root.eventTint, IrisStyle.danger) || Qt.colorEqual(root.eventTint, IrisStyle.warning)
    readonly property string levelIcon: String(root.island?.feedbackIcon ?? "volume_up")
    readonly property color levelPigment: root.levelIcon.indexOf("bright") >= 0 || root.levelIcon.indexOf("light") >= 0
        ? Airisu.pigment("caution") : root.levelIcon.indexOf("mic") >= 0 ? Airisu.pigment("time")
        : root.levelIcon.indexOf("volume") >= 0 || root.levelIcon.indexOf("speaker") >= 0 ? Airisu.pigment("music")
        : Airisu.pigment("system")
    readonly property color pigment: {
        switch (root.mode) {
        case "media": return Airisu.pigment("music")
        case "record": return Airisu.pigment("live")
        case "timer": return Airisu.pigment("time")
        case "task": return Airisu.pigment("rest")
        case "edit": return Airisu.pigment("system")
        case "event": return root.eventCaution ? Airisu.pigment("caution") : Airisu.pigment("rest")
        case "feedback": return root.island?.feedbackMuted ? Airisu.pigment("system") : root.levelPigment
        default: return Airisu.pigment("rest")
        }
    }
    // The strip is the body itself: only a notice and a recording lacquer it, the one thing that must be seen from across
    // the room.
    readonly property color surface: root.mode === "event" ? (root.eventCaution ? Airisu.vivid(root.pigment) : Airisu.coat(root.pigment))
        : root.mode === "record" ? Airisu.coat(root.pigment) : "transparent"
    readonly property bool barLevel: root.mode === "feedback" && root.levelStyle === "bar"
    // A level fills the strip as a meter does; anything else that runs is a band of shu along its foot.
    readonly property bool fills: root.mode === "feedback" && !root.barLevel
    readonly property color coatColour: root.fills ? Airisu.coat(root.pigment) : Airisu.vivid(root.pigment)
    // Type over a coat that runs the whole height takes the ink that reads on both coats.
    readonly property color ink: root.run > 0 && root.fills ? Airisu.inkOver(root.surface, root.coatColour) : Airisu.inkOn(root.surface)
    readonly property color inkSecond: ColorUtils.mix(root.ink, root.surface, 0.74) // iris-literal: second tone on lacquer
    readonly property color inkThird: ColorUtils.mix(root.ink, root.surface, 0.52)  // iris-literal: third tone on lacquer

    // What runs, as the second coat: how far, and whether it is moving now.
    readonly property string levelStyle: root.island?.levelStyle ?? "capsule"
    readonly property real run: root.mode === "media" ? (root.island?.trackProgress ?? 0)
        : root.mode === "timer" ? (root.island?.timerProgress ?? 0)
        : root.mode === "task" ? Math.max(0, Number(root.island?.task?.progress ?? 0))
        : root.mode === "feedback" && root.levelStyle !== "minimal" ? (root.island?.feedbackValue ?? 0) : 0

    // The panel keeps only the cuts its body shows: welded to the band (the notch) the body hangs square from it and only
    // its far corner is cut, so the panel is cut there alone and stays concentric with it; floating, both.
    readonly property bool welded: root.island?.notch ?? false
    readonly property bool atFoot: root.island?.bottomEdge ?? false
    readonly property int kiss: Math.max(2, Math.round(3 * root.d))
    ALacquer {
        id: panel
        anchors.fill: parent
        anchors.margins: root.kiss
        cut: Math.max(2, Airisu.chamfer - root.kiss)
        cutTopRight: !root.welded || root.atFoot
        cutBottomLeft: !root.welded || !root.atFoot
        lacquer: root.surface
        coat: root.coatColour
        band: root.fills ? 0 : root.barLevel ? Math.max(3, Math.round(panel.height * 0.22)) : Math.max(2, Math.round(panel.height * 0.09))
        share: root.run
        // A level follows the hand; a song and a timer step once a second (a pixel or two, no animation to pay for).
        travel: root.mode === "feedback" ? Airisu.detent : root.mode === "task" ? Airisu.snap : 0
    }

    // The time in the figures' face.
    component Time: AText {
        property real figureSize: root.figure
        voice: "figure"
        size: figureSize
        color: root.ink
        text: String(DateTime.timeDisplay)
    }

    // A small mark: AIRISU draws marks in the strip's ink, never on a plate of their own.
    component Mark: MaterialSymbol {
        iconSize: Math.round(17 * root.d)
        fill: 1
        color: root.ink
    }

    // A row of the strip, laid at the strip's width, shown only in its mode. Changing mode is a detent, not a fade.
    component Face: RowLayout {
        id: face
        property int enter: Airisu.detent
        property int leave: Airisu.detent
        readonly property bool current: root.rows[root.mode] === face
        anchors.fill: parent
        anchors.leftMargin: root.pad
        anchors.rightMargin: root.pad
        spacing: Airisu.u(2.5)
        opacity: face.current ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { enabled: Airisu.moving; NumberAnimation { duration: face.current ? face.enter : face.leave; easing.type: Easing.BezierSpline; easing.bezierCurve: Airisu.curve } }
    }

    // The clock, by the style Settings asks for: the time alone, or with the date or the weather set small before it.
    Face {
        id: idle
        readonly property string style: root.island?.clockStyle ?? "time"
        readonly property string gloss: idle.style === "dateTime"
            ? Translation.locale.toString(DateTime.clock.date, "ddd d").replace(/\./g, "")
            : idle.style === "weather" ? String(Weather.data?.temp ?? "") : ""
        Item { Layout.fillWidth: true }
        MaterialSymbol {
            visible: idle.style === "weather" && idle.gloss.length > 0
            Layout.alignment: Qt.AlignVCenter
            text: Icons.getWeatherIcon(Weather.data?.wCode, Weather.isNightNow()) ?? "cloud"
            iconSize: Math.round(16 * root.d)
            fill: 1
            color: root.inkSecond
        }
        // The date is ruby (ルビ): set small over the time where the strip stacks, the way furigana sits over its word;
        // a slim strip and the weather keep it on the line, before the figure.
        readonly property bool ruby: idle.style === "dateTime" && root.stacks
        AText {
            visible: idle.gloss.length > 0 && !idle.ruby
            Layout.alignment: Qt.AlignVCenter
            Layout.rightMargin: Airisu.u(0.5)
            size: IrisStyle.typeMeta
            font.weight: Font.Bold
            text: idle.gloss
            color: root.inkSecond
        }
        Column {
            Layout.alignment: Qt.AlignVCenter
            spacing: Math.round(-2 * root.d)
            AText {
                visible: idle.ruby && idle.gloss.length > 0
                voice: "ruby"
                font.weight: Font.Bold
                color: root.inkSecond
                text: idle.gloss
            }
            Time {}
        }
        Item { Layout.fillWidth: true }
    }

    // Music: the cover as a print set into the lacquer, the title and under it the artist; playing is the coat moving,
    // so only a pause needs a mark.
    Face {
        id: media
        Item {
            Layout.preferredWidth: Math.round(root.h * 0.62)
            Layout.preferredHeight: Layout.preferredWidth
            Layout.alignment: Qt.AlignVCenter
            IrisArtwork {
                anchors.fill: parent
                source: MediaArtwork.displaySource
                radius: 0
                decodeSize: Math.ceil(parent.width * 2)
            }
        }
        Column {
            Layout.fillWidth: true
            Layout.maximumWidth: Math.round(200 * root.d)
            Layout.alignment: Qt.AlignVCenter
            spacing: Math.round(-1 * root.d)
            AText {
                width: Math.min(implicitWidth, Math.round(200 * root.d))
                text: StringUtils.cleanMusicTitle(root.island?.title ?? "")
                size: IrisStyle.typeLabel
                font.weight: Font.Bold
                color: root.ink
            }
            AText {
                visible: root.stacks && text.length > 0
                width: Math.min(implicitWidth, Math.round(200 * root.d))
                text: String(MprisController.artistOf(root.island?.player) ?? "")
                size: IrisStyle.typeMeta
                font.weight: Font.Medium
                color: root.inkSecond
            }
        }
        Mark {
            visible: !(root.island?.playing ?? false)
            Layout.alignment: Qt.AlignVCenter
            text: "pause"
            color: root.inkSecond
        }
    }

    Face {
        id: record
        // The lamp: the one live mark, on and off at a slow beat.
        Rectangle {
            Layout.preferredWidth: Airisu.u(2)
            Layout.preferredHeight: Layout.preferredWidth
            Layout.alignment: Qt.AlignVCenter
            radius: width / 2
            color: root.ink
            SequentialAnimation on opacity {
                running: root.mode === "record" && Airisu.moving
                loops: Animation.Infinite
                PropertyAction { value: 1 }
                PauseAnimation { duration: 700 }
                PropertyAction { value: 0.3 }
                PauseAnimation { duration: 500 }
            }
        }
        AText {
            Layout.fillWidth: true
            text: Translation.tr("Recording")
            size: IrisStyle.typeLabel
            font.weight: Font.Bold
            color: root.ink
        }
        AText {
            voice: "figure"
            size: root.figure
            color: root.ink
            text: root.island?.clockText(RecorderStatus.elapsedSeconds) ?? ""
        }
    }

    Face {
        id: timer
        readonly property bool paused: root.island?.timerPaused ?? false
        Mark {
            text: timer.paused ? "pause" : (root.island?.timerGlyph ?? "timer")
            color: timer.paused ? root.inkSecond : root.ink
        }
        AText {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            text: root.island?.timerLabel ?? ""
            size: IrisStyle.typeMeta
            font.weight: Font.Bold
            color: root.inkSecond
        }
        AText {
            voice: "figure"
            size: root.figure
            color: timer.paused ? root.inkSecond : root.ink
            text: root.island?.clockText(root.island?.timerSeconds ?? 0) ?? ""
        }
    }

    Face {
        id: task
        Mark { text: String(root.island?.task?.glyph ?? "bolt") }
        Column {
            Layout.fillWidth: true
            Layout.maximumWidth: Math.round(200 * root.d)
            Layout.alignment: Qt.AlignVCenter
            spacing: Math.round(-1 * root.d)
            AText {
                width: Math.min(implicitWidth, Math.round(200 * root.d))
                text: String(root.island?.task?.title ?? "")
                size: IrisStyle.typeLabel
                font.weight: Font.Bold
                color: root.ink
            }
            AText {
                visible: root.stacks && text.length > 0
                width: Math.min(implicitWidth, Math.round(200 * root.d))
                text: String(root.island?.task?.detail ?? "")
                size: IrisStyle.typeMeta
                font.weight: Font.Medium
                color: root.inkSecond
            }
        }
        AText {
            visible: Number(root.island?.task?.progress ?? -1) >= 0
            voice: "figure"
            size: root.figure
            color: root.ink
            text: Math.round(Number(root.island?.task?.progress ?? 0) * 100) + "%"
        }
    }

    Face {
        id: edit
        Mark { text: "edit" }
        AText {
            Layout.fillWidth: true
            text: Translation.tr("Editing desktop")
            size: IrisStyle.typeLabel
            font.weight: Font.Bold
            color: root.ink
        }
        // The engine's press area ends editing; this is the key it presses, lacquered in the accent.
        ALacquer {
            Layout.preferredHeight: Math.round(root.h * 0.56)
            Layout.preferredWidth: doneLabel.implicitWidth + Airisu.u(5)
            Layout.alignment: Qt.AlignVCenter
            cut: Math.round(Layout.preferredHeight / 3)
            lacquer: Airisu.vivid(Airisu.pigment("rest"))
            AText {
                id: doneLabel
                anchors.centerIn: parent
                text: Translation.tr("Done")
                size: IrisStyle.typeMeta
                font.weight: Font.Bold
                color: Airisu.inkOn(Airisu.vivid(Airisu.pigment("rest")))
            }
        }
    }

    // A notice: the strip is repainted in the notice's colour from its start, and what it says is set on it.
    Face {
        id: event
        enter: 0
        leave: Airisu.tear
        Mark {
            text: root.island?.eventGlyph ?? ""
        }
        AText {
            Layout.fillWidth: true
            Layout.maximumWidth: Math.round(180 * root.d)
            text: root.island?.event?.title ?? ""
            color: root.ink
            size: IrisStyle.typeLabel
            font.weight: Font.Bold
        }
        AText {
            visible: text.length > 0 && (root.island?.event?.value ?? -1) < 0
            Layout.maximumWidth: Math.round(130 * root.d)
            text: root.island?.event?.detail ?? ""
            color: root.inkSecond
            size: IrisStyle.typeMeta
            font.weight: Font.Medium
        }
        AText {
            visible: (root.island?.event?.value ?? -1) >= 0
            voice: "figure"
            size: root.figure
            color: root.ink
            text: Math.round((root.island?.event?.value ?? 0) * 100) + "%"
        }
    }

    // A level while it moves: the coat is the level, the mark and the figure are set on it. Bar keeps the coat to a band
    // along the foot; Minimal leaves the lacquer bare and says the level in the figure alone.
    Face {
        id: level
        readonly property bool muted: root.island?.feedbackMuted ?? false
        Mark {
            text: root.levelIcon
            color: level.muted ? root.inkSecond : root.ink
        }
        Item { Layout.fillWidth: true; Layout.preferredWidth: Math.round(120 * root.d) }
        AText {
            visible: root.island?.levelFigure ?? true
            Layout.preferredWidth: Math.round(root.figure * 1.9)
            horizontalAlignment: Text.AlignRight
            voice: "figure"
            size: root.figure
            color: level.muted ? root.inkSecond : root.ink
            text: Math.round((root.island?.feedbackValue ?? 0) * 100)
        }
    }
}
