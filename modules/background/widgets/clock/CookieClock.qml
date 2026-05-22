pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell.Io

import qs.modules.background.widgets.clock.dateIndicator
import qs.modules.background.widgets.clock.minuteMarks

Item {
    id: root

    readonly property string clockStyle: Config.getNestedValue("background.widgets.clock.style", "cookie")
    readonly property bool aiStyling: Config.getNestedValue("background.widgets.clock.cookie.aiStyling", false)
    readonly property bool constantlyRotate: Config.getNestedValue("background.widgets.clock.cookie.constantlyRotate", false)
    readonly property int sides: Config.getNestedValue("background.widgets.clock.cookie.sides", 14)
    readonly property bool hourMarks: Config.getNestedValue("background.widgets.clock.cookie.hourMarks", false)
    readonly property bool timeIndicators: Config.getNestedValue("background.widgets.clock.cookie.timeIndicators", true)
    readonly property string minuteHandStyle: Config.getNestedValue("background.widgets.clock.cookie.minuteHandStyle", "medium")
    readonly property string hourHandStyle: Config.getNestedValue("background.widgets.clock.cookie.hourHandStyle", "fill")
    readonly property string secondHandStyle: Config.getNestedValue("background.widgets.clock.cookie.secondHandStyle", "dot")
    readonly property string dateStyle: Config.getNestedValue("background.widgets.clock.cookie.dateStyle", "bubble")

    property real scaleFactor: 1.0
    property real implicitSize: Math.round((Config.getNestedValue("background.widgets.clock.cookie.size", 230)) * scaleFactor)

    // ── Style-dispatched colors (overridable from parent) ──
    readonly property color _primaryColor: Appearance.angelEverywhere ? Appearance.angel.colPrimary
        : Appearance.inirEverywhere ? Appearance.inir.colPrimary
        : Appearance.auroraEverywhere ? Appearance.m3colors.m3primary
        : Appearance.colors.colPrimary
    readonly property color _secondaryColor: Appearance.angelEverywhere ? Appearance.angel.colSecondary
        : Appearance.inirEverywhere ? Appearance.inir.colSecondary
        : Appearance.auroraEverywhere ? Appearance.m3colors.m3secondary
        : Appearance.colors.colSecondary
    readonly property color _tertiaryColor: Appearance.angelEverywhere ? Appearance.angel.colTertiary
        : Appearance.inirEverywhere ? Appearance.inir.colTertiary
        : Appearance.auroraEverywhere ? Appearance.m3colors.m3tertiary
        : Appearance.colors.colTertiary
    readonly property color _primaryContainerColor: Appearance.angelEverywhere ? Appearance.angel.colPrimaryContainer
        : Appearance.inirEverywhere ? Appearance.inir.colPrimaryContainer
        : Appearance.auroraEverywhere ? Appearance.m3colors.m3primaryContainer
        : Appearance.colors.colPrimaryContainer

    property color colShadow: Appearance.colors.colShadow
    property color colBackground: root._primaryContainerColor
    property color colOnBackground: ColorUtils.mix(root._secondaryColor, root._primaryContainerColor, 0.15)
    property color colBackgroundInfo: ColorUtils.mix(root._primaryColor, root._primaryContainerColor, 0.55)
    property color colHourHand: root._primaryColor
    property color colMinuteHand: root._tertiaryColor
    property color colSecondHand: root._primaryColor

    readonly property list<string> clockNumbers: DateTime.time.split(/[: ]/)
    readonly property int clockHour: parseInt(clockNumbers[0]) % 12
    readonly property int clockMinute: DateTime.clock.minutes
    readonly property int clockSecond: DateTime.clock.seconds

    implicitWidth: implicitSize
    implicitHeight: implicitSize

    function applyStyle(sides, dialStyle, hourHandStyle, minuteHandStyle, secondHandStyle, dateStyle) {
        Config.setNestedValue('background.widgets.clock.cookie.sides', sides)
        Config.setNestedValue('background.widgets.clock.cookie.dialNumberStyle', dialStyle)
        Config.setNestedValue('background.widgets.clock.cookie.hourHandStyle', hourHandStyle)
        Config.setNestedValue('background.widgets.clock.cookie.minuteHandStyle', minuteHandStyle)
        Config.setNestedValue('background.widgets.clock.cookie.secondHandStyle', secondHandStyle)
        Config.setNestedValue('background.widgets.clock.cookie.dateStyle', dateStyle)
    }

    function setClockPreset(category) {
        if (!root.aiStyling) return;
        if (category === "") return;
        print("[Cookie clock] Setting clock preset for category: " + category)
        // "abstract", "anime", "city", "minimalist", "landscape", "plants", "person", "space"
        if (category == "abstract") {
            applyStyle(9, "none", "fill", "medium", "dot", "bubble")
        } else if (category == "anime") {
            applyStyle(7, "none", "fill", "bold", "dot", "bubble")
        } else if (category == "city" || category == "space") {
            applyStyle(23, "full", "hollow", "thin", "classic", "bubble")
        } else if (category == "minimalist") {
            applyStyle(6, "none", "fill", "bold", "dot", "hide")
        } else if (category == "landscape") {
            applyStyle(14, "full", "hollow", "medium", "classic", "bubble")
        } else if (category == "plants") {
            applyStyle(9, "dots", "fill", "bold", "dot", "border")
        } else if (category == "person") {
            applyStyle(14, "full", "classic", "classic", "classic", "rect")
        }
    }

    Connections {
        target: Config
        function onReadyChanged() {
            categoryFileView.path = Directories.generatedWallpaperCategoryPath
        }
    }

    FileView {
        id: categoryFileView
        path: ""
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            root.setClockPreset(categoryFileView.text().trim())
        }
        onLoadFailed: (error) => {
            // If the category file doesn't exist yet, keep defaults without spamming logs
            if (error === FileViewError.FileNotFound) {
                return;
            }
        }
    }

    property bool useSineCookie: Config.getNestedValue("background.widgets.clock.cookie.useSineCookie", false)
    StyledDropShadow {
        target: useSineCookie ? sineCookieLoader : roundedPolygonCookieLoader

        RotationAnimation on rotation {
            running: root.constantlyRotate
            duration: 30000
            easing.type: Easing.Linear
            loops: Animation.Infinite
            from: 360
            to: 0
        }
    }
    Loader {
        id: sineCookieLoader
        z: 0
        visible: false // The DropShadow already draws it
        active: useSineCookie
        sourceComponent: SineCookie {
            implicitSize: root.implicitSize
            sides: root.sides
            color: root.colBackground
        }
    }
    Loader {
        id: roundedPolygonCookieLoader
        z: 0
        visible: false // The DropShadow already draws it
        active: !useSineCookie
        sourceComponent: MaterialCookie {
            implicitSize: root.implicitSize
            sides: root.sides
            color: root.colBackground
        }
    }

    // Hour/minutes numbers/dots/lines
    MinuteMarks {
        anchors.fill: parent
        color: root.colOnBackground
    }

    // Stupid extra hour marks in the middle
    FadeLoader {
        id: hourMarksLoader
        anchors.centerIn: parent
        shown: root.hourMarks
        sourceComponent: HourMarks {
            implicitSize: 135 * (1.75 - 0.75 * hourMarksLoader.opacity)
            color: root.colOnBackground
            colOnBackground: ColorUtils.mix(root.colBackgroundInfo, root.colOnBackground, 0.5)
        }
    }

    // Number column in the middle
    FadeLoader {
        id: timeColumnLoader
        anchors.centerIn: parent
        shown: root.timeIndicators
        scale: 1.4 - 0.4 * timeColumnLoader.shown
        Behavior on scale {
            animation: NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
        }

        sourceComponent: TimeColumn {
            color: root.colBackgroundInfo
        }
    }

    // Minute hand
    FadeLoader {
        anchors.fill: parent
        z: 1
        shown: root.minuteHandStyle !== "hide"
        sourceComponent: MinuteHand {
            anchors.fill: parent
            clockMinute: root.clockMinute
            style: root.minuteHandStyle
            color: root.colMinuteHand
        }
    }

    // Hour hand
    FadeLoader {
        anchors.fill: parent
        z: item?.style === "hollow" ? 0 : 2
        shown: root.hourHandStyle !== "hide"
        sourceComponent: HourHand {
            clockHour: root.clockHour
            clockMinute: root.clockMinute
            style: root.hourHandStyle
            color: root.colHourHand
        }
    }

    // Second hand
    FadeLoader {
        id: secondHandLoader
        z: root.secondHandStyle === "line" ? 2 : 3
        shown: Config.options.time.secondPrecision && root.secondHandStyle !== "hide"
        anchors.fill: parent
        sourceComponent: SecondHand {
            id: secondHand
            clockSecond: root.clockSecond
            style: root.secondHandStyle
            color: root.colSecondHand
        }
    }

    // Center dot
    FadeLoader {
        z: 4
        anchors.centerIn: parent
        shown: root.minuteHandStyle !== "bold"
        sourceComponent: Rectangle {
            color: root.minuteHandStyle === "medium" ? root.colBackground : root.colMinuteHand
            implicitWidth: 6
            implicitHeight: implicitWidth
            radius: width / 2
        }
    }

    // Date
    FadeLoader {
        anchors.fill: parent
        shown: root.dateStyle !== "hide"

        sourceComponent: DateIndicator {
            color: root.colBackgroundInfo
            style: root.dateStyle
        }
    }
}
