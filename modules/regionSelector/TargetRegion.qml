pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import Quickshell
import Quickshell.Widgets

Rectangle {
    id: root
    required property var clientDimensions

    property bool hasValidGeometry: !!(clientDimensions
        && clientDimensions.at && clientDimensions.size
        && clientDimensions.at.length >= 2 && clientDimensions.size.length >= 2)

    property color colBackground: Qt.alpha("#88111111", 0.9)
    property color colForeground: "#ddffffff"
    property bool showLabel: Config.options?.regionSelector?.targetRegions?.showLabel ?? true
    property bool showIcon: false
    property bool targeted: false
    property color borderColor
    property color fillColor: "transparent"
    property string text: ""
    property real textPadding: 10
    z: 2
    color: fillColor
    border.color: borderColor
    border.width: targeted ? 4 : 2
    radius: Appearance.rounding.unsharpen

    visible: hasValidGeometry && opacity > 0
    Behavior on opacity {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }
    x: hasValidGeometry ? clientDimensions.at[0] : 0
    y: hasValidGeometry ? clientDimensions.at[1] : 0
    width: hasValidGeometry ? clientDimensions.size[0] : 0
    height: hasValidGeometry ? clientDimensions.size[1] : 0

    Loader {
        anchors {
            top: parent.top
            left: parent.left
            topMargin: root.textPadding
            leftMargin: root.textPadding
        }
        
        active: root.showLabel
        sourceComponent: Rectangle {
            property real verticalPadding: 5
            property real horizontalPadding: 10
            radius: Appearance.rounding.verysmall
            color: root.colBackground
            border.width: 1
            border.color: Appearance.m3colors.m3outlineVariant
            implicitWidth: regionInfoRow.implicitWidth + horizontalPadding * 2
            implicitHeight: regionInfoRow.implicitHeight + verticalPadding * 2

            Row {
                id: regionInfoRow
                anchors.centerIn: parent
                spacing: 4

                Loader {
                    id: regionIconLoader
                    active: root.showIcon
                    visible: active
                    sourceComponent: IconImage {
                        implicitSize: Appearance.font.pixelSize.larger
                        source: Quickshell.iconPath(AppSearch.guessIcon(root.text), "image-missing")
                    }
                }

                StyledText {
                    id: regionText
                    text: root.text
                    color: root.colForeground
                }
            }
        }
    }
}