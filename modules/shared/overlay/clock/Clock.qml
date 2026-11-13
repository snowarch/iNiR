pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.shared.overlay

// The time over a fullscreen game, read in a glance. Digital: the hours large, AM/PM and the seconds stacked at their
// side, the date beneath; analog: a quiet dial whose seconds hand ticks in the accent. Resized in shape from any edge
// or the wheel, everything drawn from one scale; 24 or 12 hours and the date as the shell writes them.
StyledOverlayWidget {
    id: root

    readonly property string face: Config.getNestedValue("overlay.clock.face", "digital") === "analog" ? "analog" : "digital"
    readonly property bool showSeconds: Config.getNestedValue("overlay.clock.seconds", false) === true
    readonly property bool showDate: Config.getNestedValue("overlay.clock.date", true) === true

    resizable: true
    aspectRatio: faces.implicitWidth / faces.implicitHeight
    minimumWidth: Math.round(200 * root.d)
    options: [
        { key: "overlay.clock.face", label: "Face", fallback: "digital",
            choices: [{ value: "digital", label: "Digital" }, { value: "analog", label: "Analog" }] },
        { key: "overlay.clock.seconds", label: "Seconds", toggle: true, fallback: false },
        { key: "overlay.clock.date", label: "Date", toggle: true, fallback: true }
    ]

    SystemClock {
        id: clock
        enabled: root.visible
        precision: root.showSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    // The shell's own format, its AM/PM and seconds taken out to be drawn apart.
    readonly property string format: Config.options?.time?.format ?? "hh:mm"
    readonly property bool twelveHour: /a/i.test(root.format)
    readonly property string hoursFormat: root.format.replace(/\s*(ap|a)/i, "").replace(/:s{1,2}/, "").trim() || "hh:mm"
    readonly property string hoursText: Qt.locale().toString(clock.date, root.hoursFormat)
    readonly property string meridiem: root.twelveHour ? Qt.locale().toString(clock.date, "AP") : ""
    readonly property string secondsText: Qt.locale().toString(clock.date, "ss")
    readonly property string dateText: Translation.locale.toString(clock.date, Config.options?.time?.dateFormat ?? "ddd, dd/MM")

    // Every measure below is at scale 1; the face draws at `k`, whatever size it was given.
    readonly property real k: root.contentH / Math.max(1, faces.implicitHeight)
    readonly property real figureSize: 60 * root.d

    function scaled(v: real): real { return Math.round(v * root.k) }

    TextMetrics {
        id: digits
        font.family: OverlayLook.fontNumbers
        font.pixelSize: root.figureSize
        font.weight: Font.DemiBold
        font.features: ({ "tnum": 1 })
        text: "00:00"
    }
    TextMetrics {
        id: secondsInk
        font.family: OverlayLook.fontNumbers
        font.pixelSize: root.figureSize * 0.4
        font.weight: Font.DemiBold
        font.features: ({ "tnum": 1 })
        text: "00"
    }
    TextMetrics {
        id: meridiemInk
        font.family: OverlayLook.fontMain
        font.pixelSize: root.figureSize * 0.26
        font.weight: Font.DemiBold
        text: root.meridiem || "AM"
    }
    TextMetrics {
        id: dateLine
        font.family: OverlayLook.fontMain
        font.pixelSize: OverlayLook.typeLabel
        font.weight: Font.Medium
        text: root.dateText
    }

    // A hand of the analog face, turning about the dial's centre.
    component Hand: Item {
        id: hand
        property real length: 0.5
        property real tail: 0
        property real thickness: 4
        property color tint: OverlayLook.colOnLayer1
        property real angle: 0
        property real r: 0
        anchors.centerIn: parent
        width: hand.r * 2
        height: width
        rotation: hand.angle
        Behavior on rotation {
            RotationAnimation { direction: RotationAnimation.Clockwise; duration: 160; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: hand.r * (1 - hand.length)
            width: Math.max(1, root.scaled(hand.thickness * root.d))
            height: hand.r * (hand.length + hand.tail)
            radius: width / 2
            antialiasing: true
            color: hand.tint
        }
    }

    contentItem: Item {
        id: faces
        anchors.fill: parent
        readonly property real pad: 14 * root.d
        readonly property real inkH: digits.tightBoundingRect.height
        readonly property bool tail: root.showSeconds || root.twelveHour
        readonly property real digitalW: 2 * faces.pad + Math.max(
            digits.advanceWidth + (faces.tail ? 6 * root.d + Math.max(root.showSeconds ? secondsInk.advanceWidth : 0, root.twelveHour ? meridiemInk.advanceWidth : 0) : 0),
            root.showDate ? dateLine.advanceWidth : 0)
        readonly property real digitalH: 2 * faces.pad + faces.inkH + (root.showDate ? 10 * root.d + dateLine.height : 0)
        implicitWidth: Math.round(root.face === "analog" ? 200 * root.d : faces.digitalW)
        implicitHeight: Math.round(root.face === "analog" ? 200 * root.d : faces.digitalH)

        WheelHandler {
            enabled: !root.resizing
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => root.scaleBy(Math.pow(1.1, event.angleDelta.y / 120))
        }

        // Digital: the figure's ink sits on one baseline with the seconds; AM/PM tops out with it.
        Item {
            id: digital
            anchors.fill: parent
            visible: root.face === "digital"

            Item {
                id: row
                readonly property real inkTop: root.scaled(faces.pad)
                anchors.horizontalCenter: parent.horizontalCenter
                width: figure.width + (faces.tail ? root.scaled(6 * root.d) + tailColumn.width : 0)
                height: parent.height

                Item { id: baseline; y: row.inkTop + root.scaled(faces.inkH); width: 1; height: 1 }

                StyledText {
                    id: figure
                    anchors.left: parent.left
                    anchors.baseline: baseline.top
                    text: root.hoursText
                    color: OverlayLook.colOnLayer1
                    font.family: OverlayLook.fontNumbers
                    font.pixelSize: root.scaled(root.figureSize)
                    font.weight: Font.DemiBold
                    font.features: ({ "tnum": 1 })
                }
                Item {
                    id: tailColumn
                    anchors.left: figure.right
                    anchors.leftMargin: root.scaled(6 * root.d)
                    visible: faces.tail
                    width: Math.max(meridiemText.visible ? meridiemText.width : 0, secondsLabel.visible ? secondsLabel.width : 0)
                    height: parent.height
                    StyledText {
                        id: meridiemText
                        visible: root.twelveHour
                        anchors.left: parent.left
                        // Its capitals top out with the figure's.
                        y: row.inkTop + root.scaled(meridiemInk.tightBoundingRect.height) - meridiemText.baselineOffset
                        text: root.meridiem
                        color: OverlayLook.colSubtext
                        font.family: OverlayLook.fontMain
                        font.pixelSize: root.scaled(root.figureSize * 0.26)
                        font.weight: Font.DemiBold
                    }
                    StyledText {
                        id: secondsLabel
                        visible: root.showSeconds
                        anchors.left: parent.left
                        y: baseline.y - secondsLabel.baselineOffset
                        text: root.secondsText
                        color: OverlayLook.colPrimary
                        font.family: OverlayLook.fontNumbers
                        font.pixelSize: root.scaled(root.figureSize * 0.4)
                        font.weight: Font.DemiBold
                        font.features: ({ "tnum": 1 })
                    }
                }
            }
            StyledText {
                visible: root.showDate
                anchors.horizontalCenter: parent.horizontalCenter
                y: baseline.y + root.scaled(10 * root.d)
                text: root.dateText
                color: OverlayLook.colSubtext
                font.family: OverlayLook.fontMain
                font.pixelSize: root.scaled(OverlayLook.typeLabel)
                font.weight: Font.Medium
            }
        }

        // Analog: twelve marks, the quarters longer, three hands from one hub.
        Item {
            id: analog
            readonly property real r: Math.min(width, height) / 2 - root.scaled(8 * root.d)
            readonly property real hours: (clock.hours % 12) + clock.minutes / 60
            anchors.fill: parent
            visible: root.face === "analog"

            Rectangle {
                anchors.centerIn: parent
                width: analog.r * 2
                height: width
                radius: width / 2
                color: OverlayLook.colRecessed
            }
            Repeater {
                model: 12
                Item {
                    id: mark
                    required property int index
                    readonly property bool quarter: mark.index % 3 === 0
                    visible: !(mark.index === 3 && root.showDate)
                    anchors.centerIn: parent
                    width: analog.r * 2
                    height: width
                    rotation: mark.index * 30
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: root.scaled(8 * root.d)
                        width: Math.max(1, root.scaled((mark.quarter ? 3 : 2) * root.d))
                        height: root.scaled((mark.quarter ? 12 : 6) * root.d)
                        radius: width / 2
                        antialiasing: true
                        color: mark.quarter ? OverlayLook.colSubtext : OverlayLook.colFaint
                    }
                }
            }
            // The date as a watch keeps it: day and number in a window at three o'clock, in place of its mark.
            Rectangle {
                visible: root.showDate
                anchors.verticalCenter: parent.verticalCenter
                x: parent.width / 2 + analog.r * 0.42
                width: dayDate.implicitWidth + root.scaled(10 * root.d)
                height: dayDate.implicitHeight + root.scaled(4 * root.d)
                radius: root.scaled(OverlayLook.roundingSmall)
                color: OverlayLook.colLayer2
                border.width: 1
                border.color: OverlayLook.colHairline
                StyledText {
                    id: dayDate
                    anchors.centerIn: parent
                    text: Translation.locale.toString(clock.date, "ddd d")
                    color: OverlayLook.colOnLayer1
                    font.family: OverlayLook.fontMain
                    font.pixelSize: root.scaled(OverlayLook.typeFootnote)
                    font.weight: Font.DemiBold
                    font.capitalization: Font.AllUppercase
                    font.features: ({ "tnum": 1 })
                }
            }
            Hand { r: analog.r; angle: analog.hours * 30; length: 0.52; thickness: 6 }
            Hand { r: analog.r; angle: (clock.minutes + (root.showSeconds ? clock.seconds / 60 : 0)) * 6; length: 0.8; thickness: 4 }
            Hand {
                r: analog.r
                visible: root.showSeconds
                angle: clock.seconds * 6
                length: 0.86
                tail: 0.16
                thickness: 1.5
                tint: OverlayLook.colPrimary
            }
            Rectangle {
                anchors.centerIn: parent
                width: root.scaled(10 * root.d)
                height: width
                radius: width / 2
                color: OverlayLook.colOnLayer1
                Rectangle {
                    anchors.centerIn: parent
                    visible: root.showSeconds
                    width: root.scaled(4 * root.d)
                    height: width
                    radius: width / 2
                    color: OverlayLook.colPrimary
                }
            }
        }
    }
}
