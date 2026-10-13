pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.iris.style
import qs.modules.iris.components
import "../components"

// AIRISU's activity page: one lacquer panel for each thing that runs (the recording, the timer, what scripts publish),
// each in its subject's pigment (the recording the accent, because it is live; the timer time's; a job its own line),
// with how far it has come as the second coat laid at 45°. Each sets its state over its name, its figure large and
// leaning at the right, and its keys after it, all cut out of the panel's ink. Everything it reads and does is the engine's.
ColumnLayout {
    id: page
    property Item island: null
    readonly property real d: Airisu.d
    spacing: Airisu.u(2)

    readonly property bool recording: page.island?.recording ?? false
    readonly property string timerKind: page.island?.timerKind ?? ""

    component Key: IrisButton {
        id: key
        property string glyph
        property color under: Airisu.ground
        property color ink: key.emphasized ? Airisu.inkOnSeal : Airisu.inkOn(key.under)
        quiet: !key.emphasized
        skinData: ({ under: key.under })
        implicitWidth: Math.round(36 * page.d)
        implicitHeight: Math.round(32 * page.d)
        MaterialSymbol {
            anchors.centerIn: parent
            text: key.glyph
            iconSize: Math.round(18 * page.d)
            fill: 1
            color: key.ink
        }
    }
    // One panel: its mark, its state over its name, its figure, its keys; how far it has come is its coat.
    component Slip: Item {
        id: slip
        property string glyph
        property color pigment: Airisu.pigment("rest")
        property string reading
        property string name
        property string figure
        property real progress: -1
        property bool running: true
        default property alias keys: keyRow.data
        readonly property color lacquer: Airisu.lacquerOf(slip.pigment)
        readonly property color coat: Airisu.coat(slip.pigment)
        readonly property color ink: slip.progress > 0 ? Airisu.inkOver(slip.lacquer, slip.coat) : Airisu.inkOn(slip.lacquer)
        readonly property color inkSecond: ColorUtils.mix(slip.ink, slip.lacquer, 0.74) // iris-literal: second tone on lacquer
        readonly property color inkThird: ColorUtils.mix(slip.ink, slip.lacquer, 0.52)  // iris-literal: third tone on lacquer
        readonly property int pad: Airisu.u(3)
        Layout.fillWidth: true
        implicitHeight: body.implicitHeight + 2 * slip.pad

        ALacquer {
            anchors.fill: parent
            lacquer: slip.lacquer
            coat: slip.coat
            share: Math.max(0, slip.progress)
            travel: Airisu.snap
        }
        RowLayout {
            id: body
            x: slip.pad
            y: slip.pad
            width: parent.width - 2 * slip.pad
            spacing: Airisu.u(3)
            MaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                iconSize: Math.round(18 * page.d)
                fill: 1
                text: slip.glyph
                color: slip.running ? slip.ink : slip.inkThird
            }
            Column {
                Layout.fillWidth: true
                spacing: 0
                AText {
                    width: parent.width
                    size: IrisStyle.typeFootnote
                    font.weight: Font.Bold
                    color: slip.inkSecond
                    text: slip.reading
                }
                AText {
                    width: parent.width
                    size: IrisStyle.typeLabel
                    font.weight: Font.Bold
                    color: slip.ink
                    text: slip.name
                }
            }
            AText {
                visible: slip.figure.length > 0
                Layout.alignment: Qt.AlignVCenter
                voice: "figure"
                size: IrisStyle.typeDisplay
                text: slip.figure
                color: slip.running ? slip.ink : slip.inkThird
            }
            Row {
                id: keyRow
                Layout.alignment: Qt.AlignVCenter
                spacing: Airisu.u(1)
            }
        }
    }

    Slip {
        visible: page.recording
        id: recordSlip
        glyph: "radio_button_checked"
        pigment: Airisu.pigment("live")
        reading: RecorderStatus.effectiveAudioMode === "none" ? Translation.tr("No audio")
            : RecorderStatus.effectiveAudioMode === "microphone" ? Translation.tr("Microphone")
            : RecorderStatus.effectiveAudioMode === "both" ? Translation.tr("System and microphone")
            : Translation.tr("System audio")
        name: Translation.tr("Screen recording")
        figure: page.island?.clockText(RecorderStatus.elapsedSeconds) ?? ""
        Key {
            glyph: "stop"
            emphasized: true
            under: recordSlip.lacquer
            Accessible.name: Translation.tr("Stop recording")
            onClicked: {
                Quickshell.execDetached([Directories.recordScriptPath, "--stop"])
                RecorderStatus.scheduleQuickCheck()
            }
        }
    }

    Slip {
        id: timerSlip
        visible: page.timerKind.length > 0
        readonly property bool paused: page.island?.timerPaused ?? false
        glyph: page.island?.timerGlyph ?? "timer"
        pigment: Airisu.pigment("time")
        reading: timerSlip.paused ? Translation.tr("Paused")
            : page.timerKind === "pomodoro"
                ? Translation.tr("Cycle %1 of %2").arg(TimerService.pomodoroCycle + 1).arg(TimerService.cyclesBeforeLongBreak)
            : Translation.tr("Running")
        name: page.island?.timerLabel ?? ""
        figure: page.island?.clockText(page.island?.timerSeconds ?? 0) ?? ""
        progress: page.timerKind !== "stopwatch" ? (page.island?.timerProgress ?? 0) : -1
        running: !timerSlip.paused
        Key {
            glyph: timerSlip.paused ? "play_arrow" : "pause"
            under: timerSlip.lacquer
            Accessible.name: timerSlip.paused ? Translation.tr("Resume") : Translation.tr("Pause")
            onClicked: {
                if (page.timerKind === "pomodoro") TimerService.togglePomodoro()
                else if (page.timerKind === "countdown") TimerService.toggleCountdown()
                else TimerService.toggleStopwatch()
            }
        }
        Key {
            glyph: "close"
            under: timerSlip.lacquer
            Accessible.name: Translation.tr("Stop timer")
            onClicked: {
                if (page.timerKind === "pomodoro") TimerService.stopPomodoro()
                else if (page.timerKind === "countdown") TimerService.stopCountdown()
                else TimerService.stopStopwatch()
            }
        }
    }

    Repeater {
        model: LiveActivities.active
        Slip {
            id: job
            required property var modelData
            required property int index
            readonly property real share: Number(job.modelData.progress ?? -1)
            glyph: String(job.modelData.glyph ?? "bolt")
            reading: String(job.modelData.detail ?? "").length > 0 ? String(job.modelData.detail)
                : job.share < 0 ? Translation.tr("Working") : Translation.tr("In progress")
            name: String(job.modelData.title ?? "")
            figure: job.share >= 0 ? Math.round(job.share * 100) + "%" : ""
            progress: job.share
            pigment: Airisu.pigment("rest")
            Key {
                glyph: "close"
                under: job.lacquer
                Accessible.name: Translation.tr("Dismiss")
                onClicked: LiveActivities.dismiss(String(job.modelData.id))
            }
        }
    }
}
