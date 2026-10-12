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

// AIRISU's Island face (SYSTEM.md §4: the Island is the sheet's main sticker). The engine (IrisIsland) decides the mode,
// the events, the levels, the clock style and the size; this prints each one. The secondary datum sits over the main one
// as ruby (the date over the time, the artist over the title); the time's colon is two seal squares, the strip's one
// colour at rest; anything that runs in time is punched tape along the foot; a notice is a stamp's impression, set
// down whole and drying out; a level is the LED board.
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
    // Ruby needs a strip tall enough to stack two lines; a slim strip sets the datum on the time's line.
    readonly property bool stacks: root.h >= Math.round(34 * root.d)

    // The time in the figures' face; the colon is two seal squares.
    component Time: Row {
        id: time
        property real size: root.figure
        property color ink: Airisu.ink
        readonly property var parts: String(DateTime.timeDisplay).split(":")
        spacing: Math.max(2, Math.round(time.size * 0.14))
        AText {
            anchors.verticalCenter: parent.verticalCenter
            voice: "figure"
            size: time.size
            color: time.ink
            text: time.parts[0] ?? ""
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: Math.round(time.size * 0.04)
            spacing: Math.max(2, Math.round(time.size * 0.2))
            Repeater {
                model: 2
                Rectangle {
                    width: Math.max(2, Math.round(time.size * 0.15))
                    height: width
                    color: Airisu.seal
                }
            }
        }
        AText {
            anchors.verticalCenter: parent.verticalCenter
            voice: "figure"
            size: time.size
            color: time.ink
            text: (time.parts[1] ?? "").trim()
        }
    }

    // A datum with its ruby over it, left-aligned on one edge (furigana reads over the word it glosses).
    component Ruby: Column {
        id: ruby
        property string gloss: ""
        default property alias body: line.data
        spacing: 0
        AText {
            visible: ruby.gloss.length > 0 && root.stacks
            width: Math.min(implicitWidth, Math.round(200 * root.d))
            voice: "ruby"
            size: IrisStyle.typeCaption
            text: ruby.gloss
        }
        Item {
            id: line
            implicitWidth: childrenRect.width
            implicitHeight: childrenRect.height
        }
    }

    // A small mark: AIRISU draws marks, it does not plate them.
    component Mark: MaterialSymbol {
        iconSize: Math.round(17 * root.d)
        fill: 0
        color: Airisu.ink
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

    // The clock, by the style Settings asks for: the time alone, the date as its ruby, or the weather as its ruby.
    Face {
        id: idle
        readonly property string style: root.island?.clockStyle ?? "time"
        readonly property string gloss: idle.style === "dateTime"
            ? Translation.locale.toString(DateTime.clock.date, "ddd d MMM").replace(/\./g, "")
            : idle.style === "weather" ? String(Weather.data?.temp ?? "") : ""
        Item { Layout.fillWidth: true }
        // A slim strip: the date beside the time, in the ruby's ink.
        AText {
            visible: !root.stacks && idle.gloss.length > 0
            Layout.alignment: Qt.AlignVCenter
            voice: "ruby"
            text: idle.gloss
        }
        Column {
            Layout.alignment: Qt.AlignVCenter
            spacing: Math.round(-1 * root.d)
            Row {
                visible: root.stacks && idle.gloss.length > 0
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Airisu.u(1)
                MaterialSymbol {
                    visible: idle.style === "weather"
                    anchors.verticalCenter: parent.verticalCenter
                    text: Icons.getWeatherIcon(Weather.data?.wCode, Weather.isNightNow()) ?? "cloud"
                    iconSize: IrisStyle.typeMeta
                    color: Airisu.inkSecond
                }
                AText {
                    anchors.verticalCenter: parent.verticalCenter
                    voice: "ruby"
                    size: IrisStyle.typeCaption
                    text: idle.gloss
                }
            }
            Time { anchors.horizontalCenter: parent.horizontalCenter }
        }
        Item { Layout.fillWidth: true }
    }

    Face {
        id: media
        // The cover as a print laid on the strip: square, its own edge a rule.
        Rectangle {
            Layout.preferredWidth: Math.round(root.h * 0.58)
            Layout.preferredHeight: Layout.preferredWidth
            color: Airisu.groundRaised
            IrisArtwork {
                anchors.fill: parent
                source: MediaArtwork.displaySource
                radius: 0
                decodeSize: Math.ceil(parent.width * 2)
            }
        }
        Ruby {
            Layout.fillWidth: true
            Layout.maximumWidth: Math.round(190 * root.d)
            Layout.alignment: Qt.AlignVCenter
            gloss: String(MprisController.artistOf(root.island?.player) ?? "")
            AText {
                width: Math.min(implicitWidth, Math.round(190 * root.d))
                text: StringUtils.cleanMusicTitle(root.island?.title ?? "")
                size: IrisStyle.typeLabel
                font.weight: Font.Bold
            }
        }
        // Playing is the seal lit; paused, the seal is only its outline.
        Rectangle {
            Layout.preferredWidth: Airisu.u(2)
            Layout.preferredHeight: Layout.preferredWidth
            color: root.island?.playing ? Airisu.seal : "transparent"
            border.width: root.island?.playing ? 0 : Airisu.hair
            border.color: Airisu.inkSecond
        }
    }

    Face {
        id: record
        Rectangle {
            Layout.preferredWidth: Airisu.u(2.5)
            Layout.preferredHeight: Layout.preferredWidth
            color: Airisu.seal
            // The recording lamp: on, off, a slow beat (the seal is what is live).
            SequentialAnimation on opacity {
                running: root.mode === "record" && Airisu.moving
                loops: Animation.Infinite
                PropertyAction { value: 1 }
                PauseAnimation { duration: 700 }
                PropertyAction { value: 0.25 }
                PauseAnimation { duration: 500 }
            }
        }
        AText {
            Layout.fillWidth: true
            text: Translation.tr("Recording")
            size: IrisStyle.typeLabel
            font.weight: Font.Bold
        }
        AText {
            voice: "figure"
            size: root.figure
            color: Airisu.sealText
            text: root.island?.clockText(RecorderStatus.elapsedSeconds) ?? ""
        }
    }

    Face {
        id: timer
        readonly property bool paused: root.island?.timerPaused ?? false
        Mark {
            text: timer.paused ? "pause" : (root.island?.timerGlyph ?? "timer")
            color: timer.paused ? Airisu.inkThird : Airisu.ink
        }
        Item { Layout.fillWidth: true }
        Ruby {
            Layout.alignment: Qt.AlignVCenter
            gloss: root.island?.timerLabel ?? ""
            AText {
                voice: "figure"
                size: root.figure
                color: timer.paused ? Airisu.inkThird : Airisu.ink
                text: root.island?.clockText(root.island?.timerSeconds ?? 0) ?? ""
            }
        }
    }

    Face {
        id: task
        // The task's line colour, as a station sign carries its line.
        Rectangle {
            Layout.preferredWidth: Airisu.u(1)
            Layout.preferredHeight: Math.round(root.h * 0.5)
            color: Airisu.band(String(root.island?.task?.tint ?? "lavender"))
        }
        Mark { text: String(root.island?.task?.glyph ?? "bolt") }
        Ruby {
            Layout.fillWidth: true
            Layout.maximumWidth: Math.round(190 * root.d)
            Layout.alignment: Qt.AlignVCenter
            gloss: String(root.island?.task?.detail ?? "")
            AText {
                width: Math.min(implicitWidth, Math.round(190 * root.d))
                text: String(root.island?.task?.title ?? "")
                size: IrisStyle.typeLabel
                font.weight: Font.Bold
            }
        }
        AText {
            visible: Number(root.island?.task?.progress ?? -1) >= 0
            voice: "figure"
            size: root.figure
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
        }
        // The engine's press area ends editing; this is the seal it presses.
        ADie {
            Layout.preferredHeight: Math.round(root.h * 0.6)
            Layout.preferredWidth: doneLabel.implicitWidth + Airisu.u(5)
            kind: "chamfer"
            fill: Airisu.seal
            AText {
                id: doneLabel
                anchors.centerIn: parent
                text: Translation.tr("Done")
                size: IrisStyle.typeMeta
                font.weight: Font.Bold
                color: Airisu.inkOnSeal
            }
        }
    }

    // A notice is a stamp's impression: it is set down whole, the first moment a touch heavy (the plate pressed, its
    // under-plate showing), then it settles; it leaves as ink that dries, never sliding. Caution prints in yamabuki.
    Face {
        id: event
        anchors.leftMargin: Airisu.u(1.5)
        anchors.rightMargin: Airisu.u(1.5)
        readonly property color tint: root.island?.event?.tint ?? Airisu.ink
        readonly property bool caution: Qt.colorEqual(event.tint, IrisStyle.danger) || Qt.colorEqual(event.tint, IrisStyle.warning)
        readonly property color ink: event.caution ? Airisu.inkOnCaution : Airisu.reverse
        readonly property bool shown: root.mode === "event"
        property bool fresh: false
        onShownChanged: if (event.shown && Airisu.moving) { event.fresh = true; settle.restart() }
        Timer { id: settle; interval: Airisu.snap; onTriggered: event.fresh = false }
        enter: 0
        leave: Airisu.tear
        APrint {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: Airisu.u(1.5)
            Layout.bottomMargin: Airisu.u(1.5)
            implicitWidth: stamp.implicitWidth + Airisu.u(6)
            die: "chamfer"
            pressed: event.fresh
            fill: event.caution ? Airisu.caution : Airisu.ink
            under: event.caution ? Airisu.caution : Airisu.inkUnder
            RowLayout {
                id: stamp
                anchors.fill: parent
                anchors.leftMargin: Airisu.u(2.5)
                anchors.rightMargin: Airisu.u(3)
                spacing: Airisu.u(2)
                Mark {
                    text: root.island?.eventGlyph ?? ""
                    color: event.ink
                    fill: 1
                }
                AText {
                    Layout.fillWidth: true
                    Layout.maximumWidth: Math.round(170 * root.d)
                    text: root.island?.event?.title ?? ""
                    color: event.ink
                    size: IrisStyle.typeLabel
                    font.weight: Font.Bold
                }
                AText {
                    visible: text.length > 0 && (root.island?.event?.value ?? -1) < 0
                    Layout.maximumWidth: Math.round(120 * root.d)
                    text: root.island?.event?.detail ?? ""
                    color: event.ink
                    size: IrisStyle.typeMeta
                    font.weight: Font.Medium
                }
                AText {
                    visible: (root.island?.event?.value ?? -1) >= 0
                    voice: "figure"
                    size: root.figure
                    color: event.ink
                    text: Math.round((root.island?.event?.value ?? 0) * 100) + "%"
                }
            }
        }
    }

    // A level, while it moves, is the LED board: the mark, the cells, the figure. Bar slims the board; Minimal drops
    // it and prints the level as the postmark round the mark.
    Face {
        id: level
        readonly property string style: root.island?.levelStyle ?? "capsule"
        readonly property bool minimal: level.style === "minimal"
        readonly property bool muted: root.island?.feedbackMuted ?? false
        readonly property color ink: level.muted ? Airisu.inkThird : Airisu.ink
        Item {
            implicitWidth: level.minimal ? Math.max(Airisu.u(6), Math.round(root.h * 0.66)) : mark.implicitWidth
            implicitHeight: implicitWidth
            ProgressRing {
                anchors.fill: parent
                visible: level.minimal
                progress: root.island?.feedbackValue ?? 0
                tint: level.ink
                stroke: Math.round(2 * root.d)
            }
            Mark {
                id: mark
                anchors.centerIn: parent
                iconSize: Math.round((level.minimal ? 13 : 17) * root.d)
                text: root.island?.feedbackIcon ?? "volume_up"
                color: level.ink
            }
        }
        ALed {
            visible: !level.minimal
            Layout.fillWidth: true
            Layout.preferredWidth: Math.round(156 * root.d)
            Layout.preferredHeight: level.style === "bar" ? Airisu.m : Airisu.u(2)
            value: root.island?.feedbackValue ?? 0
            dim: level.muted
        }
        AText {
            visible: root.island?.levelFigure ?? true
            Layout.preferredWidth: Math.round(root.figure * 2)
            horizontalAlignment: Text.AlignRight
            voice: "figure"
            size: root.figure
            color: level.ink
            text: Math.round((root.island?.feedbackValue ?? 0) * 100)
        }
    }

    // Whatever runs in time runs as tape along the strip's foot, inside the die's cuts.
    ATape {
        readonly property bool runs: root.mode === "media" || root.mode === "timer" || root.mode === "task"
        visible: runs && value > 0
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: Math.max(root.pad, Airisu.chamfer + Airisu.u(1))
        anchors.rightMargin: Math.max(root.pad, Airisu.chamfer + Airisu.u(1))
        anchors.bottomMargin: Airisu.u(1)
        height: Airisu.u(1.5)
        head: false
        live: root.mode !== "media" || (root.island?.playing ?? false)
        value: root.mode === "media" ? (root.island?.trackProgress ?? 0)
            : root.mode === "timer" ? (root.island?.timerProgress ?? 0)
            : root.mode === "task" ? Math.max(0, Number(root.island?.task?.progress ?? 0)) : 0
    }
}
