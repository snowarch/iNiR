pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Rectangle {
    id: root
    Layout.fillWidth: true
    implicitHeight: statsRow.implicitHeight + 12
    
    readonly property bool inirEverywhere: Appearance.inirEverywhere
    readonly property bool auroraEverywhere: Appearance.auroraEverywhere

    radius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
        : inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.small
    color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
         : inirEverywhere ? Appearance.inir.colLayer1
         : auroraEverywhere ? Appearance.aurora.colSubSurface
         : Appearance.colors.colLayer1
    border.width: Appearance.angelEverywhere ? 0 : (inirEverywhere ? 1 : 0)
    border.color: Appearance.angelEverywhere ? "transparent"
        : inirEverywhere ? Appearance.inir.colBorder : "transparent"

    AngelPartialBorder { targetRadius: parent.radius; coverage: 0.45 }

    RowLayout {
        id: statsRow
        anchors.fill: parent
        anchors.margins: 6
        spacing: 8

        // CPU
        StatBar {
            Layout.fillWidth: true
            label: "CPU"
            value: (ResourceUsage.cpuUsage ?? 0) * 100
            barColor: ((ResourceUsage.cpuUsage ?? 0) * 100) > 80 ? Appearance.colors.colError 
                    : (Appearance.angelEverywhere ? Appearance.angel.colPrimary
                    : root.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary)
        }

        // RAM
        StatBar {
            Layout.fillWidth: true
            label: "RAM"
            value: (ResourceUsage.memoryUsedPercentage ?? 0) * 100
            barColor: (ResourceUsage.memoryUsedPercentage ?? 0) > 0.85 ? Appearance.colors.colError 
                    : (Appearance.angelEverywhere ? Appearance.angel.colPrimary
                    : root.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary)
        }

        // Battery (if available)
        Loader {
            Layout.fillWidth: true
            active: Battery.available
            sourceComponent: StatBar {
                label: "BAT"
                value: Battery.percentage ?? 0
                barColor: (Battery.percentage ?? 0) < 20 ? Appearance.colors.colError 
                        : Battery.charging ? Appearance.colors.colSuccess 
                        : (Appearance.angelEverywhere ? Appearance.angel.colPrimary
                        : root.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary)
            }
        }
    }

    component StatBar: ColumnLayout {
        id: bar
        property string label
        property real value: 0
        property color barColor: Appearance.angelEverywhere ? Appearance.angel.colPrimary
            : root.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary

        spacing: 2

        RowLayout {
            spacing: 4
            StyledText {
                text: bar.label
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
                     : root.inirEverywhere ? Appearance.inir.colTextSecondary
                     : root.auroraEverywhere ? Appearance.m3colors.m3onSurfaceVariant
                     : Appearance.colors.colSubtext
            }
            Item { Layout.fillWidth: true }
            StyledText {
                text: Math.round(bar.value) + "%"
                font.pixelSize: Appearance.font.pixelSize.smallest
                font.family: Appearance.font.family.numbers
                color: Appearance.angelEverywhere ? Appearance.angel.colText
                     : root.inirEverywhere ? Appearance.inir.colText
                     : root.auroraEverywhere ? Appearance.m3colors.m3onSurface
                     : Appearance.colors.colOnLayer1
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 4
            radius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall : 2
            color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                 : root.inirEverywhere ? Appearance.inir.colLayer2 
                 : root.auroraEverywhere ? ColorUtils.transparentize(Appearance.aurora.colSubSurface, 0.5)
                 : Appearance.colors.colLayer2

            Rectangle {
                width: parent.width * Math.min(1, Math.max(0, bar.value / 100))
                height: parent.height
                radius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall : 2
                color: bar.barColor

                Behavior on width {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                }
            }
        }
    }
}
