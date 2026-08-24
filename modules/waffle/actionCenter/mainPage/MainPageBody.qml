import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.waffle.looks
import qs.modules.waffle.actionCenter
import qs.modules.waffle.actionCenter.screenTime

BodyRectangle {
    id: root
    implicitHeight: contentLayout.implicitHeight

    ColumnLayout {
        id: contentLayout
        anchors.fill: parent
        spacing: 0

        MainPageBodyToggles {
            id: togglesContainer
            Layout.fillWidth: true
        }

        Rectangle {
            implicitHeight: 1
            Layout.fillWidth: true
            color: Looks.colors.bgPanelSeparator
        }

        MainPageBodySliders {
            Layout.margins: Looks.dp(12)
            Layout.topMargin: Looks.dp(18)
            Layout.bottomMargin: Looks.dp(14)
        }

        // Screen Time entry point
        WBorderlessButton {
            visible: Config.options?.sidebar?.screenTime?.enable ?? false
            Layout.fillWidth: true
            Layout.leftMargin: Looks.dp(8)
            Layout.rightMargin: Looks.dp(8)
            Layout.bottomMargin: Looks.dp(8)

            Component {
                id: screenTimePageComp
                ScreenTimePage {}
            }

            onClicked: {
                if (ActionCenterContext.stackView)
                    ActionCenterContext.stackView.push(screenTimePageComp)
            }

            contentItem: RowLayout {
                spacing: Looks.dp(8)
                FluentIcon {
                    icon: "schedule"
                    implicitSize: 18
                    color: Looks.colors.accent
                }
                WText {
                    Layout.fillWidth: true
                    text: Translation.tr("Screen Time")
                }
                WText {
                    text: ScreenTime.formatDuration((ScreenTime.todayData?.totalSeconds) || 0)
                    font.family: Looks.font.family.monospace
                    color: Looks.colors.subfg
                }
                FluentIcon {
                    icon: "chevron-right"
                    implicitSize: 16
                    color: Looks.colors.subfg
                }
            }
        }
    }
}
