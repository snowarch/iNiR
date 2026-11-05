pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

// Material's Medium and Large weather: what it is now in the widget's shape, the next hours under it, and on Large the
// days with their range drawn on one shared scale.
Item {
    id: root

    required property var widget
    property bool large: false

    readonly property real s: root.widget.scaleFactor
    function px(value: real): int { return Math.round(value * root.s) }
    readonly property color ink: root.widget.widgetInk
    readonly property color inkMuted: ColorUtils.applyAlpha(root.ink, 0.62)
    readonly property bool night: Weather.isNightNow()
    readonly property string glyph: Icons.getWeatherIcon(Weather.data?.wCode, root.night) ?? "cloud"
    readonly property var hours: Array.from(Weather.data?.hourly ?? []).slice(0, root.large ? 6 : 5)
    readonly property var days: Array.from(Weather.data?.forecast ?? []).slice(0, 5)
    readonly property real weekLow: Math.min(...root.days.map(day => Number(day.loVal)).filter(Number.isFinite), 99)
    readonly property real weekHigh: Math.max(...root.days.map(day => Number(day.hiVal)).filter(Number.isFinite), -99)
    function degrees(value: var): string {
        const text = String(value ?? "").trim()
        return text.length === 0 || text.startsWith("--") ? "" : text.replace(/°[CF]$/, "°").replace(/([0-9])$/, "$1°")
    }
    readonly property string range: {
        const high = root.degrees(Weather.data?.tempMax)
        const low = root.degrees(Weather.data?.tempMin)
        return high && low ? Translation.tr("H:%1  L:%2").arg(high).arg(low) : ""
    }
    readonly property var facts: [
        { icon: "thermostat", value: Translation.tr("Feels %1").arg(root.degrees(Weather.data?.tempFeelsLike)) },
        { icon: "humidity_percentage", value: String(Weather.data?.humidity ?? "").trim() },
        { icon: "air", value: String(Weather.data?.wind ?? "").trim() },
        { icon: "light_mode", value: Translation.tr("UV") + " " + String(Weather.data?.uv ?? "").trim() }
    ].filter(fact => fact.value.length > 0 && !/--|\s$/.test(fact.value))
    // One line of facts, as many as the width holds: a second line fell on the plate's edge.
    readonly property var shownFacts: {
        const room = root.width - 2 * root.px(16)
        let used = 0
        const out = []
        for (const fact of root.facts) {
            const chip = root.px(15) + root.px(5) + Math.ceil(factMetrics.advanceWidth(fact.value)) + root.px(18)
            if (used + chip > room) break
            used += chip + root.px(6)
            out.push(fact)
        }
        return out
    }
    FontMetrics {
        id: factMetrics
        font.family: Appearance.font.family.main
        font.pixelSize: root.px(Appearance.font.pixelSize.smaller)
        font.weight: Font.Medium
    }
    readonly property string city: Weather.showVisibleCity ? String(Weather.visibleCity).split(",")[0].trim() : ""

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.px(16)
        spacing: root.px(root.large ? 12 : 8)

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: false
            spacing: root.px(12)

            MaterialShapeWrappedMaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                shape: root.widget.pillShapeEnum
                color: root.widget.shapeFill
                colSymbol: root.widget.shapeInk
                text: root.glyph
                fill: 1
                iconSize: root.px(30)
                padding: root.px(13)
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 0
                StyledText {
                    Layout.fillWidth: true
                    text: root.widget.temperatureText
                    color: root.ink
                    elide: Text.ElideRight
                    font.family: Appearance.font.family.expressive
                    font.pixelSize: root.px(root.large ? 46 : 40)
                    font.weight: Font.Bold
                    font.features: ({ "tnum": 1 })
                }
                StyledText {
                    Layout.fillWidth: true
                    text: String(Weather.data?.description ?? "").replace(/^./, first => first.toUpperCase())
                    color: root.ink
                    elide: Text.ElideRight
                    font.pixelSize: root.px(Appearance.font.pixelSize.small)
                    font.weight: Font.Medium
                }
                StyledText {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: [root.range, root.city].filter(part => part.length > 0).join("  ·  ")
                    color: root.inkMuted
                    elide: Text.ElideRight
                    font.pixelSize: root.px(Appearance.font.pixelSize.smaller)
                }
            }
        }

        // The next hours: each a column of its hour, its sky and its temperature, the current one in its container.
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: false
            visible: root.hours.length > 0
            spacing: root.px(4)
            Repeater {
                model: root.hours
                Rectangle {
                    id: hour
                    required property var modelData
                    required property int index
                    readonly property bool now: hour.index === 0
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: hourColumn.implicitHeight + root.px(8)
                    radius: root.px(14)
                    color: hour.now ? root.widget.widgetSemanticContainer(root.widget.widgetPrimaryRole) : "transparent"
                    readonly property color hourInk: hour.now ? root.widget.widgetSemanticOnContainer(root.widget.widgetPrimaryRole) : root.ink
                    ColumnLayout {
                        id: hourColumn
                        anchors.centerIn: parent
                        spacing: root.px(1)
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: hour.now ? Translation.tr("Now") : String(hour.modelData.label ?? "")
                            color: hour.now ? hour.hourInk : root.inkMuted
                            font.pixelSize: root.px(Appearance.font.pixelSize.smallest)
                            font.weight: Font.Medium
                        }
                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            text: Icons.getWeatherIcon(hour.modelData.code, Boolean(hour.modelData.isNight)) ?? "cloud"
                            fill: 1
                            iconSize: root.px(18)
                            color: hour.now ? hour.hourInk : root.widget.widgetAccentVisible
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.degrees(hour.modelData.temp)
                            color: hour.hourInk
                            font.family: root.widget.widgetNumbersFamily
                            font.pixelSize: root.px(Appearance.font.pixelSize.small)
                            font.weight: Font.DemiBold
                            font.features: ({ "tnum": 1 })
                        }
                    }
                }
            }
        }

        // Large: the days, each range a stretch of one shared low-to-high scale so the week reads at a glance.
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: false
            visible: root.large && root.days.length > 0
            spacing: root.px(2)
            Repeater {
                model: root.large ? root.days : []
                RowLayout {
                    id: day
                    required property var modelData
                    required property int index
                    readonly property real lo: Number(day.modelData.loVal)
                    readonly property real hi: Number(day.modelData.hiVal)
                    readonly property real span: Math.max(1, root.weekHigh - root.weekLow)
                    Layout.fillWidth: true
                    implicitHeight: root.px(26)
                    spacing: root.px(10)
                    StyledText {
                        Layout.preferredWidth: root.px(44)
                        text: day.index === 0 ? Translation.tr("Today") : String(day.modelData.dayName ?? "")
                        color: root.ink
                        elide: Text.ElideRight
                        font.pixelSize: root.px(Appearance.font.pixelSize.small)
                        font.weight: Font.Medium
                    }
                    MaterialSymbol {
                        text: Icons.getWeatherIcon(day.modelData.code, false) ?? "cloud"
                        fill: 1
                        iconSize: root.px(18)
                        color: root.widget.widgetAccentVisible
                    }
                    StyledText {
                        Layout.preferredWidth: root.px(30)
                        horizontalAlignment: Text.AlignRight
                        text: root.degrees(day.modelData.lo)
                        color: root.inkMuted
                        font.family: root.widget.widgetNumbersFamily
                        font.pixelSize: root.px(Appearance.font.pixelSize.small)
                        font.features: ({ "tnum": 1 })
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: root.px(6)
                        radius: height / 2
                        color: ColorUtils.applyAlpha(root.ink, 0.12)
                        Rectangle {
                            x: Number.isFinite(day.lo) ? parent.width * (day.lo - root.weekLow) / day.span : 0
                            width: Number.isFinite(day.lo) && Number.isFinite(day.hi)
                                ? Math.max(parent.height, parent.width * (day.hi - day.lo) / day.span) : 0
                            height: parent.height
                            radius: height / 2
                            color: root.widget.widgetAccentVisible
                        }
                    }
                    StyledText {
                        Layout.preferredWidth: root.px(30)
                        text: root.degrees(day.modelData.hi)
                        color: root.ink
                        font.family: root.widget.widgetNumbersFamily
                        font.pixelSize: root.px(Appearance.font.pixelSize.small)
                        font.weight: Font.DemiBold
                        font.features: ({ "tnum": 1 })
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        // Large: what the sky feels like, in the tonal chips the detail style uses.
        Row {
            Layout.fillWidth: true
            visible: root.large && root.shownFacts.length > 0
            spacing: root.px(6)
            Repeater {
                model: root.large ? root.shownFacts : []
                Rectangle {
                    id: fact
                    required property var modelData
                    required property int index
                    readonly property string role: fact.index % 2 === 0 ? root.widget.widgetSecondaryRole : root.widget.widgetTertiaryRole
                    width: factRow.implicitWidth + root.px(18)
                    height: factRow.implicitHeight + root.px(10)
                    radius: height / 2
                    color: root.widget.widgetSemanticContainer(fact.role)
                    Row {
                        id: factRow
                        anchors.centerIn: parent
                        spacing: root.px(5)
                        MaterialSymbol {
                            anchors.verticalCenter: parent.verticalCenter
                            text: fact.modelData.icon
                            fill: 1
                            iconSize: root.px(15)
                            color: root.widget.widgetSemanticOnContainer(fact.role)
                        }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: fact.modelData.value
                            color: root.widget.widgetSemanticOnContainer(fact.role)
                            font.pixelSize: root.px(Appearance.font.pixelSize.smaller)
                            font.weight: Font.Medium
                        }
                    }
                }
            }
        }
    }
}
