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
    id: actionButton

    property string label: ""
    property string materialIcon: ""
    property bool primary: false

    implicitWidth: actionContent.implicitWidth + 24
    implicitHeight: 42
    buttonRadius: root.welcomeControlRadius
    rippleEnabled: true
    cookieMorphing: false
    colBackground: primary ? root.welcomeAccent : "transparent"
    colBackgroundHover: primary
        ? ColorUtils.mix(root.welcomeAccent, root.welcomeOnAccent, 0.88)
        : root.welcomeSurfaceHigh
    colRipple: primary
        ? ColorUtils.applyAlpha(root.welcomeOnAccent, 0.22)
        : root.welcomeSurfaceHighest

    contentItem: RowLayout {
        id: actionContent
        anchors.centerIn: parent
        spacing: actionButton.materialIcon.length > 0 ? 6 : 0

        MaterialSymbol {
            visible: actionButton.materialIcon.length > 0
            text: actionButton.materialIcon
            iconSize: 17
            color: actionButton.primary ? root.welcomeOnAccent : root.welcomeAccent
        }

        WelcomeText {
            text: actionButton.label
            font.family: root.welcomeFontTitle
            font.pixelSize: root.welcomeFontBody
            font.weight: actionButton.primary ? Font.Bold : Font.Medium
            color: actionButton.primary ? root.welcomeOnAccent : root.welcomeOnSurface
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
