pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Qt5Compat.GraphicalEffects
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.overlay

StyledOverlayWidget {
    id: root
    minimumWidth: 300
    minimumHeight: 200

    Component.onCompleted: ResourceUsage.ensureRunning()
    property list<var> resources: [
        {
            "icon": "planner_review",
            "name": Translation.tr("CPU"),
            "history": ResourceUsage.cpuUsageHistory,
            "maxAvailableString": ResourceUsage.maxAvailableCpuString,
            "detailString": Translation.tr("Temp: %1°C").arg(ResourceUsage.cpuTemp)
        },
        {
            "icon": "memory_alt",
            "name": Translation.tr("GPU"),
            "history": ResourceUsage.gpuUsageHistory,
            "maxAvailableString": ResourceUsage.maxAvailableGpuString,
            "detailString": Translation.tr("Temp: %1°C").arg(ResourceUsage.gpuTemp)
        },
        {
            "icon": "memory",
            "name": Translation.tr("RAM"),
            "history": ResourceUsage.memoryUsageHistory,
            "maxAvailableString": ResourceUsage.maxAvailableMemoryString,
            "detailString": Translation.tr("Used: %1 GB").arg((ResourceUsage.memoryUsed / (1024 * 1024)).toFixed(1))
        },
        {
            "icon": "swap_horiz",
            "name": Translation.tr("Swap"),
            "history": ResourceUsage.swapUsageHistory,
            "maxAvailableString": ResourceUsage.maxAvailableSwapString,
            "detailString": Translation.tr("Used: %1 GB").arg((ResourceUsage.swapUsed / (1024 * 1024)).toFixed(1))
        },
    ]

    contentItem: OverlayBackground {
        id: contentItem
        radius: root.contentRadius
        property real padding: 4
        ColumnLayout {
            id: contentColumn
            anchors {
                fill: parent
                margins: parent.padding
            }
            spacing: 8

            SecondaryTabBar {
                id: tabBar

                currentIndex: Persistent.states.overlay.resources.tabIndex
                onCurrentIndexChanged: {
                    Persistent.states.overlay.resources.tabIndex = tabBar.currentIndex;
                }

                Repeater {
                    model: root.resources.length
                    delegate: SecondaryTabButton {
                        required property int index
                        property var modelData: root.resources[index]
                        buttonIcon: modelData.icon
                        buttonText: modelData.name
                    }
                }
            }

            ResourceSummary {
                Layout.margins: 8
                history: root.resources[tabBar.currentIndex]?.history ?? []
                maxAvailableString: root.resources[tabBar.currentIndex]?.maxAvailableString ?? "--"
                detailString: root.resources[tabBar.currentIndex]?.detailString ?? ""
            }
        }
    }

    component ResourceSummary: RowLayout {
        id: resourceSummary
        required property list<real> history
        required property string maxAvailableString
        required property string detailString
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 12

        ColumnLayout {
            spacing: 2
            StyledText {
                text: (resourceSummary.history[resourceSummary.history.length - 1] * 100).toFixed(1) + "%"
                font {
                    family: Appearance.font.family.numbers
                    variableAxes: Appearance.font.variableAxes.numbers
                    pixelSize: Appearance.font.pixelSize.huge
                }
            }
            StyledText {
                text: Translation.tr("of %1").arg(resourceSummary.maxAvailableString)
                font {
                    // family: Appearance.font.family.numbers
                    // variableAxes: Appearance.font.variableAxes.numbers
                    pixelSize: Appearance.font.pixelSize.smallie
                }
                color: Appearance.colors.colSubtext
            }
            StyledText {
                text: resourceSummary.detailString
                font.pixelSize: Appearance.font.pixelSize.smallie
                color: Appearance.colors.colSubtext
                visible: text.length > 0
            }
            Item {
                Layout.fillHeight: true
            }
        }
        Rectangle {
            id: graphBg
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Appearance.rounding.small
            // ZZZ: a recessed carbon plate for the graph; the bright signal is for
            // the plotted line, not the track behind it.
            color: Appearance.zzzEverywhere ? Appearance.zzz.bg3 : Appearance.colors.colSecondaryContainer
            Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: graphBg.width
                    height: graphBg.height
                    radius: graphBg.radius
                }
            }
            Graph {
                anchors.fill: parent
                values: root.resources[tabBar.currentIndex]?.history ?? []
                points: ResourceUsage.historyLength
                alignment: Graph.Alignment.Right
            }
        }
    }
}
