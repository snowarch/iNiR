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
    defaultConfig: ({
        placementStrategy: "free", preset: "default", displayMode: "ring",
        showTime: true, ringSize: 72, ringLineWidth: 6,
        barCount: 20, barSpacing: 2, barRadius: 2, pillHeight: 12,
        dim: 0, widgetScale: 100, widgetOpacity: 100, colorMode: "auto",
        showBackground: true, useBlur: false, showBorder: true,
        backgroundOpacity: 0.16, borderWidth: 1, borderOpacity: 0.2,
        cornerRadius: -1, x: 50, y: 50
    })

    implicitWidth: Math.round(160 * scaleFactor)
    implicitHeight: Math.round(104 * scaleFactor)

    visibleWhenLocked: true
    needsColText: true
    resizableAxes: ({ uniform: "widgetScale" })
    resizeMinWidth: 40
    resizeMinHeight: 40

    editPopoverContent: Component {
        ColumnLayout {
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
                        buttonText: Translation.tr(modelData.label)
                        toggled: root.displayMode === modelData.value
                        onClicked: Config.setNestedValue("background.widgets.battery.displayMode", modelData.value)
                    }
                }
            }
            SelectionGroupButton {
                Layout.alignment: Qt.AlignHCenter
                leftmost: true; rightmost: true
                buttonIcon: "timer"
                buttonText: Translation.tr("Show time")
                toggled: root.showTimeEstimate
                onClicked: Config.setNestedValue("background.widgets.battery.showTime", !root.showTimeEstimate)
            }
        }
    }

    readonly property string displayMode: Config.getNestedValue("background.widgets.battery.displayMode", "ring")
    readonly property bool showTimeEstimate: Config.getNestedValue("background.widgets.battery.showTime", true)
    readonly property int ringSize: Math.round(Number(root._readConfigKey("ringSize") ?? 72) * scaleFactor)
    readonly property int ringLineWidth: Math.round((Config.getNestedValue("background.widgets.battery.ringLineWidth", 6)) * scaleFactor)
    readonly property int barCount: Config.getNestedValue("background.widgets.battery.barCount", 20)
    readonly property int barSpacing: Config.getNestedValue("background.widgets.battery.barSpacing", 2)
    readonly property int barRadius: Config.getNestedValue("background.widgets.battery.barRadius", 2)
    readonly property int pillHeight: Math.round((Config.getNestedValue("background.widgets.battery.pillHeight", 12)) * scaleFactor)

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
        visible: root.backgroundOpacity > 0 || root.borderWidth > 0 || root.effectiveBlur
    }

    // ── Ring mode ─────────────────────────────────────────────
    Item {
        anchors.fill: parent
        anchors.margins: Appearance.angelEverywhere || Appearance.inirEverywhere ? 4 : 0
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
                    color: root.widgetInk
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
                color: root.widgetInkMuted
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
                font { pixelSize: Math.round(Appearance.font.pixelSize.small * root.scaleFactor); family: Appearance.font.family.numbers; weight: Font.DemiBold }
            }
            StyledText {
                text: root.timeLabel
                color: root.widgetInkMuted
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
                color: root.widgetInk
                font { pixelSize: Math.round(Appearance.font.pixelSize.normal * root.scaleFactor); family: Appearance.font.family.numbers; weight: Font.DemiBold }
            }
            StyledText {
                text: root.timeLabel
                color: root.widgetInkMuted
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
