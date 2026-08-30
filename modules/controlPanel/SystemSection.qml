pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// Fondo de la sección ahora desde el molde compartido (PanelSurface): en zzz toma
// la placa con esquina cortada de las cards; en el resto, el color de capa correcto.
PanelSurface {
    id: root
    islandSkin: (Config.options?.controlPanel?.style ?? "panel") === "island"
    Layout.fillWidth: true
    implicitHeight: statsRow.implicitHeight + 12
    elevation: 1
    radiusOverride: islandSkin ? -1 : (Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.small)

    readonly property bool compactMode: Config.options?.controlPanel?.compactMode ?? true
    // zzz: el placa tiene esquinas redondeadas (panelRadius); el contenido debe
    // quedar dentro de la curva para no chocar contra las esquinas (antes el
    // rail y los labels llegaban hasta el borde y "chocaban"). Pad horizontal =
    // panelRadius en zzz, none en el resto.
    readonly property real _contentHPad: Appearance.zzzEverywhere
        ? Appearance.zzz.panelRadius : (root.compactMode ? 5 : 6)
    readonly property real _contentVPad: root.compactMode ? 5 : 6

    readonly property bool inirEverywhere: Appearance.inirEverywhere
    readonly property bool auroraEverywhere: Appearance.auroraEverywhere

    AngelPartialBorder { targetRadius: root.radiusOverride; coverage: 0.45; visible: Appearance.angelEverywhere && !root.islandSkin }

    RowLayout {
        id: statsRow
        anchors.fill: parent
        anchors.leftMargin: root._contentHPad
        anchors.rightMargin: root._contentHPad
        anchors.topMargin: root._contentVPad
        anchors.bottomMargin: root._contentVPad
        spacing: root.compactMode ? 6 : 8

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
            Layout.fillWidth: Battery.available
            visible: active
            active: Battery.available
            sourceComponent: StatBar {
                label: "BAT"
                value: (Battery.percentage ?? 0) * 100
                barColor: (Battery.percentage ?? 0) * 100 < 20 ? Appearance.colors.colError
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
                     : root.auroraEverywhere ? Appearance.colors.colOnSurfaceVariant
                     : Appearance.colors.colSubtext
            }
            Item { Layout.fillWidth: true }
            StyledText {
                text: Math.round(bar.value) + "%"
                font.pixelSize: Appearance.font.pixelSize.smallest
                font.family: Appearance.font.family.numbers
                color: Appearance.angelEverywhere ? Appearance.angel.colText
                     : root.inirEverywhere ? Appearance.inir.colText
                     : root.auroraEverywhere ? Appearance.colors.colOnSurface
                     : Appearance.colors.colOnLayer1
            }
        }

        Item {
            Layout.fillWidth: true
            implicitHeight: root.compactMode ? (Appearance.zzzEverywhere ? 8 : 3) : (Appearance.zzzEverywhere ? 10 : 4)

            // Non-zzz: continuous progress bar
            Rectangle {
                anchors.fill: parent
                visible: !Appearance.zzzEverywhere
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

            // ZZZ: segmented poster rail (the stat-bar card's signature)
            Row {
                id: segRail
                anchors.fill: parent
                visible: Appearance.zzzEverywhere
                spacing: 2
                clip: true
                readonly property int segs: 14
                readonly property int lit: Math.round(Math.min(1, Math.max(0, bar.value / 100)) * segs)
                Repeater {
                    model: segRail.segs
                    delegate: Rectangle {
                        required property int index
                        width: Math.max(1, (segRail.width - (segRail.segs - 1) * segRail.spacing) / segRail.segs)
                        height: segRail.height
                        radius: Appearance.zzz.cornerRadius
                        color: index < segRail.lit ? bar.barColor : Appearance.zzz.metricTrack
                        Behavior on color {
                            enabled: Appearance.animationsEnabled
                            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }
                    }
                }
            }
        }
    }
}
