pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.iris.style

// The date leads in the figure face; where the day sits in the year is said as facts, and large draws the year itself
// (a bar beside "Day 296" said the same value twice).
IrisWidgetFace {
    id: root
    designFace: IrisDesign.skin("widgetDate")

    readonly property var today: root.widget.today
    readonly property int dayOfYear: root.widget.dayOfYear
    readonly property int daysInYear: root.widget.daysInYear
    readonly property int week: {
        const t = new Date(root.today.getFullYear(), root.today.getMonth(), root.today.getDate())
        t.setDate(t.getDate() + 3 - (t.getDay() + 6) % 7)
        const first = new Date(t.getFullYear(), 0, 4)
        return 1 + Math.round(((t.getTime() - first.getTime()) / 86400000 - 3 + (first.getDay() + 6) % 7) / 7)
    }
    readonly property string weekday: IrisFaceData.capitalized(Translation.locale.toString(root.today, "dddd"))
    readonly property string month: IrisFaceData.capitalized(Translation.locale.toString(root.today, root.widget.showYear ? "MMMM yyyy" : "MMMM"))

    component Lead: ColumnLayout {
        id: lead
        property real figureSize: 62
        spacing: 0
        FaceHeader {
            face: root
            visible: root.widget.showWeekday
            Layout.fillWidth: true
            glyph: "calendar_today"
            text: root.weekday
            tint: root.highlight
        }
        FaceFigure {
            face: root
            Layout.topMargin: -root.dp(4)
            text: root.today.getDate()
            size: lead.figureSize
        }
        FaceText {
            face: root
            Layout.fillWidth: true
            text: root.month
            color: root.inkSecondary
            size: 13
            weight: Font.DemiBold
        }
    }

    ColumnLayout {
        visible: root.small
        anchors.fill: parent
        spacing: 0
        Lead { Layout.fillWidth: true }
        Item { Layout.fillHeight: true }
        FaceAside {
            face: root
            visible: root.widget.showOrdinal
            label: Translation.tr("Week")
            value: root.week
        }
    }

    RowLayout {
        visible: root.medium
        anchors.fill: parent
        spacing: root.dp(18)
        Lead {
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: root.contentWidth * 0.42
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignBottom
            spacing: root.dp(8)
            FaceFact {
                face: root
                tint: root.highlight
                Layout.fillWidth: true
                rule: false
                glyph: "view_week"
                label: Translation.tr("Week")
                value: root.week
            }
            FaceFact {
                face: root
                tint: root.highlight
                visible: root.widget.showOrdinal
                Layout.fillWidth: true
                glyph: "today"
                label: Translation.tr("Day")
                value: root.dayOfYear
            }
            FaceFact {
                face: root
                tint: root.highlight
                Layout.fillWidth: true
                glyph: "hourglass_bottom"
                label: Translation.tr("Left this year")
                value: root.daysInYear - root.dayOfYear
            }
        }
    }

    // Large: the year drawn as the Day draws the day, by its light: the length of each day across the year (from the
    // weather's place, or found from today's sunrise and sunset), warm up to today, quiet after.
    readonly property real latitude: {
        if (Weather.location?.valid)
            return Number(Weather.location.lat)
        const rise = Weather._timeToMinutes(Weather.data?.sunrise)
        const set = Weather._timeToMinutes(Weather.data?.sunset)
        const decl = root.declination(root.dayOfYear)
        if (rise < 0 || set <= rise || Math.abs(Math.tan(decl)) < 0.05)
            return NaN
        return Math.atan(-Math.cos((set - rise) / 1440 * Math.PI) / Math.tan(decl)) * 180 / Math.PI
    }
    readonly property bool lit: Number.isFinite(root.latitude)
    function declination(day: real): real {
        return 23.44 * Math.PI / 180 * Math.sin(2 * Math.PI * (284 + day) / 365)
    }
    function daylight(day: real): real {
        const x = -Math.tan(root.latitude * Math.PI / 180) * Math.tan(root.declination(day))
        return x >= 1 ? 0 : x <= -1 ? 24 : 24 * Math.acos(x) / Math.PI
    }
    readonly property var year: {
        const out = []
        if (root.lit)
            for (let day = 1; day <= 365; day += 4)
                out.push(root.daylight(day))
        return out
    }
    readonly property real shortest: root.year.length > 0 ? Math.min(...root.year) : 0
    readonly property real longest: root.year.length > 0 ? Math.max(...root.year) : 24
    readonly property real yearAt: (root.dayOfYear - 0.5) / root.daysInYear
    readonly property bool lengthening: root.lit && root.daylight(root.dayOfYear + 1) > root.daylight(root.dayOfYear)
    function span(hours: real): string {
        const minutes = Math.round(hours * 60)
        return Translation.tr("%1 h %2 min").arg(Math.floor(minutes / 60)).arg(minutes % 60)
    }

    ColumnLayout {
        visible: root.large
        anchors.fill: parent
        spacing: 0
        FaceHeader {
            face: root
            Layout.fillWidth: true
            glyph: "calendar_today"
            text: root.widget.showWeekday ? root.weekday : root.month
            tint: root.highlight
            trailing: root.lit ? (root.lengthening ? Translation.tr("Days getting longer") : Translation.tr("Days getting shorter")) : ""
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: root.dp(10)
            FaceFigure {
                face: root
                Layout.topMargin: -root.dp(4)
                text: root.today.getDate()
                size: 80
            }
            ColumnLayout {
                Layout.alignment: Qt.AlignBottom
                Layout.bottomMargin: root.dp(12)
                spacing: 0
                FaceText {
                    face: root
                    text: IrisFaceData.capitalized(Translation.locale.standaloneMonthName(root.today.getMonth()))
                    size: 17
                    weight: Font.DemiBold
                }
                FaceText {
                    face: root
                    visible: root.widget.showYear
                    text: root.today.getFullYear()
                    color: root.inkSecondary
                    size: 13
                }
            }
        }
        FaceArea {
            face: root
            visible: root.lit
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: root.dp(10)
            curve: t => 0.08 + 0.84 * (root.daylight(t * 365) - root.shortest) / Math.max(0.01, root.longest - root.shortest)
            upTo: root.yearAt
            rest: true
            tint: root.warm
        }
        Item { visible: !root.lit; Layout.fillHeight: true }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: root.dp(2)
            spacing: 0
            Repeater {
                model: root.large ? 12 : 0
                FaceText {
                    required property int index
                    face: root
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    horizontalAlignment: Text.AlignHCenter
                    text: Translation.locale.toString(new Date(2024, index, 1), "MMM").charAt(0).toUpperCase()
                    color: index === root.today.getMonth() ? root.ink : root.inkTertiary
                    size: 10.5
                    weight: index === root.today.getMonth() ? Font.DemiBold : Font.Medium
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: root.dp(12)
            spacing: root.dp(14)
            FaceAside { face: root; visible: root.lit; label: Translation.tr("Daylight"); value: root.span(root.daylight(root.dayOfYear)) }
            Item { Layout.fillWidth: true }
            FaceAside { face: root; label: Translation.tr("Week"); value: root.week }
            FaceAside { face: root; visible: root.widget.showOrdinal; label: Translation.tr("Day"); value: root.dayOfYear }
        }
    }
}
