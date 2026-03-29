import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.modules.common.functions
import qs.modules.waffle.looks

AcrylicButton {
    id: root

    property var altAction: () => {}
    property var middleClickAction: () => {}
    readonly property var panelScreen: root.QsWindow?.window?.screen ?? null
    readonly property real panelScale: Looks.barScale(panelScreen)

    Layout.fillHeight: true
    topInset: Math.max(3, Looks.scaledBar(4, panelScreen))
    bottomInset: Math.max(3, Looks.scaledBar(4, panelScreen))
    leftInset: 0
    rightInset: 0
    horizontalPadding: Math.max(6, Looks.scaledBar(8, panelScreen))

    colBackground: ColorUtils.transparentize(Looks.colors.bg1)

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton | Qt.MiddleButton
        propagateComposedEvents: true
        onClicked: event => {
            if (event.button === Qt.RightButton) root.altAction();
            if (event.button === Qt.MiddleButton) root.middleClickAction();
        }
    }
}
