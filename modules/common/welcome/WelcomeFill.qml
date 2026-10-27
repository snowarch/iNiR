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

// A quiet plate behind a card, for a family whose look asks for one.
Rectangle {
    readonly property var root: WelcomeHost.wizard
    anchors.fill: parent
    visible: root.welcomeQuietFill.a > 0
    radius: root.welcomePlateRadius
    color: root.welcomeQuietFill
    border.width: 0
}
