pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.shared.background.widgets
import qs.modules.shared.background.widgets.instrument
AbstractBackgroundWidget {
    id: root

    configEntryName: "worldClock"
    familyOptions: [
        { key: "showNames", raw: true, label: Translation.tr("City names"), icon: "label", fallback: true },
        { key: "showOffsets", raw: true, label: Translation.tr("Time difference"), icon: "schedule", fallback: true }
    ]
    resizeMinWidth: 240
    resizeMinHeight: root.instrument ? root.instrumentHeightTarget : 170
    needsColText: true

    readonly property color surfaceInk: root.widgetInk
    readonly property string localCity: Weather.visibleCity
    readonly property var cities: WorldClock.entries
    readonly property bool instrument: String(root._readConfigKey("style") ?? "cards") === "instrument"
    readonly property string instrumentLayout: String(root._readConfigKey("instrumentLayout") ?? "grid")
    readonly property bool instrumentHero: root.isLarge
    readonly property bool showNames: Boolean(root._readConfigKey("showNames") ?? true)
    readonly property bool showOffsets: Boolean(root._readConfigKey("showOffsets") ?? true)
    readonly property bool showDate: Boolean(root._readConfigKey("showDate") ?? true)
    readonly property bool showDayState: Boolean(root._readConfigKey("showDayState") ?? true)
    readonly property bool pulseSeparator: Boolean(root._readConfigKey("pulseSeparator") ?? false)
    readonly property int instrumentHeightTarget: {
        const headerHeight = Math.round(26 * root.scaleFactor)
        const count = Math.max(1, root.cities.length)
        if (root.instrumentLayout === "rows")
            return headerHeight + Math.round(count * 52 * root.scaleFactor)
        const heroHeight = Math.round(94 * root.scaleFactor)
        const comparisonHeight = Math.round(Math.max(0, count - 1) * 48 * root.scaleFactor)
        return headerHeight + heroHeight + comparisonHeight
    }

    function cityDayDelta(index: int): int {
        const cityDate = WorldClock.cityDisplayDate(index)
        if (!cityDate)
            return 0
        return Math.round((
            Date.UTC(cityDate.getFullYear(), cityDate.getMonth(), cityDate.getDate())
            - Date.UTC(WorldClock.now.getFullYear(), WorldClock.now.getMonth(), WorldClock.now.getDate())
        ) / 86400000)
    }

    function cityDateText(index: int): string {
        const cityDate = WorldClock.cityDisplayDate(index)
        return cityDate ? root.widgetCase(Translation.locale.toString(cityDate, "ddd d MMM")) : ""
    }

    Loader {
        anchors.fill: parent
        active: !root.familyFaced
        sourceComponent: Item {
            WidgetSurface {
                widget: root
                anchors.fill: parent
                surfaceColor: root.surfaceInk
                surfaceAccent: root.widgetAccent3
                shown: !root.familyFaced && !root.instrument
                    && (root.backgroundOpacity > 0 || root.borderWidth > 0 || root.effectiveBlur)
            }
        }
    }

    // ── Instrument: world-time atlas ────────────────────────
    // The first zone is the reference city. Additional zones are comparisons,
    // not cloned cards: hierarchy communicates what the user is comparing.
    Loader {
        anchors.fill: parent
        active: !root.familyFaced
        sourceComponent: Item {
            ColumnLayout {
                anchors.fill: parent
                // a sized card keeps its readings off the edge as the plated faces do
                anchors.margins: Math.round(12 * root.scaleFactor)
                opacity: root.instrument ? 1 : 0
                visible: !root.familyFaced && opacity > 0
                enabled: root.instrument
                spacing: Math.round(5 * root.scaleFactor)

                Behavior on opacity {
                    enabled: root.animationsActive
                    NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(20, Math.round(24 * root.scaleFactor))
                    spacing: Math.round(7 * root.scaleFactor)

                    InstrumentLabel {
                        Layout.fillWidth: true
                        text: root.cities.length > 1 ? Translation.tr("Chronometer / %1 zones").arg(root.cities.length)
                            : Translation.tr("Chronometer / Zone")
                        color: root.widgetAccentVisible
                        scaleFactor: root.scaleFactor
                        strong: true
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: root.instrumentLayout === "grid"
                    spacing: Math.round(4 * root.scaleFactor)

                    Item {
                        id: referenceZone
                        // a short card (small, medium) lists every city alike: the lead city squeezed under the rest
                        visible: root.instrumentHero
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredHeight: root.cities.length > 1
                            ? Math.max(78, Math.round(92 * root.scaleFactor))
                            : Math.max(118, Math.round(132 * root.scaleFactor))
                        readonly property var modelData: root.cities.length > 0 ? root.cities[0] : null
                        readonly property int dayDelta: root.cityDayDelta(0)
                        readonly property color accent: root.widgetAccentVisible

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Math.round(6 * root.scaleFactor)
                            anchors.rightMargin: anchors.leftMargin
                            spacing: Math.round(2 * root.scaleFactor)

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Math.round(6 * root.scaleFactor)

                                Rectangle {
                                    id: referenceMark
                                    Layout.preferredWidth: Math.max(2, Math.round(3 * root.scaleFactor))
                                    Layout.preferredHeight: Math.round(14 * root.scaleFactor)
                                    radius: height / 2
                                    color: referenceZone.accent
                                }
                                InstrumentLabel {
                                    Layout.fillWidth: true
                                    visible: referenceZone.modelData
                                    text: referenceZone.modelData ? String(referenceZone.modelData.name) : ""
                                    color: root.widgetInkMuted
                                    scaleFactor: root.scaleFactor
                                    size: 10
                                }
                                StyledText {
                                    visible: root.showOffsets && referenceZone.modelData
                                    text: referenceZone.modelData ? referenceZone.modelData.offset : ""
                                    color: root.widgetInkMuted
                                    font.family: root.widgetNumbersFamily
                                    font.pixelSize: Math.max(8, Math.round(9 * root.scaleFactor))
                                    font.weight: Font.Medium
                                    font.features: ({ "tnum": 1 })
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                verticalAlignment: Text.AlignVCenter
                                text: referenceZone.modelData ? referenceZone.modelData.time : "--:--"
                                color: root.widgetInk
                                fontSizeMode: Text.Fit
                                minimumPixelSize: Math.max(26, Math.round(26 * root.scaleFactor))
                                font.family: root.widgetNumbersFamily
                                font.pixelSize: Math.round(48 * root.scaleFactor)
                                font.weight: root.look.emphasisWeight(Font.Bold)
                                font.features: ({ "tnum": 1 })
                                font.letterSpacing: -1
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                visible: root.showDate || root.showDayState
                                spacing: Math.round(5 * root.scaleFactor)

                                MaterialSymbol {
                                    visible: root.showDayState && referenceZone.modelData
                                    text: referenceZone.modelData && referenceZone.modelData.isDay ? "light_mode" : "bedtime"
                                    color: referenceZone.accent
                                    iconSize: Math.max(10, Math.round(11 * root.scaleFactor))
                                }
                                StyledText {
                                    visible: root.showDate && referenceZone.dayDelta !== 0
                                    text: (referenceZone.dayDelta > 0 ? "+" : "") + referenceZone.dayDelta + "D"
                                    color: referenceZone.accent
                                    font.family: root.widgetNumbersFamily
                                    font.pixelSize: Math.max(8, Math.round(9 * root.scaleFactor))
                                    font.weight: Font.Bold
                                }
                                InstrumentLabel {
                                    Layout.fillWidth: true
                                    visible: root.showDate
                                    text: root.cityDateText(0)
                                    color: root.widgetInkMuted
                                    scaleFactor: root.scaleFactor
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: root.cities.length > (root.instrumentHero ? 1 : 0)
                        spacing: 0

                        Repeater {
                            model: Math.max(0, root.cities.length - (root.instrumentHero ? 1 : 0))

                            Item {
                                id: comparisonZone
                                required property int index
                                readonly property int cityIndex: index + (root.instrumentHero ? 1 : 0)
                                readonly property var modelData: root.cities[cityIndex]
                                readonly property int dayDelta: root.cityDayDelta(cityIndex)
                                readonly property string role: cityIndex % 2 === 0
                                    ? root.widgetTertiaryRole : root.widgetSecondaryRole
                                readonly property color accent: root.widgetSemanticForeground(role)

                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.minimumHeight: Math.max(42, Math.round(46 * root.scaleFactor))

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Math.round(6 * root.scaleFactor)
                                    anchors.rightMargin: anchors.leftMargin
                                    spacing: Math.round(6 * root.scaleFactor)

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: -1
                                        StyledText {
                                            Layout.fillWidth: true
                                            visible: true
                                            text: String(comparisonZone.modelData.name)
                                            color: root.widgetInk
                                            elide: Text.ElideRight
                                            font.family: root.widgetBodyFamily
                                            font.pixelSize: Math.max(11, Math.round(11 * root.scaleFactor))
                                            font.weight: root.widgetLabelWeight
                                            font.letterSpacing: root.widgetMetadataTracking
                                            font.capitalization: root.familyDesign ? Font.MixedCase : Font.AllUppercase
                                        }
                                        RowLayout {
                                            Layout.fillWidth: true
                                            visible: root.showDate || root.showOffsets
                                            spacing: Math.round(4 * root.scaleFactor)
                                            StyledText {
                                                visible: root.showDate && comparisonZone.dayDelta !== 0
                                                text: (comparisonZone.dayDelta > 0 ? "+" : "") + comparisonZone.dayDelta + "D"
                                                color: comparisonZone.accent
                                                font.family: root.widgetNumbersFamily
                                                font.pixelSize: Math.max(7, Math.round(8 * root.scaleFactor))
                                                font.weight: Font.Bold
                                            }
                                            StyledText {
                                                Layout.fillWidth: true
                                                // small has room for the offset only
                                                visible: root.showDate && !root.isSmall
                                                text: root.cityDateText(comparisonZone.cityIndex)
                                                color: root.widgetInkMuted
                                                elide: Text.ElideRight
                                                font.family: root.widgetBodyFamily
                                                font.pixelSize: Math.max(10, Math.round(10 * root.scaleFactor))
                                                font.weight: Font.Medium
                                                font.letterSpacing: root.widgetMetadataTracking
                                                font.capitalization: root.familyDesign ? Font.MixedCase : Font.AllUppercase
                                            }
                                            StyledText {
                                                visible: root.showOffsets
                                                text: comparisonZone.modelData.offset
                                                color: root.widgetInkMuted
                                                font.family: root.widgetNumbersFamily
                                                font.pixelSize: Math.max(10, Math.round(10 * root.scaleFactor))
                                                font.weight: Font.Medium
                                            }
                                        }
                                    }
                                    MaterialSymbol {
                                        visible: root.showDayState
                                        text: comparisonZone.modelData.isDay ? "light_mode" : "bedtime"
                                        color: comparisonZone.accent
                                        iconSize: Math.max(9, Math.round(10 * root.scaleFactor))
                                    }
                                    StyledText {
                                        text: comparisonZone.modelData.time
                                        color: root.widgetInk
                                        font.family: root.widgetNumbersFamily
                                        // small leaves the city's name its room
                                        font.pixelSize: Math.round((root.isSmall ? 19 : 24) * root.scaleFactor)
                                        font.weight: root.look.emphasisWeight(Font.DemiBold)
                                        font.features: ({ "tnum": 1 })
                                        font.letterSpacing: -1
                                    }
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: root.instrumentLayout === "rows"
                    spacing: 0

                    Repeater {
                        model: root.cities.length

                        Item {
                            id: ledgerZone
                            required property int index
                            readonly property var modelData: root.cities[index]
                            readonly property int dayDelta: root.cityDayDelta(index)
                            readonly property string role: index === 0 ? root.widgetPrimaryRole
                                : index % 2 === 0 ? root.widgetTertiaryRole : root.widgetSecondaryRole
                            readonly property color accent: root.widgetSemanticForeground(role)

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: Math.max(40, Math.round(44 * root.scaleFactor))

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Math.round(5 * root.scaleFactor)
                                anchors.rightMargin: anchors.leftMargin
                                spacing: Math.round(7 * root.scaleFactor)

                                // small gives the rule's room to the city's name
                                Rectangle {
                                    visible: !root.isSmall
                                    Layout.preferredWidth: index === 0
                                        ? Math.max(18, Math.round(24 * root.scaleFactor))
                                        : Math.max(10, Math.round(14 * root.scaleFactor))
                                    Layout.preferredHeight: Math.max(2, Math.round(2 * root.scaleFactor))
                                    radius: height / 2
                                    color: ledgerZone.accent
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: -1
                                    StyledText {
                                        Layout.fillWidth: true
                                        visible: true
                                        text: root.widgetCase(String(ledgerZone.modelData.name))
                                        color: index === 0 ? root.widgetInk : root.widgetInkMuted
                                        elide: Text.ElideRight
                                        font.family: root.widgetBodyFamily
                                        font.pixelSize: Math.max(8, Math.round(9 * root.scaleFactor))
                                        font.weight: index === 0 ? root.widgetLabelWeight : Font.Medium
                                        font.letterSpacing: root.widgetMetadataTracking
                                        font.capitalization: root.familyDesign ? Font.MixedCase : Font.AllUppercase
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        visible: root.showDate || root.showOffsets
                                        spacing: Math.round(4 * root.scaleFactor)
                                        StyledText {
                                            visible: root.showDate && ledgerZone.dayDelta !== 0
                                            text: (ledgerZone.dayDelta > 0 ? "+" : "") + ledgerZone.dayDelta + "D"
                                            color: ledgerZone.accent
                                            font.family: root.widgetNumbersFamily
                                            font.pixelSize: Math.max(7, Math.round(8 * root.scaleFactor))
                                            font.weight: Font.Bold
                                        }
                                        StyledText {
                                            Layout.fillWidth: true
                                            // small keeps the day's step (+1D) and drops the date it can't fit
                                            visible: root.showDate && !root.isSmall
                                            text: root.cityDateText(index)
                                            color: root.widgetInkMuted
                                            elide: Text.ElideRight
                                            font.family: root.widgetBodyFamily
                                            font.pixelSize: Math.max(7, Math.round(8 * root.scaleFactor))
                                            font.weight: Font.Medium
                                            font.letterSpacing: root.widgetMetadataTracking
                                            font.capitalization: root.familyDesign ? Font.MixedCase : Font.AllUppercase
                                        }
                                        StyledText {
                                            visible: root.showOffsets
                                            text: ledgerZone.modelData.offset
                                            color: root.widgetInkMuted
                                            font.family: root.widgetNumbersFamily
                                            font.pixelSize: Math.max(7, Math.round(8 * root.scaleFactor))
                                            font.weight: Font.Medium
                                        }
                                    }
                                }
                                MaterialSymbol {
                                    visible: root.showDayState
                                    text: ledgerZone.modelData.isDay ? "light_mode" : "bedtime"
                                    color: ledgerZone.accent
                                    iconSize: Math.max(9, Math.round(10 * root.scaleFactor))
                                }
                                StyledText {
                                    text: ledgerZone.modelData.time
                                    color: root.widgetInk
                                    font.family: root.widgetNumbersFamily
                                    font.pixelSize: root.isSmall ? Math.round((index === 0 ? 22 : 19) * root.scaleFactor)
                                        : index === 0 ? Math.max(22, Math.round(27 * root.scaleFactor))
                                        : Math.max(20, Math.round(24 * root.scaleFactor))
                                    font.weight: index === 0 ? root.look.emphasisWeight(Font.DemiBold) : Font.DemiBold
                                    font.features: ({ "tnum": 1 })
                                    font.letterSpacing: -0.6
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    Loader {
        anchors.fill: parent
        active: !root.familyFaced
        sourceComponent: Item {
            ColumnLayout {
                opacity: root.instrument ? 0 : 1
                visible: !root.familyFaced && opacity > 0
                enabled: !root.instrument
                Behavior on opacity {
                    enabled: root.animationsActive
                    NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
                }
                anchors.fill: parent
                anchors.margins: Math.round(14 * root.scaleFactor)
                spacing: Math.round(8 * root.scaleFactor)

                // small is only the cities: a row each, its name over its time
                Rectangle {
                    Layout.alignment: Qt.AlignLeft
                    visible: Weather.showVisibleCity && !root.isSmall
                    implicitWidth: localChip.implicitWidth + Math.round(18 * root.scaleFactor)
                    implicitHeight: localChip.implicitHeight + Math.round(8 * root.scaleFactor)
                    radius: root.widgetEditorial ? root.widgetControlRadius : height / 2
                    color: root.widgetPrimaryMark.fill

                    RowLayout {
                        id: localChip
                        anchors.centerIn: parent
                        spacing: Math.round(5 * root.scaleFactor)

                        MaterialSymbol {
                            text: "place"
                            fill: 1
                            iconSize: Math.round(Appearance.font.pixelSize.small * root.scaleFactor)
                            color: root.widgetPrimaryMark.ink
                        }

                        StyledText {
                            text: root.localCity || Translation.tr("Local")
                            elide: Text.ElideRight
                            color: root.widgetPrimaryMark.ink
                            font.pixelSize: Math.round(Appearance.font.pixelSize.smaller * root.scaleFactor)
                            font.weight: root.widgetLabelWeight
                        }
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: !root.isSmall
                    text: DateTime.time || "--:--"
                    color: root.surfaceInk
                    elide: Text.ElideRight
                    font {
                        family: root.widgetNumbersFamily
                        // here leads: never smaller than the cities' times under it
                        pixelSize: Math.round((root.isLarge ? 40 : Appearance.font.pixelSize.huge) * root.scaleFactor)
                        weight: Font.DemiBold
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    // a short card spends its height on the cities; the date put the last of them past the edge
                    visible: root.height >= Math.round(200 * root.scaleFactor) && !root.isSmall
                    text: Translation.locale.toString(WorldClock.now, "dddd, MMMM d yyyy")
                    color: root.widgetInkMuted
                    elide: Text.ElideRight
                    font.pixelSize: Math.round(Appearance.font.pixelSize.smaller * root.scaleFactor)
                }

                GridLayout {
                    id: cityGrid
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    // one size for every tile: measured per tile, a row a pixel shorter (London) came out a size down
                    readonly property int rows: Math.max(1, Math.ceil(root.cities.length / Math.max(1, cityGrid.columns)))
                    readonly property real cellHeight: (cityGrid.height - (cityGrid.rows - 1) * cityGrid.rowSpacing) / cityGrid.rows
                    readonly property real cellWidth: (cityGrid.width - (cityGrid.columns - 1) * cityGrid.columnSpacing) / Math.max(1, cityGrid.columns)
                    readonly property bool roomy: cityGrid.cellHeight >= Math.round(70 * root.scaleFactor)
                        && cityGrid.cellWidth >= Math.round(140 * root.scaleFactor)
                    // a wide card lays its cities in one row; two rows of tiles ran past a medium card, and an odd count
                    // in two columns left a hole
                    columns: root.width > root.height * 1.5 ? Math.min(4, Math.max(1, root.cities.length))
                        : root.isSmall || root.cities.length % 2 === 1 ? 1 : 2
                    columnSpacing: Math.round(6 * root.scaleFactor)
                    rowSpacing: Math.round(6 * root.scaleFactor)

                    Repeater {
                        model: root.cities

                        delegate: Rectangle {
                            id: cityCell
                            required property var modelData
                            required property int index
                            readonly property bool alternate: (index % 2) === (Math.floor(index / 2) % 2)
                            readonly property string cellRole: cityCell.alternate
                                ? root.widgetSecondaryRole : root.widgetTertiaryRole
                            readonly property color cellColor: root.widgetSemanticContainer(cityCell.cellRole)
                            readonly property color cellInk: root.widgetSemanticOnContainer(cityCell.cellRole)
                            readonly property color cellAccent: root.widgetSemanticColor(cityCell.cellRole)
                            // a tall, wide tile (large, a city a row) sets its city and time a size up
                            readonly property bool roomy: cityGrid.roomy

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: Math.round(44 * root.scaleFactor)
                            radius: root.widgetCardRadius * 0.72
                            color: cityCell.cellColor

                            Behavior on color {
                                enabled: Appearance.animationsEnabled
                                ColorAnimation {
                                    duration: Appearance.animation.elementMoveFast.duration
                                    easing.type: Appearance.animation.elementMoveFast.type
                                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: Math.round(8 * root.scaleFactor)
                                spacing: Math.round(6 * root.scaleFactor)

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: -Math.round(2 * root.scaleFactor)

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Math.round(4 * root.scaleFactor)

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: cityCell.modelData.name
                                            elide: Text.ElideRight
                                            color: ColorUtils.applyAlpha(cityCell.cellInk, 0.7)
                                            font.pixelSize: Math.round((cityCell.roomy ? Appearance.font.pixelSize.small : Appearance.font.pixelSize.smallest) * root.scaleFactor)
                                        }

                                        StyledText {
                                            // a narrow tile keeps the city's name whole; the offset is the first to go
                                            visible: cityCell.width >= Math.round(150 * root.scaleFactor)
                                            text: cityCell.modelData.offset
                                            color: ColorUtils.applyAlpha(cityCell.cellInk, 0.5)
                                            font.pixelSize: Math.round(Appearance.font.pixelSize.smallest * root.scaleFactor)
                                        }
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: cityCell.modelData.time
                                        elide: Text.ElideRight
                                        color: cityCell.cellInk
                                        font {
                                            family: root.widgetNumbersFamily
                                            pixelSize: Math.round((cityCell.roomy ? 30 : Appearance.font.pixelSize.large) * root.scaleFactor)
                                            weight: Font.Bold
                                        }
                                    }
                                }

                                MaterialShape {
                                    Layout.alignment: Qt.AlignVCenter
                                    visible: cityCell.height >= Math.round(40 * root.scaleFactor)
                                    implicitSize: Math.round((cityCell.roomy ? 34 : 24) * root.scaleFactor)
                                    shape: cityCell.modelData.isDay
                                        ? MaterialShape.Shape.Sunny
                                        : MaterialShape.Shape.ClamShell
                                    color: ColorUtils.applyAlpha(cityCell.cellAccent, 0.9)

                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: cityCell.modelData.isDay ? "light_mode" : "dark_mode"
                                        fill: 1
                                        iconSize: Math.round((cityCell.roomy ? 18 : 13) * root.scaleFactor)
                                        color: root.widgetSemanticOnColor(cityCell.cellRole)
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
