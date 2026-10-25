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

    configEntryName: "uptime"
    defaultConfig: ({
        placementStrategy: "free", contentWidth: 250, contentHeight: 96,
        widgetScale: 100, widgetOpacity: 100, colorMode: "auto", dim: 0,
        style: "row", showSince: true, showBreakdown: true,
        showBackground: true, showBorder: true, backgroundOpacity: 0.16,
        borderWidth: 1, borderOpacity: 0.2, cornerRadius: -1, useBlur: false,
        x: 80, y: 80
    })

    readonly property string uptimeStyle: String(root._readConfigKey("style") ?? "row")
    readonly property bool instrument: root.uptimeStyle === "instrument"
    readonly property bool showSince: Boolean(root._readConfigKey("showSince") ?? true)
    readonly property bool showBreakdown: Boolean(root._readConfigKey("showBreakdown") ?? true)
    readonly property bool showInstrumentDetails: root.showSince || root.showBreakdown

    widgetSurfaceEnabled: !root.instrument
    readonly property int sessionSeconds: {
        const m = String(DateTime.uptime).match(/(\d+)d/)
        const h = String(DateTime.uptime).match(/(\d+)h/)
        const min = String(DateTime.uptime).match(/(\d+)m/)
        return (Number(m?.[1] ?? 0)) * 86400
            + (Number(h?.[1] ?? 0)) * 3600 + (Number(min?.[1] ?? 0)) * 60
    }
    // Session day is an ordinal; elapsed duration remains the primary value.
    readonly property int sessionDay: Math.max(1, Math.floor(root.sessionSeconds / 86400) + 1)

    readonly property int rowWidth: Math.round(Number(root._readConfigKey("contentWidth") ?? 250) * scaleFactor)
    readonly property int rowHeight: Math.round(Number(root._readConfigKey("contentHeight") ?? 96) * scaleFactor)
    // Preserve the saved row dimensions when switching presentation.
    implicitWidth: root.irisFaced ? root.irisFaceWidth : root.materialSized ? root.materialWidth : root.instrument ? Math.max(root.rowWidth, Math.round(260 * scaleFactor)) : root.rowWidth
    implicitHeight: root.irisFaced ? root.irisFaceHeight : root.materialSized ? root.materialHeight : root.instrument ? Math.max(root.rowHeight, Math.round(130 * scaleFactor)) : root.rowHeight
    irisFacePart: "uptime"
    irisSizes: ["small", "medium", "large"]
    irisOptions: [
        { key: "showSince", raw: true, label: Translation.tr("Start time"), icon: "login", fallback: true }
    ]
    resizableAxes: ({ width: "contentWidth", height: "contentHeight" })
    resizeMinWidth: root.instrument ? Math.round(260 * scaleFactor) : 190
    resizeMinHeight: root.instrument ? Math.round(130 * scaleFactor) : 76
    needsColText: true
    readonly property color surfaceInk: root.widgetInk

    // Boot wall-clock estimate: the parsed uptime is minute-granular, which is
    // all a “since HH:mm” caption promises.
    readonly property var bootDate: {
        const d = new Date(DateTime.clock.date.getTime() - root.sessionSeconds * 1000)
        return d
    }
    readonly property string bootLabel: Qt.locale().toString(root.bootDate, "HH:mm")
    // The session laid on the day, 0..1: from waking to now. Early in a day a session from yesterday would be a sliver,
    // so it reads the last 24 hours instead.
    readonly property real nowAt: (DateTime.clock.date.getHours() * 60 + DateTime.clock.date.getMinutes()) / 1440
    readonly property bool sinceYesterday: root.sessionSeconds / 86400 >= root.nowAt
    readonly property real bootAt: root.sinceYesterday ? 0 : root.nowAt - root.sessionSeconds / 86400
    readonly property bool rolling: root.sinceYesterday && root.nowAt < 0.25
    readonly property real sessionFrom: root.rolling ? Math.max(0, 1 - root.sessionSeconds / 86400) : root.bootAt
    readonly property real sessionTo: root.rolling ? 1 : root.nowAt
    readonly property var sessionMarks: {
        if (!root.rolling)
            return ["0", "6", "12", "18", "24"]
        const now = DateTime.clock.date
        const hour = now.getHours() + (now.getMinutes() >= 30 ? 1 : 0)
        return [-24, -18, -12, -6].map(back => String(((hour + back) % 24 + 24) % 24)).concat([Translation.tr("Now")])
    }
    readonly property string bootDay: Translation.locale.toString(root.bootDate, "dddd").replace(/^./, first => first.toUpperCase())
    readonly property string startedText: (root.sinceYesterday ? root.bootDay + " " : "") + root.bootLabel
    function spanText(seconds: int): string {
        const h = Math.floor(seconds / 3600)
        const m = Math.floor(seconds % 3600 / 60)
        return h > 0 ? Translation.tr("%1 h %2 min").arg(h).arg(m) : Translation.tr("%1 min").arg(m)
    }
    readonly property string onTodayText: root.spanText(Math.round((root.nowAt - root.bootAt) * 86400))

    Loader {
        anchors.fill: parent
        active: !root.irisFaced
        sourceComponent: Item {
            WidgetSurface {
                irisPresentation: root.widgetIris
                regionBrightness: root.regionBrightness
                anchors.fill: parent
                shown: !root.irisFaced && !root.instrument
                    && (root.backgroundOpacity > 0 || root.borderWidth > 0 || root.effectiveBlur)
                surfaceRadius: root.cornerRadiusOverride >= 0 ? root.cornerRadiusOverride : root.widgetCardRadius
                surfaceOpacity: root.backgroundOpacity
                surfaceBorderWidth: root.borderWidth
                surfaceBorderOpacity: root.borderOpacity
                surfaceColor: root.surfaceInk
                colorMode: root.colorMode
                surfaceAccent: root.widgetAccent3
                surfaceFill: root.widgetPlateColor
                surfaceUseBlur: root.effectiveBlur
                screenX: root.x
                screenY: root.y
                screenWidth: root.scaledScreenWidth
                screenHeight: root.scaledScreenHeight
            }
        }
    }

    // ── Row style (default) ──
    // Sized: the two largest units are the figure, each number in the figure face with its unit a step down; when
    // the session began under it.
    readonly property var materialParts: {
        const days = Math.floor(root.sessionSeconds / 86400)
        const hours = Math.floor(root.sessionSeconds % 86400 / 3600)
        const minutes = Math.floor(root.sessionSeconds % 3600 / 60)
        return days > 0 ? [{ value: days, unit: Translation.tr("d") }, { value: hours, unit: Translation.tr("h") }]
            : hours > 0 ? [{ value: hours, unit: Translation.tr("h") }, { value: minutes, unit: Translation.tr("min") }]
            : [{ value: minutes, unit: Translation.tr("min") }]
    }
    Loader {
        anchors.fill: parent
        active: !root.irisFaced
        sourceComponent: Item {
            UptimeDay {
                anchors.fill: parent
                visible: !root.irisFaced && !root.instrument && root.materialSized && !root.materialSmall
                widget: root
                large: root.materialLarge
            }
        }
    }
    ColumnLayout {
        visible: !root.irisFaced && !root.instrument && root.materialSmall
        anchors.fill: parent
        anchors.margins: Math.round(16 * root.scaleFactor)
        spacing: Math.round(2 * root.scaleFactor)
        Rectangle {
            implicitWidth: Math.round(40 * root.scaleFactor)
            implicitHeight: implicitWidth
            radius: width / 2
            color: root.widgetSemanticContainer(root.widgetTertiaryRole)
            MaterialSymbol {
                anchors.centerIn: parent
                text: "avg_pace"
                fill: 1
                iconSize: Math.round(22 * root.scaleFactor)
                color: root.widgetSemanticOnContainer(root.widgetTertiaryRole)
            }
        }
        Item { Layout.fillHeight: true }
        StyledText {
            text: Translation.tr("Uptime")
            color: ColorUtils.applyAlpha(root.surfaceInk, 0.66)
            font.pixelSize: Math.round(Appearance.font.pixelSize.small * root.scaleFactor)
        }
        Row {
            spacing: Math.round(6 * root.scaleFactor)
            Repeater {
                model: root.materialParts
                Row {
                    id: part
                    required property var modelData
                    spacing: Math.round(1 * root.scaleFactor)
                    StyledText {
                        id: partValue
                        text: String(part.modelData.value)
                        color: root.surfaceInk
                        font.family: root.widgetNumbersFamily
                        font.pixelSize: Math.round(34 * root.scaleFactor)
                        font.weight: Font.DemiBold
                        font.features: ({ "tnum": 1 })
                    }
                    StyledText {
                        anchors.baseline: partValue.baseline
                        text: part.modelData.unit
                        color: ColorUtils.applyAlpha(root.surfaceInk, 0.66)
                        font.pixelSize: Math.round(16 * root.scaleFactor)
                        font.weight: Font.DemiBold
                    }
                }
            }
        }
        StyledText {
            Layout.fillWidth: true
            visible: root.showSince
            text: Translation.tr("Since %1").arg(root.bootLabel)
            color: ColorUtils.applyAlpha(root.surfaceInk, 0.66)
            elide: Text.ElideRight
            font.pixelSize: Math.round(Appearance.font.pixelSize.smaller * root.scaleFactor)
        }
    }

    Loader {
        anchors.fill: parent
        active: !root.irisFaced
        sourceComponent: Item {
            RowLayout {
                opacity: root.instrument ? 0 : 1
                visible: !root.irisFaced && !root.materialSized && opacity > 0
                enabled: !root.instrument
                Behavior on opacity {
                    enabled: root.animationsActive
                    NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
                }
                anchors.fill: parent
                anchors.margins: Math.round(14 * root.scaleFactor)
                spacing: Math.round(12 * root.scaleFactor)

                MaterialSymbol {
                    text: "avg_pace"
                    iconSize: Math.round(38 * root.scaleFactor)
                    color: root.widgetAccent3Visible
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Math.round(2 * root.scaleFactor)

                    StyledText {
                        text: Translation.tr("System uptime")
                        color: ColorUtils.applyAlpha(root.surfaceInk, 0.66)
                        font.pixelSize: Math.round(Appearance.font.pixelSize.smaller * root.scaleFactor)
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: DateTime.uptime || "--"
                        color: root.surfaceInk
                        elide: Text.ElideRight
                        wrapMode: Text.NoWrap
                        font {
                            family: root.widgetNumbersFamily
                            pixelSize: Math.round(Appearance.font.pixelSize.large * root.scaleFactor)
                            weight: Font.DemiBold
                        }
                    }
                }
            }
        }
    }

    // ── Instrument: session chronometer ───────────────────────
    // Uptime has no finish line. The elapsed duration is the instrument; the
    // session day and boot time are annotations, not competing hero values.
    Loader {
        anchors.fill: parent
        active: !root.irisFaced
        sourceComponent: Item {
            Item {
                id: instrumentArea
                anchors.fill: parent
                anchors.margins: Math.round(13 * root.scaleFactor)
                opacity: root.instrument ? 1 : 0
                visible: !root.irisFaced && opacity > 0
                enabled: root.instrument

                Behavior on opacity {
                    enabled: root.animationsActive
                    NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
                }

                // small stacks the reading over its notes; beside it they left the figure 40 px
                GridLayout {
                    id: instrumentReading
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: root.materialLarge ? implicitHeight : parent.height
                    columns: root.materialSmall ? 1 : 3
                    columnSpacing: Math.round(12 * root.scaleFactor)
                    rowSpacing: Math.round(8 * root.scaleFactor)

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: Math.round(6 * root.scaleFactor)

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Math.round(6 * root.scaleFactor)

                            InstrumentLabel {
                                Layout.fillWidth: true
                                text: root.materialSmall ? Translation.tr("Uptime") : Translation.tr("System / Uptime")
                                color: root.widgetAccentVisible
                                scaleFactor: root.scaleFactor
                                strong: true
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            verticalAlignment: Text.AlignVCenter
                            text: root.materialSmall ? root.materialParts.map(part => part.value + part.unit).join(" ") : DateTime.uptime || "--"
                            color: root.widgetInk
                            elide: Text.ElideRight
                            fontSizeMode: Text.Fit
                            minimumPixelSize: Math.max(20, Math.round(20 * root.scaleFactor))
                            font.family: root.widgetNumbersFamily
                            font.pixelSize: Math.round(42 * root.scaleFactor)
                            font.weight: root.widgetEditorial ? Appearance.editorial.titleWeight : Font.Bold
                            font.features: ({ "tnum": 1 })
                            font.letterSpacing: -1
                        }
                    }

                    Rectangle {
                        visible: root.showInstrumentDetails && !root.materialSmall
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredHeight: Math.round(58 * root.scaleFactor)
                        Layout.preferredWidth: Math.max(1, Math.round(root.scaleFactor))
                        color: ColorUtils.applyAlpha(root.widgetInk, 0.16)
                    }

                    ColumnLayout {
                        visible: root.showInstrumentDetails
                        Layout.preferredWidth: Math.max(84, Math.round(96 * root.scaleFactor))
                        Layout.fillWidth: root.materialSmall
                        Layout.alignment: Qt.AlignVCenter
                        spacing: Math.round(5 * root.scaleFactor)

                        Item { Layout.fillHeight: true; visible: !root.materialSmall }

                        StyledText {
                            visible: root.showBreakdown
                            text: Translation.tr("Day") + " " + root.sessionDay
                            color: root.widgetAccent3Visible
                            font.family: root.widgetNumbersFamily
                            font.pixelSize: Math.max(15, Math.round(18 * root.scaleFactor))
                            font.weight: Font.Bold
                            font.features: ({ "tnum": 1 })
                        }

                        InstrumentLabel {
                            visible: root.showSince
                            Layout.fillWidth: true
                            text: Translation.tr("Since") + " " + root.bootLabel
                            color: root.widgetInkMuted
                            scaleFactor: root.scaleFactor
                        }

                        Item { Layout.fillHeight: true; visible: !root.materialSmall }
                    }
                }

                // Large: the day in 24 ticks, the hours it has been on lit, and the session's facts under them.
                ColumnLayout {
                    visible: root.materialLarge
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    spacing: Math.round(8 * root.scaleFactor)
                    Row {
                        id: dayTicks
                        Layout.fillWidth: true
                        spacing: Math.round(3 * root.scaleFactor)
                        readonly property real tick: (width - spacing * 23) / 24
                        Repeater {
                            model: 24
                            Rectangle {
                                required property int index
                                readonly property bool on: (index + 1) / 24 > root.sessionFrom && index / 24 < root.sessionTo
                                width: dayTicks.tick
                                height: Math.round(22 * root.scaleFactor)
                                color: on ? root.widgetAccentVisible : ColorUtils.applyAlpha(root.widgetInk, 0.14)
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: -Math.round(4 * root.scaleFactor)
                        Repeater {
                            model: root.sessionMarks
                            InstrumentLabel {
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                horizontalAlignment: index === 0 ? Text.AlignLeft : index === root.sessionMarks.length - 1 ? Text.AlignRight : Text.AlignHCenter
                                text: String(modelData)
                                color: root.widgetInkMuted
                                scaleFactor: root.scaleFactor
                                size: 9
                            }
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.topMargin: Math.round(6 * root.scaleFactor)
                        implicitHeight: Math.max(1, Math.round(root.scaleFactor))
                        color: ColorUtils.applyAlpha(root.widgetInk, 0.16)
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Math.round(12 * root.scaleFactor)
                        Repeater {
                            model: [
                                { label: Translation.tr("Started"), value: root.startedText },
                                { label: Translation.tr("On today"), value: root.onTodayText }
                            ]
                            InstrumentField {
                                required property var modelData
                                Layout.fillWidth: true
                                scaleFactor: root.scaleFactor
                                label: modelData.label
                                value: modelData.value
                                ink: root.widgetInk
                                muted: root.widgetInkMuted
                                family: root.widgetNumbersFamily
                                valueSize: 13
                            }
                        }
                    }
                }
            }
        }
    }

    editPopoverContent: Component {
        ColumnLayout {
            spacing: 14
            WidgetQuickSection {
                title: Translation.tr("Style")
                WidgetQuickChoices {
                    current: root.uptimeStyle
                    model: [
                        { label: Translation.tr("Row"), icon: "table_rows", value: "row" },
                        { label: Translation.tr("Instrument"), icon: "avg_pace", value: "instrument" }
                    ]
                    onPicked: value => root._setOutputValue("style", value)
                }
            }
            WidgetQuickSection {
                visible: root.instrument
                title: Translation.tr("Show")
                Repeater {
                    model: [
                        { label: Translation.tr("Since"), icon: "schedule", key: "showSince", fallback: true },
                        { label: Translation.tr("Breakdown"), icon: "view_agenda", key: "showBreakdown", fallback: true }
                    ]
                    WidgetQuickToggle {
                        required property var modelData
                        Layout.fillWidth: true
                        iconName: modelData.icon
                        label: modelData.label
                        checked: Boolean(root._readConfigKey(modelData.key) ?? modelData.fallback)
                        onToggled: root._setOutputValue(modelData.key, !checked)
                    }
                }
            }
        }
    }
}
