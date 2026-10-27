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

RippleButton {
    readonly property var root: WelcomeHost.wizard
    id: listAction

    property string materialIcon: ""
    property string title: ""
    property string subtitle: ""

    implicitHeight: 46
    buttonRadius: root.welcomeControlRadius
    rippleEnabled: true
    cookieMorphing: false
    colBackground: root.welcomeSegmentFill
    colBackgroundHover: root.welcomeSurfaceHigh
    colRipple: root.welcomeSurfaceHighest

    contentItem: RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 10

        MaterialSymbol {
            text: listAction.materialIcon
            iconSize: 18
            color: root.welcomeAccent
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            WelcomeText {
                Layout.fillWidth: true
                text: listAction.title
                font.family: root.welcomeFontTitle
                font.pixelSize: root.welcomeFontBody
                font.weight: Font.DemiBold
                color: root.welcomeOnSurface
                elide: Text.ElideRight
            }
            WelcomeText {
                Layout.fillWidth: true
                text: listAction.subtitle
                font.pixelSize: root.welcomeFontCaption
                color: root.welcomeSecondaryText
                elide: Text.ElideRight
            }
        }

        MaterialSymbol {
            text: "arrow_forward"
            iconSize: 16
            color: root.welcomeSecondaryText
            opacity: 0.7
        }
    }
}
