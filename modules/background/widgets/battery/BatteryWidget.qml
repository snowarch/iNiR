pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.background.widgets
import qs.modules.background.widgets.instrument
import qs.modules.iris.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "battery"
    defaultConfig: ({
        placementStrategy: "free", preset: "default", displayMode: "ring",
        showTime: true, showRate: true, ringSize: 72, ringLineWidth: 6,
        barCount: 20, barSpacing: 2, barRadius: 2, pillHeight: 12,
        dim: 0, widgetScale: 100, widgetOpacity: 100, colorMode: "auto",
        showBackground: true, useBlur: false, showBorder: true,
        backgroundOpacity: 0.16, borderWidth: 1, borderOpacity: 0.2,
        cornerRadius: -1, x: 50, y: 50
    })

    implicitWidth: root.irisFaced ? root.irisFaceWidth : Math.round((root.displayMode === "instrument" ? 220 : 160) * scaleFactor)
    implicitHeight: root.irisFaced ? root.irisFaceHeight : Math.round((root.displayMode === "instrument" ? 140 : 104) * scaleFactor)
    irisFace: Component { IrisBatteryFace { widget: root } }
    irisSizes: ["small", "medium"]
    irisOptions: [
        { key: "showTime", raw: true, label: Translation.tr("Time remaining"), icon: "timer", fallback: true }
    ]
    widgetSurfaceEnabled: root.displayMode !== "instrument"

    visibleWhenLocked: true
    needsColText: true
    resizableAxes: ({ uniform: "widgetScale" })
    resizeMinWidth: 40
    resizeMinHeight: 40

    editPopoverContent: Component {
        ColumnLayout {
            spacing: 14
            WidgetQuickSection {
                title: Translation.tr("Style")
                WidgetQuickChoices {
                    current: root.displayMode
                    model: [
                        { label: Translation.tr("Ring"), icon: "donut_large", value: "ring" },
                        { label: Translation.tr("Bars"), icon: "bar_chart", value: "bars" },
                        { label: Translation.tr("Pill"), icon: "horizontal_rule", value: "pill" },
                        { label: Translation.tr("Instrument"), icon: "battery_charging_full", value: "instrument" }
                    ]
                    onPicked: value => root._setOutputValue("displayMode", value)
                }
            }
            WidgetQuickSection {
                title: Translation.tr("Show")
                WidgetQuickToggle {
                    Layout.fillWidth: true
                    iconName: "timer"
                    label: Translation.tr("Time left")
                    checked: root.showTimeEstimate
                    onToggled: root._setOutputValue("showTime", !root.showTimeEstimate)
                }
                WidgetQuickToggle {
                    visible: root.displayMode === "instrument"
                    Layout.fillWidth: true
                    iconName: "electric_bolt"
                    label: Translation.tr("Power draw")
                    checked: root.showEnergyRate
                    onToggled: root._setOutputValue("showRate", !root.showEnergyRate)
                }
            }
        }
    }

    readonly property string displayMode: root._readConfigKey("displayMode") ?? "ring"
    readonly property bool showTimeEstimate: root._readConfigKey("showTime") ?? true
    readonly property bool showEnergyRate: root._readConfigKey("showRate") ?? true
    readonly property int ringSize: Math.round(Number(root._readConfigKey("ringSize") ?? 72) * scaleFactor)
    readonly property int ringLineWidth: Math.round(Number(root._readConfigKey("ringLineWidth") ?? 6) * scaleFactor)
    readonly property int barCount: Number(root._readConfigKey("barCount") ?? 20)
    readonly property int barSpacing: Number(root._readConfigKey("barSpacing") ?? 2)
    readonly property int barRadius: Number(root._readConfigKey("barRadius") ?? 2)
    readonly property int pillHeight: Math.round(Number(root._readConfigKey("pillHeight") ?? 12) * scaleFactor)

    // ── Style tokens ──────────────────────────────────────────
    readonly property real cardRadius: root.widgetCardRadius

    // Battery state chooses one configured semantic slot; fill and track then use
    // that role's generated color/container pair exactly like a tonal Tile.
    readonly property string _batteryRole: Battery.isLow ? root.widgetSignalRole
        : Battery.isCharging ? root.widgetTertiaryRole : root.widgetPrimaryRole
    readonly property color accentColor: root.widgetSemanticColor(root._batteryRole)
    readonly property color trackColor: root.widgetSemanticContainer(root._batteryRole)

    // ── Text helpers ─────────────────────────────────────────
    readonly property string percentText: Math.round(Battery.percentage * 100) + "%"
    readonly property string timeText: {
        const secs = Battery.isCharging ? Battery.timeToFull : Battery.timeToEmpty;
        if (secs <= 0) return "";
        const h = Math.floor(secs / 3600);
        const m = Math.floor((secs % 3600) / 60);
        if (h > 0 && m > 0) return h + "h " + m + "m";
        if (h > 0) return h + "h";
        return m + "m";
    }
    readonly property string timeLabel: {
        if (!root.showTimeEstimate || root.timeText === "") return "";
        return Translation.tr("%1 remaining").arg(root.timeText);
    }

    // ── Card background ───────────────────────────────────────
    WidgetSurface {
        irisPresentation: root.widgetIris
        regionBrightness: root.regionBrightness
        anchors.fill: parent
        surfaceRadius: root.cornerRadiusOverride >= 0 ? root.cornerRadiusOverride : root.cardRadius
        surfaceOpacity: root.backgroundOpacity
        surfaceBorderWidth: root.borderWidth
        surfaceBorderOpacity: root.borderOpacity
        surfaceColor: root.widgetSurfaceInk
        colorMode: root.colorMode
        surfaceAccent: root.widgetAccent
        surfaceFill: root.widgetPlateColor
        surfaceUseBlur: root.effectiveBlur
        screenX: root.x
        screenY: root.y
        screenWidth: root.scaledScreenWidth
        screenHeight: root.scaledScreenHeight
        shown: !root.irisFaced && root.displayMode !== "instrument"
            && (root.backgroundOpacity > 0 || root.borderWidth > 0 || root.effectiveBlur)
    }

    // ── Instrument: energy reserve, not a clock face ─────────
    Item {
        id: instrumentArea
        anchors.fill: parent
        opacity: root.displayMode === "instrument" ? 1 : 0
        visible: !root.irisFaced && opacity > 0
        enabled: root.displayMode === "instrument"
        Behavior on opacity {
            enabled: root.animationsActive
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Math.round(10 * root.scaleFactor)
            spacing: Math.round(4 * root.scaleFactor)

            RowLayout {
                Layout.fillWidth: true
                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Battery")
                    color: root.widgetInkMuted
                    font.family: root.widgetBodyFamily
                    font.pixelSize: Math.round(11 * root.scaleFactor)
                    font.weight: Font.DemiBold
                    font.capitalization: root.widgetIris ? Font.MixedCase : Font.AllUppercase
                    font.letterSpacing: root.scaleFactor
                }
                MaterialSymbol {
                    text: !Battery.available ? "power" : Battery.isCharging ? "bolt" : "battery_full"
                    color: root.widgetSemanticForeground(root._batteryRole)
                    iconSize: Math.round(20 * root.scaleFactor)
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Math.round(3 * root.scaleFactor)
                StyledText {
                    text: Battery.available ? String(Math.round(Battery.percentage * 100)) : "—"
                    color: root.widgetInk
                    font.family: root.widgetNumbersFamily
                    font.pixelSize: Math.round(52 * root.scaleFactor)
                    font.weight: root.widgetEditorial ? Appearance.editorial.titleWeight : Font.Bold
                    font.features: ({ "tnum": 1 })
                    font.letterSpacing: -0.8
                }
                StyledText {
                    Layout.alignment: Qt.AlignBottom
                    Layout.bottomMargin: Math.round(10 * root.scaleFactor)
                    visible: Battery.available
                    text: "%"
                    color: root.widgetInkMuted
                    font.family: root.widgetBodyFamily
                    font.pixelSize: Math.round(16 * root.scaleFactor)
                    font.weight: Font.DemiBold
                }
                Item { Layout.fillWidth: true }
                StyledText {
                    Layout.alignment: Qt.AlignBottom
                    Layout.bottomMargin: Math.round(10 * root.scaleFactor)
                    visible: root.showEnergyRate && Battery.available && Battery.energyRate > 0
                    text: Number(Battery.energyRate).toFixed(1) + " W"
                    color: root.widgetSemanticForeground(root._batteryRole)
                    font.family: root.widgetNumbersFamily
                    font.pixelSize: Math.round(12 * root.scaleFactor)
                    font.weight: Font.DemiBold
                }
            }
            InstrumentScale {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(16 * root.scaleFactor)
                fraction: Battery.available ? Battery.percentage : 0
                ink: root.widgetInk
                accent: root.widgetSemanticForeground(root._batteryRole)
                animated: root.animationsActive
            }
            StyledText {
                Layout.fillWidth: true
                text: !Battery.available ? Translation.tr("No battery")
                    : root.timeLabel || (Battery.isCharging ? Translation.tr("Charging") : Translation.tr("Battery"))
                color: root.widgetInkMuted
                elide: Text.ElideRight
                font.family: root.widgetBodyFamily
                font.pixelSize: Math.round(11 * root.scaleFactor)
            }
        }
    }

    // ── Ring mode ─────────────────────────────────────────────
    Item {
        anchors.fill: parent
        anchors.margins: Appearance.angelEverywhere || Appearance.inirEverywhere ? 4 : 0
        opacity: root.displayMode === "ring" ? 1 : 0
        visible: !root.irisFaced && opacity > 0
        enabled: root.displayMode === "ring"
        Behavior on opacity {
            enabled: root.animationsActive
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }

        Column {
            anchors.centerIn: parent
            spacing: Math.round(4 * root.scaleFactor)

            CircularProgress {
                anchors.horizontalCenter: parent.horizontalCenter
                implicitSize: root.ringSize
                lineWidth: root.ringLineWidth
                value: Battery.percentage
                colPrimary: root.accentColor
                colSecondary: root.trackColor

                // Percentage text centered in ring
                StyledText {
                    anchors.centerIn: parent
                    text: root.percentText
                    color: root.widgetInk
                    font {
                        pixelSize: Math.round(Appearance.font.pixelSize.normal * root.scaleFactor)
                        family: root.widgetNumbersFamily
                        weight: Font.DemiBold
                    }
                }
            }

            // Time estimate below ring
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.timeLabel
                color: root.widgetInkMuted
                visible: root.timeLabel !== ""
                font {
                    pixelSize: Math.round(Appearance.font.pixelSize.smaller * root.scaleFactor)
                    family: root.widgetBodyFamily
                }
            }
        }
    }

    // ── Bars mode (VU meter style) ────────────────────────────
    Item {
        anchors.fill: parent
        anchors.margins: Appearance.angelEverywhere || Appearance.inirEverywhere ? 4 : 0
        opacity: root.displayMode === "bars" ? 1 : 0
        visible: !root.irisFaced && opacity > 0
        enabled: root.displayMode === "bars"
        Behavior on opacity {
            enabled: root.animationsActive
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }

        Row {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: _barsLabel.visible ? _barsLabel.top : parent.bottom
            anchors.bottomMargin: _barsLabel.visible ? Math.round(2 * root.scaleFactor) : 0
            spacing: root.barSpacing

            Repeater {
                model: root.barCount

                Item {
                    id: battBar
                    required property int index
                    width: (parent.width - (root.barCount - 1) * root.barSpacing) / root.barCount
                    height: parent.height

                    readonly property bool filled: (index + 1) / root.barCount <= Battery.percentage
                    readonly property bool isThreshold: Math.abs((index + 1) / root.barCount - Battery.percentage) < 0.06

                    Rectangle {
                        width: parent.width
                        height: parent.height
                        anchors.bottom: parent.bottom
                        radius: root.barRadius
                        color: battBar.filled ? root.accentColor
                            : ColorUtils.applyAlpha(root.trackColor, 0.4)
                        opacity: battBar.filled ? (battBar.isThreshold ? 0.6 : 0.85) : 0.3

                        Behavior on color {
                            enabled: Appearance.animationsEnabled
                            ColorAnimation {
                                duration: Appearance.animation.elementMoveFast.duration
                                easing.type: Appearance.animation.elementMoveFast.type
                                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                            }
                        }
                        Behavior on opacity {
                            enabled: Appearance.animationsEnabled
                            NumberAnimation {
                                duration: Appearance.animation.elementMoveFast.duration
                                easing.type: Appearance.animation.elementMoveFast.type
                                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                            }
                        }
                    }
                }
            }
        }

        // Percentage + time below bars
        Row {
            id: _barsLabel
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            spacing: Math.round(6 * root.scaleFactor)

            StyledText {
                text: root.percentText
                color: root.widgetInk
                font { pixelSize: Math.round(Appearance.font.pixelSize.small * root.scaleFactor); family: root.widgetNumbersFamily; weight: Font.DemiBold }
            }
            StyledText {
                text: root.timeLabel
                color: root.widgetInkMuted
                visible: root.timeLabel !== ""
                font { pixelSize: Math.round(Appearance.font.pixelSize.smaller * root.scaleFactor); family: root.widgetBodyFamily }
                anchors.baseline: parent.children[0].baseline
            }
        }
    }

    // ── Pill mode (minimal horizontal bar) ────────────────────
    Item {
        anchors.fill: parent
        anchors.margins: Appearance.angelEverywhere || Appearance.inirEverywhere ? 8 : 4
        opacity: root.displayMode === "pill" ? 1 : 0
        visible: !root.irisFaced && opacity > 0
        enabled: root.displayMode === "pill"
        Behavior on opacity {
            enabled: root.animationsActive
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }

        // Percentage + time above pill
        Row {
            id: _pillLabel
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: _pillTrack.top
            anchors.bottomMargin: Math.round(4 * root.scaleFactor)
            spacing: Math.round(6 * root.scaleFactor)

            StyledText {
                text: root.percentText
                color: root.widgetInk
                font { pixelSize: Math.round(Appearance.font.pixelSize.normal * root.scaleFactor); family: root.widgetNumbersFamily; weight: Font.DemiBold }
            }
            StyledText {
                text: root.timeLabel
                color: root.widgetInkMuted
                visible: root.timeLabel !== ""
                font { pixelSize: Math.round(Appearance.font.pixelSize.smaller * root.scaleFactor); family: root.widgetBodyFamily }
                anchors.baseline: parent.children[0].baseline
            }
        }

        // Track
        Rectangle {
            id: _pillTrack
            anchors.centerIn: parent
            anchors.verticalCenterOffset: Math.round((_pillLabel.visible ? _pillLabel.height / 2 : 0) * 0.5)
            width: parent.width
            height: root.pillHeight
            radius: Appearance.rounding.full
            color: root.trackColor

            // Fill
            Rectangle {
                width: parent.width * Battery.percentage
                height: parent.height
                radius: parent.radius
                color: root.accentColor

                Behavior on width {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation {
                        duration: Appearance.animation.elementResize.duration
                        easing.type: Appearance.animation.elementResize.type
                        easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
                    }
                }
            }
        }
    }
}
