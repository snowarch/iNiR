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
import "../components"

// AIRISU's Island face. The engine (IrisIsland) decides the mode, the events, the levels and the size class; this draws
// each one as an instrument at night: figures are wide and lit, the colon of the time is two seal squares, anything that
// runs in time leaves a light trail along the plate's lower edge, a notice is a gofun sticker pressed on, and a level is
// the plate turned into a twenty-segment meter.
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
    readonly property real figure: Math.round(15 * IrisStyle.typeScale * (root.island?.clockScale ?? 1))

    // The light trail: a long exposure of where a run is, brightening toward its head; the head is the seal.
    component Trail: Item {
        id: trail
        property real progress: 0
        property bool live: true
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: Airisu.cut
        anchors.rightMargin: Airisu.cut
        height: Math.max(2, Math.round(2 * root.d))
        visible: trail.progress > 0
        Rectangle {
            width: Math.round(trail.width * Math.max(0, Math.min(1, trail.progress)))
            height: parent.height
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.7; color: Qt.alpha(Airisu.gofun, 0.35) } // iris-literal: the trail fades into the lacquer
                GradientStop { position: 1; color: Airisu.gofun }
            }
            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(6 * root.d)
                height: parent.height
                color: trail.live ? Airisu.seal : Airisu.quiet
            }
        }
    }

    // The time in wide figures; the colon is two seal squares, the only colour on a resting strip.
    component Time: Row {
        id: time
        property real size: root.figure
        property color ink: Airisu.gofun
        readonly property var parts: String(DateTime.timeDisplay).split(":")
        spacing: Math.round(time.size * 0.16)
        AText {
            id: hours
            anchors.verticalCenter: parent.verticalCenter
            voice: "wide"
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
                    width: Math.max(2, Math.round(time.size * 0.16))
                    height: width
                    color: Airisu.seal
                }
            }
        }
        AText {
            anchors.verticalCenter: parent.verticalCenter
            voice: "wide"
            size: time.size
            color: time.ink
            text: (time.parts[1] ?? "").trim()
        }
    }

    // A small mark as a line glyph: AIRISU draws marks, it does not plate them.
    component Mark: MaterialSymbol {
        iconSize: Math.round(17 * root.d)
        fill: 0
        color: Airisu.gofun
    }

    // A row of the strip, laid at the strip's width, shown only in its mode.
    component Face: RowLayout {
        id: face
        property string kind: ""
        anchors.fill: parent
        anchors.leftMargin: root.pad
        anchors.rightMargin: root.pad
        spacing: Math.round(10 * root.d)
        opacity: root.rows[root.mode] === face ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { enabled: IrisStyle.motionEnabled; NumberAnimation { duration: Airisu.shift; easing.type: Easing.BezierSpline; easing.bezierCurve: Airisu.curve } }
    }

    Face {
        id: idle
        Item { Layout.fillWidth: true; visible: root.mode === "clock" }
        Row {
            visible: root.island?.clockStyle === "dateTime"
            spacing: Math.round(6 * root.d)
            AText {
                anchors.baseline: dayNumber.baseline
                text: Translation.locale.toString(DateTime.clock.date, "ddd").replace(/\.$/, "").toLowerCase()
                color: Airisu.data
                size: IrisStyle.typeMeta
                font.weight: Font.Medium
            }
            AText {
                id: dayNumber
                voice: "wide"
                size: Math.round(root.figure * 0.8)
                color: Airisu.data
                text: Translation.locale.toString(DateTime.clock.date, "d")
            }
        }
        Row {
            visible: root.island?.clockStyle === "weather"
            spacing: Math.round(6 * root.d)
            Mark {
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.getWeatherIcon(Weather.data?.wCode, Weather.isNightNow()) ?? "cloud"
                color: Airisu.data
            }
            AText {
                anchors.verticalCenter: parent.verticalCenter
                voice: "wide"
                size: Math.round(root.figure * 0.8)
                color: Airisu.data
                text: String(Weather.data?.temp ?? "").replace(/[CF]$/, "")
            }
        }
        Item { Layout.fillWidth: true }
        Time { Layout.alignment: Qt.AlignVCenter }
        Item { Layout.fillWidth: true; visible: root.mode === "clock" }
    }

    Face {
        id: media
        // The cover is a sticker: square, cut at its upper right like every AIRISU body.
        Item {
            Layout.preferredWidth: Math.round(24 * root.d)
            Layout.preferredHeight: Layout.preferredWidth
            IrisArtwork {
                anchors.fill: parent
                source: MediaArtwork.displaySource
                radius: 0
                decodeSize: Math.ceil(parent.width * 2)
            }
            Rectangle {
                width: Math.round(6 * root.d)
                height: width
                rotation: 45
                x: parent.width - width / 2
                y: -height / 2
                color: Airisu.lacquer
            }
        }
        AText {
            Layout.fillWidth: true
            Layout.maximumWidth: Math.round(190 * root.d)
            text: StringUtils.cleanMusicTitle(root.island?.title ?? "")
            size: IrisStyle.typeLabel
        }
        // Playing is the seal lit; paused, the seal goes out to an outline.
        Rectangle {
            Layout.preferredWidth: Math.round(7 * root.d)
            Layout.preferredHeight: Layout.preferredWidth
            color: root.island?.playing ? Airisu.seal : "transparent"
            border.width: root.island?.playing ? 0 : Airisu.line
            border.color: Airisu.quiet
        }
        Time { size: Math.round(root.figure * 0.8); ink: Airisu.data }
    }

    Face {
        id: record
        Rectangle {
            Layout.preferredWidth: Math.round(10 * root.d)
            Layout.preferredHeight: Layout.preferredWidth
            color: Airisu.seal
            SequentialAnimation on opacity {
                running: root.mode === "record" && IrisStyle.motionEnabled
                loops: Animation.Infinite
                NumberAnimation { to: 0.35; duration: 600 }
                NumberAnimation { to: 1; duration: 600 }
            }
        }
        AText {
            Layout.fillWidth: true
            text: Translation.tr("Recording")
            size: IrisStyle.typeLabel
        }
        AText {
            voice: "wide"
            size: root.figure
            color: Airisu.sealText
            text: root.island?.clockText(RecorderStatus.elapsedSeconds) ?? ""
        }
    }

    Face {
        id: timer
        Mark {
            text: root.island?.timerPaused ? "pause" : (root.island?.timerGlyph ?? "timer")
            color: root.island?.timerPaused ? Airisu.quiet : Airisu.gofun
        }
        AText {
            Layout.fillWidth: true
            text: root.island?.timerLabel ?? ""
            color: Airisu.data
            size: IrisStyle.typeMeta
        }
        AText {
            voice: "wide"
            size: root.figure
            color: root.island?.timerPaused ? Airisu.quiet : Airisu.gofun
            text: root.island?.clockText(root.island?.timerSeconds ?? 0) ?? ""
        }
    }

    Face {
        id: task
        Mark { text: String(root.island?.task?.glyph ?? "bolt") }
        AText {
            Layout.fillWidth: true
            Layout.maximumWidth: Math.round(190 * root.d)
            text: String(root.island?.task?.title ?? "")
            size: IrisStyle.typeLabel
        }
        AText {
            visible: Number(root.island?.task?.progress ?? -1) >= 0
            voice: "wide"
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
        }
        ASeal {
            Layout.preferredHeight: root.h - Math.round(12 * root.d)
            kind: "gofun"
            text: Translation.tr("Done")
            enabled: false // the engine's press area ends editing
        }
    }

    // A notice is a sticker pressed onto the strip: gofun, or amber for danger, inked in lacquer, put on with a
    // small turn that the press takes out.
    Face {
        id: event
        anchors.leftMargin: Math.round(6 * root.d)
        anchors.rightMargin: Math.round(6 * root.d)
        readonly property color tint: root.island?.event?.tint ?? Airisu.gofun
        readonly property bool danger: Qt.colorEqual(event.tint, IrisStyle.danger)
        Item {
            id: sticker
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: Math.round(6 * root.d)
            Layout.bottomMargin: Math.round(6 * root.d)
            implicitWidth: stickerRow.implicitWidth + Math.round(24 * root.d)
            rotation: root.mode === "event" ? 0 : -4
            scale: root.mode === "event" ? 1 : 1.08
            Behavior on rotation { enabled: IrisStyle.motionEnabled; NumberAnimation { duration: Airisu.roll; easing.type: Easing.BezierSpline; easing.bezierCurve: Airisu.curve } }
            Behavior on scale { enabled: IrisStyle.motionEnabled; NumberAnimation { duration: Airisu.roll; easing.type: Easing.BezierSpline; easing.bezierCurve: Airisu.curve } }
            APlate {
                anchors.fill: parent
                cuts: ["tr", "bl"]
                colour: event.danger ? Airisu.amber : Airisu.gofun
            }
            RowLayout {
                id: stickerRow
                anchors.fill: parent
                anchors.leftMargin: Math.round(10 * root.d)
                anchors.rightMargin: Math.round(12 * root.d)
                spacing: Math.round(8 * root.d)
                Mark {
                    text: root.island?.eventGlyph ?? ""
                    color: event.danger ? Airisu.inkOnAmber : Airisu.inkOnGofun
                    fill: 1
                }
                AText {
                    Layout.fillWidth: true
                    Layout.maximumWidth: Math.round(170 * root.d)
                    text: root.island?.event?.title ?? ""
                    color: event.danger ? Airisu.inkOnAmber : Airisu.inkOnGofun
                    size: IrisStyle.typeLabel
                    font.weight: Font.Bold
                }
                AText {
                    visible: text.length > 0 && (root.island?.event?.value ?? -1) < 0
                    Layout.maximumWidth: Math.round(120 * root.d)
                    text: root.island?.event?.detail ?? ""
                    color: event.danger ? Airisu.inkOnAmber : Airisu.inkOnGofun
                    opacity: 0.7
                    size: IrisStyle.typeFootnote
                }
                AText {
                    visible: (root.island?.event?.value ?? -1) >= 0
                    voice: "wide"
                    size: root.figure
                    color: event.danger ? Airisu.inkOnAmber : Airisu.inkOnGofun
                    text: Math.round((root.island?.event?.value ?? 0) * 100) + "%"
                }
            }
        }
    }

    // A level turns the strip into the meter: the mark, twenty segments, and the figure.
    Face {
        id: level
        readonly property bool minimal: root.island?.levelStyle === "minimal"
        Mark {
            visible: !level.minimal
            text: root.island?.feedbackIcon ?? "volume_up"
            color: root.island?.feedbackMuted ? Airisu.quiet : Airisu.gofun
        }
        AMeter {
            Layout.fillWidth: true
            Layout.preferredWidth: Math.round(160 * root.d)
            Layout.preferredHeight: Math.round(12 * root.d)
            interactive: false
            value: root.island?.feedbackMuted ? 0 : (root.island?.feedbackValue ?? 0)
        }
        AText {
            visible: root.island?.levelFigure ?? true
            Layout.preferredWidth: Math.round(root.figure * 2.2)
            horizontalAlignment: Text.AlignRight
            voice: "wide"
            size: root.figure
            color: root.island?.feedbackMuted ? Airisu.quiet : Airisu.gofun
            text: Math.round((root.island?.feedbackValue ?? 0) * 100)
        }
    }

    Trail {
        visible: progress > 0 && (root.mode === "media" || root.mode === "timer" || root.mode === "task")
        live: root.mode !== "media" || (root.island?.playing ?? false)
        progress: root.mode === "media" ? (root.island?.trackProgress ?? 0)
            : root.mode === "timer" ? (root.island?.timerProgress ?? 0)
            : root.mode === "task" ? Math.max(0, Number(root.island?.task?.progress ?? 0)) : 0
    }
}
