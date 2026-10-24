pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.iris.style

// The session drawn on the day as the Day draws the sun: the line rises when the machine woke and runs on to now.
// The time on is the one figure; when it started is a fact beside it, never a second count of the same hours.
IrisWidgetFace {
    id: root
    designFace: IrisDesign.skin("widgetUptime")

    readonly property int total: root.widget.sessionSeconds
    readonly property int days: Math.floor(root.total / 86400)
    readonly property int hours: Math.floor(root.total % 86400 / 3600)
    readonly property int minutes: Math.floor(root.total % 3600 / 60)
    readonly property var parts: root.days > 0
        ? [{ value: root.days, unit: Translation.tr("d") }, { value: root.hours, unit: Translation.tr("h") }]
        : [{ value: root.hours, unit: Translation.tr("h") }, { value: root.minutes, unit: Translation.tr("min") }]

    readonly property var now: DateTime.clock.date
    readonly property real nowAt: (root.now.getHours() * 60 + root.now.getMinutes()) / 1440
    // Started before midnight: the whole day so far is on.
    readonly property bool sinceYesterday: root.total / 86400 >= root.nowAt
    readonly property real bootAt: root.sinceYesterday ? 0 : root.nowAt - root.total / 86400
    readonly property var boot: root.widget.bootDate
    readonly property var bootParts: IrisFaceData.timeParts(IrisFaceData.clockText(root.boot))
    readonly property string bootDay: IrisFaceData.capitalized(Translation.locale.toString(root.boot, "dddd"))
    // On from waking to now: the line rises over the first hours like the sun does and holds (a straight ramp said
    // only that time passes; a hard step read as a bar).
    // Early in a day the session began before: the day so far was a sliver at its left edge, so the drawing reads the
    // last 24 hours instead, ending now.
    readonly property bool rolling: root.sinceYesterday && root.nowAt < 0.25
    readonly property real areaFrom: root.rolling ? Math.max(0, 1 - root.total / 86400) : root.bootAt
    readonly property real areaTo: root.rolling ? 1 : root.nowAt
    readonly property var marks: {
        if (!root.rolling)
            return [0, 6, 12, 18, 24]
        const hour = root.now.getHours() + (root.now.getMinutes() >= 30 ? 1 : 0)
        return [-24, -18, -12, -6].map(back => ((hour + back) % 24 + 24) % 24).concat([Translation.tr("Now")])
    }
    function level(t: real): real {
        if (root.sinceYesterday && !(root.rolling && root.areaFrom > 0))
            return 0.8
        const k = Math.max(0, Math.min(1, (t - root.areaFrom) * 24 / 2.5))
        return 0.8 * k * k * (3 - 2 * k)
    }
    function span(seconds: int): string {
        const h = Math.floor(seconds / 3600)
        const m = Math.floor(seconds % 3600 / 60)
        return h > 0 ? Translation.tr("%1 h %2 min").arg(h).arg(m) : Translation.tr("%1 min").arg(m)
    }

    component Lead: Row {
        id: lead
        property real figureSize: 34
        spacing: root.dp(6)
        Repeater {
            model: root.parts
            Row {
                id: part
                required property var modelData
                spacing: root.dp(2)
                FaceFigure {
                    id: figure
                    face: root
                    text: part.modelData.value
                    size: lead.figureSize
                }
                FaceText {
                    face: root
                    anchors.baseline: figure.baseline
                    text: part.modelData.unit
                    color: root.inkSecondary
                    size: Math.round(lead.figureSize * 0.42)
                    weight: Font.DemiBold
                }
            }
        }
    }

    component Since: FaceAside {
        face: root
        visible: root.widget.showSince
        label: root.sinceYesterday ? root.bootDay : Translation.tr("Since")
        value: root.bootParts.main
        unit: root.bootParts.suffix
    }

    component Session: FaceArea {
        face: root
        from: root.areaFrom
        to: root.areaTo
        curve: t => root.level(t)
    }

    ColumnLayout {
        visible: root.small
        anchors.fill: parent
        spacing: root.dp(2)
        FaceHeader {
            face: root
            Layout.fillWidth: true
            glyph: "timelapse"
            text: Translation.tr("Uptime")
        }
        Lead { figureSize: 34 }
        Session {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: root.dp(6)
        }
        Since { Layout.topMargin: root.dp(6) }
    }

    ColumnLayout {
        visible: !root.small
        anchors.fill: parent
        spacing: root.dp(2)
        FaceHeader {
            face: root
            Layout.fillWidth: true
            glyph: "timelapse"
            text: Translation.tr("Uptime")
            trailing: root.medium && root.days > 0 ? Translation.tr("Day %1 of this session").arg(root.widget.sessionDay) : ""
        }
        RowLayout {
            Layout.fillHeight: false
            Layout.fillWidth: true
            spacing: root.dp(10)
            Lead { figureSize: root.large ? 44 : 38 }
            Item { Layout.fillWidth: true }
            Since {
                visible: root.medium && root.widget.showSince
                Layout.alignment: Qt.AlignBottom
                Layout.bottomMargin: root.dp(4)
            }
        }
        Session {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: root.dp(6)
        }
        FaceHours { face: root; marks: root.marks; Layout.fillWidth: true; Layout.topMargin: root.dp(2) }
        ColumnLayout {
            Layout.fillHeight: false
            visible: root.large
            Layout.fillWidth: true
            Layout.topMargin: root.dp(12)
            spacing: root.dp(8)
            FaceFact {
                face: root
                Layout.fillWidth: true
                glyph: "login"
                label: Translation.tr("Started")
                value: (root.sinceYesterday ? root.bootDay + " " : "") + IrisFaceData.clockText(root.boot)
            }
            FaceFact {
                face: root
                Layout.fillWidth: true
                glyph: "today"
                label: Translation.tr("On today")
                value: root.span(Math.round((root.nowAt - root.bootAt) * 86400))
            }
            FaceFact {
                face: root
                Layout.fillWidth: true
                glyph: "dns"
                label: root.days > 0 ? Translation.tr("Session day") : Translation.tr("Machine")
                value: root.days > 0 ? String(root.widget.sessionDay) : (SystemInfo.hostname || SystemInfo.distroName)
            }
        }
    }
}
