pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components
import "../components"

// AIRISU's activity page: the shop's book of jobs in hand, one slip for each thing that runs (the recording, the timer,
// what scripts publish), torn apart by perforations. Each slip sets its state as ruby over its name, its figure large at
// the right and its time as punched tape along its foot; a job that has a line wears its band on the bottom edge. The
// recording is the one live thing, so it alone carries the seal. Everything it reads and does is the engine's.
ColumnLayout {
    id: page
    property Item island: null
    readonly property real d: Airisu.d
    spacing: Airisu.u(3)

    readonly property bool recording: page.island?.recording ?? false
    readonly property string timerKind: page.island?.timerKind ?? ""

    component Mark: MaterialSymbol {
        iconSize: Math.round(18 * page.d)
        fill: 0
        color: Airisu.ink
    }
    component Key: IrisButton {
        id: key
        property string glyph
        property color ink: key.emphasized ? Airisu.inkOnSeal : Airisu.ink
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
    // One slip: its mark, its state over its name, its figure, its keys; its time runs along the foot.
    component Slip: Item {
        id: slip
        property string glyph
        property color markInk: Airisu.ink
        property string reading
        property string name
        property string figure
        property color figureInk: Airisu.ink
        property real progress: -1
        property bool running: true
        property color band: "transparent"
        property bool torn: false
        default property alias keys: keyRow.data
        Layout.fillWidth: true
        implicitHeight: body.implicitHeight + Airisu.u(3) + (slip.torn ? Airisu.u(3) : 0)

        APerforation {
            visible: slip.torn
            width: parent.width
        }
        RowLayout {
            id: body
            y: slip.torn ? Airisu.u(3) : 0
            width: parent.width
            spacing: Airisu.u(3)
            Mark {
                Layout.alignment: Qt.AlignVCenter
                text: slip.glyph
                color: slip.markInk
            }
            Column {
                Layout.fillWidth: true
                spacing: 0
                AText {
                    width: parent.width
                    voice: "ruby"
                    text: slip.reading
                }
                AText {
                    width: parent.width
                    size: IrisStyle.typeLabel
                    font.weight: Font.Bold
                    text: slip.name
                }
            }
            AText {
                visible: slip.figure.length > 0
                Layout.alignment: Qt.AlignVCenter
                voice: "figure"
                size: IrisStyle.typeDisplay
                text: slip.figure
                color: slip.figureInk
            }
            Row {
                id: keyRow
                Layout.alignment: Qt.AlignVCenter
                spacing: Airisu.u(1)
            }
        }
        ATape {
            visible: slip.progress >= 0
            anchors.bottom: parent.bottom
            x: lineBand.visible ? lineBand.width + Airisu.u(2) : 0
            width: parent.width - x
            height: Airisu.u(2)
            head: true
            live: slip.running
            value: Math.max(0, slip.progress)
        }
        // The line the job belongs to, as a station sign carries it: a short band on the bottom edge.
        Rectangle {
            id: lineBand
            visible: slip.band.a > 0
            anchors.bottom: parent.bottom
            anchors.bottomMargin: slip.progress >= 0 ? Math.round((Airisu.u(2) - height) / 2) : 0
            width: Airisu.u(8)
            height: Airisu.m
            color: slip.band
        }
    }

    Slip {
        visible: page.recording
        glyph: "radio_button_checked"
        markInk: Airisu.seal
        reading: RecorderStatus.effectiveAudioMode === "none" ? Translation.tr("No audio")
            : RecorderStatus.effectiveAudioMode === "microphone" ? Translation.tr("Microphone")
            : RecorderStatus.effectiveAudioMode === "both" ? Translation.tr("System and microphone")
            : Translation.tr("System audio")
        name: Translation.tr("Screen recording")
        figure: page.island?.clockText(RecorderStatus.elapsedSeconds) ?? ""
        figureInk: Airisu.sealText
        Key {
            glyph: "stop"
            emphasized: true
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
        torn: page.recording
        readonly property bool paused: page.island?.timerPaused ?? false
        glyph: page.island?.timerGlyph ?? "timer"
        markInk: timerSlip.paused ? Airisu.inkThird : Airisu.ink
        reading: timerSlip.paused ? Translation.tr("Paused")
            : page.timerKind === "pomodoro"
                ? Translation.tr("Cycle %1 of %2").arg(TimerService.pomodoroCycle + 1).arg(TimerService.cyclesBeforeLongBreak)
            : Translation.tr("Running")
        name: page.island?.timerLabel ?? ""
        figure: page.island?.clockText(page.island?.timerSeconds ?? 0) ?? ""
        figureInk: timerSlip.paused ? Airisu.inkThird : Airisu.ink
        progress: page.timerKind !== "stopwatch" ? (page.island?.timerProgress ?? 0) : -1
        running: !timerSlip.paused
        Key {
            glyph: timerSlip.paused ? "play_arrow" : "pause"
            Accessible.name: timerSlip.paused ? Translation.tr("Resume") : Translation.tr("Pause")
            onClicked: {
                if (page.timerKind === "pomodoro") TimerService.togglePomodoro()
                else if (page.timerKind === "countdown") TimerService.toggleCountdown()
                else TimerService.toggleStopwatch()
            }
        }
        Key {
            glyph: "close"
            quiet: true
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
            torn: job.index > 0 || page.recording || page.timerKind.length > 0
            glyph: String(job.modelData.glyph ?? "bolt")
            reading: String(job.modelData.detail ?? "").length > 0 ? String(job.modelData.detail)
                : job.share < 0 ? Translation.tr("Working") : Translation.tr("In progress")
            name: String(job.modelData.title ?? "")
            figure: job.share >= 0 ? Math.round(job.share * 100) + "%" : ""
            progress: job.share
            band: Airisu.band(String(job.modelData.tint ?? "lavender"))
            Key {
                glyph: "close"
                quiet: true
                Accessible.name: Translation.tr("Dismiss")
                onClicked: LiveActivities.dismiss(String(job.modelData.id))
            }
        }
    }
}
