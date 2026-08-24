pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.waffle.looks

// Text field setting row - Windows 11 style
WSettingsRow {
    id: root

    property string placeholderText: ""
    property string text: ""

    signal textEdited(string newText)

    control: Component {
        Rectangle {
            implicitWidth: Looks.dp(220)
            implicitHeight: Looks.dp(36)
            radius: Looks.settings.radiusMedium
            color: Looks.colors.inputBg
            border.width: fieldInput.activeFocus ? 2 : 1
            border.color: fieldInput.activeFocus
                ? Looks.colors.accent
                : Looks.settings.strokeStrong

            Behavior on border.color {
                animation: ColorAnimation { duration: Looks.transition.enabled ? 70 : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
            }
            Behavior on border.width {
                animation: NumberAnimation { duration: Looks.transition.enabled ? Looks.transition.duration.ultraFast : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
            }

            Item {
                anchors {
                    fill: parent
                    leftMargin: Looks.dp(12)
                    rightMargin: Looks.dp(12)
                }

                WTextInput {
                    id: fieldInput
                    anchors.fill: parent
                    font.pixelSize: Looks.font.pixelSize.normal
                    color: Looks.colors.fg
                    selectByMouse: true
                    clip: true
                    text: root.text
                    onTextEdited: root.textEdited(text)
                }

                WText {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    text: root.placeholderText
                    color: Looks.colors.subfg
                    font.pixelSize: fieldInput.font.pixelSize
                    visible: !fieldInput.text && !fieldInput.activeFocus
                }
            }
        }
    }
}
