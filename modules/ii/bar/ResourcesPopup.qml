import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: popup

    property QtObject resourceMonitor: ResourceUsageMonitor { active: popup.active }

    component ResourceItem: RowLayout {
        id: resourceItem
        required property string icon
        required property string label
        required property string value
        spacing: 4

        MaterialSymbol {
            text: resourceItem.icon
            color: Appearance.colors.colOnSurfaceVariant
            iconSize: Appearance.font.pixelSize.large
        }
        StyledText {
            text: resourceItem.label
            color: Appearance.colors.colOnSurfaceVariant
        }
        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            visible: resourceItem.value !== ""
            color: Appearance.colors.colOnSurfaceVariant
            text: resourceItem.value
        }
    }

    component ResourceHeaderItem: Row {
        id: headerItem
        required property var icon
        required property var label
        spacing: 5

        MaterialSymbol {
            anchors.verticalCenter: parent.verticalCenter
            fill: 0
            font.weight: Font.Medium
            text: headerItem.icon
            iconSize: Appearance.font.pixelSize.large
            color: Appearance.colors.colOnSurfaceVariant
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: headerItem.label
            font {
                weight: Font.Medium
                pixelSize: Appearance.font.pixelSize.normal
            }
            color: Appearance.colors.colOnSurfaceVariant
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: 12

        // Helper functions inline
        function formatKB(kb) {
            return (kb / (1024 * 1024)).toFixed(1) + " GB";
        }
        function formatTemp(temp) {
            return temp + "°C"
        }

        Column {
            anchors.top: parent.top
            spacing: 8

            ResourceHeaderItem {
                icon: "memory"
                label: "RAM"
            }
            Column {
                spacing: 4
                ResourceItem {
                    icon: "clock_loader_60"
                    label: Translation.tr("Used:")
                    value: (ResourceUsage.memoryUsed / (1024 * 1024)).toFixed(1) + " GB"
                }
                ResourceItem {
                    icon: "check_circle"
                    label: Translation.tr("Available") + ":"
                    value: (ResourceUsage.memoryFree / (1024 * 1024)).toFixed(1) + " GB"
                }
                ResourceItem {
                    icon: "empty_dashboard"
                    label: Translation.tr("Total:")
                    value: (ResourceUsage.memoryTotal / (1024 * 1024)).toFixed(1) + " GB"
                }
            }
        }

        Column {
            anchors.top: parent.top
            spacing: 8

            ResourceHeaderItem {
                icon: "thermostat"
                label: Translation.tr("Temperature")
            }
            Column {
                spacing: 4
                ResourceItem {
                    icon: "memory"
                    label: "CPU:"
                    value: ResourceUsage.cpuTemp + "°C"
                }
                ResourceItem {
                    icon: "memory_alt"
                    label: "GPU:"
                    value: ResourceUsage.gpuTemp + "°C"
                }
            }
        }

        Column {
            anchors.top: parent.top
            spacing: 8

            ResourceHeaderItem {
                icon: "planner_review"
                label: "CPU"
            }
            Column {
                spacing: 4
                ResourceItem {
                    icon: "bolt"
                    label: Translation.tr("Load:")
                    value: (ResourceUsage.cpuUsage > 0.8 ? Translation.tr("High") : ResourceUsage.cpuUsage > 0.4 ? Translation.tr("Medium") : Translation.tr("Low")) + ` (${Math.round(ResourceUsage.cpuUsage * 100)}%)`
                }
                ResourceItem {
                    icon: "memory_alt"
                    label: Translation.tr("GPU:")
                    value: ResourceUsage.gpuUsageAvailable
                        ? (ResourceUsage.gpuUsage > 0.8 ? Translation.tr("High") : ResourceUsage.gpuUsage > 0.4 ? Translation.tr("Medium") : Translation.tr("Low")) + ` (${Math.round(ResourceUsage.gpuUsage * 100)}%)`
                        : "--"
                }
            }
        }
    }
}
