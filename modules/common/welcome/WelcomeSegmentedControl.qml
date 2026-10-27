import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

RowLayout {
    readonly property var root: WelcomeHost.wizard
    id: segmented

    property var options: []
    property var currentValue: null
    signal selected(var value)

    spacing: 6

    Repeater {
        model: segmented.options

        RippleButton {
            id: segmentButton
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: 36
            readonly property bool active: segmented.currentValue != null
                && segmented.currentValue == modelData.value
            buttonRadius: root.welcomeControlRadius
            rippleEnabled: true
            cookieMorphing: false
            colBackground: active ? root.welcomeAccentContainer
                : root.welcomeSegmentFill
            colBackgroundHover: active ? root.welcomeAccentHover : root.welcomeSurfaceHigh
            colRipple: root.welcomeSurfaceHighest
            onClicked: segmented.selected(modelData.value)

            contentItem: Item {
                WelcomeText {
                    anchors.centerIn: parent
                    text: segmentButton.modelData.displayName
                    font.family: root.welcomeFontTitle
                    font.pixelSize: root.welcomeFontCaption
                    font.weight: segmentButton.active ? Font.Bold : Font.Medium
                    color: segmentButton.active ? root.welcomeOnSurface : root.welcomeSecondaryText
                    horizontalAlignment: Text.AlignHCenter
                }

                MaterialSymbol {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: segmentButton.modelData.icon || ""
                    iconSize: 15
                    color: segmentButton.active ? root.welcomeAccent : root.welcomeSecondaryText
                }
            }
        }
    }
}
