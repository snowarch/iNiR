pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services

Item {
    id: root
    implicitHeight: 64

    Component.onCompleted: ResourceUsage.ensureRunning()
    onVisibleChanged: if (visible) ResourceUsage.ensureRunning()

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 4

        Ring {
            icon: "memory"
            value: ResourceUsage.cpuUsage
            label: Math.round(ResourceUsage.cpuUsage * 100) + "%"
            ringColor: ResourceUsage.cpuUsage >= 0.9 ? Appearance.colors.colError :
                   ResourceUsage.cpuUsage >= 0.7 ? Appearance.colors.colTertiary :
                   Appearance.colors.colPrimary
            tip: "CPU"
            visible: Config.options?.sidebar?.widgets?.statusRings?.showCpu ?? true
        }

        Ring {
            icon: "memory_alt"
            value: ResourceUsage.memoryUsedPercentage
            label: Math.round(ResourceUsage.memoryUsedPercentage * 100) + "%"
            ringColor: ResourceUsage.memoryUsedPercentage >= 0.9 ? Appearance.colors.colError :
                   ResourceUsage.memoryUsedPercentage >= 0.7 ? Appearance.colors.colTertiary :
                   Appearance.colors.colPrimary
            tip: "RAM"
            visible: Config.options?.sidebar?.widgets?.statusRings?.showRam ?? true
        }

        Ring {
            icon: "hard_drive"
            value: ResourceUsage.diskUsedPercentage
            label: Math.round(ResourceUsage.diskUsedPercentage * 100) + "%"
            ringColor: ResourceUsage.diskUsedPercentage >= 0.9 ? Appearance.colors.colError :
                   ResourceUsage.diskUsedPercentage >= 0.8 ? Appearance.colors.colTertiary :
                   Appearance.colors.colPrimary
            tip: "Disk"
            visible: Config.options?.sidebar?.widgets?.statusRings?.showDisk ?? true
        }

        Ring {
            icon: "thermostat"
            value: Math.min(1, ResourceUsage.maxTemp / 100)
            label: ResourceUsage.maxTemp + "°"
            ringColor: ResourceUsage.maxTemp >= 80 ? Appearance.colors.colError :
                   ResourceUsage.maxTemp >= 60 ? Appearance.colors.colTertiary :
                   Appearance.colors.colPrimary
            visible: ResourceUsage.cpuTemp > 0 && (Config.options?.sidebar?.widgets?.statusRings?.showTemp ?? true)
            tip: Translation.tr("Temperature")
        }

        Ring {
            icon: Battery.isCharging ? "battery_charging_full" : "battery_full"
            value: Battery.percentage
            label: Math.round(Battery.percentage * 100) + "%"
            ringColor: Battery.isCritical ? Appearance.colors.colError :
                   Battery.isCharging ? Appearance.colors.colPrimary :
                   Battery.percentage < 0.3 ? Appearance.colors.colTertiary :
                   Appearance.colors.colPrimary
            visible: Battery.available && (Config.options?.sidebar?.widgets?.statusRings?.showBattery ?? true)
            tip: Battery.isCharging ? Translation.tr("Charging") : Translation.tr("Battery")
        }
    }

    component Ring: Item {
        property string icon
        property string label
        property string tip
        property real value
        property color ringColor: Appearance.colors.colPrimary

        Layout.fillWidth: true
        Layout.fillHeight: true

        Rectangle {
            id: ringBg
            anchors.centerIn: parent
            width: 52
            height: 52
            radius: 26
            color: "transparent"
            border.width: 3
            border.color: Appearance.inirEverywhere ? Appearance.inir.colBorderSubtle
                        : Appearance.auroraEverywhere ? "transparent" 
                        : Appearance.colors.colLayer2

            Behavior on border.color {
                enabled: Appearance.animationsEnabled
                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
            }

            Canvas {
                id: canvas
                anchors.fill: parent

                property real progressValue: value
                property color progressColor: ringColor

                onProgressValueChanged: requestPaint()
                onProgressColorChanged: requestPaint()

                Behavior on progressValue {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
                }

                Behavior on progressColor {
                    enabled: Appearance.animationsEnabled
                    ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                }

                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    ctx.lineWidth = 3
                    ctx.lineCap = "round"
                    ctx.strokeStyle = progressColor
                    ctx.beginPath()
                    ctx.arc(width/2, height/2, width/2 - 2, -Math.PI/2, -Math.PI/2 + 2 * Math.PI * Math.min(1, progressValue))
                    ctx.stroke()
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: -2

                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: icon
                    iconSize: 14
                    color: Appearance.colors.colOnLayer1
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: label
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.family: Appearance.font.family.numbers
                    font.weight: Font.Medium
                    color: Appearance.colors.colOnLayer1
                }
            }

            MouseArea {
                id: hoverArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
            }

            StyledToolTip {
                text: tip
                extraVisibleCondition: false
                alternativeVisibleCondition: hoverArea.containsMouse && tip !== ""
            }
        }
    }
}
