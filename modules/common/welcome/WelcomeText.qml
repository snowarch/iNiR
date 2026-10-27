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

StyledText {
    readonly property var root: WelcomeHost.wizard
    defaultFont: root.welcomeFontMain
    font.letterSpacing: 0
    font.variableAxes: ({})
}
