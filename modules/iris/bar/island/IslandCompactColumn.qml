pragma ComponentBehavior: Bound

import QtQuick
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components

Item {
    id: column

    required property Item island
    property string mode: "idle"
    property real thickness: 42
    property real clockScale: 1
    property color clockAccent: IrisStyle.secondaryAccent
    property string clockStyle: "dateTime"

    readonly property real d: IrisStyle.density
    readonly property real figure: 12 * IrisStyle.typeScale
    readonly property Item current: ({ idle: clockStack, clock: clockStack, media: mediaStack, record: recordStack,
        timer: timerStack, task: taskStack, edit: editStack })[column.mode] ?? clockStack
    implicitWidth: column.thickness
    implicitHeight: column.current.implicitHeight + (column.island.zoned ? Math.round(16 * column.d) : 0)


    component Stack: Column {
        property string modes: ""
        readonly property bool shown: String(modes).split(" ").includes(column.mode)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: Math.round(6 * column.d)
        opacity: shown ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
    }

    component Figure: IrisNumber {
        anchors.horizontalCenter: parent.horizontalCenter
        pixelSize: text.length > 5 ? Math.round(column.figure * 0.8) : column.figure
        weight: Font.DemiBold
    }

    Stack {
        id: clockStack
        modes: "idle clock"
        Glyph {
            visible: column.clockStyle === "weather"
            anchors.horizontalCenter: parent.horizontalCenter
            text: Icons.getWeatherIcon(Weather.data?.wCode, Weather.isNightNow()) ?? "cloud"
            iconSize: 16 * column.d
            color: IrisStyle.subtext
        }
        IslandStackedClock {
            anchors.horizontalCenter: parent.horizontalCenter
            pixelSize: 15 * IrisStyle.typeScale * column.clockScale
            accent: column.clockAccent
            showDay: column.clockStyle === "dateTime"
        }
    }

    Stack {
        id: mediaStack
        modes: "media"
        IrisArtwork {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.round(24 * column.d)
            height: width
            source: MediaArtwork.displaySource
            circular: Config.options?.iris?.player?.roundCover ?? false
            radius: circular ? width / 2 : 6 * column.d
        }
        IrisVisualizer {
            anchors.horizontalCenter: parent.horizontalCenter
            running: column.island.playing && column.mode === "media" && !column.island.visualExpanded
            tint: IrisStyle.visualizerTint(column.island.artTint)
            barHeight: 13 * column.d
        }
        // On its side there is room for the time under what plays.
        IslandStackedClock {
            anchors.horizontalCenter: parent.horizontalCenter
            pixelSize: 13 * IrisStyle.typeScale * column.clockScale
            accent: column.clockAccent
            showDay: false
        }
    }

    Stack {
        id: recordStack
        modes: "record"
        RecordDot { anchors.horizontalCenter: parent.horizontalCenter }
        Figure {
            text: column.island.clockText(RecorderStatus.elapsedSeconds)
            color: IrisStyle.danger
        }
    }

    Stack {
        id: timerStack
        modes: "timer"
        Glyph {
            anchors.horizontalCenter: parent.horizontalCenter
            text: column.island.timerPaused ? "pause" : column.island.timerGlyph
            iconSize: 17 * column.d
            color: IrisStyle.secondaryAccent
        }
        Figure {
            text: column.island.clockText(column.island.timerSeconds)
            countDown: column.island.timerKind !== "stopwatch"
            color: column.island.timerPaused ? IrisStyle.subtext : IrisStyle.secondaryAccent
        }
    }

    Stack {
        id: taskStack
        modes: "task"
        Glyph {
            anchors.horizontalCenter: parent.horizontalCenter
            text: String(column.island.task?.glyph ?? "bolt")
            iconSize: 17 * column.d
            color: column.island.taskTint
        }
        Figure {
            visible: Number(column.island.task?.progress ?? -1) >= 0
            text: Math.round(Number(column.island.task?.progress ?? 0) * 100) + "%"
            color: column.island.taskTint
        }
        RecordDot {
            visible: Number(column.island.task?.progress ?? -1) < 0
            anchors.horizontalCenter: parent.horizontalCenter
            color: column.island.taskTint
        }
    }

    Stack {
        id: editStack
        modes: "edit"
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.round(26 * column.d)
            height: width
            radius: width / 2
            color: IrisStyle.tintFill(IrisStyle.accent)
            Glyph {
                anchors.centerIn: parent
                text: "edit"
                iconSize: 15 * column.d
                color: IrisStyle.accent
            }
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.round(26 * column.d)
            height: width
            radius: width / 2
            color: IrisStyle.accent
            Glyph {
                anchors.centerIn: parent
                text: "check"
                iconSize: 16 * column.d
                color: IrisStyle.inkOnAccent
            }
        }
    }
}
