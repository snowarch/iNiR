pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import Quickshell
import QtQuick
import QtQuick.Layouts

// Rich weather view for the right-sidebar Weather tab. Material 3, minimalist:
// hero · hourly strip · daily forecast with temperature-range bars · sun/moon ·
// metrics · air quality. Family-aware tokens (material / aurora / inir / angel).
Item {
    id: root
    property int margin: 12
    implicitHeight: content.implicitHeight + margin * 2

    Component.onCompleted: { if (!Weather.location.valid) Weather.getData() }

    // ── Tokens ───────────────────────────────────────────────────────────
    readonly property bool angel: Appearance.angelEverywhere
    readonly property bool inir: Appearance.inirEverywhere
    readonly property bool aurora: Appearance.auroraEverywhere
    readonly property bool zzz: Appearance.zzzEverywhere
    readonly property color colText: angel ? Appearance.angel.colText
        : inir ? Appearance.inir.colText
        : zzz ? Appearance.zzz.ink : Appearance.colors.colOnSurface
    readonly property color colSub: angel ? Appearance.angel.colTextSecondary
        : inir ? Appearance.inir.colTextSecondary
        : zzz ? Appearance.zzz.inkMuted : Appearance.colors.colOnSurfaceVariant
    readonly property color colPrimary: angel ? Appearance.angel.colPrimary
        : inir ? Appearance.inir.colPrimary
        : zzz ? Appearance.zzz.accent : Appearance.colors.colPrimary
    readonly property color colCard: angel ? Appearance.angel.colGlassCard
        : inir ? Appearance.inir.colLayer1
        : zzz ? "transparent" // zzz: bgless — el fondo verde (tinte del wallpaper) chocaba; las cards viven sobre el placa carbon
        : aurora ? ColorUtils.transparentize(Appearance.colors.colLayer1, 0.4)
        : Appearance.colors.colSurfaceContainerHigh
    readonly property color colTrack: ColorUtils.transparentize(root.colSub, 0.78)
    readonly property color colHairline: ColorUtils.transparentize(root.colSub, 0.86)
    readonly property color colTint: ColorUtils.transparentize(root.colPrimary, 0.78)
    readonly property real cardRadius: inir ? Appearance.inir.roundingNormal
        : angel ? Appearance.angel.roundingNormal : Appearance.rounding.normal

    readonly property var w: Weather.data
    readonly property var aq: Weather.airQuality
    readonly property var forecast: Weather.data?.forecast ?? []
    readonly property var hourly: Weather.data?.hourly ?? []
    readonly property real aqiProgress: Math.max(0, Math.min(1, (parseFloat(root.aq?.aqi ?? 0) || 0) / 100))

    function weatherSymbol(code, isNight = false): string {
        const icon = Icons.getWeatherIcon(code, isNight) ?? "cloud"
        if (icon === "clear_day") return "light_mode"
        if (icon === "clear_night") return "dark_mode"
        if (icon === "partly_cloudy_day") return "light_mode"
        if (icon === "partly_cloudy_night") return "dark_mode"
        return icon
    }

    function moonPhaseIndex(age): int {
        const a = ((age ?? 0) % 29.530588853 + 29.530588853) % 29.530588853
        if (a < 1.84566 || a >= 27.68493) return 0
        if (a < 5.53699) return 1
        if (a < 9.22831) return 2
        if (a < 12.91963) return 3
        if (a < 16.61096) return 4
        if (a < 20.30228) return 5
        if (a < 23.99361) return 6
        return 7
    }

    function moonPhaseSymbolForIndex(index): string {
        const symbols = ["radio_button_unchecked", "brightness_2", "contrast", "tonality", "circle", "tonality", "contrast", "brightness_2"]
        return symbols[Math.max(0, Math.min(7, index))]
    }

    // Week temperature extent for the range bars.
    readonly property real weekMin: {
        let m = Infinity
        for (const d of root.forecast) if (!isNaN(d.loVal) && d.loVal < m) m = d.loVal
        return m === Infinity ? 0 : m
    }
    readonly property real weekMax: {
        let m = -Infinity
        for (const d of root.forecast) if (!isNaN(d.hiVal) && d.hiVal > m) m = d.hiVal
        return m === -Infinity ? 1 : m
    }

    component Card: Rectangle {
        radius: root.cardRadius
        color: root.colCard
        border.width: (root.angel || root.inir) ? 1 : 0
        border.color: ColorUtils.transparentize(root.colSub, 0.82)
    }

    component MetricTile: Item {
        id: tile
        property string icon: "circle"
        property string title
        property string value
        Layout.fillWidth: true
        implicitHeight: 43

        ColumnLayout {
            anchors.fill: parent
            spacing: 1

            RowLayout {
                Layout.fillWidth: true
                spacing: 5
                MaterialSymbol {
                    text: tile.icon
                    iconSize: 15
                    fill: 1
                    color: ColorUtils.transparentize(root.colPrimary, 0.08)
                }
                StyledText {
                    Layout.fillWidth: true
                    text: tile.title
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: root.colSub
                    elide: Text.ElideRight
                }
            }
            StyledText {
                Layout.fillWidth: true
                text: tile.value
                font.pixelSize: Appearance.font.pixelSize.small
                font.family: Appearance.font.family.numbers
                font.weight: Font.Medium
                color: root.colText
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignLeft
            }
        }
    }

    component PollutantTile: Item {
        id: pollutant
        property string title
        property string value
        Layout.fillWidth: true
        implicitHeight: 42

        ColumnLayout {
            anchors.fill: parent
            spacing: 0
            RowLayout {
                Layout.fillWidth: true
                spacing: 5
                MaterialSymbol {
                    text: "blur_on"
                    iconSize: 14
                    fill: 1
                    color: ColorUtils.transparentize(root.colPrimary, 0.12)
                }
                StyledText {
                    Layout.fillWidth: true
                    text: pollutant.title
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: root.colSub
                    elide: Text.ElideRight
                }
            }
            StyledText {
                Layout.fillWidth: true
                text: pollutant.value
                font.pixelSize: Appearance.font.pixelSize.small
                font.family: Appearance.font.family.numbers
                font.weight: Font.Medium
                color: root.colText
                elide: Text.ElideRight
            }
        }
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: root.margin
        spacing: 10

        // ── Hero ─────────────────────────────────────────────────────────
        Card {
            Layout.fillWidth: true
            implicitHeight: heroRow.implicitHeight + 28

            RowLayout {
                id: heroRow
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 16
                anchors.topMargin: 14
                anchors.bottomMargin: 14
                spacing: 14

                MaterialSymbol {
                    Layout.alignment: Qt.AlignVCenter
                    text: root.weatherSymbol(root.w?.wCode, Weather.isNightNow())
                    iconSize: 56
                    fill: 1
                    color: root.colPrimary
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 0

                    StyledText {
                        text: root.w?.description ?? Translation.tr("Weather")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                        color: root.colSub; elide: Text.ElideRight; Layout.fillWidth: true
                    }
                    StyledText {
                        text: root.w?.temp ?? "--°"
                        font.pixelSize: Appearance.font.pixelSize.huge * 1.45
                        font.weight: Font.Light
                        font.family: Appearance.font.family.numbers
                        color: root.colText; lineHeight: 0.95
                    }
                    RowLayout {
                        spacing: 8
                        Layout.fillWidth: true
                        StyledText {
                            text: Weather.visibleCity
                            visible: Weather.showVisibleCity
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: root.colSub; elide: Text.ElideRight
                            Layout.maximumWidth: 150
                        }
                        StyledText {
                            visible: (root.w?.tempMax ?? "") !== ""
                            text: `↑${root.w?.tempMax ?? ""}  ↓${root.w?.tempMin ?? ""}`
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.family: Appearance.font.family.numbers
                            color: root.colSub
                        }
                    }
                }
            }

            // Borderless refresh — no background, anchored inside the hero.
            MaterialSymbol {
                id: refreshIcon
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 10
                anchors.rightMargin: 12
                text: "refresh"
                iconSize: 20
                fill: 0
                color: refreshMA.containsMouse ? root.colPrimary : root.colSub
                Behavior on color {
                    enabled: Appearance.animationsEnabled
                    ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                }
                MouseArea {
                    id: refreshMA
                    anchors.fill: parent
                    anchors.margins: -7
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Weather.forceRefresh()
                }
            }
        }

        // ── Hourly strip ─────────────────────────────────────────────────
        Card {
            Layout.fillWidth: true
            visible: root.hourly.length > 0
            implicitHeight: 96

            StyledFlickable {
                anchors.fill: parent
                anchors.margins: 6
                contentWidth: hourRow.implicitWidth
                flickableDirection: Flickable.HorizontalFlick
                clip: true

                Row {
                    id: hourRow
                    height: parent.height
                    spacing: 2
                    Repeater {
                        model: root.hourly
                        delegate: ColumnLayout {
                            required property var modelData
                            width: 52
                            height: hourRow.height
                            spacing: 2
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: modelData.label
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: root.colSub
                            }
                            MaterialSymbol {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.weatherSymbol(modelData.code, modelData.isNight)
                                iconSize: 24
                                fill: 1
                                color: root.colPrimary
                            }
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: modelData.temp
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.Medium
                                font.family: Appearance.font.family.numbers
                                color: root.colText
                            }
                        }
                    }
                }
            }
        }

        // ── Daily forecast with temperature-range bars ───────────────────
        Item {
            Layout.fillWidth: true
            visible: root.forecast.length > 1
            implicitHeight: dailyCol.implicitHeight + 20

            ColumnLayout {
                id: dailyCol
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                anchors.topMargin: 9
                anchors.bottomMargin: 9
                spacing: 4

                Repeater {
                    model: root.forecast
                    delegate: RowLayout {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        implicitHeight: 30
                        spacing: 9

                        StyledText {
                            Layout.preferredWidth: 42
                            text: modelData.dayName
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: index === 0 ? Font.Medium : Font.Normal
                            color: index === 0 ? root.colText : root.colSub
                        }
                        MaterialSymbol {
                            Layout.preferredWidth: 24
                            text: root.weatherSymbol(modelData.code, false)
                            iconSize: 22
                            fill: 1
                            color: root.colPrimary
                        }
                        StyledText {
                            Layout.preferredWidth: 34
                            horizontalAlignment: Text.AlignRight
                            text: modelData.lo
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.family: Appearance.font.family.numbers
                            color: root.colSub
                        }
                        // Range bar
                        Item {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            implicitHeight: 8
                            readonly property real span: Math.max(1, root.weekMax - root.weekMin)
                            readonly property real x0: isNaN(modelData.loVal) ? 0 : (modelData.loVal - root.weekMin) / span
                            readonly property real x1: isNaN(modelData.hiVal) ? 1 : (modelData.hiVal - root.weekMin) / span
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                height: 2
                                radius: Math.min(width, height) / 2
                                color: root.colTrack
                            }
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                x: parent.width * parent.x0
                                width: Math.max(parent.height, parent.width * (parent.x1 - parent.x0))
                                height: 5
                                radius: Math.min(width, height) / 2
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: ColorUtils.transparentize(root.colPrimary, 0.55) }
                                    GradientStop { position: 1.0; color: root.colPrimary }
                                }
                                Behavior on x {
                                    enabled: Appearance.animationsEnabled
                                    NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Appearance.animation.elementMove.type; easing.bezierCurve: Appearance.animation.elementMove.bezierCurve }
                                }
                                Behavior on width {
                                    enabled: Appearance.animationsEnabled
                                    NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
                                }
                            }
                        }
                        StyledText {
                            Layout.preferredWidth: 34
                            text: modelData.hi
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Medium
                            font.family: Appearance.font.family.numbers
                            color: root.colText
                        }
                    }
                }
            }
        }

        // ── Sun & moon ───────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            implicitHeight: sunMoonCol.implicitHeight + 24

            ColumnLayout {
                id: sunMoonCol
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                anchors.topMargin: 10
                anchors.bottomMargin: 12
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Item {
                        Layout.fillWidth: true
                        implicitHeight: 38

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 0

                            RowLayout {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 5
                                MaterialSymbol { text: "wb_twilight"; iconSize: 15; fill: 1; color: ColorUtils.transparentize(root.colPrimary, 0.08) }
                                StyledText { text: Translation.tr("Sunrise"); font.pixelSize: Appearance.font.pixelSize.smaller; color: root.colSub }
                            }
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.w?.sunrise ?? "--:--"
                                font.pixelSize: Appearance.font.pixelSize.small; font.weight: Font.Medium
                                font.family: Appearance.font.family.numbers; color: root.colText
                            }
                        }
                    }
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: 38

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 0

                            RowLayout {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 5
                                MaterialSymbol { text: "dark_mode"; iconSize: 15; fill: 1; color: root.colSub }
                                StyledText { text: Translation.tr("Sunset"); font.pixelSize: Appearance.font.pixelSize.smaller; color: root.colSub }
                            }
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.w?.sunset ?? "--:--"
                                font.pixelSize: Appearance.font.pixelSize.small; font.weight: Font.Medium
                                font.family: Appearance.font.family.numbers; color: root.colText
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    spacing: 12

                    MaterialSymbol {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        Layout.alignment: Qt.AlignVCenter
                        text: root.moonPhaseSymbolForIndex(root.moonPhaseIndex(Weather.moonAge))
                        iconSize: 30
                        fill: 1
                        color: root.colText
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            StyledText {
                                Layout.fillWidth: true
                                text: Weather.moonPhaseName
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.Medium
                                color: root.colText
                                elide: Text.ElideRight
                            }
                            StyledText {
                                text: Translation.tr("%1% lit").arg(Math.round(Weather.moonIllumination * 100))
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.family: Appearance.font.family.numbers
                                color: root.colSub
                            }
                        }

                        Item {
                            id: phaseRail
                            Layout.fillWidth: true
                            implicitHeight: 28
                            readonly property int activeIndex: root.moonPhaseIndex(Weather.moonAge)

                            RowLayout {
                                anchors.fill: parent
                                spacing: 3

                                Repeater {
                                    model: 8
                                    delegate: Item {
                                        id: phaseItem
                                        required property int index
                                        Layout.fillWidth: true
                                        implicitHeight: phaseRail.implicitHeight

                                        MaterialSymbol {
                                            anchors.centerIn: parent
                                            text: root.moonPhaseSymbolForIndex(phaseItem.index)
                                            iconSize: phaseItem.index === phaseRail.activeIndex ? 17 : 14
                                            fill: phaseItem.index === phaseRail.activeIndex ? 1 : 0
                                            animateFill: true
                                            color: phaseItem.index === phaseRail.activeIndex ? root.colPrimary : ColorUtils.transparentize(root.colSub, 0.2)
                                            Behavior on iconSize {
                                                enabled: Appearance.animationsEnabled
                                                NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

            }
        }

        // ── Metrics ──────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            implicitHeight: metricsGrid.implicitHeight + 16

            GridLayout {
                id: metricsGrid
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                anchors.topMargin: 8
                anchors.bottomMargin: 8
                columns: 3
                rowSpacing: 8; columnSpacing: 13

                MetricTile { icon: "device_thermostat"; title: Translation.tr("Feels"); value: root.w?.tempFeelsLike ?? "--" }
                MetricTile { icon: "humidity_low"; title: Translation.tr("Humidity"); value: root.w?.humidity ?? "--" }
                MetricTile { icon: "air"; title: Translation.tr("Wind"); value: `${root.w?.windDir ?? ""} ${root.w?.wind ?? ""}`.trim() }
                MetricTile { icon: "rainy_light"; title: Translation.tr("Precip"); value: root.w?.precip ?? "--" }
                MetricTile { icon: "visibility"; title: Translation.tr("Visibility"); value: root.w?.visib ?? "--" }
                MetricTile { icon: "readiness_score"; title: Translation.tr("Pressure"); value: root.w?.press ?? "--" }
            }
        }

        // ── Air quality ──────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            visible: implicitHeight > 0
            implicitHeight: (root.aq?.available ?? false) ? aqiCol.implicitHeight + 18 : 0
            clip: true
            Behavior on implicitHeight {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
            }

            ColumnLayout {
                id: aqiCol
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                anchors.topMargin: 8
                anchors.bottomMargin: 10
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    MaterialSymbol {
                        text: "eco"
                        iconSize: 18
                        fill: 1
                        color: root.colPrimary
                    }
                    StyledText {
                        text: Translation.tr("Air Quality")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium; color: root.colText
                    }
                    Item { Layout.fillWidth: true }
                    StyledText {
                        text: `${root.aq?.aqi ?? "--"} ${root.aq?.scale ?? ""} · ${root.aq?.label ?? ""}`
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.Medium; color: root.colPrimary
                    }
                }
                Item {
                    Layout.fillWidth: true
                    implicitHeight: 5
                    Rectangle {
                        anchors.fill: parent
                        radius: Math.min(width, height) / 2
                        color: root.colTrack
                    }
                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(height, parent.width * root.aqiProgress)
                        height: parent.height
                        radius: Math.min(width, height) / 2
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: ColorUtils.transparentize(root.colPrimary, 0.48) }
                            GradientStop { position: 1.0; color: root.colPrimary }
                        }
                        Behavior on width {
                            enabled: Appearance.animationsEnabled
                            NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
                        }
                    }
                }
                GridLayout {
                    Layout.fillWidth: true
                    columns: 3; rowSpacing: 8; columnSpacing: 12
                    PollutantTile { title: "PM2.5"; value: root.aq?.pm25 ?? "--" }
                    PollutantTile { title: "PM10"; value: root.aq?.pm10 ?? "--" }
                    PollutantTile { title: Translation.tr("Ozone"); value: root.aq?.ozone ?? "--" }
                }
            }
        }

        // ── Footer ───────────────────────────────────────────────────────
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Translation.tr("Updated %1").arg(root.w?.lastRefresh ?? "--:--")
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: root.colSub
        }
    }
}
