pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.waffle.looks

WBarAttachedPanelContent {
    id: root

    property Timer timer: Timer {
        id: autoCloseTimer
        running: true
        interval: Config.options?.osd?.timeout ?? 3000
        repeat: false
        onTriggered: root.close()
    }

    Connections {
        target: KeyboardIndicators
        function onPopupSequenceChanged() {
            autoCloseTimer.restart()
        }
    }

    contentItem: WPane {
        screenX: root.panelScreenX + root.visualMargin
        screenY: root.panelScreenY + root.visualMargin
        screenWidth: root._screenW
        screenHeight: root._screenH
        contentItem: Item {
            implicitWidth: contentRow.implicitWidth + 24
            implicitHeight: 46

            RowLayout {
                id: contentRow
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                FluentIcon {
                    Layout.alignment: Qt.AlignVCenter
                    icon: KeyboardIndicators.popupFluentIcon
                    implicitSize: 18
                }

                WText {
                    Layout.fillWidth: true
                    text: KeyboardIndicators.popupText
                    font.pixelSize: Looks.font.pixelSize.normal
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }
        }
    }
}
