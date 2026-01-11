import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

/**
 * Material 3 FAB.
 */
RippleButton {
    id: root
    property string iconText: "add"
    property bool expanded: false
    property real baseSize: 56
    property real elementSpacing: 5
    implicitWidth: expanded ? (Math.max(contentRowLayout.implicitWidth + 10 * 2, baseSize)) : baseSize
    implicitHeight: baseSize
    buttonRadius: baseSize / 14 * 4
    colBackground: Appearance.inirEverywhere ? Appearance.inir.colPrimaryContainer
                 : Appearance.auroraEverywhere ? Appearance.m3colors.m3primaryContainer
                 : Appearance.colors.colPrimaryContainer
    colBackgroundHover: Appearance.inirEverywhere ? Appearance.inir.colPrimaryContainerHover
                      : Appearance.auroraEverywhere ? Appearance.m3colors.m3primaryContainer
                      : Appearance.colors.colPrimaryContainerHover
    colRipple: Appearance.inirEverywhere ? Appearance.inir.colPrimaryContainerActive
             : Appearance.auroraEverywhere ? Appearance.m3colors.m3primaryContainer
             : Appearance.colors.colPrimaryContainerActive
    property color colOnBackground: Appearance.inirEverywhere ? Appearance.inir.colOnPrimaryContainer
                                  : Appearance.auroraEverywhere ? Appearance.m3colors.m3onPrimaryContainer
                                  : Appearance.colors.colOnPrimaryContainer
    contentItem: Row {
        id: contentRowLayout
        property real horizontalMargins: (root.baseSize - icon.width) / 2
        anchors {
            verticalCenter: parent?.verticalCenter
            left: parent?.left
            leftMargin: contentRowLayout.horizontalMargins
        }
        spacing: 0

        MaterialSymbol {
            id: icon
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            iconSize: 26
            color: root.colOnBackground
            text: root.iconText
        }
        Loader {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.buttonText?.length > 0
            active: true
            sourceComponent: Revealer {
                visible: root.expanded || implicitWidth > 0
                reveal: root.expanded
                width: reveal ? (buttonText.implicitWidth + root.elementSpacing + contentRowLayout.horizontalMargins) : 0
                StyledText {
                    id: buttonText
                    anchors {
                        left: parent.left
                        leftMargin: root.elementSpacing
                        verticalCenter: parent.verticalCenter
                    }
                    text: root.buttonText
                    color: root.colOnBackground
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: 450
                }
            }
        }
    }
}
