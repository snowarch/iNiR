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

AbstractBackgroundWidget {
    id: root

    configEntryName: "battery"
    defaultConfig: ({ placementStrategy: "free", preset: "default", displayMode: "ring", showTime: true, ringSize: 72, ringLineWidth: 6, barCount: 20, pillHeight: 12, dim: 0, widgetScale: 100, widgetOpacity: 100, showBackground: true, showBorder: true, colorMode: "auto", x: 50, y: 50 })

    implicitWidth: Math.round(160 * scaleFactor)
    implicitHeight: Math.round(104 * scaleFactor)

    visibleWhenLocked: true
    needsColText: true
    resizableAxes: ({ uniform: "ringSize" })
    resizeMinWidth: 40
    resizeMinHeight: 40

    editPopoverContent: Component {
        Column {
            spacing: 6
            GridLayout {
                columns: 3
                columnSpacing: 4
                rowSpacing: 4
                Layout.alignment: Qt.AlignHCenter
                Repeater {
                    model: [
                        { label: "Ring", icon: "donut_large", value: "ring" },
                        { label: "Bars", icon: "bar_chart", value: "bars" },
                        { label: "Pill", icon: "horizontal_rule", value: "pill" }
                    ]
                    SelectionGroupButton {
                        required property var modelData
                        Layout.fillWidth: true
                        leftmost: true; rightmost: true
                        buttonIcon: modelData.icon
                        buttonText: modelData.label
                        toggled: root.displayMode === modelData.value
                        onClicked: Config.setNestedValue("background.widgets.battery.displayMode", modelData.value)
                    }
                }
            }
            SelectionGroupButton {
                Layout.alignment: Qt.AlignHCenter
                leftmost: true; rightmost: true
                buttonIcon: "timer"
                buttonText: "Show time"
                toggled: root.showTimeEstimate
                onClicked: Config.setNestedValue("background.widgets.battery.showTime", !root.showTimeEstimate)
            }
        }
    }

    readonly property bool _active: (Config.getNestedValue("background.widgets.battery.enable", false)) && Battery.available
    readonly property string displayMode: Config.getNestedValue("background.widgets.battery.displayMode", "ring")
    readonly property bool showTimeEstimate: Config.getNestedValue("background.widgets.battery.showTime", true)
    readonly property int ringSize: Math.round((Config.getNestedValue("background.widgets.battery.ringSize", 72)) * scaleFactor)
    readonly property int ringLineWidth: Math.round((Config.getNestedValue("background.widgets.battery.ringLineWidth", 6)) * scaleFactor)
    readonly property int barCount: Config.getNestedValue("background.widgets.battery.barCount", 20)
    readonly property int barSpacing: Config.getNestedValue("background.widgets.battery.barSpacing", 2)
    readonly property int barRadius: Config.getNestedValue("background.widgets.battery.barRadius", 2)
    readonly property int pillHeight: Math.round((Config.getNestedValue("background.widgets.battery.pillHeight", 12)) * scaleFactor)

    property real dimFactor: {
        const v = Config.getNestedValue("background.widgets.battery.dim", 0);
        const n = Number(v);
        return Math.max(0, Math.min(1, Number.isFinite(n) ? n / 100 : 0));
    }

    // ── Style tokens ──────────────────────────────────────────
    readonly property real cardRadius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
        : Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal

    readonly property color accentColor: Battery.isLow
        ? (Appearance.angelEverywhere ? Appearance.angel.colError
            : Appearance.inirEverywhere ? Appearance.inir.colError
            : Appearance.colors.colError)
        : Battery.isCharging
            ? (Appearance.angelEverywhere ? Appearance.angel.colTertiary
                : Appearance.inirEverywhere ? Appearance.inir.colTertiary
                : Appearance.auroraEverywhere ? Appearance.m3colors.m3tertiary
                : Appearance.colors.colTertiary)
            : (Appearance.angelEverywhere ? Appearance.angel.colPrimary
                : Appearance.inirEverywhere ? Appearance.inir.colPrimary
                : Appearance.auroraEverywhere ? Appearance.m3colors.m3primary
                : Appearance.colors.colPrimary)

    readonly property color trackColor: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2
        : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurface
        : Appearance.colors.colSecondaryContainer

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
        return Battery.isCharging ? root.timeText + " left" : root.timeText;
    }

    // ── Card background ───────────────────────────────────────
    WidgetSurface {
        anchors.fill: parent
        surfaceRadius: root.cornerRadiusOverride >= 0 ? root.cornerRadiusOverride : root.cardRadius
        surfaceOpacity: root.backgroundOpacity
        surfaceBorderWidth: root.borderWidth
        surfaceBorderOpacity: root.borderOpacity
        surfaceColor: root.colText
        surfaceUseBlur: root.useBlur
        screenX: root.x
        screenY: root.y
        screenWidth: root.scaledScreenWidth
        screenHeight: root.scaledScreenHeight
        visible: root.backgroundOpacity > 0 || root.borderWidth > 0
    }

    // ── Ring mode ─────────────────────────────────────────────
    Item {
        anchors.fill: parent
        anchors.margins: Appearance.angelEverywhere || Appearance.inirEverywhere ? 4 : 0
        opacity: 1.0 - root.dimFactor * 0.6
        visible: root.displayMode === "ring"

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
                    color: root.colText
                    font {
                        pixelSize: Math.round(Appearance.font.pixelSize.normal * root.scaleFactor)
                        family: Appearance.font.family.numbers
                        weight: Font.DemiBold
                    }
                }
            }

            // Time estimate below ring
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.timeLabel
                color: ColorUtils.applyAlpha(root.colText, 0.6)
                visible: root.timeLabel !== ""
                font {
                    pixelSize: Math.round(Appearance.font.pixelSize.smaller * root.scaleFactor)
                    family: Appearance.font.family.main
                }
            }
        }
    }

    // ── Bars mode (VU meter style) ────────────────────────────
    Item {
        anchors.fill: parent
        anchors.margins: Appearance.angelEverywhere || Appearance.inirEverywhere ? 4 : 0
        opacity: 1.0 - root.dimFactor * 0.6
        visible: root.displayMode === "bars"

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
                            ColorAnimation { duration: 100 }
                        }
                        Behavior on opacity {
                            enabled: Appearance.animationsEnabled
                            NumberAnimation { duration: 80 }
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
                color: root.colText
                font { pixelSize: Math.round(Appearance.font.pixelSize.small * root.scaleFactor); family: Appearance.font.family.numbers; weight: Font.DemiBold }
            }
            StyledText {
                text: root.timeLabel
                color: ColorUtils.applyAlpha(root.colText, 0.6)
                visible: root.timeLabel !== ""
                font { pixelSize: Math.round(Appearance.font.pixelSize.smaller * root.scaleFactor); family: Appearance.font.family.main }
                anchors.baseline: parent.children[0].baseline
            }
        }
    }

    // ── Pill mode (minimal horizontal bar) ────────────────────
    Item {
        anchors.fill: parent
        anchors.margins: Appearance.angelEverywhere || Appearance.inirEverywhere ? 8 : 4
        opacity: 1.0 - root.dimFactor * 0.6
        visible: root.displayMode === "pill"

        // Percentage + time above pill
        Row {
            id: _pillLabel
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: _pillTrack.top
            anchors.bottomMargin: Math.round(4 * root.scaleFactor)
            spacing: Math.round(6 * root.scaleFactor)

            StyledText {
                text: root.percentText
                color: root.colText
                font { pixelSize: Math.round(Appearance.font.pixelSize.normal * root.scaleFactor); family: Appearance.font.family.numbers; weight: Font.DemiBold }
            }
            StyledText {
                text: root.timeLabel
                color: ColorUtils.applyAlpha(root.colText, 0.6)
                visible: root.timeLabel !== ""
                font { pixelSize: Math.round(Appearance.font.pixelSize.smaller * root.scaleFactor); family: Appearance.font.family.main }
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
                    NumberAnimation { duration: 300; easing.type: Easing.OutQuad }
                }
            }
        }
    }
}
