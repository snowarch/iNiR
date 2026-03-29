pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.waffle.looks
import qs.modules.waffle.actionCenter
import qs.modules.waffle.actionCenter.mainPage

WBarAttachedPanelContent {
    id: root

    revealFromSides: true
    revealFromLeft: false

    readonly property bool barAtBottom: Config.options?.waffles?.bar?.bottom ?? false
    
    contentItem: ColumnLayout {
        // This somewhat sophisticated anchoring is needed to make opening anim not jump abruptly when stuff appear
        anchors {
            left: parent.left
            right: parent.right
            top: root.barAtBottom ? undefined : parent.top
            bottom: root.barAtBottom ? parent.bottom : undefined
            margins: root.visualMargin
            bottomMargin: 0
        }
        spacing: Looks.dp(12)

        WPane {
            id: mediaPane
            readonly property bool hasActivePlayer: MprisController.activePlayer != null
            visible: hasActivePlayer
            Layout.fillWidth: true
            screenX: root.panelScreenX + root.visualMargin * 2
            screenY: root.panelScreenY + root.visualMargin * 2
            screenWidth: root._screenW
            screenHeight: root._screenH
            contentItem: MediaPaneContent {}
        }
        WPane {
            Layout.fillWidth: true
            screenX: root.panelScreenX + root.visualMargin * 2
            screenY: root.panelScreenY + root.visualMargin * 2 + (mediaPane.visible ? mediaPane.height + Looks.dp(12) : 0)
            screenWidth: root._screenW
            screenHeight: root._screenH
            contentItem: WStackView {
                id: stackView
                implicitWidth: initItem.implicitWidth
                implicitHeight: initItem.implicitHeight

                initialItem: WPanelPageColumn {
                    id: initItem
                    MainPageBody {}
                    WPanelSeparator {}
                    MainPageFooter {}
                }

                Component.onCompleted: {
                    ActionCenterContext.stackView = this;
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.BackButton
                    onClicked: {
                        ActionCenterContext.back();
                    }
                }
            }
        }
    }
}
