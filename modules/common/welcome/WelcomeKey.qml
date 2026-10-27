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

Rectangle {
    readonly property var root: WelcomeHost.wizard
    id: keyCap
    property string key: ""

    implicitWidth: keyLabel.implicitWidth + 14
    implicitHeight: 24
    radius: root.welcomeKeyRadius
    color: root.welcomeSurfaceHighest
    border.width: 1
    border.color: ColorUtils.applyAlpha(root.welcomeOutline, 0.55)

    WelcomeText {
        id: keyLabel
        anchors.centerIn: parent
        text: keyCap.key
        font.family: root.welcomeFontMain
        font.pixelSize: root.welcomeFontMeta
        font.weight: Font.Medium
        color: root.welcomeOnSurface
    }
}
