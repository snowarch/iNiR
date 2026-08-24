import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

BarWidgetSwitcherArea {
    id: root
    property bool alwaysShowAllResources: false
    horizontalExtraPadding: 12

    Component.onCompleted: ResourceUsage.keepAlive()
    Component.onDestruction: ResourceUsage.releaseKeepAlive()

    readonly property bool clickForDetails: Config.options?.bar?.m3?.tooltips?.clickToShow ?? false
    hoverEnabled: true

    onClicked: mouse => {
        if (mouse.button === Qt.LeftButton && root.clickForDetails)
            resourcesPopup.active = !resourcesPopup.active
    }

    rowDefault: Component {
        RowLayout {
            spacing: 0
            Resource {
                iconName: "memory"
                shown: Config.options.bar.m3.resources.alwaysShowRam
                percentage: ResourceUsage.memoryUsedPercentage
                warningThreshold: Config.options.bar.m3.resources.memoryWarningThreshold
            }
            Resource {
                iconName: "planner_review"
                shown: Config.options.bar.m3.resources.alwaysShowCpu
                percentage: ResourceUsage.cpuUsage
                Layout.leftMargin: shown ? 6 : 0
                warningThreshold: Config.options.bar.m3.resources.cpuWarningThreshold
            }
            Resource {
                iconName: "thermostat"
                shown: Config.options.bar.m3.resources.alwaysShowCpuTemp
                percentage: ResourceUsage.cpuTemp / 100
                Layout.leftMargin: shown ? 6 : 0
            }
            Resource {
                iconName: "hard_drive"
                shown: Config.options.bar.m3.resources.alwaysShowDisk
                percentage: ResourceUsage.diskUsedPercentage
                Layout.leftMargin: shown ? 6 : 0
            }
            Resource {
                iconName: "swap_horiz"
                shown: Config.options.bar.m3.resources.alwaysShowSwap
                percentage: ResourceUsage.swapUsedPercentage
                Layout.leftMargin: shown ? 6 : 0
                warningThreshold: Config.options.bar.m3.resources.swapWarningThreshold
            }
        }
    }

    rowMaterial: Component {
        RowLayout {
            spacing: 0
            Resource {
                iconName: "memory"
                shown: Config.options.bar.m3.resources.alwaysShowRam
                percentage: ResourceUsage.memoryUsedPercentage
                warningThreshold: Config.options.bar.m3.resources.memoryWarningThreshold
            }
            Resource {
                iconName: "planner_review"
                shown: Config.options.bar.m3.resources.alwaysShowCpu
                percentage: ResourceUsage.cpuUsage
                Layout.leftMargin: shown ? 6 : 0
                warningThreshold: Config.options.bar.m3.resources.cpuWarningThreshold
            }
            Resource {
                iconName: "thermostat"
                shown: Config.options.bar.m3.resources.alwaysShowCpuTemp
                percentage: ResourceUsage.cpuTemp / 100
                Layout.leftMargin: shown ? 6 : 0
            }
            Resource {
                iconName: "hard_drive"
                shown: Config.options.bar.m3.resources.alwaysShowDisk
                percentage: ResourceUsage.diskUsedPercentage
                Layout.leftMargin: shown ? 6 : 0
            }
            Resource {
                iconName: "swap_horiz"
                shown: Config.options.bar.m3.resources.alwaysShowSwap
                percentage: ResourceUsage.swapUsedPercentage
                Layout.leftMargin: shown ? 6 : 0
                warningThreshold: Config.options.bar.m3.resources.swapWarningThreshold
            }
        }
    }

    colDefault: Component {
        ColumnLayout {
            spacing: 7
            Resource {
                Layout.alignment: Qt.AlignHCenter
                iconName: "memory"
                vertical: true
                visible: Config.options.bar.m3.resources.alwaysShowRam
                percentage: ResourceUsage.memoryUsedPercentage
                warningThreshold: Config.options.bar.m3.resources.memoryWarningThreshold
            }
            Resource {
                Layout.alignment: Qt.AlignHCenter
                iconName: "planner_review"
                vertical: true
                visible: Config.options.bar.m3.resources.alwaysShowCpu
                percentage: ResourceUsage.cpuUsage
                warningThreshold: Config.options.bar.m3.resources.cpuWarningThreshold
            }
            Resource {
                Layout.alignment: Qt.AlignHCenter
                iconName: "thermostat"
                vertical: true
                visible: Config.options.bar.m3.resources.alwaysShowCpuTemp
                percentage: ResourceUsage.cpuTemp / 100
            }
            Resource {
                Layout.alignment: Qt.AlignHCenter
                iconName: "hard_drive"
                vertical: true
                visible: Config.options.bar.m3.resources.alwaysShowDisk
                percentage: ResourceUsage.diskUsedPercentage
            }
            Resource {
                Layout.alignment: Qt.AlignHCenter
                iconName: "swap_horiz"
                vertical: true
                visible: Config.options.bar.m3.resources.alwaysShowSwap
                percentage: ResourceUsage.swapUsedPercentage
                warningThreshold: Config.options.bar.m3.resources.swapWarningThreshold
            }
        }
    }

    colMaterial: Component {
        ColumnLayout {
            spacing: 7
            Resource {
                Layout.alignment: Qt.AlignHCenter
                iconName: "memory"
                vertical: true
                visible: Config.options.bar.m3.resources.alwaysShowRam
                percentage: ResourceUsage.memoryUsedPercentage
                warningThreshold: Config.options.bar.m3.resources.memoryWarningThreshold
            }
            Resource {
                Layout.alignment: Qt.AlignHCenter
                iconName: "planner_review"
                vertical: true
                visible: Config.options.bar.m3.resources.alwaysShowCpu
                percentage: ResourceUsage.cpuUsage
                warningThreshold: Config.options.bar.m3.resources.cpuWarningThreshold
            }
            Resource {
                Layout.alignment: Qt.AlignHCenter
                iconName: "thermostat"
                vertical: true
                visible: Config.options.bar.m3.resources.alwaysShowCpuTemp
                percentage: ResourceUsage.cpuTemp / 100
            }
            Resource {
                Layout.alignment: Qt.AlignHCenter
                iconName: "hard_drive"
                vertical: true
                visible: Config.options.bar.m3.resources.alwaysShowDisk
                percentage: ResourceUsage.diskUsedPercentage
            }
            Resource {
                Layout.alignment: Qt.AlignHCenter
                iconName: "swap_horiz"
                vertical: true
                visible: Config.options.bar.m3.resources.alwaysShowSwap
                percentage: ResourceUsage.swapUsedPercentage
                warningThreshold: Config.options.bar.m3.resources.swapWarningThreshold
            }
        }
    }

    ResourcesPopup {
        id: resourcesPopup
        hoverTarget: root
        hoverActivates: !root.clickForDetails
        closeOnOutsideClick: root.clickForDetails
        onRequestClose: active = false
    }
}
