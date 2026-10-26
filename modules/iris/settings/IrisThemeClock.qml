pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.components
import qs.modules.iris.style

// Settings › Colour › Day and night: the day as a 24-hour ring, midnight at the top. The day's arc wears the day
// theme (its paper with its accent through the middle), the night's arc the night theme; the sun and the moon are
// the hours it switches, dragged round the ring in quarter hours. The centre says which theme holds now and until when.
RowLayout {
    id: root

    readonly property real d: IrisStyle.settingsDensity
    readonly property var schedule: Config.options?.appearance?.themeSchedule ?? ({})
    function minutesOf(text: string): int {
        const parts = String(text).split(":").map(Number)
        return ((parts[0] || 0) * 60 + (parts[1] || 0)) % 1440
    }
    function clock(minutes: int): string {
        const m = ((minutes % 1440) + 1440) % 1440
        return ("0" + Math.floor(m / 60)).slice(-2) + ":" + ("0" + m % 60).slice(-2)
    }
    // While a handle is held the ring follows the pointer; the config is written once, on release.
    property int dragDay: -1
    property int dragNight: -1
    readonly property int dayStart: root.dragDay >= 0 ? root.dragDay : root.minutesOf(root.schedule.dayStart ?? "06:00")
    readonly property int nightStart: root.dragNight >= 0 ? root.dragNight : root.minutesOf(root.schedule.nightStart ?? "18:00")
    property date now: new Date()
    readonly property int nowMinutes: root.now.getHours() * 60 + root.now.getMinutes()
    readonly property bool nightNow: root.dayStart <= root.nightStart
        ? root.nowMinutes < root.dayStart || root.nowMinutes >= root.nightStart
        : root.nowMinutes >= root.nightStart && root.nowMinutes < root.dayStart
    function look(id: string): var {
        if (String(id) === "auto") return { name: Translation.tr("Wallpaper"), paper: IrisStyle.fillActive, ink: IrisStyle.wallpaperLight, dots: [IrisStyle.wallpaperLight, IrisStyle.accent, IrisStyle.secondaryAccent] }
        const preset = ThemePresets.getPreset(String(id))
        const c = preset?.colors ?? ({})
        const of = (hex, fallback) => hex ? Qt.color(String(hex)) : fallback
        return { name: String(preset?.name ?? id), paper: of(c.m3background, IrisStyle.fillActive), ink: of(c.m3primary, IrisStyle.accent),
            dots: [c.m3primary, c.m3secondary, c.m3tertiary].map(hex => of(hex, IrisStyle.identity.gray)) }
    }
    readonly property var themes: IrisOptions.choicesOf({ choicesFrom: "colourThemes" }).map(choice => ({ label: Translation.tr(choice.label), value: choice.value }))
    readonly property var day: root.look(root.schedule.dayTheme ?? "auto")
    readonly property var night: root.look(root.schedule.nightTheme ?? "auto")

    Timer {
        interval: 30000
        repeat: true
        running: root.visible
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    spacing: Math.round(28 * root.d)

    Item {
        id: dial
        readonly property real size: Math.round(208 * root.d)
        readonly property real band: Math.round(18 * root.d)
        readonly property real radius: dial.size / 2 - Math.round(20 * root.d)
        readonly property real centre: dial.size / 2
        function angleOf(minutes: real): real { return -90 + minutes / 1440 * 360 }
        function pointOf(minutes: real, distance: real): point {
            const a = dial.angleOf(minutes) * Math.PI / 180
            return Qt.point(dial.centre + Math.cos(a) * distance, dial.centre + Math.sin(a) * distance)
        }
        readonly property real daySweep: ((root.nightStart - root.dayStart + 1440) % 1440) / 1440 * 360
        Layout.preferredWidth: dial.size
        Layout.preferredHeight: dial.size
        Layout.alignment: Qt.AlignVCenter

        // The night's arc and the day's: each is its theme's paper with its accent drawn through the middle.
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "transparent"
                strokeColor: root.night.paper
                strokeWidth: dial.band
                capStyle: ShapePath.FlatCap
                PathAngleArc { centerX: dial.centre; centerY: dial.centre; radiusX: dial.radius; radiusY: dial.radius
                    startAngle: dial.angleOf(root.nightStart); sweepAngle: 360 - dial.daySweep }
            }
            ShapePath {
                fillColor: "transparent"
                strokeColor: root.day.paper
                strokeWidth: dial.band
                capStyle: ShapePath.FlatCap
                PathAngleArc { centerX: dial.centre; centerY: dial.centre; radiusX: dial.radius; radiusY: dial.radius
                    startAngle: dial.angleOf(root.dayStart); sweepAngle: dial.daySweep }
            }
            ShapePath {
                fillColor: "transparent"
                strokeColor: root.night.ink
                strokeWidth: Math.round(4 * root.d)
                capStyle: ShapePath.RoundCap
                PathAngleArc { centerX: dial.centre; centerY: dial.centre; radiusX: dial.radius; radiusY: dial.radius
                    startAngle: dial.angleOf(root.nightStart) + 10; sweepAngle: Math.max(0, 340 - dial.daySweep) }
            }
            ShapePath {
                fillColor: "transparent"
                strokeColor: root.day.ink
                strokeWidth: Math.round(4 * root.d)
                capStyle: ShapePath.RoundCap
                PathAngleArc { centerX: dial.centre; centerY: dial.centre; radiusX: dial.radius; radiusY: dial.radius
                    startAngle: dial.angleOf(root.dayStart) + 10; sweepAngle: Math.max(0, dial.daySweep - 20) }
            }
        }

        // Hours: a tick every hour inside the ring, the four quarters named.
        Repeater {
            model: 24
            delegate: Rectangle {
                required property int index
                readonly property bool quarter: index % 6 === 0
                readonly property point at: dial.pointOf(index * 60, dial.radius - dial.band / 2 - Math.round(8 * root.d))
                width: Math.round((quarter ? 4 : 2) * root.d)
                height: width
                radius: IrisStyle.capsule(width)
                x: Math.round(at.x - width / 2)
                y: Math.round(at.y - height / 2)
                color: quarter ? IrisStyle.textSecondary : IrisStyle.textTertiary
            }
        }
        Repeater {
            model: [0, 6, 12, 18]
            delegate: IrisText {
                required property int modelData
                readonly property point at: dial.pointOf(modelData * 60, dial.radius - dial.band / 2 - Math.round(22 * root.d))
                x: Math.round(at.x - width / 2)
                y: Math.round(at.y - height / 2)
                text: ("0" + modelData).slice(-2)
                font.family: IrisStyle.fontNumbers
                font.pixelSize: IrisStyle.typeCaption
                color: IrisStyle.textTertiary
            }
        }

        // Now: a highlight mark just outside the ring.
        Rectangle {
            readonly property point at: dial.pointOf(root.nowMinutes, dial.radius + dial.band / 2 + Math.round(8 * root.d))
            width: Math.round(6 * root.d)
            height: width
            radius: IrisStyle.capsule(width)
            x: Math.round(at.x - width / 2)
            y: Math.round(at.y - height / 2)
            color: IrisStyle.secondaryAccent
        }

        ColumnLayout {
            anchors.centerIn: parent
            width: dial.radius * 1.1
            spacing: Math.round(2 * root.d)
            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                text: root.nightNow ? "dark_mode" : "light_mode"
                iconSize: Math.round(20 * root.d)
                fill: 1
                color: (root.nightNow ? root.night : root.day).ink
            }
            IrisText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: (root.nightNow ? root.night : root.day).name
                font.pixelSize: IrisStyle.typeHeadline
                font.weight: IrisStyle.weight(Font.DemiBold)
                elide: Text.ElideRight
            }
            IrisText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: Translation.tr("until %1").arg(root.clock(root.nightNow ? root.dayStart : root.nightStart))
                font.family: IrisStyle.fontNumbers
                font.pixelSize: IrisStyle.typeMeta
                color: IrisStyle.subtext
            }
        }

        // The two hours, as the sun and the moon on the ring.
        Repeater {
            model: [{ night: false, glyph: "light_mode" }, { night: true, glyph: "dark_mode" }]
            delegate: Rectangle {
                id: handle
                required property var modelData
                readonly property int minutes: handle.modelData.night ? root.nightStart : root.dayStart
                readonly property bool held: grab.held === (handle.modelData.night ? "night" : "day")
                readonly property point at: dial.pointOf(handle.minutes, dial.radius)
                width: Math.round((handle.held ? 34 : 30) * root.d)
                height: width
                radius: IrisStyle.capsule(width)
                x: Math.round(at.x - width / 2)
                y: Math.round(at.y - height / 2)
                color: IrisStyle.text
                Behavior on width { enabled: IrisStyle.motionEnabled; NumberAnimation { duration: IrisStyle.duration(140) } }
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: handle.modelData.glyph
                    iconSize: Math.round(17 * root.d)
                    fill: 1
                    color: IrisStyle.bodySurface
                }
            }
        }

        MouseArea {
            id: grab
            property string held: ""
            anchors.fill: parent
            preventStealing: true
            hoverEnabled: true
            function minutesAt(x: real, y: real): int {
                const a = Math.atan2(y - dial.centre, x - dial.centre) * 180 / Math.PI + 90
                return Math.round(((a + 360) % 360) / 360 * 1440 / 15) * 15 % 1440
            }
            function apart(a: int, b: int): int { const gap = Math.abs(a - b) % 1440; return Math.min(gap, 1440 - gap) }
            readonly property bool overBand: Math.abs(Math.hypot(grab.mouseX - dial.centre, grab.mouseY - dial.centre) - dial.radius) < dial.band * 1.4
            cursorShape: grab.held.length > 0 ? Qt.ClosedHandCursor : grab.overBand ? Qt.OpenHandCursor : Qt.ArrowCursor
            onPressed: mouse => {
                if (!grab.overBand) { mouse.accepted = false; return }
                const at = grab.minutesAt(mouse.x, mouse.y)
                grab.held = grab.apart(at, root.dayStart) <= grab.apart(at, root.nightStart) ? "day" : "night"
                grab.follow(at)
            }
            onPositionChanged: mouse => { if (grab.held.length > 0) grab.follow(grab.minutesAt(mouse.x, mouse.y)) }
            // The two hours never meet: the one held stops a quarter hour short of the other.
            function follow(at: int): void {
                if (grab.held === "day" && at !== root.nightStart) root.dragDay = at
                if (grab.held === "night" && at !== root.dayStart) root.dragNight = at
            }
            function settle(): void {
                const updates = ({})
                if (root.dragDay >= 0) updates["appearance.themeSchedule.dayStart"] = root.clock(root.dragDay)
                if (root.dragNight >= 0) updates["appearance.themeSchedule.nightStart"] = root.clock(root.dragNight)
                if (Object.keys(updates).length > 0) Config.setNestedValues(updates)
                root.dragDay = -1
                root.dragNight = -1
                grab.held = ""
            }
            onReleased: grab.settle()
            onCanceled: grab.settle()
        }
    }

    // What each half wears and when it starts.
    ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: Math.round(18 * root.d)
        Repeater {
            model: [{ night: false }, { night: true }]
            delegate: RowLayout {
                id: half
                required property var modelData
                readonly property var theme: half.modelData.night ? root.night : root.day
                readonly property bool current: half.modelData.night === root.nightNow
                Layout.fillWidth: true
                spacing: Math.round(12 * root.d)
                Rectangle {
                    Layout.preferredWidth: Math.round(40 * root.d)
                    Layout.preferredHeight: Math.round(40 * root.d)
                    radius: IrisStyle.iconRadius(width)
                    color: half.theme.paper
                    Row {
                        anchors.centerIn: parent
                        spacing: Math.round(2 * root.d)
                        Repeater {
                            model: half.theme.dots
                            delegate: Rectangle {
                                required property color modelData
                                width: Math.round(8 * root.d)
                                height: width
                                radius: IrisStyle.capsule(width)
                                color: modelData
                            }
                        }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    IrisText {
                        text: half.modelData.night ? Translation.tr("At night, from %1").arg(root.clock(root.nightStart))
                            : Translation.tr("By day, from %1").arg(root.clock(root.dayStart))
                        font.family: IrisStyle.fontNumbers
                        font.pixelSize: IrisStyle.typeMeta
                        color: half.current ? IrisStyle.accent : IrisStyle.subtext
                    }
                    // The name is the picker: the legend and the choice are one thing.
                    IrisPopupButton {
                        readonly property string key: half.modelData.night ? "nightTheme" : "dayTheme"
                        Layout.topMargin: Math.round(2 * root.d)
                        // Its label sits under the line above, not its plate's edge.
                        Layout.leftMargin: -Math.round(10 * root.d)
                        options: root.themes
                        current: String(root.schedule[key] ?? "auto")
                        accessibleName: half.modelData.night ? Translation.tr("At night") : Translation.tr("By day")
                        onPicked: value => Config.setNestedValue("appearance.themeSchedule." + key, value)
                    }
                }
            }
        }
        IrisText {
            Layout.fillWidth: true
            text: Translation.tr("Drag the sun and the moon to change the hours.")
            font.pixelSize: IrisStyle.typeFootnote
            color: IrisStyle.textTertiary
            wrapMode: Text.Wrap
        }
    }
}
