pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.background.widgets
import qs.modules.background.widgets.instrument
import qs.modules.iris.widgets

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
    implicitWidth: root.irisFaced ? root.irisFaceWidth : root.instrument ? Math.max(root.rowWidth, Math.round(260 * scaleFactor)) : root.rowWidth
    implicitHeight: root.irisFaced ? root.irisFaceHeight : root.instrument ? Math.max(root.rowHeight, Math.round(130 * scaleFactor)) : root.rowHeight
    irisFace: Component { IrisUptimeFace { widget: root } }
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

    // ── Row style (default) ──
    RowLayout {
        opacity: root.instrument ? 0 : 1
        visible: !root.irisFaced && opacity > 0
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

    // ── Instrument: session chronometer ───────────────────────
    // Uptime has no finish line. The elapsed duration is the instrument; the
    // session day and boot time are annotations, not competing hero values.
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

        RowLayout {
            anchors.fill: parent
            spacing: Math.round(12 * root.scaleFactor)

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: Math.round(6 * root.scaleFactor)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Math.round(6 * root.scaleFactor)

                    InstrumentLabel {
                        Layout.fillWidth: true
                        text: Translation.tr("System / Uptime")
                        color: root.widgetAccentVisible
                        scaleFactor: root.scaleFactor
                        strong: true
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    verticalAlignment: Text.AlignVCenter
                    text: DateTime.uptime || "--"
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
                visible: root.showInstrumentDetails
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredHeight: Math.round(58 * root.scaleFactor)
                Layout.preferredWidth: Math.max(1, Math.round(root.scaleFactor))
                color: ColorUtils.applyAlpha(root.widgetInk, 0.16)
            }

            ColumnLayout {
                visible: root.showInstrumentDetails
                Layout.preferredWidth: Math.max(84, Math.round(96 * root.scaleFactor))
                Layout.alignment: Qt.AlignVCenter
                spacing: Math.round(5 * root.scaleFactor)

                Item { Layout.fillHeight: true }

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

                Item { Layout.fillHeight: true }
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
