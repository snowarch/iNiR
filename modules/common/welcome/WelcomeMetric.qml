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

Item {
    readonly property var root: WelcomeHost.wizard
    id: metric

    property string value: "—"
    property string label: ""
    property color accent: root.welcomeAccent

    implicitHeight: 58

    RowLayout {
        anchors.fill: parent
        spacing: 9

        Rectangle {
            Layout.preferredWidth: 3
            Layout.preferredHeight: 34
            radius: 2
            color: metric.accent
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: -1

            WelcomeText {
                Layout.fillWidth: true
                text: metric.value
                font.family: root.welcomeFontNumbers
                font.pixelSize: Appearance.font.pixelSize.huge * 1.12
                font.weight: Font.Bold
                color: metric.accent
            }

            WelcomeText {
                Layout.fillWidth: true
                text: metric.label
                font.pixelSize: root.welcomeFontMeta
                font.weight: Font.Medium
                color: root.welcomeSecondaryText
                elide: Text.ElideRight
            }
        }
    }
}
