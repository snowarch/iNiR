import qs.modules.common.widgets
import qs.services
import qs.modules.common
import QtQuick
import QtQuick.Layouts
import qs.modules.bar as Bar

MouseArea {
    id: root
    property bool alwaysShowAllResources: false
    implicitHeight: columnLayout.implicitHeight
    implicitWidth: columnLayout.implicitWidth
    hoverEnabled: true

    property QtObject resourceMonitor: ResourceUsageMonitor { target: root }

    ColumnLayout {
        id: columnLayout
        spacing: 10
        anchors.fill: parent

        Resource {
            Layout.alignment: Qt.AlignHCenter
            iconName: "memory"
            percentage: ResourceUsage.memoryUsedPercentage
            shown: Config.options?.bar?.resources?.showMemoryIndicator ?? true
            warningThreshold: Config.options?.bar?.resources?.memoryWarningThreshold ?? 90
        }

        Resource {
            Layout.alignment: Qt.AlignHCenter
            iconName: "swap_horiz"
            percentage: ResourceUsage.swapUsedPercentage
            shown: Config.options?.bar?.resources?.showSwapIndicator ?? true
            warningThreshold: Config.options?.bar?.resources?.swapWarningThreshold ?? 90
        }

        Resource {
            Layout.alignment: Qt.AlignHCenter
            iconName: "planner_review"
            percentage: ResourceUsage.cpuUsage
            shown: Config.options?.bar?.resources?.showCpuIndicator ?? true
            warningThreshold: Config.options?.bar?.resources?.cpuWarningThreshold ?? 90
        }

        Resource {
            Layout.alignment: Qt.AlignHCenter
            iconName: "memory_alt"
            percentage: ResourceUsage.gpuUsage
            shown: Config.options?.bar?.resources?.showGpuIndicator ?? true
            warningThreshold: Config.options?.bar?.resources?.gpuWarningThreshold ?? 90
        }

    }

    Bar.ResourcesPopup {
        hoverTarget: root
    }
}
