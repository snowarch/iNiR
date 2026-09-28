pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.background.widgets
import qs.modules.background.widgets.instrument
import qs.modules.iris.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "dayProgress"
    defaultConfig: ({
        placementStrategy: "free", contentWidth: 240, contentHeight: 240,
        widgetScale: 100, widgetOpacity: 100, colorMode: "auto", dim: 0,
        style: "ring", comet: true, showIcon: true, showDate: true, hourLabels: true, fontScale: 100,
        showBackground: false, showBorder: false, backgroundOpacity: 0,
        borderWidth: 0, borderOpacity: 0.2, cornerRadius: -1, useBlur: false,
        x: 80, y: 260
    })

    implicitWidth: root.irisFaced ? root.irisFaceWidth : Math.round(Number(root._readConfigKey("contentWidth") ?? 240) * scaleFactor)
    implicitHeight: root.irisFaced ? root.irisFaceHeight : Math.round(Number(root._readConfigKey("contentHeight") ?? 240) * scaleFactor)
    irisFace: Component { IrisDayFace { widget: root } }
    irisSizes: ["small", "medium"]
    resizableAxes: ({ width: "contentWidth", height: "contentHeight" })
    resizeMinWidth: 190
    resizeMinHeight: 190
    needsColText: true
    widgetSurfaceEnabled: false

    // ── Tokens ───────────────────────────────────────────────
    // Semantic roles follow the shared desktop-widget palette contract
    // (colorMode + per-role palette), never hardcoded colors.
    readonly property color ink: root.widgetInk
    readonly property color inkMuted: root.widgetInkMuted
    readonly property color inkFaint: ColorUtils.applyAlpha(root.ink, 0.16)
    readonly property color inkDim: ColorUtils.applyAlpha(root.ink, 0.34)
    readonly property color accent: root.widgetAccentVisible
    readonly property color accentSoft: root.widgetAccent3Visible

    // ── Customization ────────────────────────────────────────
    readonly property string ringStyle: String(root._readConfigKey("style") ?? "ring")
    readonly property bool showTicks: root.ringStyle !== "arc"
    readonly property bool showArc: root.ringStyle !== "ticks"
    readonly property bool showComet: root.showArc && Boolean(root._readConfigKey("comet") ?? true)
    readonly property bool showIcon: Boolean(root._readConfigKey("showIcon") ?? true)
    readonly property bool showDate: Boolean(root._readConfigKey("showDate") ?? true)
    readonly property bool showHourLabels: Boolean(root._readConfigKey("hourLabels") ?? true)
    // Text emphasis control: 100% keeps the ring-relative defaults.
    readonly property real textScale: {
        const v = Number(root._readConfigKey("fontScale") ?? 100)
        return Math.max(0.6, Math.min(1.8, Number.isFinite(v) ? v / 100 : 1))
    }

    // ── Day state ────────────────────────────────────────────
    readonly property real dayFraction: {
        const d = DateTime.clock.date
        return (d.getHours() * 3600 + d.getMinutes() * 60 + d.getSeconds()) / 86400
    }
    readonly property bool isDaytime: {
        const h = DateTime.clock.date.getHours()
        return h >= 6 && h < 19
    }

    // Borderless composition: no card, no border. The wallpaper-sampled ink
    // (needsColText) is the only thing keeping ring and type legible.
    ColumnLayout {
        visible: !root.irisFaced
        anchors.fill: parent
        anchors.margins: Math.round(14 * root.scaleFactor)
        spacing: Math.round(10 * root.scaleFactor)

        Item {
            id: ringArea
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            Layout.fillHeight: true

            readonly property real size: Math.min(width, height)
            readonly property real dialScale: root.scaleFactor

            InstrumentRing {
                id: ring
                anchors.fill: parent
                scaleFactor: ringArea.dialScale
                fraction: root.dayFraction
                showTicks: root.showTicks
                showArc: root.showArc
                showComet: root.showComet
                labels: [
                    { text: "00", hour: 0 }, { text: "06", hour: 6 },
                    { text: "12", hour: 12 }, { text: "18", hour: 18 }
                ]
                showLabels: root.showHourLabels
                ink: root.ink
                accent: root.accent
                accentSoft: root.accentSoft
                animated: root.animationsActive
            }

            // ── Center readout ───────────────────────────────
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 0

                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    visible: root.showIcon
                    text: root.isDaytime ? "light_mode" : "bedtime"
                    iconSize: Math.round(ringArea.size * 0.095 * root.textScale)
                    color: root.accentSoft
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: root.showIcon ? Math.round(2 * root.scaleFactor) : 0
                    Layout.maximumWidth: ringArea.size * 0.68
                    text: DateTime.time
                    fontSizeMode: Text.Fit
                    minimumPixelSize: 12
                    color: root.ink
                    font {
                        family: root.widgetNumbersFamily
                        pixelSize: Math.round(ringArea.size * 0.205 * root.textScale)
                        weight: Font.DemiBold
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: Math.round(1 * root.scaleFactor)
                    spacing: Math.round(3 * root.scaleFactor)

                    // Signal is the number: live ticks in accent. The phrase
                    // is a caption and stays muted.
                    StyledText {
                        text: Math.round(root.dayFraction * 100) + "%"
                        color: root.accentSoft
                        font {
                            family: root.widgetNumbersFamily
                            pixelSize: Math.round(ringArea.size * 0.075 * root.textScale)
                            weight: Font.DemiBold
                            letterSpacing: 0.4
                        }
                    }

                    StyledText {
                        text: Translation.tr("of the day")
                        color: root.inkMuted
                        font {
                            family: root.widgetBodyFamily
                            pixelSize: Math.round(ringArea.size * 0.062 * root.textScale)
                            weight: Font.DemiBold
                            letterSpacing: Math.round(1.2 * root.scaleFactor)
                            capitalization: root.widgetIris ? Font.MixedCase : Font.AllUppercase
                        }
                    }
                }
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            visible: root.showDate
            text: DateTime.date
            color: root.inkMuted
            font {
                family: root.widgetNumbersFamily
                pixelSize: Math.round(13 * root.scaleFactor * root.textScale)
                weight: Font.Medium
                letterSpacing: 0.6
            }
        }
    }

    // ── Quick controls ───────────────────────────────────────
    editPopoverContent: Component {
        ColumnLayout {
            spacing: 14
            WidgetQuickSection {
                title: Translation.tr("Style")
                WidgetQuickChoices {
                    current: root.ringStyle
                    model: [
                        { value: "ring", label: Translation.tr("Ring"), icon: "donut_large" },
                        { value: "arc", label: Translation.tr("Arc"), icon: "data_usage" },
                        { value: "ticks", label: Translation.tr("Ticks"), icon: "blur_on" }
                    ]
                    onPicked: value => root._setOutputValue("style", value)
                }
            }
            WidgetQuickSection {
                title: Translation.tr("Show")
                WidgetQuickToggle {
                    enabled: root.showArc
                    Layout.fillWidth: true
                    iconName: "flare"
                    label: Translation.tr("Comet tail")
                    checked: root.showComet
                    onToggled: root._setOutputValue("comet", !root.showComet)
                }
                WidgetQuickToggle {
                    Layout.fillWidth: true
                    iconName: root.isDaytime ? "light_mode" : "bedtime"
                    label: Translation.tr("Sun icon")
                    checked: root.showIcon
                    onToggled: root._setOutputValue("showIcon", !root.showIcon)
                }
                WidgetQuickToggle {
                    Layout.fillWidth: true
                    iconName: "pin_drop"
                    label: Translation.tr("Hour labels")
                    checked: root.showHourLabels
                    onToggled: root._setOutputValue("hourLabels", !root.showHourLabels)
                }
                WidgetQuickToggle {
                    Layout.fillWidth: true
                    iconName: "event"
                    label: Translation.tr("Date")
                    checked: root.showDate
                    onToggled: root._setOutputValue("showDate", !root.showDate)
                }
            }
            WidgetQuickSlider {
                title: Translation.tr("Text size")
                from: 60; to: 180; stepSize: 10; unit: "%"
                value: Math.round(root.textScale * 100)
                onMoved: v => root.previewIrisValue("fontScale", v)
                onCommitted: v => root.commitIrisValue("fontScale", v)
            }
        }
    }
}
